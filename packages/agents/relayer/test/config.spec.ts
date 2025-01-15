import { expect } from '@chimera-monorepo/utils';
import { stub } from 'sinon';
import { getConfig, getEnvConfig } from '../src/config';
import { createProcessEnv, createRelayerConfig } from './mock';

describe('Config', () => {
  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
  });

  describe('#getEnvConfig', () => {
    it('should work', async () => {
      const retrieved = await getEnvConfig();
      const config = createRelayerConfig();
      expect(retrieved).to.containSubset(config);
    });

    it('should read overrides from .env', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv({ logLevel: 'debug' }),
      });

      const retrieved = await getEnvConfig();
      const config = createRelayerConfig();
      expect(retrieved).to.containSubset(config);
    });

    it('should throw if config is invalid', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(),
        RELAYER_LOG_LEVEL: 'fail',
      });
      await expect(getEnvConfig()).to.be.rejected;
    });

    it('should not fail if config file doesnt exist', async () => {
      stub(process, 'env').value({
        ...process.env,
        ...createProcessEnv(),
        EVERCLEAR_CONFIG_FILE: '',
        RELAYER_CONFIG_FILE: 'test-config.json',
      });
      console.error(await getEnvConfig());
      await expect(getEnvConfig()).to.be.fulfilled;
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
      expect(config.logLevel).to.eq('info');
    });
  });
});
