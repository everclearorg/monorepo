import { MonitorConfig } from '../types';

export const getSupportedDomains = (chains: MonitorConfig['chains']): string[] => {
  return Object.keys(chains).filter((domain) => ['evm', 'tvm'].includes(chains[domain].network || ''));
};
