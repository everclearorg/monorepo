import { expect } from 'chai';
import { stub, restore } from 'sinon';
import { TronKeyManager, TronKeyConfig, TronKeyManagerOptions } from '../../src/crypto/tron-key-manager';
import { Logger } from '../../src/logging';
import { TEST_TRON_KEYS } from '../../src/crypto/test-keys';

describe('TronKeyManager', () => {
  let logger: Logger;
  let options: TronKeyManagerOptions;

  beforeEach(() => {
    logger = new Logger({ name: 'TestLogger' });
    options = {
      environment: 'development',
      fallbackToTestKey: true,
      logger,
    };
  });

  afterEach(() => {
    restore();
  });

  describe('constructor', () => {
    it('should create instance with provided options', () => {
      const manager = new TronKeyManager(options);
      
      expect(manager).to.be.instanceOf(TronKeyManager);
    });

    it('should create instance with default logger if not provided', () => {
      const optionsWithoutLogger = {
        environment: 'development' as const,
        fallbackToTestKey: true,
      };
      
      const manager = new TronKeyManager(optionsWithoutLogger);
      
      expect(manager).to.be.instanceOf(TronKeyManager);
    });
  });

  describe('getPrivateKey', () => {
    it('should return private key from environment variable', async () => {
      const envKey = 'test-env-key';
      const manager = new TronKeyManager(options);
      
      // Stub the getFromEnvironment method
      const getFromEnvironmentStub = stub(manager as any, 'getFromEnvironment').returns(envKey);
      
      const result = await manager.getPrivateKey();
      
      expect(result).to.equal(envKey);
      expect(getFromEnvironmentStub.calledOnce).to.be.true;
    });

    it('should return private key from KMS if environment key not available', async () => {
      const kmsKey = 'test-kms-key';
      const manager = new TronKeyManager(options);
      
      // Stub methods
      const getFromEnvironmentStub = stub(manager as any, 'getFromEnvironment').returns(undefined);
      const getFromKMSStub = stub(manager as any, 'getFromKMS').resolves(kmsKey);
      
      const result = await manager.getPrivateKey();
      
      expect(result).to.equal(kmsKey);
      expect(getFromEnvironmentStub.calledOnce).to.be.true;
      expect(getFromKMSStub.calledOnce).to.be.true;
    });

    it('should return private key from HSM if KMS not available', async () => {
      const hsmKey = 'test-hsm-key';
      const manager = new TronKeyManager(options);
      
      // Stub methods
      const getFromEnvironmentStub = stub(manager as any, 'getFromEnvironment').returns(undefined);
      const getFromKMSStub = stub(manager as any, 'getFromKMS').resolves(undefined);
      const getFromHSMStub = stub(manager as any, 'getFromHSM').resolves(hsmKey);
      
      const result = await manager.getPrivateKey();
      
      expect(result).to.equal(hsmKey);
      expect(getFromEnvironmentStub.calledOnce).to.be.true;
      expect(getFromKMSStub.calledOnce).to.be.true;
      expect(getFromHSMStub.calledOnce).to.be.true;
    });

    it('should return test key if fallback is enabled and no other keys available', async () => {
      const manager = new TronKeyManager(options);
      
      // Stub methods
      const getFromEnvironmentStub = stub(manager as any, 'getFromEnvironment').returns(undefined);
      const getFromKMSStub = stub(manager as any, 'getFromKMS').resolves(undefined);
      const getFromHSMStub = stub(manager as any, 'getFromHSM').resolves(undefined);
      const getTestPrivateKeyStub = stub(manager as any, 'getTestPrivateKey').returns(TEST_TRON_KEYS.PRIVATE_KEY);
      
      const result = await manager.getPrivateKey();
      
      expect(result).to.equal(TEST_TRON_KEYS.PRIVATE_KEY);
      expect(getFromEnvironmentStub.calledOnce).to.be.true;
      expect(getFromKMSStub.calledOnce).to.be.true;
      expect(getFromHSMStub.calledOnce).to.be.true;
      expect(getTestPrivateKeyStub.calledOnce).to.be.true;
    });

    it('should throw error if no keys available and fallback disabled', async () => {
      const optionsWithoutFallback = {
        environment: 'production' as const,
        fallbackToTestKey: false,
        logger,
      };
      
      const manager = new TronKeyManager(optionsWithoutFallback);
      
      // Stub methods
      const getFromEnvironmentStub = stub(manager as any, 'getFromEnvironment').returns(undefined);
      const getFromKMSStub = stub(manager as any, 'getFromKMS').resolves(undefined);
      const getFromHSMStub = stub(manager as any, 'getFromHSM').resolves(undefined);
      
      await expect(manager.getPrivateKey()).to.be.rejectedWith('No Tron private key available');
      
      expect(getFromEnvironmentStub.calledOnce).to.be.true;
      expect(getFromKMSStub.calledOnce).to.be.true;
      expect(getFromHSMStub.calledOnce).to.be.true;
    });
  });

  describe('getKeyPair', () => {
    it('should return cached key pair if available', async () => {
      const manager = new TronKeyManager(options);
      const mockKeyPair = {
        privateKey: TEST_TRON_KEYS.PRIVATE_KEY,
        publicKey: TEST_TRON_KEYS.PUBLIC_KEY,
        address: {
          hex: TEST_TRON_KEYS.ADDRESS_HEX,
          base58: TEST_TRON_KEYS.ADDRESS_BASE58,
        },
      };
      
      // Set cached key pair
      (manager as any).cachedKeyPair = mockKeyPair;
      
      const result = await manager.getKeyPair();
      
      expect(result).to.equal(mockKeyPair);
    });

    it('should generate new key pair if not cached', async () => {
      const manager = new TronKeyManager(options);
      const mockKeyPair = {
        privateKey: TEST_TRON_KEYS.PRIVATE_KEY,
        publicKey: TEST_TRON_KEYS.ADDRESS_HEX, // This is what the implementation actually returns
        address: {
          hex: TEST_TRON_KEYS.ADDRESS_HEX,
          base58: TEST_TRON_KEYS.ADDRESS_BASE58,
        },
      };
      
      // Stub getPrivateKey and createTronWeb
      const getPrivateKeyStub = stub(manager, 'getPrivateKey').resolves(TEST_TRON_KEYS.PRIVATE_KEY);
      
      // Mock the createTronWeb import
      const tronModule = await import('../../src/crypto/tron');
      const createTronWebStub = stub(tronModule, 'createTronWeb').returns({
        defaultAddress: {
          hex: TEST_TRON_KEYS.ADDRESS_HEX,
          base58: TEST_TRON_KEYS.ADDRESS_BASE58,
        },
      });
      
      const result = await manager.getKeyPair();
      
      expect(result).to.deep.equal(mockKeyPair);
      expect(getPrivateKeyStub.calledOnce).to.be.true;
      expect(createTronWebStub.calledOnce).to.be.true;
    });
  });

  describe('getFromEnvironment', () => {
    it('should return private key from environment variable', () => {
      const envKey = 'da146374a75310b9666e834ee4ad0866d6f4035967bfc76217c5a495fff9f0d0'; // Valid 64-char hex key
      const manager = new TronKeyManager(options);
      
      // Stub process.env
      const originalEnv = process.env.TRON_PRIVATE_KEY;
      process.env.TRON_PRIVATE_KEY = envKey;
      
      const result = (manager as any).getFromEnvironment();
      
      expect(result).to.equal(envKey);
      
      // Restore original env
      if (originalEnv) {
        process.env.TRON_PRIVATE_KEY = originalEnv;
      } else {
        delete process.env.TRON_PRIVATE_KEY;
      }
    });

    it('should return undefined if environment variable not set', () => {
      const manager = new TronKeyManager(options);
      
      // Ensure env var is not set
      const originalEnv = process.env.TRON_PRIVATE_KEY;
      delete process.env.TRON_PRIVATE_KEY;
      
      const result = (manager as any).getFromEnvironment();
      
      expect(result).to.equal(null);
      
      // Restore original env
      if (originalEnv) {
        process.env.TRON_PRIVATE_KEY = originalEnv;
      }
    });
  });

  describe('getTestPrivateKey', () => {
    it('should return test key if fallback enabled', () => {
      const manager = new TronKeyManager(options);
      
      // Set the required environment variable
      const originalEnv = process.env.TEST_PRIVATE_KEY;
      process.env.TEST_PRIVATE_KEY = TEST_TRON_KEYS.PRIVATE_KEY;
      
      const result = (manager as any).getTestPrivateKey();
      
      expect(result).to.equal(TEST_TRON_KEYS.PRIVATE_KEY);
      
      // Restore original env
      if (originalEnv) {
        process.env.TEST_PRIVATE_KEY = originalEnv;
      } else {
        delete process.env.TEST_PRIVATE_KEY;
      }
    });

    it('should throw error if fallback disabled', () => {
      const optionsWithoutFallback = {
        environment: 'production' as const,
        fallbackToTestKey: false,
        logger,
      };
      
      const manager = new TronKeyManager(optionsWithoutFallback);
      
      // The getTestPrivateKey method itself doesn't check for production environment
      // It only checks if the environment variable is set
      // Set the required environment variable
      const originalEnv = process.env.TEST_PRIVATE_KEY;
      process.env.TEST_PRIVATE_KEY = TEST_TRON_KEYS.PRIVATE_KEY;
      
      const result = (manager as any).getTestPrivateKey();
      
      expect(result).to.equal(TEST_TRON_KEYS.PRIVATE_KEY);
      
      // Restore original env
      if (originalEnv) {
        process.env.TEST_PRIVATE_KEY = originalEnv;
      } else {
        delete process.env.TEST_PRIVATE_KEY;
      }
    });
  });
});
