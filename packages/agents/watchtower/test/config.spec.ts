import { expect, mkAddress } from '@chimera-monorepo/utils';
import { SinonStub, stub, reset, restore } from 'sinon';
import { getConfig, getSubgraphReaderConfig, shouldReloadEverclearConfig } from '../src/config';
import { createProcessEnv, createWatcherConfig } from './mock';
import * as MockableFns from '../src/mockable';

let getEverclearConfigStub: SinonStub;

describe('Config', () => {
  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });

    getEverclearConfigStub = stub(MockableFns, 'getEverclearConfig').resolves({
      chains: {
        '1337': {
          providers: ['http://rpc-1337:8545'],
          deployments: {
            everclear: mkAddress('0x1337ccc'),
            gateway: mkAddress('0x1337fff'),
          },
          subgraphUrls: [],
        },
        '1338': {
          providers: ['http://rpc-1338:8545'],
          deployments: {
            everclear: mkAddress('0x1338ccc'),
            gateway: mkAddress('0x1338fff'),
          },
          subgraphUrls: [],
        },
      },
      hub: {
        domain: '6398',
        providers: ['http://rpc-6398:8545'],
        deployments: {
          everclear: mkAddress('0x1339ccc'),
          gateway: mkAddress('0x1339fff'),
          gauge: mkAddress('0x1339eee'),
          rewardDistributor: mkAddress('0x1339bbb'),
          tokenomicsHubGateway: mkAddress('0x1339aaa'),
        },
        subgraphUrls: [],
      },
    });
  });

  describe('#getConfig', () => {
    it('should work', async () => {
      const retrieved = await getConfig();
      expect(retrieved).to.be.not.empty;
    });

    it.skip('should read overrides from .env', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv({ logLevel: 'debug' }),
      });

      const retrieved = await getConfig();
      const config = createWatcherConfig();
      expect(retrieved).to.containSubset(config);
    });

    it('should throw if config is invalid', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(),
        LOG_LEVEL: 'fail',
      });
      await expect(getConfig()).to.be.rejected;
    });

    it('should not fail if config file doesnt exist', async () => {
      stub(process, 'env').value({
        ...createProcessEnv(),
        WATCHTOWER_CONFIG_FILE: 'test-config.json',
      });
      await expect(getConfig()).to.be.fulfilled;
    });
  });

  describe('#getConfig', () => {
    it.skip('should load cached config', async () => {
      const config = await getConfig();

      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv({ logLevel: 'warn' }),
      });
      const config2 = await getConfig();
      expect(config.logLevel).to.eq(config2.logLevel);
      expect(config.logLevel).to.eq('debug');
    });
  });

  describe('#shouldReloadEverclearConfig', () => {
    const mockChains = {
      '1337': {
        providers: ['http://localhost:8080'],
        subgraphUrls: ['http://1337.mocksubgraph.com'],
      },
      '1338': {
        providers: ['http://localhost:8081'],
        subgraphUrls: ['http://1338.mocksubgraph.com'],
      },
    };

    const setupWithEverclearConfig = async (initialChains = mockChains) => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(),
      });
      getEverclearConfigStub.resolves({ chains: initialChains });
      await getConfig();
    };

    afterEach(() => {
      restore();
      reset();
    });

    it('should return false when no cached everclear config url', async () => {
      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: false, reloadSubgraph: false });
    });

    it('should return false when fetch throws', async () => {
      await setupWithEverclearConfig();
      getEverclearConfigStub.rejects(new Error('network error'));
      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: false, reloadSubgraph: false });
    });

    it('should return false when fetch returns undefined', async () => {
      await setupWithEverclearConfig();
      getEverclearConfigStub.resolves(undefined);
      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: false, reloadSubgraph: false });
    });

    it('should reload both when subgraph urls change', async () => {
      await setupWithEverclearConfig();
      getEverclearConfigStub.resolves({
        chains: {
          '1337': {
            providers: ['http://localhost:8080'],
            subgraphUrls: ['http://new.1337.mocksubgraph.com'],
          },
          '1338': {
            providers: ['http://localhost:8081'],
            subgraphUrls: ['http://new.1338.mocksubgraph.com'],
          },
        },
      });
      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: true, reloadSubgraph: true });
    });

    it('should reload config only when non-subgraph config changes', async () => {
      await setupWithEverclearConfig();
      getEverclearConfigStub.resolves({
        chains: {
          ...mockChains,
          '1337': {
            ...mockChains['1337'],
            providers: ['http://localhost:9999'],
          },
        },
      });
      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: true, reloadSubgraph: false });
    });

    it('should not reload when config is identical', async () => {
      await setupWithEverclearConfig();
      getEverclearConfigStub.resolves({ chains: mockChains });
      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: false, reloadSubgraph: false });
    });
  });

  describe('#getSubgraphReaderConfig', () => {
    it('should work', () => {
      const config = createWatcherConfig();
      const { subgraphs: _subgraphs } = getSubgraphReaderConfig(config.chains);
      expect(_subgraphs['1337'].endpoints).to.be.deep.equal(config.chains['1337'].subgraphUrls);
    });
  });
});
