import { utils } from 'ethers';
import { ChainConfig } from '../types/primitives';
import { EverclearError } from '../types';

export class NoTickersConfigured extends EverclearError {
  constructor(
    public readonly config: Record<string, ChainConfig>,
    public readonly domain: string = '',
    context: object = {},
  ) {
    super(`Missing asset tickers`, { config, domain, ...context });
  }
}

export class NoTickerFoundForAsset extends EverclearError {
  constructor(
    public readonly domain: string,
    public readonly asset: string,
    public readonly config: Record<string, ChainConfig>,
    context: object = {},
  ) {
    super(`No ticker found for asset`, { config, domain, asset, ...context });
  }
}

export class MultipleTickersFoundForAsset extends EverclearError {
  constructor(
    public readonly domain: string,
    public readonly asset: string,
    public readonly config: Record<string, ChainConfig>,
    context: object = {},
  ) {
    super(`No ticker found for asset`, { config, domain, asset, ...context });
  }
}

export const getTickerFromAssetContext = (domain: string, assetId: string, chains: Record<string, ChainConfig>) => {
  const { assets } = chains[domain] ?? {};
  if (!assets || Object.keys(assets ?? {}).length === 0) {
    throw new NoTickersConfigured(chains, domain);
  }
  const matched = Object.entries(assets).filter(([, asset]) => asset.address.toLowerCase() === assetId.toLowerCase());
  if (matched.length === 0) {
    throw new NoTickerFoundForAsset(domain, assetId, chains);
  }
  if (matched.length > 1) {
    throw new MultipleTickersFoundForAsset(domain, assetId, chains, { matched });
  }
  const [[ticker]] = matched;
  return ticker;
};

export const getConfiguredTickers = (chains: Record<string, ChainConfig>) => {
  // Get all the domains
  const domains = Object.keys(chains);
  // Get all the configured asset tickers
  const tickers = new Set<string>();
  domains.forEach((domain) => {
    const configured = Object.keys(chains[domain].assets ?? {});
    configured.forEach((ticker: string) => tickers.add(ticker));
  });
  // Error if no tickers are configured for settlement.
  if (tickers.size === 0) {
    throw new NoTickersConfigured(chains);
  }
  return Array.from(tickers);
};

export const getConfiguredTickerHashes = (chains: Record<string, ChainConfig>) => {
  return getTickerHashes(getConfiguredTickers(chains));
};

export const getTickerHashes = (tickers: string[]) => {
  return tickers.map((ticker) => utils.keccak256(utils.toUtf8Bytes(ticker)));
};
