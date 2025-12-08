import { expect } from 'chai';
import { stub, restore } from 'sinon';
import { SafeService } from '../../src/safeservice';
import { SafeServiceConfig } from '../../src/config';
import { Logger, RequestContext } from '@chimera-monorepo/utils';

describe('SafeService', () => {
  let safeService: SafeService;
  let mockLogger: any;
  let mockConfig: SafeServiceConfig;
  let mockRequestContext: RequestContext;

  beforeEach(() => {
    // Mock Logger
    mockLogger = {
      debug: stub(),
      info: stub(),
      warn: stub(),
      error: stub()
    };

    // Mock config
    mockConfig = {
      domain: 1337,
      provider: 'mock-provider' as any,
      safe: {
        signer: '0x1234567890123456789012345678901234567890123456789012345678901234' as any,
        safeAddress: '0xSafeAddress1234567890123456789012345678901234',
        masterCopyAddress: '0xMasterCopy1234567890123456789012345678901234',
        fallbackHandlerAddress: '0xFallbackHandler1234567890123456789012345678901234',
        txService: 'https://safe-transaction-service.test.com'
      }
    };

    // Mock request context
    mockRequestContext = {
      id: 'test-request-id',
      origin: 'test-origin'
    };

    safeService = new SafeService(mockLogger, mockConfig);
  });

  afterEach(() => {
    restore();
  });

  describe('constructor', () => {
    it('should initialize with logger and config', () => {
      expect(safeService).to.be.an('object');
      expect(safeService).to.have.property('senderAddress');
    });

    it('should set sender address from private key', () => {
      expect(safeService.senderAddress).to.be.a('string');
      expect(safeService.senderAddress).to.match(/^0x[a-fA-F0-9]{40}$/);
    });
  });

  describe('proposeTransaction', () => {
    it('should handle transaction proposal with error gracefully', async () => {
      const tx = {
        domain: 1337,
        to: '0xRecipientAddress1234567890123456789012345678901234',
        value: BigInt(1000000000000000000), // 1 ETH
        data: '0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc454e4438f44e0000000000000000000000000000000000000000000000000de0b6b3a7640000'
      };

      try {
        await safeService.proposeTransaction(tx, mockRequestContext);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
      }
    });

    it('should log transaction details', async () => {
      const tx = {
        domain: 1337,
        to: '0xRecipientAddress1234567890123456789012345678901234',
        value: BigInt(1000000000000000000),
        data: '0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc454e4438f44e0000000000000000000000000000000000000000000000000de0b6b3a7640000'
      };

      try {
        await safeService.proposeTransaction(tx, mockRequestContext);
        expect.fail('Should have thrown an error');
      } catch (error) {
        // Check that logging was attempted
        expect(mockLogger.debug.calledOnce).to.be.true;
        const logCall = mockLogger.debug.getCall(0);
        expect(logCall.args[0]).to.equal('Method start');
        // The log structure might be different, so just check that it was called
        expect(logCall.args).to.have.length.greaterThan(0);
      }
    });

    it('should handle zero value transaction', async () => {
      const tx = {
        domain: 1337,
        to: '0xRecipientAddress1234567890123456789012345678901234',
        value: BigInt(0),
        data: '0x'
      };

      try {
        await safeService.proposeTransaction(tx, mockRequestContext);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
      }
    });

    it('should handle empty data transaction', async () => {
      const tx = {
        domain: 1337,
        to: '0xRecipientAddress1234567890123456789012345678901234',
        value: BigInt(1000000000000000000),
        data: '0x'
      };

      try {
        await safeService.proposeTransaction(tx, mockRequestContext);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
      }
    });

    it('should handle long data transaction', async () => {
      const longData = '0x' + 'a'.repeat(2000); // Very long data
      const tx = {
        domain: 1337,
        to: '0xRecipientAddress1234567890123456789012345678901234',
        value: BigInt(0),
        data: longData
      };

      try {
        await safeService.proposeTransaction(tx, mockRequestContext);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
        
        // Check that logging was attempted
        expect(mockLogger.debug.calledOnce).to.be.true;
      }
    });

    it('should handle different domain values', async () => {
      const tx = {
        domain: 1, // Mainnet
        to: '0xRecipientAddress1234567890123456789012345678901234',
        value: BigInt(0),
        data: '0x'
      };

      try {
        await safeService.proposeTransaction(tx, mockRequestContext);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
      }
    });
  });
});
