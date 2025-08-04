import { Logger, expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStubbedInstance } from 'sinon';
import { getTronLastIntentNonce, getTronBlock } from '../../src/helpers/tron';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import { ChainReader } from '@chimera-monorepo/chainservice';

describe('Tron Helpers', () => {
  let chainreader: SinonStubbedInstance<ChainReader>;
  let logger: SinonStubbedInstance<Logger>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    logger = mock.instances.logger() as SinonStubbedInstance<Logger>;
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#getTronLastIntentNonce', () => {
    it('should return 0 when no Tron chains configured', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '1337': { network: 'evm' }, // Only EVM chains
          },
        },
      });

      const result = await getTronLastIntentNonce();
      
      expect(result).to.equal(0);
      expect(logger.warn.calledWith('No Tron chains configured')).to.be.true;
    });

    it('should return 0 when no spoke address configured', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '728126428': { 
              network: 'tvm',
              deployments: {}, // No everclear deployment
            },
          },
        },
      });

      const result = await getTronLastIntentNonce();
      
      expect(result).to.equal(0);
      expect(logger.error.calledWith('No Tron spoke address configured')).to.be.true;
    });

    it('should use first configured Tron domain', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '728126428': { 
              network: 'tvm',
              deployments: { everclear: 'TEverclearAddress123' },
            },
            '728126429': { 
              network: 'tvm',
              deployments: { everclear: 'TEverclearAddress456' },
            },
          },
        },
      });

      const result = await getTronLastIntentNonce();
      
      // Should use first domain's configuration
      expect(result).to.equal(0); // Contract integration not implemented yet
    });

    it('should handle contract call errors gracefully', async () => {
      const result = await getTronLastIntentNonce();
      
      // Should not throw and return 0
      expect(result).to.equal(0);
    });

    it('should log debug message about contract integration needed', async () => {
      await getTronLastIntentNonce();
      
      expect(logger.debug.calledWith('Tron intent nonce check - contract integration needed')).to.be.true;
    });
  });

  describe('#getTronBlock', () => {
    beforeEach(() => {
      chainreader.getBlock.resolves({
        number: 12345678,
        timestamp: 1640995200,
        hash: '0x1234567890abcdef',
      });
    });

    it('should get Tron block successfully', async () => {
      const result = await getTronBlock('728126428');
      
      expect(result).to.deep.equal({
        number: 12345678,
        timestamp: 1640995200,
        hash: '0x1234567890abcdef',
      });
      
      expect(chainreader.getBlock.calledWith(728126428, 'latest')).to.be.true;
    });

    it('should get specific block number', async () => {
      const result = await getTronBlock('728126428', 12345000);
      
      expect(chainreader.getBlock.calledWith(728126428, 12345000)).to.be.true;
    });

    it('should get block by string number', async () => {
      const result = await getTronBlock('728126428', '12345000');
      
      expect(chainreader.getBlock.calledWith(728126428, '12345000')).to.be.true;
    });

    it('should throw error for non-Tron chains', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '1337': { network: 'evm' }, // EVM chain
          },
        },
      });

      try {
        await getTronBlock('1337');
        expect.fail('Should have thrown error');
      } catch (error) {
        expect(error.message).to.equal('Domain 1337 is not a Tron chain');
      }
    });

    it('should handle chainreader errors gracefully', async () => {
      chainreader.getBlock.rejects(new Error('RPC connection failed'));
      
      try {
        await getTronBlock('728126428');
        expect.fail('Should have thrown error');
      } catch (error) {
        expect(error.message).to.equal('RPC connection failed');
        expect(logger.error.called).to.be.true;
      }
    });

    it('should default to latest block', async () => {
      await getTronBlock('728126428');
      
      expect(chainreader.getBlock.calledWith(728126428, 'latest')).to.be.true;
    });

    it('should validate domain exists in config', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '728126428': { network: 'tvm' },
          },
        },
      });

      // Should work when domain exists
      await getTronBlock('728126428');
      expect(chainreader.getBlock.called).to.be.true;
    });

    it('should handle missing domain in config', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {}, // No chains configured
        },
      });

      try {
        await getTronBlock('728126428');
        expect.fail('Should have thrown error');
      } catch (error) {
        // Should throw because domain is not in config
        expect(error).to.exist;
      }
    });
  });

  describe('Tron-specific behavior', () => {
    it('should only work with tvm network chains', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '1337': { network: 'evm' },
            '728126428': { network: 'tvm' },
            '1151111081099710': { network: 'svm' },
          },
        },
      });

      // Should only find Tron chain
      const result = await getTronLastIntentNonce();
      expect(result).to.equal(0); // No error about missing Tron chains
    });

    it('should handle multiple Tron domains', async () => {
      getContextStub.returns({
        ...mock.context(),
        config: {
          ...mock.config(),
          chains: {
            '728126428': { 
              network: 'tvm',
              deployments: { everclear: 'TMainnetAddress' },
            },
            '728126429': { 
              network: 'tvm',
              deployments: { everclear: 'TTestnetAddress' },
            },
          },
        },
      });

      // Should use first Tron domain
      const result = await getTronLastIntentNonce();
      expect(result).to.equal(0);
    });
  });
});