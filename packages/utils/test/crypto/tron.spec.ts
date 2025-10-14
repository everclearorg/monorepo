import {
  expect,
  generateTronKeyPair,
  getAddressFromPrivateKey,
  ethereumToTronAddress, 
  signTransactionHash,
  signMessage,
  verifyMessage,
  createTronWeb,
  TEST_TRON_KEYS,
} from '../../src';
import { restore, stub, SinonStub } from 'sinon';

// Mock process.env
const originalEnv = process.env;

describe('Tron Crypto Functions', () => {
  let mockTronWeb: any;
  let mockTronWebInstance: any;
  let mockTronWebConstructor: SinonStub;

  beforeEach(() => {
    restore();
    process.env = { ...originalEnv };
    
    // Create fresh mocks for each test
    mockTronWeb = {
      createAccount: stub(),
      address: {
        fromPrivateKey: stub(),
        toHex: stub(),
        fromHex: stub(),
      },
    };

    mockTronWebInstance = {
      trx: {
        sign: stub(),
        signMessageV2: stub(),
        verifyMessageV2: stub(),
      },
    };

    mockTronWebConstructor = stub();
    mockTronWebConstructor.returns(mockTronWebInstance);
  });

  after(() => {
    process.env = originalEnv;
  });

  describe('generateTronKeyPair', () => {
    it('should be a function', () => {
      expect(generateTronKeyPair).to.be.a('function');
    });
  });

  describe('getAddressFromPrivateKey', () => {
    it('should be a function', () => {
      expect(getAddressFromPrivateKey).to.be.a('function');
    });
  });

  describe('ethereumToTronAddress', () => {
    it('should throw error for invalid Ethereum address format', () => {
      expect(() => ethereumToTronAddress('invalid-address')).to.throw('Invalid Ethereum address format');
    });

    it('should handle addresses without 0x prefix', () => {
      expect(() => ethereumToTronAddress('928c9af0651632157ef27a2cf17ca72c575a4d21')).to.throw('Invalid Ethereum address format');
    });

    it('should handle empty string', () => {
      expect(() => ethereumToTronAddress('')).to.throw('Invalid Ethereum address format');
    });

    it('should handle null input', () => {
      expect(() => ethereumToTronAddress(null as any)).to.throw();
    });

    it('should handle undefined input', () => {
      expect(() => ethereumToTronAddress(undefined as any)).to.throw();
    });

  });

  describe('signTransactionHash', () => {
    it('should be a function', () => {
      expect(signTransactionHash).to.be.a('function');
    });
  });

  describe('signMessage', () => {
    it('should be a function', () => {
      expect(signMessage).to.be.a('function');
    });
  });

  describe('verifyMessage', () => {
    it('should be a function', () => {
      expect(verifyMessage).to.be.a('function');
    });
  });

  describe('createTronWeb', () => {
    it('should be a function', () => {
      expect(createTronWeb).to.be.a('function');
    });

    it('should throw error when TRON_PRO_API_KEY is not set', () => {
      delete process.env.TRON_PRO_API_KEY;

      expect(() => createTronWeb(TEST_TRON_KEYS.PRIVATE_KEY)).to.throw('TRON_PRO_API_KEY is not set');
    });

    it('should throw error when TRON_PRO_API_KEY is empty string', () => {
      process.env.TRON_PRO_API_KEY = '';

      expect(() => createTronWeb(TEST_TRON_KEYS.PRIVATE_KEY)).to.throw('TRON_PRO_API_KEY is not set');
    });

    it('should throw error when TRON_PRO_API_KEY is null', () => {
      process.env.TRON_PRO_API_KEY = null as any;

      expect(() => createTronWeb(TEST_TRON_KEYS.PRIVATE_KEY)).to.throw('TRON_PRO_API_KEY is not set');
    });

    it('should throw error when TRON_PRO_API_KEY is undefined', () => {
      process.env.TRON_PRO_API_KEY = undefined as any;

      expect(() => createTronWeb(TEST_TRON_KEYS.PRIVATE_KEY)).to.throw('TRON_PRO_API_KEY is not set');
    });

    it('should handle empty private key', () => {
      process.env.TRON_PRO_API_KEY = 'test-key';

      // This will create TronWeb instance but with empty private key
      expect(() => createTronWeb('')).to.not.throw();
    });

    it('should handle null private key', () => {
      process.env.TRON_PRO_API_KEY = 'test-key';

      // This will create TronWeb instance but with null private key
      expect(() => createTronWeb(null as any)).to.not.throw();
    });

    it('should handle undefined private key', () => {
      process.env.TRON_PRO_API_KEY = 'test-key';

      // This will create TronWeb instance but with undefined private key
      expect(() => createTronWeb(undefined as any)).to.not.throw();
    });
  });
});
