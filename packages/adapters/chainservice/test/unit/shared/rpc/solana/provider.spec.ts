import { expect } from 'chai';
import { stub, restore } from 'sinon';
import { SolanaProvider } from '../../../../../src/shared/rpc/solana/provider';

describe('SolanaProvider', () => {
  let provider: SolanaProvider;

  beforeEach(() => {
    provider = new SolanaProvider('https://api.testnet.solana.com');
  });

  afterEach(() => {
    restore();
  });

  describe('constructor', () => {
    it('should initialize with default values', () => {
      expect(provider.name).to.equal('SolanaProvider');
      expect(provider.syncedBlockNumber).to.equal(0);
      expect(provider.synced).to.be.false;
      expect(provider.priority).to.equal(0);
      expect(provider.lag).to.equal(0);
      expect(provider.reliability).to.equal(1.0);
      expect(provider.latency).to.equal(0.0);
      expect(provider.cpsTimestamps).to.be.an('array');
    });

    it('should handle URL with https:// prefix', () => {
      const httpsProvider = new SolanaProvider('https://api.testnet.solana.com');
      expect(httpsProvider.name).to.equal('SolanaProvider');
    });

    it('should handle URL without https:// prefix', () => {
      const httpProvider = new SolanaProvider('api.testnet.solana.com');
      expect(httpProvider.name).to.equal('SolanaProvider');
    });
  });

  describe('send', () => {
    it('should throw not implemented error', async () => {
      try {
        await provider.send('test-method', []);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.equal('Method not implemented.');
      }
    });
  });

  describe('estimateGas', () => {
    it('should throw not implemented error', async () => {
      const tx = {
        to: 'test-address',
        data: '0x',
        value: '0'
      };

      try {
        await provider.estimateGas(tx);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.equal('Method not implemented.');
      }
    });
  });

  describe('getCode', () => {
    it('should throw not implemented error', async () => {
      try {
        await provider.getCode('test-address');
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.equal('Method not implemented.');
      }
    });
  });

  describe('getDecimals', () => {
    it('should throw not implemented error', async () => {
      try {
        await provider.getDecimals('test-address');
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.equal('Method not implemented.');
      }
    });
  });

  describe('getTransactionCount', () => {
    it('should throw not implemented error', async () => {
      try {
        await provider.getTransactionCount('test-address', 'latest');
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.equal('Method not implemented.');
      }
    });
  });

  describe('cps property', () => {
    it('should calculate calls per second', () => {
      const now = Date.now();
      provider.cpsTimestamps = [
        now - 5000, // 5 seconds ago
        now - 3000, // 3 seconds ago
        now - 1000, // 1 second ago
      ];

      const cps = provider.cps;
      expect(cps).to.equal(0.3); // 3 calls over 10 seconds
    });

    it('should filter old timestamps', () => {
      const now = Date.now();
      provider.cpsTimestamps = [
        now - 15000, // 15 seconds ago (should be filtered)
        now - 5000,  // 5 seconds ago
        now - 1000,  // 1 second ago
      ];

      const cps = provider.cps;
      expect(cps).to.equal(0.2); // 2 calls over 10 seconds
      expect(provider.cpsTimestamps).to.have.length(2);
    });
  });

  describe('connect', () => {
    it('should delegate to getSigner', async () => {
      const getSignerStub = stub(provider, 'getSigner').resolves({} as any);
      
      await provider.connect('test-signer');
      
      expect(getSignerStub.calledOnce).to.be.true;
      expect(getSignerStub.calledWith('test-signer')).to.be.true;
    });
  });
});

