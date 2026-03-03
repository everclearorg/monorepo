import { SubgraphConfig } from '@chimera-monorepo/adapters-subgraph';
import { CartographerConfig } from '../config';

const DEFAULT_SUBGRAPH_TIMEOUT = 7500;

/**
 * Helper to check if a domain has valid subgraph URLs
 * @param subgraphUrls Array of subgraph URLs
 * @returns true if at least one non-empty URL exists
 */
const hasValidSubgraphUrls = (subgraphUrls: string[]): boolean => {
  return subgraphUrls && subgraphUrls.length > 0 && subgraphUrls.some((url) => url && url.trim() !== '');
};

/**
 * Helper to get subgraph reader config
 * @param config Cartographer config
 * @returns SubgraphConfig used to instantiate subgraph reader
 */
export const getSubgraphReaderConfig = (config: CartographerConfig): SubgraphConfig => {
  const subgraphs: Record<string, { endpoints: string[]; timeout: number }> = {};
  Object.keys(config.chains).forEach((domainId) => {
    if (config.chains[domainId].network === 'evm' && hasValidSubgraphUrls(config.chains[domainId].subgraphUrls)) {
      subgraphs[domainId] = { endpoints: config.chains[domainId].subgraphUrls, timeout: DEFAULT_SUBGRAPH_TIMEOUT };
    }
  });
  if (hasValidSubgraphUrls(config.hub.subgraphUrls)) {
    subgraphs[config.hub.domain] = { endpoints: config.hub.subgraphUrls, timeout: DEFAULT_SUBGRAPH_TIMEOUT };
  }

  // Add Envio configuration if available
  const envioConfig: SubgraphConfig['envio'] = config.hub.envioSubgraphUrl
    ? {
        url: config.hub.envioSubgraphUrl,
        timeout: DEFAULT_SUBGRAPH_TIMEOUT / 1000, // Convert to seconds
      }
    : undefined;

  return { subgraphs, ...(envioConfig && { envio: envioConfig }) };
};

/**
 * Helper to get domains that have valid subgraph configurations
 * Only returns domains that are EVM-based and have non-empty subgraph URLs
 * @param config Cartographer config
 * @returns Array of domain IDs that can be queried via subgraph
 */
export const getSubgraphSupportedDomains = (config: CartographerConfig): string[] => {
  return Object.keys(config.chains).filter((domainId) => {
    const chain = config.chains[domainId];
    return domainId !== config.hub.domain && chain.network === 'evm' && hasValidSubgraphUrls(chain.subgraphUrls);
  });
};
