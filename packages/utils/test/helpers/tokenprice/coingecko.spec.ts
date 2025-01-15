import { SinonStub, stub } from 'sinon';
import { expect, AssetConfig, getTokenPriceFromCoingecko, mkAddress } from '../../../src';
import Axios from 'axios';

const UNAUTHED_URL = 'https://api.coingecko.com/api/v3/simple/price';
const AUTHED_URL = 'https://pro-api.coingecko.com/api/v3/simple/price';

describe('Helpers:token price', () => {
  describe('#getTokenPriceFromCoingecko', () => {
    const assetConfig: AssetConfig = {
      symbol: 'ETH',
      address: mkAddress(),
      decimals: 18,
      price: {
        isStable: false,
        coingeckoId: 'ethereum',
      },
      isNative: true,
    };

    const baseHeaders = { accept: 'application/json' };
    const params = { ids: [assetConfig.price.coingeckoId], vs_currencies: 'usd' };

    let getStub: SinonStub<any[]>;

    type ResponseType = Record<string, { [usd: string]: number }>;
    const response: ResponseType = {
      [assetConfig.price.coingeckoId!]: { usd: 3200.1235 },
    };

    beforeEach(() => {
      getStub = stub(Axios, 'get');
      getStub.resolves({ data: response });
    });

    it('should work if unauthed', async () => {
      const price = await getTokenPriceFromCoingecko(assetConfig);
      expect(price).to.eq(response[assetConfig.price.coingeckoId!].usd);
      expect(
        getStub.calledOnceWith(UNAUTHED_URL, {
          params,
          headers: baseHeaders,
        }),
      );
    });

    it('should work if authed', async () => {
      const price = await getTokenPriceFromCoingecko(assetConfig, 'key');
      expect(price).to.eq(response[assetConfig.price.coingeckoId!].usd);
      expect(
        getStub.calledOnceWith(AUTHED_URL, {
          params,
          headers: { ...baseHeaders, ['x-cg-pro-api-key']: 'key' },
        }),
      );
    });

    it('should work if authed fails and unauthed works', async () => {
      const withKey = { ...baseHeaders, ['x-cg-pro-api-key']: 'key' };
      getStub.withArgs(AUTHED_URL).rejects(new Error('bad'));
      getStub.withArgs(UNAUTHED_URL).resolves({ data: response });
      const price = await getTokenPriceFromCoingecko(assetConfig, 'key', 1);
      expect(price).to.eq(response[assetConfig.price.coingeckoId!].usd);
      expect(getStub.firstCall.args).to.containSubset([
        AUTHED_URL,
        {
          params,
          headers: withKey,
        },
      ]);
      expect(getStub.lastCall.args).to.containSubset([
        UNAUTHED_URL,
        {
          params,
          headers: withKey,
        },
      ]);
    });

    it('should return 0 if there is no matching asset in returned data', async () => {
      getStub.resolves({ data: {} });
      const price = await getTokenPriceFromCoingecko(assetConfig);
      expect(price).to.eq(0);
    });

    it('should return 0 if getting prices fails', async () => {
      getStub.rejects(new Error('fail'));
      const price = await getTokenPriceFromCoingecko(assetConfig, undefined, 1);
      expect(price).to.eq(0);
    });
  });
});
