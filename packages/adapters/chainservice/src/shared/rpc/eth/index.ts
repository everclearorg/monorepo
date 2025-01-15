import { RpcProvider } from '../';
import { SyncProvider } from './provider';

export { SyncProvider } from './provider';

export const getEthRpcProvider = (domainId: number, url: string): RpcProvider => {
  return new SyncProvider(url, domainId);
};
