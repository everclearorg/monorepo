import { Web3Signer } from '@chimera-monorepo/adapters-web3signer';
import { Logger, RequestContext, createLoggingContext, createMethodContext } from '@chimera-monorepo/utils';
import { StoreManager } from '@chimera-monorepo/adapters-cache';
import { ChainService } from '@chimera-monorepo/chainservice';
import { SubgraphReader, SubgraphConfig } from '@chimera-monorepo/adapters-subgraph';

import { AppContext } from './lib/entities';
import { getConfig, getSubgraphReaderConfig } from './config';
import { bindServer } from './bindings/server';
import { bindInterval } from './bindings/interval';

const context: AppContext = {} as any;
export const getContext = () => context;

export const makeWatcher = async () => {
  try {
    await setupContext();

    // Bind server
    await bindServer();

    // Bind intevals
    bindInterval();
  } catch (err: unknown) {
    console.error('Error starting watcher :(', err);
    process.exit(1);
  }
};

export const setupContext = async () => {
  const { requestContext, methodContext } = createLoggingContext(setupContext.name);
  try {
    context.adapters = {} as any;

    /// MARK - Config
    context.config = await getConfig();
    context.logger = new Logger({
      level: context.config.logLevel,
      name: 'watcher',
      formatters: {
        level: (label) => {
          return { level: label.toUpperCase() };
        },
      },
    });
    context.logger.info('Watcher config generated.', requestContext, methodContext, {
      config: { ...context.config, abis: 'n/a' },
    });

    /// MARK - Adapters
    // Set up adapters.
    context.adapters.cache = await setupCache(context.config.redis, context.logger, requestContext);
    context.adapters.wallet = new Web3Signer(context.config.web3SignerUrl!);
    const hubChainServiceConfig: Record<string, object> = {
      [context.config.hub.domain]: {
        providers: context.config.hub.providers,
      },
    };
    context.adapters.chainservice = new ChainService(
      context.logger.child({ module: 'ChainService', level: context.config.logLevel }),
      { ...context.config.chains, ...hubChainServiceConfig },
      context.adapters.wallet,
      true, // Ghost instance, in the event that this is running in the same process as a solver.
    );

    const { domain: hubDomain, ...remainder } = context.config.hub;
    context.adapters.subgraph = await setupSubgraphReader(
      getSubgraphReaderConfig({ ...context.config.chains, [hubDomain]: remainder }),
      context.logger,
      requestContext,
    );
  } catch (error: unknown) {
    console.error('Error setup context Watcher! D: Who could have done this?', error);
  }
};

export const setupCache = async (
  redis: { host?: string; port?: number },
  logger: Logger,
  requestContext: RequestContext,
): Promise<StoreManager> => {
  const methodContext = createMethodContext(setupCache.name);

  logger.info('Cache instance setup in progress...', requestContext, methodContext, {});

  const cacheInstance = StoreManager.getInstance({
    redis: { host: redis.host, port: redis.port, instance: undefined },
    mock: !redis.host || !redis.port,
  });

  logger.info('Cache instance setup is done!', requestContext, methodContext, {
    host: redis.host,
    port: redis.port,
  });
  return cacheInstance;
};

export const setupSubgraphReader = async (
  readerConfig: SubgraphConfig,
  logger: Logger,
  requestContext: RequestContext,
): Promise<SubgraphReader> => {
  const methodContext = createMethodContext(setupSubgraphReader.name);
  logger.info('Subgraph reader setup in progress...', requestContext, methodContext);

  const subgraphReader = SubgraphReader.create(readerConfig);
  logger.info('Subgraph reader setup done', requestContext, methodContext);
  return subgraphReader;
};
