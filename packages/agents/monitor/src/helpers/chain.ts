import { getContext } from '../context';

const TTL = 2_500;
export const getLatestBlockFromBlockMap = (domain: string, rpcOrigin?: string) => {
  const {
    adapters: { blockMap },
  } = getContext();
  // Check if exists
  if (!blockMap.has(domain)) {
    return undefined;
  }

  // Get the entry for this chain & rpc (if provided)
  const entry = rpcOrigin
    ? blockMap.get(domain)!.filter((e) => e.rpcOrigin.toLowerCase() === rpcOrigin.toLowerCase())
    : blockMap.get(domain)!;

  // Find latest
  const [latest] = entry.sort((a, b) => b.number - a.number);
  const now = Math.floor(Date.now() / 1_000);
  if (now - latest.timestamp > TTL) {
    return undefined;
  }
  return latest;
};
