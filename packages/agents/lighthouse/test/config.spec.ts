import { expect } from '@chimera-monorepo/utils';
import { stub, SinonStub } from 'sinon';
import { getConfig, loadConfig } from '../src/config';
import { InvalidConfig } from '../src/errors';
import { mock } from './globalTestHook';
import * as Mockable from '../src/tasks/helpers/mockable';

describe('Config', () => {
  let exitStub: SinonStub;
  let ssmStub: SinonStub;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...mock.env(),
    });
    exitStub = stub(process, 'exit');
    exitStub.returns(1);
    ssmStub = stub(Mockable, 'getSsmParameter');
    ssmStub.resolves(undefined);
  });
  describe('#loadConfig', () => {
    it('should work', async () => {
      await expect(loadConfig()).to.be.fulfilled;
    });

    it('should read overrides from .env', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...mock.env(),
        LIGHTHOUSE_LOG_LEVEL: 'debug',
      });
      const config = await loadConfig();
      expect(config).to.containSubset({
        logLevel: 'debug',
        environment: mock.env().LIGHTHOUSE_ENVIRONMENT,
        service: mock.env().LIGHTHOUSE_SERVICE,
        chains: mock.chains(),
        healthUrls: mock.health(),
        hub: mock.hub(),
        database: mock.database(),
      });
    });

    it('should throw if config is invalid', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...mock.env(),
        LIGHTHOUSE_LOG_LEVEL: 'fail',
      });
      await expect(loadConfig()).to.be.rejectedWith(InvalidConfig);
    });

    it('should read config from the config file', async () => {
      stub(process, 'env').value({
        LIGHTHOUSE_CONFIG: 'xxx',
        LIGHTHOUSE_CONFIG_FILE: './test/test_config.json',
      }); 
      await expect(loadConfig()).to.be.fulfilled;
    })

    it('should fail if config file doesnt exist', async () => {
      stub(process, 'env').value({
        LIGHTHOUSE_CONFIG_FILE: 'test-config.json',
      });
      await expect(loadConfig()).to.be.rejected;
    });

    it('should fail if config file is as empty json', async () => {
      stub(process, 'env').value({
        LIGHTHOUSE_CONFIG_FILE: './empty_config.json',
      });
      await expect(loadConfig()).to.be.rejected;
    });

    it('should fail if config file is unreadable', async () => {
      stub(process, 'env').value({
        LIGHTHOUSE_CONFIG_FILE: '/dev/null',
      });
      await expect(getConfig()).to.be.rejected;
      expect(exitStub.calledOnce).to.be.true;
    });

    it('should read config from AWS SSM parameter store', async () => {
      stub(process, 'env').value({
        ...process.env,
        CONFIG_PARAMETER_NAME: 'lighthouse-config',
      });
      ssmStub.resolves(JSON.stringify(mock.config({ coingecko: 'prices.com' })));
      const config = await getConfig();
      await expect(config.coingecko).to.be.equal('prices.com');
    });
  });

  describe('#getConfig', () => {
    it('should load cached config', async () => {
      const config = await getConfig();

      stub(process, 'env').value({
        ...process.env,
        LIGHTHOUSE_LOG_LEVEL: 'debug',
      });
      const config2 = await getConfig();
      expect(config.logLevel).to.eq(config2.logLevel);
      expect(config.logLevel).to.eq('info');
    });
  });
});
