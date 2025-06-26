import { RpcProvider } from '../';
import { SolanaProvider } from './provider';

export const getSolanaRpcProvider = (domainId: number, url?: string): RpcProvider => {
  return new SolanaProvider(url);
};
