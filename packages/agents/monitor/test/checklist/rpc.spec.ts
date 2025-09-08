import { expect, chainWrapper } from '@chimera-monorepo/utils';
import { restore, reset, stub, SinonStub } from 'sinon';
import { checkRpcs } from '../../src/checklist/rpc';
import { getContextStub, mock } from '../globalTestHook';
import { createProcessEnv } from '../mock';
import * as Mockable from '../../src/mockable';
import * as ChainHelpers from '../../src/helpers/chain';

describe('checkRpcs', () => {
  let sendAlertsStub: SinonStub;
  let resolveAlertsStub: SinonStub;
  let createPublicClientStub: SinonStub;
  let httpStub: SinonStub;
  let getBlockNumberStub: SinonStub;
  let getLatestBlockFromBlockMapStub: SinonStub;

  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    getContextStub.returns({
      ...mock.context(),
      config: { ...mock.config() },
    });

    sendAlertsStub = stub(Mockable, 'sendAlerts');
    sendAlertsStub.resolves();
    resolveAlertsStub = stub(Mockable, 'resolveAlerts');
    resolveAlertsStub.resolves();

    // Mock chainWrapper functions
    createPublicClientStub = stub(chainWrapper, 'createPublicClient');
    httpStub = stub(chainWrapper, 'http');
    
    // Mock client methods
    const mockClient = {
      getBlockNumber: stub().resolves(BigInt(12345)),
    };
    createPublicClientStub.returns(mockClient);
    getBlockNumberStub = mockClient.getBlockNumber;

    // Mock getLatestBlockFromBlockMap to return null so we test the RPC path
    getLatestBlockFromBlockMapStub = stub(ChainHelpers, 'getLatestBlockFromBlockMap');
    getLatestBlockFromBlockMapStub.returns(null);
  });

  afterEach(() => {
    restore();
    reset();
  });

  describe('#checkRpcs', () => {
    it('should not leak api key to alert', async () => {
      // Mock RPC calls to fail so we test the alert sending path
      getBlockNumberStub.rejects(new Error('RPC connection failed'));
      
      await checkRpcs();
      
      // Should send alerts for the 4 failed RPC calls
      expect(sendAlertsStub.callCount).to.equal(4);
      // Should not resolve any alerts since all RPCs failed
      expect(resolveAlertsStub.callCount).to.equal(0);
      // Verify that the alert reason doesn't contain the API key
      expect((sendAlertsStub.getCall(0).args[0] as any).reason).to.not.contain("mock_api_key");
    });

    it('should handle cached block numbers', async () => {
      getLatestBlockFromBlockMapStub.returns({ number: 12345 });

      await checkRpcs(1000);

      // Should call getLatestBlockFromBlockMap for each provider (4 calls)
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(4);
      // Should resolve alerts for cached blocks (4 calls)
      expect(resolveAlertsStub.callCount).to.equal(4);
      // Should not create any RPC clients since we're using cached data
      expect(createPublicClientStub.callCount).to.equal(0);
      expect(getBlockNumberStub.callCount).to.equal(0);
      // Should not send any error alerts
      expect(sendAlertsStub.callCount).to.equal(0);
    });

    it('should handle Solana network RPCs', async () => {
      getContextStub.returns({
        ...mock.context(),
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
      
      // Should call getLatestBlockFromBlockMap once for the single provider
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(1);
      // Should not create EVM clients for Solana
      expect(createPublicClientStub.callCount).to.equal(0);
      expect(getBlockNumberStub.callCount).to.equal(0);
      // Should resolve alerts for successful Solana RPC calls
      expect(sendAlertsStub.callCount).to.equal(0);
      expect(resolveAlertsStub.callCount).to.equal(1);
    });

    it('should handle EVM network RPCs', async () => {
      getContextStub.returns({
        ...mock.context(),
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
      
      // Should call getLatestBlockFromBlockMap once for the single provider
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(1);
      // Should create one EVM client for the single provider
      expect(createPublicClientStub.callCount).to.equal(1);
      // Should call getBlockNumber once
      expect(getBlockNumberStub.callCount).to.equal(1);
      // Should resolve alerts for successful RPC calls
      expect(resolveAlertsStub.callCount).to.equal(1);
      // Should not send any error alerts
      expect(sendAlertsStub.callCount).to.equal(0);
    });

    it('should handle RPC errors', async () => {
      getBlockNumberStub.rejects(new Error('RPC connection failed'));

      await checkRpcs(1000);

      // Should call getLatestBlockFromBlockMap for each provider (4 calls)
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(4);
      // Should create EVM clients for EVM chains (4 calls)
      expect(createPublicClientStub.callCount).to.equal(4);
      // Should attempt to call getBlockNumber for each EVM provider (4 calls)
      expect(getBlockNumberStub.callCount).to.equal(4);
      // Should send alerts for RPC errors (4 calls)
      expect(sendAlertsStub.callCount).to.equal(4);
      // Should not resolve any alerts due to errors
      expect(resolveAlertsStub.callCount).to.equal(0);
    });

    it('should handle Solana RPC errors', async () => {
      getContextStub.returns({
        ...mock.context(),
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
      
      // Should call getLatestBlockFromBlockMap once for the single provider
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(1);
      // Should not create EVM clients for Solana
      expect(createPublicClientStub.callCount).to.equal(0);
      expect(getBlockNumberStub.callCount).to.equal(0);
      // Should resolve alerts for successful Solana RPC calls
      expect(sendAlertsStub.callCount).to.equal(0);
      expect(resolveAlertsStub.callCount).to.equal(1);
    });

    it('should handle timeout errors', async () => {
      getBlockNumberStub.returns(new Promise(() => {})); // Never resolves

      await checkRpcs(1000);

      // Should call getLatestBlockFromBlockMap for each provider (4 calls)
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(4);
      // Should create EVM clients for EVM chains (4 calls)
      expect(createPublicClientStub.callCount).to.equal(4);
      // Should attempt to call getBlockNumber for each EVM provider (4 calls)
      expect(getBlockNumberStub.callCount).to.equal(4);
      // Should send alerts for timeout errors (4 calls)
      expect(sendAlertsStub.callCount).to.equal(4);
      // Should not resolve any alerts due to timeouts
      expect(resolveAlertsStub.callCount).to.equal(0);
    });

    it('should handle undefined block number', async () => {
      getBlockNumberStub.resolves(undefined);

      await checkRpcs(1000);

      // Should call getLatestBlockFromBlockMap for each provider (4 calls)
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(4);
      // Should create EVM clients for EVM chains (4 calls)
      expect(createPublicClientStub.callCount).to.equal(4);
      // Should attempt to call getBlockNumber for each EVM provider (4 calls)
      expect(getBlockNumberStub.callCount).to.equal(4);
      // Should send alerts for undefined block numbers (4 calls)
      expect(sendAlertsStub.callCount).to.equal(4);
      // Should not resolve any alerts due to undefined block numbers
      expect(resolveAlertsStub.callCount).to.equal(0);
    });

    it('should skip Solana 429 errors', async () => {
      getContextStub.returns({
        ...mock.context(),
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
      
      // Should call getLatestBlockFromBlockMap once for the single provider
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(1);
      // Should not create EVM clients for Solana
      expect(createPublicClientStub.callCount).to.equal(0);
      expect(getBlockNumberStub.callCount).to.equal(0);
      // Should resolve alerts for successful Solana RPC calls (429 errors are skipped)
      expect(sendAlertsStub.callCount).to.equal(0);
      expect(resolveAlertsStub.callCount).to.equal(1);
    });

    it('should handle malformed URLs', async () => {
      getContextStub.returns({
        ...mock.context(),
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
      
      // Should call getLatestBlockFromBlockMap once for the single provider
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(1);
      // Should create one EVM client for the single provider
      expect(createPublicClientStub.callCount).to.equal(1);
      // Should attempt to call getBlockNumber once
      expect(getBlockNumberStub.callCount).to.equal(1);
      // Malformed URLs are handled gracefully and succeed, so we expect resolved alerts
      expect(sendAlertsStub.callCount).to.equal(0);
      expect(resolveAlertsStub.callCount).to.equal(1);
    });

    it('should handle successful RPC calls', async () => {
      await checkRpcs(1000);
      
      // Should call getLatestBlockFromBlockMap for each provider (4 calls)
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(4);
      // Should create EVM clients for EVM chains (4 calls)
      expect(createPublicClientStub.callCount).to.equal(4);
      // Should call getBlockNumber for each EVM provider (4 calls)
      expect(getBlockNumberStub.callCount).to.equal(4);
      // Should resolve alerts for successful RPC calls (4 calls)
      expect(resolveAlertsStub.callCount).to.equal(4);
      // Should not send any error alerts for successful calls
      expect(sendAlertsStub.callCount).to.equal(0);
    });

    it('should handle mixed success and failure scenarios', async () => {
      getContextStub.returns({
        ...mock.context(),
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

      // First RPC succeeds, second fails
      getBlockNumberStub.onFirstCall().resolves(BigInt(12345));
      getBlockNumberStub.onSecondCall().rejects(new Error('Connection failed'));
      
      await checkRpcs(1000);
      
      // Should call getLatestBlockFromBlockMap twice (once per provider)
      expect(getLatestBlockFromBlockMapStub.callCount).to.equal(2);
      // Should create two EVM clients (one per provider)
      expect(createPublicClientStub.callCount).to.equal(2);
      // Should call getBlockNumber twice (once per provider)
      expect(getBlockNumberStub.callCount).to.equal(2);
      // Should send alerts for the failed RPC
      expect(sendAlertsStub.callCount).to.equal(1);
      // Should resolve alerts for the successful RPC
      expect(resolveAlertsStub.callCount).to.equal(1);
    });
  });
});
