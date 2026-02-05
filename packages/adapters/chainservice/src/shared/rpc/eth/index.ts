import { RpcProvider } from '../';
import { SyncProvider } from './provider';

export { SyncProvider } from './provider';

export const getEthRpcProvider = (domainId: number, urls: string[]): RpcProvider => {
  return new SyncProvider(urls, domainId);
};
