import { providers } from 'ethers';
/**
 * Gets the best RPC URL between several options by comparing latencies
 * @param rpcUrls - The source list
 * @returns - The best RPC URL
 */
export const getBestProvider = async (rpcUrls: string[]): Promise<string | undefined> => {
  let bestProvider: string | undefined = undefined;
  let bestLatency = Infinity;

  for (const url of rpcUrls) {
    const provider = new providers.JsonRpcProvider(url);
    try {
      const start = Date.now();
      await provider.getBlockNumber();
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
