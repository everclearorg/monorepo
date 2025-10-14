import {
  getConfiguredTickerHashes,
  getConfiguredTickers,
  getTickerFromAssetContext,
  getTickerHashes,
  NoTickerFoundForAsset,
  NoTickersConfigured,
  MultipleTickersFoundForAsset,
  ChainConfig,
  expect,
  mkAddress,
} from '../../src';
import { utils } from 'ethers';

const MOCK_CHAINS = {
  '1337': {
    providers: ['http://localhost:8080'],
    subgraphUrls: ['http://1337.mocksubgraph.com'],
    deployments: {
      everclear: mkAddress('0xabc'),
      gateway: mkAddress('0xdef'),
    },
    assets: {},
  },
  '1338': {
    providers: ['http://localhost:8081'],
    subgraphUrls: ['http://1338.mocksubgraph.com'],
    deployments: {
      everclear: mkAddress('0xabc'),
      gateway: mkAddress('0xdef'),
    },
    assets: {},
  },
};

describe('Helpers:assets', () => {
  const ticker = 'USDC';
  let config: Record<string, ChainConfig>;

  beforeEach(() => {
    config = {
      ...MOCK_CHAINS,
      '1': {
        ...MOCK_CHAINS[1337],
        assets: {
          [ticker]: {
            address: mkAddress('0x1234'),
            symbol: 'USDC',
            decimals: 6,
            isNative: false,
            price: { isStable: true },
          },
        },
      },
    };
  });

  describe('#getTickerFromAssetContext', () => {
    it('should fail if no assets', async () => {
      expect(() => getTickerFromAssetContext('1337', mkAddress('0x55'), config)).to.throw(NoTickersConfigured);
    });

    it('should fail if no matching ticker', async () => {
      expect(() => getTickerFromAssetContext('1', mkAddress('0x55'), config)).to.throw(NoTickerFoundForAsset);
    });

    it('should fail if multiple tickers found', async () => {
      config['1'].assets!['USDC2'] = { ...config['1'].assets!['USDC'] };
      expect(() => getTickerFromAssetContext('1', config['1'].assets!['USDC'].address, config)).to.throw(MultipleTickersFoundForAsset);
    });

    it('should work with exact address match', async () => {
      const ret = getTickerFromAssetContext('1', config['1'].assets![ticker].address, config);
      expect(ret).to.be.eq(ticker);
    });

    it('should work with case-insensitive address match', async () => {
      const ret = getTickerFromAssetContext('1', config['1'].assets![ticker].address.toUpperCase(), config);
      expect(ret).to.be.eq(ticker);
    });

    it('should fail if domain does not exist', async () => {
      expect(() => getTickerFromAssetContext('999', mkAddress('0x55'), config)).to.throw(NoTickersConfigured);
    });
  });

  describe('#getConfiguredTickers', () => {
    it('should throw if no tickers configured for chains', async () => {
      expect(() => getConfiguredTickers(MOCK_CHAINS)).to.throw(NoTickersConfigured);
    });

    it('should work with all assets', async () => {
      expect(getConfiguredTickers(config)).to.be.deep.eq([ticker]);
    });

    it('should work with skipNativeAssets=false', async () => {
      expect(getConfiguredTickers(config, false)).to.be.deep.eq([ticker]);
    });

    it('should skip native assets when skipNativeAssets=true', async () => {
      // Add a native asset
      config['1'].assets!['ETH'] = {
        address: mkAddress('0xeth'),
        symbol: 'ETH',
        decimals: 18,
        isNative: true,
        price: { isStable: false },
      };

      const result = getConfiguredTickers(config, true);
      expect(result).to.not.include('ETH');
      expect(result).to.include('USDC');
    });

    it('should include native assets when skipNativeAssets=false', async () => {
      // Add a native asset
      config['1'].assets!['ETH'] = {
        address: mkAddress('0xeth'),
        symbol: 'ETH',
        decimals: 18,
        isNative: true,
        price: { isStable: false },
      };

      const result = getConfiguredTickers(config, false);
      expect(result).to.include('ETH');
      expect(result).to.include('USDC');
    });

    it('should handle multiple domains with different assets', async () => {
      config['2'] = {
        ...MOCK_CHAINS[1337],
        assets: {
          'USDT': {
            address: mkAddress('0xusdt'),
            symbol: 'USDT',
            decimals: 6,
            isNative: false,
            price: { isStable: true },
          },
        },
      };

      const result = getConfiguredTickers(config);
      expect(result).to.include('USDC');
      expect(result).to.include('USDT');
    });

    it('should handle assets with undefined values', async () => {
      config['1'].assets!['INVALID'] = undefined as any;
      
      const result = getConfiguredTickers(config);
      expect(result).to.be.deep.eq([ticker]);
    });
  });

  describe('#getConfiguredTickerHashes', () => {
    it('should work', async () => {
      expect(getConfiguredTickerHashes(config)).to.be.deep.eq(getTickerHashes([ticker]));
    });
  });

  describe('#getTickerHashes', () => {
    it('should work', async () => {
      const tickers = [ticker];
      const hashes = getTickerHashes(tickers);
      expect(hashes.length).to.be.eq(tickers.length);
      expect(utils.isHexString(hashes[0])).to.be.true;
    });
  });
});
