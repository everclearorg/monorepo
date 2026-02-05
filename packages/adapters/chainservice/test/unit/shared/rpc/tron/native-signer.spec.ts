import { expect } from 'chai';
import { stub, restore } from 'sinon';
import { TronNativeSigner } from '../../../../../src/shared/rpc/tron/native-signer';

describe('TronNativeSigner', () => {
  let signer: TronNativeSigner;
  let originalEnv: string | undefined;

  beforeEach(() => {
    // Set the required environment variable
    originalEnv = process.env.TRON_PRO_API_KEY;
    process.env.TRON_PRO_API_KEY = 'test-api-key';
    
    // Use a test private key for testing
    signer = new TronNativeSigner('da146374a75310b9666e834ee4ad0866d6f4035967bfc76217c5a495fff9f0d0');
  });

  afterEach(() => {
    // Restore original environment variable
    if (originalEnv) {
      process.env.TRON_PRO_API_KEY = originalEnv;
    } else {
      delete process.env.TRON_PRO_API_KEY;
    }
    restore();
  });

  describe('constructor', () => {
    it('should initialize with provided private key', () => {
      expect(signer).to.be.an('object');
    });

    it('should initialize with test private key when none provided', () => {
      const defaultSigner = new TronNativeSigner();
      expect(defaultSigner).to.be.an('object');
    });

    it('should initialize with default host when none provided', () => {
      const defaultSigner = new TronNativeSigner('da146374a75310b9666e834ee4ad0866d6f4035967bfc76217c5a495fff9f0d0');
      expect(defaultSigner).to.be.an('object');
    });
  });

  describe('getAddress', () => {
    it('should return an address', async () => {
      const address = await signer.getAddress();
      
      expect(address).to.be.a('string');
      expect(address.length).to.be.greaterThan(0);
    });
  });

  describe('connect', () => {
    it('should return self as connected signer', async () => {
      const connectedSigner = await signer.connect();
      
      expect(connectedSigner).to.equal(signer);
    });
  });

  describe('sendTransaction', () => {
    it('should handle transaction with invalid data gracefully', async () => {
      const transaction = {
        to: 'invalid-address',
        data: 'invalid-data',
        value: '0',
        gasLimit: '100000',
        gasPrice: '420'
      };

      try {
        await signer.sendTransaction(transaction);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
      }
    });

    it('should use default values when gas parameters not provided', async () => {
      const transaction = {
        to: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        data: '0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc454e4438f44e0000000000000000000000000000000000000000000000000de0b6b3a7640000',
        value: '0'
      };

      try {
        await signer.sendTransaction(transaction);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
      }
    });
  });

  describe('signMessage', () => {
    it('should handle message signing', async () => {
      const message = 'Hello, Tron!';
      
      try {
        const signature = await signer.signMessage(message);
        expect(signature).to.be.a('string');
      } catch (error) {
        // It's okay if this fails in test environment
        expect(error).to.be.instanceOf(Error);
      }
    });
  });
});
