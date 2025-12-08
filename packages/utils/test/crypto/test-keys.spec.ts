import { expect } from 'chai';
import { getTestTronPrivateKey, getTestTronAddress, getTestEthAddress, TEST_TRON_KEYS, TEST_TRON_KEYS_ALT } from '../../src';

describe('Test Keys', () => {
  describe('getTestTronPrivateKey', () => {
    it('should return the test Tron private key', () => {
      const result = getTestTronPrivateKey();
      expect(result).to.equal(TEST_TRON_KEYS.PRIVATE_KEY);
      expect(result).to.be.a('string');
      expect(result).to.have.length(64);
    });
  });

  describe('getTestTronAddress', () => {
    it('should return the test Tron address in base58 format', () => {
      const result = getTestTronAddress();
      expect(result).to.equal(TEST_TRON_KEYS.ADDRESS_BASE58);
      expect(result).to.be.a('string');
      expect(result).to.match(/^T/);
    });
  });

  describe('getTestEthAddress', () => {
    it('should return the test Ethereum address for compatibility', () => {
      const result = getTestEthAddress();
      expect(result).to.equal(TEST_TRON_KEYS.ETH_ADDRESS);
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
      expect(result).to.have.length(42);
    });
  });

  describe('TEST_TRON_KEYS', () => {
    it('should have all required properties', () => {
      expect(TEST_TRON_KEYS).to.have.property('PRIVATE_KEY');
      expect(TEST_TRON_KEYS).to.have.property('PUBLIC_KEY');
      expect(TEST_TRON_KEYS).to.have.property('ADDRESS_HEX');
      expect(TEST_TRON_KEYS).to.have.property('ADDRESS_BASE58');
      expect(TEST_TRON_KEYS).to.have.property('ETH_ADDRESS');
    });

    it('should have valid private key format', () => {
      expect(TEST_TRON_KEYS.PRIVATE_KEY).to.be.a('string');
      expect(TEST_TRON_KEYS.PRIVATE_KEY).to.have.length(64);
      expect(TEST_TRON_KEYS.PRIVATE_KEY).to.match(/^[a-f0-9]+$/);
    });

    it('should have valid public key format', () => {
      expect(TEST_TRON_KEYS.PUBLIC_KEY).to.be.a('string');
      expect(TEST_TRON_KEYS.PUBLIC_KEY).to.have.length(126);
      expect(TEST_TRON_KEYS.PUBLIC_KEY).to.match(/^04/);
    });

    it('should have valid Tron address format', () => {
      expect(TEST_TRON_KEYS.ADDRESS_BASE58).to.be.a('string');
      expect(TEST_TRON_KEYS.ADDRESS_BASE58).to.match(/^T/);
      expect(TEST_TRON_KEYS.ADDRESS_BASE58).to.have.length(34);
    });

    it('should have valid Ethereum address format', () => {
      expect(TEST_TRON_KEYS.ETH_ADDRESS).to.be.a('string');
      expect(TEST_TRON_KEYS.ETH_ADDRESS).to.match(/^0x/);
      expect(TEST_TRON_KEYS.ETH_ADDRESS).to.have.length(42);
    });
  });

  describe('TEST_TRON_KEYS_ALT', () => {
    it('should have all required properties', () => {
      expect(TEST_TRON_KEYS_ALT).to.have.property('PRIVATE_KEY');
      expect(TEST_TRON_KEYS_ALT).to.have.property('ADDRESS_BASE58');
      expect(TEST_TRON_KEYS_ALT).to.have.property('ETH_ADDRESS');
    });

    it('should have valid private key format', () => {
      expect(TEST_TRON_KEYS_ALT.PRIVATE_KEY).to.be.a('string');
      expect(TEST_TRON_KEYS_ALT.PRIVATE_KEY).to.have.length(64);
      expect(TEST_TRON_KEYS_ALT.PRIVATE_KEY).to.match(/^[a-f0-9]+$/);
    });

    it('should have valid Tron address format', () => {
      expect(TEST_TRON_KEYS_ALT.ADDRESS_BASE58).to.be.a('string');
      expect(TEST_TRON_KEYS_ALT.ADDRESS_BASE58).to.match(/^T/);
      expect(TEST_TRON_KEYS_ALT.ADDRESS_BASE58).to.have.length(34);
    });

    it('should have valid Ethereum address format', () => {
      expect(TEST_TRON_KEYS_ALT.ETH_ADDRESS).to.be.a('string');
      expect(TEST_TRON_KEYS_ALT.ETH_ADDRESS).to.match(/^0x/);
      expect(TEST_TRON_KEYS_ALT.ETH_ADDRESS).to.have.length(42);
    });
  });
});
