import {
  Logger,
  RelayerType,
  createLoggingContext,
  delay,
  jsonifyError,
  sendHeartbeat,
  chainWrapper,
  setTriagePersistenceStore,
  TriageProcessingRecord,
} from '@chimera-monorepo/utils';
import { bindServer } from './bindings';
import { getConfig, shouldReloadEverclearConfig } from './config';
import { setupCache, setupSubgraphReader } from './setup';
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
      getSubgraphReaderConfig({ ...context.config.chains, [hubDomain]: remainder }, context.config.hub),
      context.logger,
      requestContext,
    );

    context.adapters.database = await getDatabase(context.config.database.url, context.logger);
    context.logger.debug('Database setup', requestContext, methodContext);

    setTriagePersistenceStore({
      hasProcessed: async (fingerprint: string) => {
        return context.adapters.database.isTriageFingerprintProcessed(fingerprint);
      },
      tryReserve: async (record: TriageProcessingRecord) => {
        return context.adapters.database.tryReserveTriageFingerprint({
          fingerprint: record.fingerprint,
          reportType: record.reportType,
          severity: record.severity,
          env: record.env,
          network: record.network,
          ids: record.ids,
          reason: record.reason,
          triageMode: record.triageMode,
          triageResult: record.triageResult,
          providerUsed: record.providerUsed,
          modelUsed: record.modelUsed,
          triageLatencyMs: record.triageLatencyMs,
          autoResolveAttempted: record.autoResolveAttempted,
          autoResolveSucceeded: record.autoResolveSucceeded,
          autoResolveReasonCode: record.autoResolveReasonCode,
          expiresAt: record.expiresAt,
        });
      },
      finalize: async (record: TriageProcessingRecord) => {
        await context.adapters.database.finalizeTriageFingerprint({
          fingerprint: record.fingerprint,
          reportType: record.reportType,
          severity: record.severity,
          env: record.env,
          network: record.network,
          ids: record.ids,
          reason: record.reason,
          triageMode: record.triageMode,
          triageResult: record.triageResult,
          providerUsed: record.providerUsed,
          modelUsed: record.modelUsed,
          triageLatencyMs: record.triageLatencyMs,
          autoResolveAttempted: record.autoResolveAttempted,
          autoResolveSucceeded: record.autoResolveSucceeded,
          autoResolveReasonCode: record.autoResolveReasonCode,
          expiresAt: record.expiresAt,
        });
      },
      setAutoResolveOutcome: async (fingerprint: string, succeeded: boolean, reasonCode?: string) => {
        await context.adapters.database.setTriageAutoResolveOutcome(fingerprint, succeeded, reasonCode);
      },
      pruneExpired: async () => {
        return context.adapters.database.pruneExpiredTriageFingerprints();
      },
    });

    // Adapters - relayers
    context.adapters.relayers = [];
    for (const relayerConfig of context.config.relayers) {
      const relayer =
        relayerConfig.type == RelayerType.Gelato
          ? await setupGelatoRelayer(relayerConfig.apiKey)
          : relayerConfig.type == RelayerType.Everclear
            ? await setupEverclearRelayer(relayerConfig.url)
            : undefined;
      if (!relayer) {
        throw new Error(`Unknown relayer configured, relayer: ${relayerConfig}`);
      }
      context.adapters.relayers.push({
        instance: relayer,
        apiKey: relayerConfig.apiKey,
        type: relayerConfig.type as RelayerType,
      });
    }
    context.logger.debug('Relayers setup', requestContext, methodContext);

    // Initialize the block data map for sharing block data between checks
    context.adapters.blockMap = new Map<string, { number: number; timestamp: number }>();

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
