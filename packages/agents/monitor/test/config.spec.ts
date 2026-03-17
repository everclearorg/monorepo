import { ajv, expect } from '@chimera-monorepo/utils';
import { stub, SinonStub } from 'sinon';
import { getConfig, shouldReloadEverclearConfig, _resetCachedEverclearConfig } from '../src/config';
import { createProcessEnv } from './mock';
import * as MockableFns from '../src/mockable';
import { mock } from './globalTestHook';

describe('Config', () => {
  let exitStub: SinonStub;
  let getEverclearConfigStub: SinonStub;
  let ssmStub: SinonStub;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    getEverclearConfigStub = stub(MockableFns, 'getEverclearConfig').resolves({
      ...mock.config(),
    });
    exitStub = stub(process, 'exit');
    exitStub.returns(1);
    ssmStub = stub(MockableFns, 'getSsmParameter');
    ssmStub.resolves(undefined);
  });

  describe('#getConfig', () => {
    it('should work', async () => {
      const retrieved = await getConfig();
      const config = mock.config();
      expect(Object.keys(retrieved).length).to.be.greaterThanOrEqual(Object.keys(config).length);
    });

    it('should read overrides from .env', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv({ logLevel: 'debug' }),
      });

      const retrieved = await getConfig();
      const config = mock.config();
      expect(retrieved.logLevel).to.equal('debug');
    });

    it('should throw if config is invalid', async () => {
      stub(process, 'env').value({});
      getEverclearConfigStub.resolves({});
      await expect(getConfig()).to.be.rejected;
    });

    it('should fail if config file doesnt exist', async () => {
      stub(process, 'env').value({
        MONITOR_CONFIG_FILE: 'test-config.json',
      });
      await expect(getConfig()).to.be.rejected;
    });

    it('should fail if config file is unreadable', async () => {
      stub(process, 'env').value({
        MONITOR_CONFIG_FILE: '/dev/null',
      });
      await expect(getConfig()).to.be.rejected;
      expect(exitStub.calledOnce).to.be.true;
    });

    it('should load cached config', async () => {
      const config = await getConfig();

      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv({ logLevel: 'info' }),
      });
      const config2 = await getConfig();
      expect(config2.logLevel).to.eq('info');
    });

    it('should read config from AWS SSM parameter store', async () => {
      stub(process, 'env').value({
        ...process.env,
        CONFIG_PARAMETER_NAME: 'monitor-config',
      });
      const database = { url: 'https://database.com' };
      ssmStub.resolves(JSON.stringify({ ...mock.config(), database }));
      const config = await getConfig();
      await expect(config.database).to.be.deep.equal(database);
    });

    it('should parse TRIAGE_CONFIG when passed as direct triage object', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(),
        TRIAGE_CONFIG: JSON.stringify({
          mode: 'dry-run',
          timeoutMs: 2500,
          providers: { openai: { apiKey: 'k' } },
        }),
      });

      const retrieved = await getConfig();
      expect(retrieved.triage?.mode).to.equal('dry-run');
      expect(retrieved.triage?.timeoutMs).to.equal(2500);
    });

    it('should parse TRIAGE_CONFIG when nested under triage key', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(),
        TRIAGE_CONFIG: JSON.stringify({
          triage: {
            mode: 'shadow',
            timeoutMs: 3000,
            providers: { openai: { apiKey: 'k' } },
          },
        }),
      });

      const retrieved = await getConfig();
      expect(retrieved.triage?.mode).to.equal('shadow');
      expect(retrieved.triage?.timeoutMs).to.equal(3000);
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
        ...createProcessEnv(mock.config()),
        EVERCLEAR_CONFIG: 'https://mock.everclear.config',
      });
      getEverclearConfigStub.resolves({ chains: initialChains });
      await getConfig();
    };

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

    it('should signal reload when initial fetch failed and later fetch succeeds', async () => {
      // Reset module state to simulate fresh start
      _resetCachedEverclearConfig();

      // Initial getConfig() with a failing everclear fetch — cachedEverclearConfig stays as {}
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(mock.config()),
        EVERCLEAR_CONFIG: 'https://mock.everclear.config',
      });
      getEverclearConfigStub.rejects(new Error('initial fetch failed'));
      await getConfig();

      // Now the fetch succeeds — should detect missing cached chains and signal full reload
      getEverclearConfigStub.resolves({ chains: mockChains });
      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: true, reloadSubgraph: true });
    });
  });
});
