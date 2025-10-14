import { providers } from 'ethers';
import { DefaultTronWebFactory } from './tron';
import { TRON_CHAINID } from '../constants';

/**
 * Gets the best RPC URL between several options by comparing latencies
 * @param rpcUrls - The source list
 * @param domain - The domain ID (optional, used for Tron chains)
 * @returns - The best RPC URL
 */
export const getBestProvider = async (rpcUrls: string[], domain?: string): Promise<string | undefined> => {
  let bestProvider: string | undefined = undefined;
  let bestLatency = Infinity;
  const tronWebFactory = new DefaultTronWebFactory();

  for (const url of rpcUrls) {
    try {
      const start = Date.now();
      if (domain === TRON_CHAINID) {
        const tronWeb = tronWebFactory.create(url);
        await tronWeb.trx.getCurrentBlock();
      } else {
        const provider = new providers.JsonRpcProvider(url);
        await provider.getBlockNumber();
      }
      const latency = Date.now() - start;

      if (latency < bestLatency) {
        bestProvider = url;
        bestLatency = latency;
      }
    } catch (error: unknown) {
      console.log(`Error connecting to provider at ${url}: ${error}`);
    }
  }

  return bestProvider;
};
