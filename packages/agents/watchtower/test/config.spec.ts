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
    beforeEach(() => {});

    afterEach(() => {
      restore();
      reset();
    });

    it('should not reload config if everclear config is undefined', async () => {
      getEverclearConfigStub.resolves(undefined);
      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: false, reloadSubgraph: false });
    });

    it('should reload config if subgraph config changes', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(),
      });
      getEverclearConfigStub.resolves({
        chains: {
          '1337': {
            providers: ['http://localhost:8080'],
            subgraphUrls: ['http://1337.mocksubgraph.com'],
          },
          '1338': {
            providers: ['http://localhost:8081'],
            subgraphUrls: ['http://1338.mocksubgraph.com'],
          },
        },
      });

      await getConfig();

      getEverclearConfigStub.resolves({
        chains: {
          '1337': {
            providers: ['http://localhost:7080'],
            subgraphUrls: ['http://a.1337.mocksubgraph.com'],
          },
          '1338': {
            providers: ['http://localhost:7081'],
            subgraphUrls: ['http://b.1338.mocksubgraph.com'],
          },
        },
      });

      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: true, reloadSubgraph: true });
    });

    it('should not reload subgraph config', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(),
      });
      getEverclearConfigStub.resolves({
        chains: {
          '1337': {
            providers: ['http://localhost:8080'],
            subgraphUrls: ['http://1337.mocksubgraph.com'],
          },
          '1338': {
            providers: ['http://localhost:8081'],
            subgraphUrls: ['http://1338.mocksubgraph.com'],
          },
        },
      });

      await getConfig();

      getEverclearConfigStub.resolves({
        chains: {
          '1337': {
            providers: ['http://localhost:7080'],
            subgraphUrls: ['http://1337.mocksubgraph.com'],
          },
          '1338': {
            providers: ['http://localhost:7081'],
            subgraphUrls: ['http://1338.mocksubgraph.com'],
          },
        },
      });

      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: true, reloadSubgraph: false });
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
