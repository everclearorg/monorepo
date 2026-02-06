import { expect } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub, SinonStubbedInstance } from 'sinon';
import { checkRpcs } from '../../src/checklist/rpc';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import * as Mockable from '../../src/mockable';
import { ChainReader } from '@chimera-monorepo/chainservice';

describe('checkRpcs', () => {
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let chainreader: SinonStubbedInstance<ChainReader>;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts');
    resolveAlertsStub.resolves();

    // Mock ChainReader
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    chainreader.getBlockNumber.resolves(12345);

    getContextStub.returns({
      ...mock.context(),
      adapters: {
        ...mock.context().adapters,
        chainreader,
      },
      config: { ...mock.config() },
    });
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkRpcs', () => {
    it('should not leak api key to alert', async () => {
      // Mock ChainReader to fail so we test the alert sending path
      chainreader.getBlockNumber.rejects(new Error('RPC connection failed'));
      
      await checkRpcs();
      
      // Should send alerts for failed RPC calls (number depends on config.chains)
      expect(sendAlertsStub.callCount).to.be.greaterThan(0);
      // Should not resolve any alerts since all RPCs failed
      expect(resolveAlertsStub.callCount).to.equal(0);
      // Verify that the alert reason doesn't contain the API key
      if (sendAlertsStub.callCount > 0) {
        expect((sendAlertsStub.getCall(0).args[0] as any).reason).to.not.contain("mock_api_key");
      }
    });

    it('should always fetch block numbers from RPC using ChainReader', async () => {
      await checkRpcs(1000);

      // Should use ChainReader.getBlockNumber (number of calls depends on config.chains)
      expect(chainreader.getBlockNumber.callCount).to.be.greaterThan(0);
      // Should not create any viem clients
      // Should resolve alerts for successful RPC calls
      expect(resolveAlertsStub.callCount).to.be.greaterThan(0);
      // Should not send any error alerts
      expect(sendAlertsStub.callCount).to.equal(0);
    });

    it('should handle Solana network RPCs', async () => {
      chainreader.getBlockNumber.resolves(12345);
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          chainreader,
        },
        config: {
          ...mock.config(),
          chains: {
            '1399811149': {
              providers: ['https://api.mainnet-beta.solana.com'],
              network: 'svm',
            },
          },
        },
      });

      await checkRpcs(1000);

      // Should use ChainReader.getBlockNumber for Solana
      expect(chainreader.getBlockNumber.callCount).to.equal(1);
      // Should resolve alerts for successful Solana RPC calls (only first provider)
      expect(sendAlertsStub.callCount).to.equal(0);
      expect(resolveAlertsStub.callCount).to.equal(1);
    });

    it('should handle EVM network RPCs', async () => {
      chainreader.getBlockNumber.resolves(12345);
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          chainreader,
        },
        config: {
          ...mock.config(),
          chains: {
            '1337': {
              providers: ['https://rpc.example.com'],
              network: 'evm',
            },
          },
        },
      });

      await checkRpcs(1000);

      // Should use ChainReader.getBlockNumber
      expect(chainreader.getBlockNumber.callCount).to.equal(1);
      // Should resolve alerts for successful RPC calls (all providers)
      expect(resolveAlertsStub.callCount).to.equal(1);
      // Should not send any error alerts
      expect(sendAlertsStub.callCount).to.equal(0);
    });

    it('should handle RPC errors', async () => {
      chainreader.getBlockNumber.rejects(new Error('RPC connection failed'));

      await checkRpcs(1000);

      // Should use ChainReader.getBlockNumber (number depends on config.chains)
      expect(chainreader.getBlockNumber.callCount).to.be.greaterThan(0);
      // Should send alerts for RPC errors
      expect(sendAlertsStub.callCount).to.be.greaterThan(0);
      // Should not resolve any alerts due to errors
      expect(resolveAlertsStub.callCount).to.equal(0);
    });

    it('should handle Solana RPC errors', async () => {
      chainreader.getBlockNumber.rejects(new Error('RPC connection failed'));
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          chainreader,
        },
        config: {
          ...mock.config(),
          chains: {
            '1399811149': {
              providers: ['https://api.mainnet-beta.solana.com'],
              network: 'svm',
            },
          },
        },
      });

      await checkRpcs(1000);

      // Should use ChainReader.getBlockNumber for Solana
      expect(chainreader.getBlockNumber.callCount).to.equal(1);
      // Should send alerts for failed Solana RPC calls
      expect(sendAlertsStub.callCount).to.equal(1);
      // Should not resolve any alerts due to errors
      expect(resolveAlertsStub.callCount).to.equal(0);
    });

    it('should handle timeout errors', async () => {
      chainreader.getBlockNumber.returns(new Promise(() => {})); // Never resolves

      await checkRpcs(1000);

      // Should use ChainReader.getBlockNumber (number depends on config.chains)
      expect(chainreader.getBlockNumber.callCount).to.be.greaterThan(0);
      // Should send alerts for timeout errors
      expect(sendAlertsStub.callCount).to.be.greaterThan(0);
      // Should not resolve any alerts due to timeouts
      expect(resolveAlertsStub.callCount).to.equal(0);
    });


    it('should skip Solana 429 errors', async () => {
      chainreader.getBlockNumber.rejects(new Error('429 Too Many Requests'));
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          chainreader,
        },
        config: {
          ...mock.config(),
          chains: {
            '1399811149': {
              providers: ['https://api.mainnet-beta.solana.com'],
              network: 'svm',
            },
          },
        },
      });

      await checkRpcs(1000);

      // Should use ChainReader.getBlockNumber for Solana
      expect(chainreader.getBlockNumber.callCount).to.equal(1);
      // Should skip alerts for Solana 429 errors
      expect(sendAlertsStub.callCount).to.equal(0);
      // Should not resolve any alerts due to errors
      expect(resolveAlertsStub.callCount).to.equal(0);
    });

    it('should handle malformed URLs', async () => {
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          chainreader,
        },
        config: {
          ...mock.config(),
          chains: {
            '1337': {
              providers: ['malformed-url'],
              network: 'evm',
            },
          },
        },
      });

      await checkRpcs(1000);

      // Should not call ChainReader.getBlockNumber for malformed URLs
      expect(chainreader.getBlockNumber.callCount).to.equal(0);
      // Should report malformed URL as bad RPC
      expect(sendAlertsStub.callCount).to.equal(1);
      // Should not resolve any alerts for malformed URLs
      expect(resolveAlertsStub.callCount).to.equal(0);
      // Verify malformed URL error message doesn't expose the full URL
      const alertReason = (sendAlertsStub.getCall(0).args[0] as any).reason;
      expect(alertReason).to.not.contain('malformed-url');
      expect(alertReason).to.contain('Invalid URL format');
    });

    it('should handle successful RPC calls', async () => {
      chainreader.getBlockNumber.resolves(12345);
      await checkRpcs(1000);

      // Should use ChainReader.getBlockNumber (number depends on config.chains)
      expect(chainreader.getBlockNumber.callCount).to.be.greaterThan(0);
      // Should resolve alerts for successful RPC calls
      expect(resolveAlertsStub.callCount).to.be.greaterThan(0);
      // Should not send any error alerts for successful calls
      expect(sendAlertsStub.callCount).to.equal(0);
    });

    it('should handle mixed success and failure scenarios', async () => {
      chainreader.getBlockNumber.rejects(new Error('Connection failed'));
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          chainreader,
        },
        config: {
          ...mock.config(),
          chains: {
            '1337': {
              providers: ['https://good-rpc.com', 'https://bad-rpc.com'],
              network: 'evm',
            },
          },
        },
      });

      await checkRpcs(1000);

      // Should use ChainReader.getBlockNumber once (aggregates all providers)
      expect(chainreader.getBlockNumber.callCount).to.equal(1);
      // Should send alerts for all providers when ChainService fails (2 providers)
      expect(sendAlertsStub.callCount).to.equal(2);
      // Should not resolve any alerts due to errors
      expect(resolveAlertsStub.callCount).to.equal(0);
    });

    it('should only check first Solana provider', async () => {
      chainreader.getBlockNumber.resolves(12345);
      getContextStub.returns({
        ...mock.context(),
        adapters: {
          ...mock.context().adapters,
          chainreader,
        },
        config: {
          ...mock.config(),
          chains: {
            '1399811149': {
              providers: [
                'https://api.mainnet-beta.solana.com',
                'https://api2.mainnet-beta.solana.com',
              ],
              network: 'svm',
            },
          },
        },
      });

      await checkRpcs(1000);

      // Should use ChainReader.getBlockNumber once (only first Solana provider checked)
      expect(chainreader.getBlockNumber.callCount).to.equal(1);
      // Should resolve alerts for only the first provider
      expect(resolveAlertsStub.callCount).to.equal(1);
      // Should not send any error alerts
      expect(sendAlertsStub.callCount).to.equal(0);
    });
  });
});
