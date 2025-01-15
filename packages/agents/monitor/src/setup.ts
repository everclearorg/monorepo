import { StoreManager } from '@chimera-monorepo/adapters-cache';
import { SubgraphConfig, SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { Logger, RequestContext, createMethodContext } from '@chimera-monorepo/utils';

export const setupCache = async (
  host: string | undefined,
  port: number | undefined,
  logger: Logger,
  requestContext: RequestContext,
): Promise<StoreManager> => {
  const methodContext = createMethodContext(setupCache.name);
  logger.info('Cache instance setup in progress...', requestContext, methodContext, {});
  const cacheInstance = StoreManager.getInstance({
    redis: { host, port, instance: undefined },
    mock: !host || !port,
  });

  logger.info('Cache instance setup is done!', requestContext, methodContext, { host, port });

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
