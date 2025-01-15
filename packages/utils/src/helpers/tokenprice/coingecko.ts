import { AssetConfig } from '../../types';
import { axiosGet } from '../axios';
/**
 * Get the token price from the trusted 3rd party services like CoinGecko, CoinMarketCap, etc.
 *
 * @param asset - The target asset
 * @param apiKey - The coingecko api key
 * @returns The token price in usd.
 */
export const getTokenPriceFromCoingecko = async (
  asset: AssetConfig,
  apiKey?: string,
  retries?: number,
): Promise<number> => {
  if (!apiKey) {
    // Get unauthenticated coingecko token price.
    try {
      return await getUnauthenticatedTokenPrice(asset, undefined, retries);
    } catch (err) {
      console.error(
        `Error getting unauthenticated token price. symbol: ${asset.symbol}, coingeckoId: ${asset.price.coingeckoId}, message: ${(err as Error).message}`,
      );
      return 0;
    }
  }
  // Try getting authenticated token price.
  try {
    const endpoint = 'https://pro-api.coingecko.com/api/v3/simple/price';

    const params = { ids: [asset.price.coingeckoId], vs_currencies: 'usd' };
    const headers = { accept: 'application/json', 'x-cg-pro-api-key': apiKey };

    const response = await axiosGet(
      endpoint,
      {
        params,
        headers,
      },
      retries,
    );

    if (response && response.data) {
      const prices = response.data as unknown as Record<string, { [usd: string]: number }>;
      return prices[asset.price.coingeckoId!].usd;
    }
  } catch (err) {
    console.warn(
      `Error getting authenticated token price, trying unauthed. symbol: ${asset.symbol}, coingeckoId: ${asset.price.coingeckoId}, message: ${(err as Error).message}`,
    );
    try {
      return await getUnauthenticatedTokenPrice(asset, apiKey, retries);
    } catch (err) {
      console.error(
        `Error getting unauthenticated token price. symbol: ${asset.symbol}, coingeckoId: ${asset.price.coingeckoId}, message: ${(err as Error).message}`,
      );
    }
  }
  return 0;
};

/**
 * Get the token price from the trusted 3rd party services like CoinGecko, CoinMarketCap, etc.
 *
 * @param asset - The target asset
 * @param apiKey - The coingecko api key
 * @returns The token price in usd.
 */
export const getHistoricTokenPriceFromCoingecko = async (
  asset: AssetConfig,
  date: Date,
  apiKey: string,
  retries?: number,
): Promise<number> => {
  const formattedDate = date
    .toLocaleDateString('en-UK', {
      timeZone: 'UTC',
    })
    .replace(/\//g, '-');
  try {
    const endpoint = `https://pro-api.coingecko.com/api/v3/coins/${asset.price.coingeckoId}/history`;

    const params = { date: formattedDate, localization: false };
    const headers = { accept: 'application/json', 'x-cg-pro-api-key': apiKey };

    const response = await axiosGet(
      endpoint,
      {
        params,
        headers,
      },
      retries,
    );

    if (response && response.data) {
      const prices = response.data as unknown as {
        market_data: {
          current_price: {
            [usd: string]: number;
          };
        };
      };
      return prices.market_data.current_price.usd;
    }
  } catch (err) {
    console.warn(
      `Error getting authenticated historic token price. symbol: ${asset.symbol}, date: ${formattedDate}, coingeckoId: ${asset.price.coingeckoId}, message: ${(err as Error).message}`,
    );
  }
  return 0;
};

const getUnauthenticatedTokenPrice = async (asset: AssetConfig, apiKey?: string, retries?: number): Promise<number> => {
  // It can be a demo api key.
  const endpoint = 'https://api.coingecko.com/api/v3/simple/price';

  const params = { ids: [asset.price.coingeckoId], vs_currencies: 'usd' };
  const headers = { accept: 'application/json' };

  const response = await axiosGet(
    endpoint,
    {
      params,
      headers: apiKey ? { ...headers, ['x-cg-pro-api-key']: apiKey } : headers,
    },
    retries,
  );

  if (response && response.data) {
    const prices = response.data as unknown as Record<string, { [usd: string]: number }>;
    return prices[asset.price.coingeckoId!].usd;
  }
  return 0;
};
