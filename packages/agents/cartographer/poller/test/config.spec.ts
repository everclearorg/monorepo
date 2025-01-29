import { expect } from '@chimera-monorepo/utils';
import { SinonStub, stub } from 'sinon';
import { getConfig, getEnvConfig } from '../src/config';
import { createProcessEnv } from './mock';
import * as Mockable from '../src/mockable';
import { createCartographerConfig } from './mock';

describe('Config', () => {
  let ssmStub: SinonStub;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
      EVERCLEAR_CONFIG: 'https://raw.githubusercontent.com/connext/chaindata/main/everclear.testnet.json',
    });
    ssmStub = stub(Mockable, 'getSsmParameter');
    ssmStub.resolves(undefined);
  });

  describe('#getEnvConfig', () => {
    it('should work', async () => {
      const retrieved = await getEnvConfig();
      expect(retrieved).to.be.not.empty
    });

    it('should read overrides from .env', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv({ logLevel: 'debug' }),
      });

      const retrieved = await getEnvConfig();
      expect(retrieved.logLevel).to.eq('debug');
    });

    it('should throw if config is invalid', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(),
        CARTOGRAPHER_LOG_LEVEL: 'fail',
      });
      await expect(getEnvConfig()).to.be.rejected;
    });

    it('should fail if config file doesnt exist', async () => {
      stub(process, 'env').value({
        CARTOGRAPHER_CONFIG_FILE: 'test-config.json',
      });
      await expect(getEnvConfig()).to.be.rejected;
    });

    it('should read config from AWS SSM parameter store', async () => {
      ssmStub.resolves(JSON.stringify({ ...createCartographerConfig(), databaseUrl: 'https://database.com' }));
      const config = await getEnvConfig();
      await expect(config.database).to.be.equal('https://database.com');
    });
  });

  describe('#getConfig', () => {
    it('should load cached config', async () => {
      const config = await getConfig();

      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv({ logLevel: 'warn' }),
      });
      const config2 = await getConfig();
      expect(config.logLevel).to.eq(config2.logLevel);
      expect(config.logLevel).to.eq('silent');
    });
  });
});
