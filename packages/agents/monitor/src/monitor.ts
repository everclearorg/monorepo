import { Logger, RelayerType, createLoggingContext, delay, jsonifyError, sendHeartbeat } from '@chimera-monorepo/utils';
import { bindServer } from './bindings';
import { getConfig, shouldReloadEverclearConfig } from './config';
import { setupCache, setupSubgraphReader } from './setup';
import { providers } from 'ethers';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { SubgraphConfig } from '@chimera-monorepo/adapters-subgraph';
import { setupEverclearRelayer, setupGelatoRelayer } from '@chimera-monorepo/adapters-relayer';
import { runChecks } from './checklist';
import interval from 'interval-promise';
import { MonitorConfig } from './types';
import { AppContext, getContext } from './context';
import { getDatabase } from '@chimera-monorepo/database';

export const MonitorService = {
  SERVER: 'server',
  POLLER: 'poller',
} as const;
export type MonitorService = (typeof MonitorService)[keyof typeof MonitorService];

const DEFAULT_SUBGRAPH_TIMEOUT = 7500;
/**
 * Helper to get subgraph reader config
 * @param chains Chain entry of monitor config (includes hub domain)
 * @param hubConfig Optional hub config for Envio URL
 * @returns SubgraphConfig used to instantiate subgraph reader
 */
export const getSubgraphReaderConfig = (
  chains: MonitorConfig['chains'],
  hubConfig?: MonitorConfig['hub'],
): SubgraphConfig => {
  const subgraphs: Record<string, { endpoints: string[]; timeout: number }> = {};
  Object.keys(chains).forEach((domainId) => {
    subgraphs[domainId] = { endpoints: chains[domainId].subgraphUrls, timeout: DEFAULT_SUBGRAPH_TIMEOUT };
  });
  
  // Add Envio configuration if available from hub config
  const envioConfig: SubgraphConfig['envio'] = hubConfig?.envioSubgraphUrl
    ? {
        url: hubConfig.envioSubgraphUrl,
        timeout: DEFAULT_SUBGRAPH_TIMEOUT / 1000, // Convert to seconds
      }
    : undefined;

  return { subgraphs, ...(envioConfig && { envio: envioConfig }) };
};

export const startBlockMapPoller = async (config: MonitorConfig, blockMap: AppContext['adapters']['blockMap']) => {
  const domains = [...new Set([config.hub.domain, ...Object.keys(config.chains)])];
  await Promise.all(
    domains.map(async (domain) => {
      const chainConfig = domain === config.hub.domain ? config.hub : config.chains[domain];
      const providerUrls = chainConfig.providers ?? [];
      const type = domain === config.hub.domain ? 'evm' : (chainConfig as { network?: string })?.network ?? 'evm';
      await Promise.all(
        providerUrls.map(async (provider) => {
          const origin = URL.canParse(provider) ? new URL(provider).origin : provider;
          if (type !== 'evm') {
            return;
          }
          const ethProvider = new providers.JsonRpcProvider(provider);
          ethProvider.on('block', (blockNumber) => {
            if (!blockNumber) {
              return;
            }

            // Create the entry
            const entry = {
              rpcOrigin: origin,
              number: blockNumber,
              timestamp: Math.floor(Date.now() / 1_000),
            };
            // Add domain array if it exists
            if (!blockMap.has(domain)) blockMap.set(domain, []);

            // Replace idx for provider if more recent
            const idx = blockMap.get(domain)!.findIndex((a) => a.rpcOrigin.toLowerCase() === origin.toLowerCase());
            if (idx === -1) {
              // no entry for origin, push
              blockMap.get(domain)!.push(entry);
              return;
            }
            // Replace the entry IFF it is more recent
            if (blockMap.get(domain)![idx].number >= blockNumber) {
              return;
            }
            blockMap.get(domain)![idx] = entry;
          });
        }),
      );
    }),
  );
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

    context.adapters.blockMap = new Map();
    await startBlockMapPoller(context.config, context.adapters.blockMap);

    const { domain: hubDomain, ...remainder } = context.config.hub;
    context.adapters.subgraph = await setupSubgraphReader(
      getSubgraphReaderConfig({ ...context.config.chains, [hubDomain]: remainder }, context.config.hub),
      context.logger,
      requestContext,
    );

    context.adapters.database = await getDatabase(context.config.database.url, context.logger);
    context.logger.debug('Database setup', requestContext, methodContext);

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
    context.logger.debug('Relayers setup', requestContext, methodContext);

    /// MARK - Bindings
    if (service == MonitorService.SERVER) {
      await bindServer();
      await bindConfig();
    } else if (service == MonitorService.POLLER) {
      const timeout = 700_000;
      const start = Date.now();
      context.logger.info('Beginning checks', requestContext, methodContext, {
        start,
        timeout,
      });
      const ret = await Promise.race([
        runChecks(requestContext)
          .then(() => {
            context.logger.info('Running checks completed', requestContext, methodContext, {
              elapsed: Date.now() - start,
              start,
              timeout,
            });
          })
          .catch((e) => {
            context.logger.error('Failed to run checks', requestContext, methodContext, jsonifyError(e), {
              start,
              timeout,
              elapsed: Date.now() - start,
            });
            throw e;
          }),
        (async () => {
          await delay(timeout);
          return 'timeout';
        })(),
      ]);
      if (ret === 'timeout') {
        context.logger.warn('Running checks timed out', requestContext, methodContext, {
          timeout,
        });
      } else {
        context.logger.info('Completed all checks within time', requestContext, methodContext, {
          timeout,
          elapsed: Date.now() - start,
        });
      }
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
          getSubgraphReaderConfig({ ...context.config.chains, [hubDomain]: remainder }, context.config.hub),
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
