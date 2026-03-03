import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { getDatabase } from '@chimera-monorepo/database';
import { getChainData, Logger } from '@chimera-monorepo/utils';
import {
  AppContext,
  CartographerConfig,
  getEnvConfig,
  getSubgraphReaderConfig,
} from '@chimera-monorepo/cartographer-core';

export type HandlerConfig = CartographerConfig & {
  goldskyWebhookSecret: string;
  handlerPort: number;
};

export const getHandlerConfig = async (): Promise<HandlerConfig> => {
  const baseConfig = await getEnvConfig();

  return {
    ...baseConfig,
    goldskyWebhookSecret: process.env.GOLDSKY_WEBHOOK_SECRET || '',
    handlerPort: parseInt(process.env.PORT || '3000', 10),
  };
};

export const initializeContext = async (config: CartographerConfig, logger: Logger): Promise<AppContext> => {
  const chainData = await getChainData();

  const chainreader = new ChainReader(logger.child({ module: 'ChainReader' }), {
    ...config.chains,
    [config.hub.domain]: config.hub,
  });

  const subgraph = SubgraphReader.create(getSubgraphReaderConfig(config));

  // Use a larger pool for ECS (not Lambda-constrained)
  const database = await getDatabase(config.database, logger);

  const domains = Object.keys(config.chains);

  return {
    logger,
    adapters: {
      subgraph,
      chainreader,
      database,
    },
    config,
    chainData,
    domains,
  };
};
