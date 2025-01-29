import { ajv, expect } from '@chimera-monorepo/utils';
import { stub, SinonStub } from 'sinon';
import { getConfig, shouldReloadEverclearConfig } from '../src/config';
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
      expect(Object.keys(retrieved).length).to.equal(Object.keys(config).length);
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
      const database = { url: 'https://database.com' };
      ssmStub.resolves(JSON.stringify({ ...mock.config(), database }));
      const config = await getConfig();
      await expect(config.database).to.be.deep.equal(database);
    });
  });

  describe('#shouldReloadEverclearConfig', () => {
    it('should reload config', async () => {
      const config = mock.config();
      config.chains['1337'].subgraphUrls = ['http://newlocalhost:8000'];
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(config),
      });

      expect(shouldReloadEverclearConfig()).to.not.be.rejected;
    });

    it('should reload config if subgraph config changes', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(mock.config()),
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

    it('should not reload config if everclear config is undefined', async () => {
      getEverclearConfigStub.resolves(undefined);
      const res = await shouldReloadEverclearConfig();
      expect(res).to.be.deep.eq({ reloadConfig: false, reloadSubgraph: false });
    });
  });
});
