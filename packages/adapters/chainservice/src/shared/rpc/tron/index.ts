import { RpcProvider } from '../';
import { TronSyncProvider } from './provider';

export { TronSyncProvider } from './provider';

export const getTronRpcProvider = (domainId: number, url?: string): RpcProvider => {
  return new TronSyncProvider(domainId, url);
};
