import { AssetConfig, getHistoricTokenPriceFromCoingecko } from '@chimera-monorepo/utils';
import { InvalidAsset } from '../../errors/tasks/rewards';

export class HistoricPrice {
  coingeckoApiKey: string;
  network: string;
  cache: {
    [id: string]: {
      [date: string]: number;
    };
  } = {};
  constructor(coingeckoApiKey: string, network: string) {
    this.coingeckoApiKey = coingeckoApiKey;
    this.network = network;
  }

  async getHistoricTokenPrice(asset: AssetConfig, date: Date) {
    if (!asset.price.coingeckoId) {
      if (asset.price.isStable && this.network == 'testnet') {
        // hardcode to USD
        return 1;
      }
      const error = new InvalidAsset(asset.address);
      throw error;
    }
    if (!this.cache[asset.price.coingeckoId]) {
      this.cache[asset.price.coingeckoId] = {};
    }
    const formattedDate = date.toLocaleDateString('en-UK', {
      timeZone: 'UTC',
    });
    if (!this.cache[asset.price.coingeckoId][formattedDate]) {
      const tokenPrice = await getHistoricTokenPriceFromCoingecko(asset, date, this.coingeckoApiKey);
      this.cache[asset.price.coingeckoId][formattedDate] = tokenPrice;
    }
    return this.cache[asset.price.coingeckoId][formattedDate];
  }
}
