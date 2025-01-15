import { SubgraphConfig } from '@chimera-monorepo/adapters-subgraph';
import { CartographerConfig } from '../../config';

const DEFAULT_SUBGRAPH_TIMEOUT = 7500;

/**
 * Helper to get subgraph reader config
 * @param config Cartographer config
 * @returns SubgraphConfig used to instantiate subgraph reader
 */
export const getSubgraphReaderConfig = (config: CartographerConfig): SubgraphConfig => {
  const subgraphs: Record<string, { endpoints: string[]; timeout: number }> = {};
  Object.keys(config.chains).forEach((domainId) => {
    subgraphs[domainId] = { endpoints: config.chains[domainId].subgraphUrls, timeout: DEFAULT_SUBGRAPH_TIMEOUT };
  });
  subgraphs[config.hub.domain] = { endpoints: config.hub.subgraphUrls, timeout: DEFAULT_SUBGRAPH_TIMEOUT };
  return { subgraphs };
};
