/* eslint-disable @typescript-eslint/no-explicit-any */
import { Web3Signer } from '@chimera-monorepo/adapters-web3signer';
import { Logger, RequestContext, createLoggingContext, createMethodContext, jsonifyError } from '@chimera-monorepo/utils';
import { StoreManager } from '@chimera-monorepo/adapters-cache';
import { ChainService } from '@chimera-monorepo/chainservice';

import { AppContext } from './lib/entities';
import { getConfig } from './config';
import { bindServer, bindRelays, bindHealthServer } from './bindings';

const context: AppContext = {} as any;
export const getContext = () => context;

const logger = new Logger({
  level: 'info',
  name: 'relayer',
  formatters: {
    level: (label) => ({ level: label.toUpperCase() }),
  },
});

export const makeRelayer = async () => {
  try {
    await setupContext();

    const service = process.env.RELAYER_SERVICE ?? '';
    switch (service) {
      case 'poller':
        await bindHealthServer();
        await bindRelays();
        break;
      case 'server':
        await bindServer();
        break;
    }
  } catch (err: unknown) {
    (context.logger ?? logger).error('Error starting relayer :(', undefined, undefined, jsonifyError(err as Error));
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
      name: 'relayer',
      formatters: {
        level: (label) => {
          return { level: label.toUpperCase() };
        },
      },
    });
    context.logger.info('Relayer config generated.', requestContext, methodContext, {
      config: { ...context.config, abis: 'n/a' },
    });

    /// MARK - Adapters
    // Set up adapters.
    context.adapters.cache = await setupCache(context.config.redis, context.logger, requestContext);
    context.adapters.wallet = new Web3Signer(context.config.web3SignerUrl!);

    const hubChainServiceConfig: Record<string, object> = {
      [context.config.hub.domain]: {
        providers: context.config.hub.providers,
        confirmations: context.config.hub.confirmations,
      },
    };
    context.adapters.chainservice = new ChainService(
      context.logger.child({ module: 'ChainService', level: context.config.logLevel }),
      { ...context.config.chains, ...hubChainServiceConfig },
      context.adapters.wallet,
      true, // Ghost instance, in the event that this is running in the same process as a solver.
    );
  } catch (error: unknown) {
    (context.logger ?? logger).error(
      'Error setup context Relayer! D: Who could have done this?',
      requestContext,
      methodContext,
      jsonifyError(error as Error),
    );
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
