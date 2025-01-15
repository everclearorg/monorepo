import { Interface } from 'ethers/lib/utils';
import { providers } from 'ethers';
import { AssetConfig, createLoggingContext, univ2PairABI } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import {
  getTokenPriceFromCoingecko,
  getTokenPriceFromChainlink,
  getTokenPriceFromUniV2,
  getTokenPriceFromUniV3,
  getBestProvider,
} from '../mockable';
import { MissingAssetConfig, MissingTokenPrice } from '../types';

/**
 * Get the token price for a specified asset on a given domain.
 * @param domain - The domain id
 * @param asset - The asset address
 */
export const getTokenPrice = async (domain: string, asset: AssetConfig): Promise<number> => {
  const {
    adapters: { chainreader },
    logger,
    config,
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(getTokenPrice.name);

  // 1. Return 1 if the specified asset is the stable token.
  if (asset.price.isStable) return 1;

  const bestRpcUrlForDomain = await getBestProvider(config.chains[domain].providers);
  const bestProviderForDomain = bestRpcUrlForDomain ? new providers.JsonRpcProvider(bestRpcUrlForDomain) : undefined;

  // 2. If a chainlink price feed is configured for the asset, retrieve the token price from the data feed.
  if (asset.price.priceFeed && bestProviderForDomain) {
    const chainlinkPrice = await getTokenPriceFromChainlink(domain, asset.price.priceFeed, bestProviderForDomain);
    logger.debug('Got the token price from the chainlink', requestContext, methodContext, {
      asset: asset.address.toLowerCase(),
      price: chainlinkPrice,
    });
    return chainlinkPrice;
  }

  // 3. If the asset has a mainnetEquivalent, calculate and return the mainnetEquivalent token price.
  if (asset.price.mainnetEquivalent) {
    const mainnetEquivalentAsset = getAssetConfig('1', asset.price.mainnetEquivalent);
    const mainnetTokenPrice = await getTokenPrice('1', mainnetEquivalentAsset);

    logger.debug('Got the mainnetEquivalent token price', requestContext, methodContext, {
      asset: asset.address.toLowerCase(),
      mainnetEquivalentAsset,
      price: mainnetTokenPrice,
    });
    return mainnetTokenPrice;
  }

  // 4. If a univ2 pair is configured, calculate token price from reserves by calling `getReserves` method from the pair contract.
  if (asset.price.univ2 && bestProviderForDomain) {
    const univ2PairIface = new Interface(univ2PairABI);
    const encodedDataForToken0 = univ2PairIface.encodeFunctionData('token0');
    const encodedDataForToken1 = univ2PairIface.encodeFunctionData('token1');
    const [encodedToken0Result, encodedToken1Result] = await Promise.all([
      chainreader.readTx(
        {
          to: asset.price.univ2.pair,
          domain: +domain,
          data: encodedDataForToken0,
        },
        'latest',
      ),
      chainreader.readTx(
        {
          to: asset.price.univ2.pair,
          domain: +domain,
          data: encodedDataForToken1,
        },
        'latest',
      ),
    ]);

    const [token0] = univ2PairIface.decodeFunctionResult('token0', encodedToken0Result);
    const [token1] = univ2PairIface.decodeFunctionResult('token1', encodedToken1Result);
    const token0Config = getAssetConfig(domain, token0);
    const token1Config = getAssetConfig(domain, token1);

    const baseAsset = token0.toLowerCase() == asset.address.toLowerCase() ? token1 : token0;
    const baseAssetConfig = getAssetConfig(domain, baseAsset);
    const baseTokenPrice = await getTokenPrice(domain, baseAssetConfig);
    const token0Price = await getTokenPriceFromUniV2(
      domain,
      asset.price.univ2.pair,
      token0Config,
      token1Config,
      bestProviderForDomain,
    );
    const assetPrice =
      token0.toLowerCase() == asset.address.toLowerCase()
        ? token0Price * baseTokenPrice
        : 1 / (token0Price * baseTokenPrice);

    logger.debug('Got the token price from univ2 pair', requestContext, methodContext, {
      asset: asset.address.toLowerCase(),
      pair: asset.price.univ2.pair,
      price: assetPrice,
    });
    return assetPrice;
  }

  // 5. If a univ3 pool is configured, calculate the token price using the tick returned from the `slot0` method call of the univ3 pool.
  if (asset.price.univ3 && bestProviderForDomain) {
    const univ3PoolIface = new Interface(univ2PairABI);
    const encodedDataForToken0 = univ3PoolIface.encodeFunctionData('token0');
    const encodedDataForToken1 = univ3PoolIface.encodeFunctionData('token1');

    const [encodedToken0Result, encodedToken1Result] = await Promise.all([
      chainreader.readTx(
        {
          to: asset.price.univ3.pool,
          domain: +domain,
          data: encodedDataForToken0,
        },
        'latest',
      ),
      chainreader.readTx(
        {
          to: asset.price.univ3.pool,
          domain: +domain,
          data: encodedDataForToken1,
        },
        'latest',
      ),
    ]);

    const [token0] = univ3PoolIface.decodeFunctionResult('token0', encodedToken0Result);
    const [token1] = univ3PoolIface.decodeFunctionResult('token1', encodedToken1Result);

    const token0Config = getAssetConfig(domain, token0);
    const token1Config = getAssetConfig(domain, token1);

    const baseAsset = token0.toLowerCase() == asset.address.toLowerCase() ? token1 : token0;
    const baseAssetConfig = getAssetConfig(domain, baseAsset);
    const baseTokenPrice = await getTokenPrice(domain, baseAssetConfig);
    const token0Price = await getTokenPriceFromUniV3(
      domain,
      asset.price.univ3.pool,
      token0Config,
      token1Config,
      bestProviderForDomain,
    );
    const assetPrice =
      token0.toLowerCase() == asset.address.toLowerCase()
        ? token0Price * baseTokenPrice
        : 1 / (token0Price * baseTokenPrice);

    logger.debug('Got the token price from univ3 pool', requestContext, methodContext, {
      asset: asset.address.toLowerCase(),
      pair: asset.price.univ3.pool,
      price: assetPrice,
    });

    return assetPrice;
  }

  // 6. Retrieve the token price from trusted third-party services like Coingecko, CoinMarketCap, etc.
  if (asset.price.coingeckoId) {
    const coingeckoPrice = await getTokenPriceFromCoingecko(asset);

    logger.debug('Got the token price from coingecko API', requestContext, methodContext, {
      asset: asset.address.toLowerCase(),
      coingeckoId: asset.price.coingeckoId,
      price: coingeckoPrice,
    });
    return coingeckoPrice;
  }

  // 7. TODO: Consider any better methods.

  throw new MissingTokenPrice({ asset, domain });
};

export const getAssetConfig = (domain: string, address: string): AssetConfig => {
  const { config } = getContext();
  const chainConfig = config.chains[domain];
  if (chainConfig && chainConfig.assets) {
    const chainAssets = Object.values(chainConfig.assets);
    const assetConfig = chainAssets.find((it) => it.address.toLowerCase() == address.toLowerCase());
    if (assetConfig) return assetConfig;
  }

  throw new MissingAssetConfig({ asset: address, domain });
};

/**
 * Get AssetConfig by ticker hash and domain.
 * If domain is not provided, use any domain that contains the ticker hash asset.
 * @param tickerHash - The ticket hash of the token
 * @param domain - domain ID
 */
export const getAssetConfigByTickerHash = (tickerHash: string, domain?: string): AssetConfig => {
  const { config } = getContext();
  const chainConfigs = domain ? { [domain]: config.chains[domain] } : config.chains;
  for (const chainConfig of Object.values(chainConfigs)) {
    if (chainConfig && chainConfig.assets) {
      const chainAssets = Object.values(chainConfig.assets);
      const assetConfig = chainAssets.find((it) => it.tickerHash.toLowerCase() == tickerHash.toLowerCase());
      if (assetConfig) return assetConfig;
    }
  }

  throw new MissingAssetConfig({ asset: tickerHash });
};
