import { expect } from 'chai';
import { restore, stub } from 'sinon';
import { generateTronKeyPair, getAddressFromPrivateKey, createTronWeb, signMessage, verifyMessage, TEST_TRON_KEYS } from '../../src';

describe('Tron Crypto Functions', () => {
  beforeEach(() => {
    // Mock the TRON_PRO_API_KEY environment variable
    process.env.TRON_PRO_API_KEY = 'test-api-key';
  });

  afterEach(() => {
    restore();
    delete process.env.TRON_PRO_API_KEY;
  });

  describe('generateTronKeyPair', () => {
    it('should generate a valid Tron key pair', async () => {
      const keyPair = await generateTronKeyPair();
      
      expect(keyPair).to.have.property('privateKey');
      expect(keyPair).to.have.property('publicKey');
      expect(keyPair).to.have.property('address');
      expect(keyPair.address).to.have.property('hex');
      expect(keyPair.address).to.have.property('base58');
      
      expect(keyPair.privateKey).to.be.a('string');
      expect(keyPair.privateKey).to.have.length(64);
      expect(keyPair.privateKey).to.match(/^[a-fA-F0-9]+$/);
      
      expect(keyPair.publicKey).to.be.a('string');
      expect(keyPair.publicKey).to.have.length(130);
      expect(keyPair.publicKey).to.match(/^04/);
      
      expect(keyPair.address.hex).to.be.a('string');
      expect(keyPair.address.hex).to.have.length(42);
      expect(keyPair.address.hex).to.match(/^41/);
      
      expect(keyPair.address.base58).to.be.a('string');
      expect(keyPair.address.base58).to.match(/^T/);
      expect(keyPair.address.base58).to.have.length(34);
    });
  });

  describe('getAddressFromPrivateKey', () => {
    it('should get address from valid private key', () => {
      const address = getAddressFromPrivateKey(TEST_TRON_KEYS.PRIVATE_KEY);
      
      expect(address).to.have.property('hex');
      expect(address).to.have.property('base58');
      
      expect(address.hex).to.be.a('string');
      expect(address.hex).to.have.length(42);
      expect(address.hex).to.match(/^41/);
      
      expect(address.base58).to.be.a('string');
      expect(address.base58).to.match(/^T/);
      expect(address.base58).to.have.length(34);
    });

    it('should throw error for invalid private key', () => {
      expect(() => getAddressFromPrivateKey('invalid-key')).to.throw('Invalid private key');
    });

    it('should throw error for empty private key', () => {
      expect(() => getAddressFromPrivateKey('')).to.throw('Invalid private key');
    });
  });

  describe('createTronWeb', () => {
    it('should create TronWeb instance with default options', () => {
      const tronWeb = createTronWeb(TEST_TRON_KEYS.PRIVATE_KEY);
      
      expect(tronWeb).to.be.an('object');
      expect(tronWeb).to.have.property('defaultAddress');
      expect(tronWeb).to.have.property('defaultPrivateKey');
    });

    it('should create TronWeb instance with custom options', () => {
      const options = {
        fullHost: 'https://api.trongrid.io',
        privateKey: TEST_TRON_KEYS.PRIVATE_KEY,
      };
      
      const tronWeb = createTronWeb(TEST_TRON_KEYS.PRIVATE_KEY, options.fullHost);
      
      expect(tronWeb).to.be.an('object');
      expect(tronWeb.defaultPrivateKey).to.equal(TEST_TRON_KEYS.PRIVATE_KEY);
    });
  });

  describe('signMessage', () => {
    it('should sign a message with valid private key', async () => {
      const message = 'Hello, Tron!';
      const signature = await signMessage(TEST_TRON_KEYS.PRIVATE_KEY, message);
      
      expect(signature).to.be.a('string');
      expect(signature).to.match(/^0x/);
    });

    it('should throw error for invalid private key', async () => {
      await expect(signMessage('invalid-key', 'test')).to.be.rejected;
    });
  });

  describe('verifyMessage', () => {
    it('should verify a valid signature', async () => {
      const message = 'Hello, Tron!';
      const signature = await signMessage(TEST_TRON_KEYS.PRIVATE_KEY, message);
      const address = getAddressFromPrivateKey(TEST_TRON_KEYS.PRIVATE_KEY);
      
      const recoveredAddress = await verifyMessage(message, signature);
      
      expect(recoveredAddress).to.equal(address.base58);
    });

    it('should reject an invalid signature', async () => {
      const message = 'Hello, Tron!';
      const invalidSignature = '0x' + '0'.repeat(128);
      
      // This will likely throw an error due to invalid signature, but we're testing the wrapper
      try {
        const recoveredAddress = await verifyMessage(message, invalidSignature);
        expect(recoveredAddress).to.not.equal(TEST_TRON_KEYS.ADDRESS_BASE58);
      } catch (error) {
        // Expected to fail with invalid signature
        expect(error).to.be.instanceOf(Error);
      }
    });

    it('should throw error for invalid address', async () => {
      const message = 'Hello, Tron!';
      const signature = await signMessage(TEST_TRON_KEYS.PRIVATE_KEY, message);
      
      // This should work, but let's test with an invalid signature
      await expect(verifyMessage(message, 'invalid-signature')).to.be.rejected;
    });
  });
});
