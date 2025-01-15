import { Logger, RelayerType, createLoggingContext, jsonifyError, sendHeartbeat } from '@chimera-monorepo/utils';
import { bindServer } from './bindings';
import { getConfig, shouldReloadEverclearConfig } from './config';
import { setupCache, setupSubgraphReader } from './setup';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { SubgraphConfig } from '@chimera-monorepo/adapters-subgraph';
import { setupEverclearRelayer, setupGelatoRelayer } from '@chimera-monorepo/adapters-relayer';
import { runChecks } from './checklist';
import interval from 'interval-promise';
import { MonitorConfig } from './types';
import { getContext } from './context';
import { getDatabase } from '@chimera-monorepo/database';

export const MonitorService = {
  SERVER: 'server',
  POLLER: 'poller',
} as const;
export type MonitorService = (typeof MonitorService)[keyof typeof MonitorService];

const DEFAULT_SUBGRAPH_TIMEOUT = 7500;
/**
 * Helper to get subgraph reader config
 * @param chains Chain entry of monitor config
 * @returns SubgraphConfig used to instantiate subgraph reader
 */
export const getSubgraphReaderConfig = (chains: MonitorConfig['chains']): SubgraphConfig => {
  const subgraphs: Record<string, { endpoints: string[]; timeout: number }> = {};
  Object.keys(chains).forEach((domainId) => {
    subgraphs[domainId] = { endpoints: chains[domainId].subgraphUrls, timeout: DEFAULT_SUBGRAPH_TIMEOUT };
  });
  return { subgraphs };
};

export const makeMonitor = async (service: MonitorService) => {
  /// Load necessary configs
  const { requestContext, methodContext } = createLoggingContext(makeMonitor.name);
  const context = getContext();

  try {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    context.adapters = {} as any;

    /// MARK - Config
    context.config = await getConfig();

    /// MARK - Logger
    context.logger = new Logger({
      level: context.config.logLevel,
      name: 'monitor',
      formatters: {
        level: (label) => {
          return { level: label.toUpperCase() };
        },
      },
    });
    context.logger.info('Generated config.', requestContext, methodContext, {
      config: { ...context.config, abis: 'N/A' },
    });

    /// MARK - Adapters
    context.adapters.cache = await setupCache(
      context.config.redis.host,
      context.config.redis.port,
      context.logger,
      requestContext,
    );

    context.adapters.chainreader = new ChainReader(context.logger.child({ module: 'ChainReader' }), {
      ...context.config.chains,
      [context.config.hub.domain]: context.config.hub,
    });

    const { domain: hubDomain, ...remainder } = context.config.hub;
    context.adapters.subgraph = await setupSubgraphReader(
      getSubgraphReaderConfig({ ...context.config.chains, [hubDomain]: remainder }),
      context.logger,
      requestContext,
    );

    context.adapters.database = await getDatabase(context.config.database.url, context.logger);

    // Adapters - relayers
    context.adapters.relayers = [];
    for (const relayerConfig of context.config.relayers) {
      const setupFunc =
        relayerConfig.type == RelayerType.Gelato
          ? setupGelatoRelayer
          : relayerConfig.type == RelayerType.Everclear
            ? setupEverclearRelayer
            : undefined;
      if (!setupFunc) {
        throw new Error(`Unknown relayer configured, relayer: ${relayerConfig}`);
      }

      const relayer = await setupFunc(relayerConfig.url);
      context.adapters.relayers.push({
        instance: relayer,
        apiKey: relayerConfig.apiKey,
        type: relayerConfig.type as RelayerType,
      });
    }

    /// MARK - Bindings
    if (service == MonitorService.SERVER) {
      await bindServer();
      await bindConfig();
    } else if (service == MonitorService.POLLER) {
      await runChecks();
      if (context.config.healthUrls[service]) {
        const url = context.config.healthUrls[service]!;
        await sendHeartbeat(url, context.logger);
      }
    }

    context.logger.info('Monitor boot complete', requestContext, methodContext, {
      port: context.config.server.port,
      chains: [...Object.keys(context.config.chains)],
    });

    console.log(
      `                                                                                         
            _/_/_/_/  _/      _/  _/_/_/_/  _/_/_/      _/_/_/  _/        _/_/_/_/    _/_/    _/_/_/    
            _/        _/      _/  _/        _/    _/  _/        _/        _/        _/    _/  _/    _/   
          _/_/_/    _/      _/  _/_/_/    _/_/_/    _/        _/        _/_/_/    _/_/_/_/  _/_/_/      
          _/          _/  _/    _/        _/    _/  _/        _/        _/        _/    _/  _/    _/     
        _/_/_/_/      _/      _/_/_/_/  _/    _/    _/_/_/  _/_/_/_/  _/_/_/_/  _/    _/  _/    _/                                                                                                  
       `,
    );
  } catch (err: unknown) {
    console.error('Error starting monitor. Sad! :(', err);
    process.exit(1);
  }
};

/**
 * Bind the Everclear configuration changes and reload if necessary.
 */
export const bindConfig = async () => {
  const context = getContext();
  context.config = await getConfig();
  const { requestContext, methodContext } = createLoggingContext(bindConfig.name);
  const pollInterval = context.config.polling.config;
  interval(async () => {
    try {
      const { reloadConfig, reloadSubgraph } = await shouldReloadEverclearConfig();
      if (reloadConfig) {
        const config = await getConfig();
        context.config = config;
      }

      if (reloadSubgraph) {
        const { domain: hubDomain, ...remainder } = context.config.hub;
        context.adapters.subgraph = await setupSubgraphReader(
          getSubgraphReaderConfig({ ...context.config.chains, [hubDomain]: remainder }),
          context.logger,
          requestContext,
        );
      }
    } catch (e: unknown) {
      context.logger.error(
        'Error binding everclear config changes, waiting for next loop',
        requestContext,
        methodContext,
        jsonifyError(e as Error),
      );
    }
  }, pollInterval);
};
