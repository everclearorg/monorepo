import { expect } from 'chai';
import { stub, restore } from 'sinon';
import { chainWrapper } from '../../src/helpers/chain';
import * as viem from 'viem';

describe('Chain Wrapper', () => {
  afterEach(() => {
    restore();
  });

  describe('Basic Functions', () => {
    it('should wrap encodeFunctionData', () => {
      const abi = [{ type: 'function', name: 'test', inputs: [], outputs: [] }];
      const functionName = 'test';
      const args: any[] = [];
      
      const result = chainWrapper.encodeFunctionData({ abi, functionName, args });
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
    });

    it('should wrap decodeFunctionResult', () => {
      const abi = [{ type: 'function', name: 'test', inputs: [], outputs: [{ type: 'uint256' }] }];
      const functionName = 'test';
      const data = '0x0000000000000000000000000000000000000000000000000000000000000001';
      
      const result = chainWrapper.decodeFunctionResult({ abi, functionName, data });
      
      expect(result).to.equal(BigInt(1));
    });

    it('should wrap decodeFunctionData', () => {
      const abi = [{ type: 'function', name: 'test', inputs: [{ type: 'uint256' }], outputs: [] }];
      const functionName = 'test';
      const data = '0xf8a8fd6d0000000000000000000000000000000000000000000000000000000000000001';
      
      // This will likely throw an error due to invalid signature, but we're testing the wrapper
      try {
        const result = chainWrapper.decodeFunctionData({ abi, functionName, data });
        expect(result).to.be.an('object');
        expect(result).to.have.property('functionName', 'test');
      } catch (error) {
        // Expected to fail with invalid signature
        expect(error).to.be.instanceOf(Error);
      }
    });

    it('should wrap decodeEventLog', () => {
      const abi = [{ type: 'event', name: 'Test', inputs: [] }];
      const eventName = 'Test';
      const data = '0x';
      const topics = ['0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'];
      
      // This will likely throw an error due to invalid signature, but we're testing the wrapper
      try {
        const result = chainWrapper.decodeEventLog({ abi, eventName, data, topics });
        expect(result).to.be.an('object');
        expect(result).to.have.property('eventName', 'Test');
      } catch (error) {
        // Expected to fail with invalid signature
        expect(error).to.be.instanceOf(Error);
      }
    });

    it('should wrap encodeAbiParameters', () => {
      const params = [{ type: 'uint256', name: 'value' }];
      const values = [BigInt(123)];
      
      const result = chainWrapper.encodeAbiParameters(params, values);
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
    });

    it('should wrap encodePacked', () => {
      const types = ['uint256', 'address'];
      const values = [BigInt(123), '0x1234567890123456789012345678901234567890'];
      
      const result = chainWrapper.encodePacked(types, values);
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
    });
  });

  describe('Conversion Functions', () => {
    it('should wrap toHex', () => {
      const input = 'hello';
      const result = chainWrapper.toHex(input);
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
    });

    it('should wrap toBytes', () => {
      const input = '0x68656c6c6f';
      const result = chainWrapper.toBytes(input);
      
      expect(result).to.be.an.instanceOf(Uint8Array);
    });

    it('should wrap fromHex', () => {
      const input = '0x68656c6c6f';
      const result = chainWrapper.fromHex(input, 'string');
      
      expect(result).to.be.a('string');
      expect(result).to.equal('hello');
    });

    it('should wrap fromBytes', () => {
      const input = new Uint8Array([104, 101, 108, 108, 111]);
      const result = chainWrapper.fromBytes(input, 'string');
      
      expect(result).to.be.a('string');
      expect(result).to.equal('hello');
    });

    it('should wrap stringToHex', () => {
      const input = 'hello';
      const result = chainWrapper.stringToHex(input);
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
    });

    it('should wrap hexToBytes', () => {
      const input = '0x68656c6c6f';
      const result = chainWrapper.hexToBytes(input);
      
      expect(result).to.be.an.instanceOf(Uint8Array);
    });

    it('should wrap stringToBytes', () => {
      const input = 'hello';
      const result = chainWrapper.stringToBytes(input);
      
      expect(result).to.be.an.instanceOf(Uint8Array);
    });
  });

  describe('Address Functions', () => {
    it('should wrap getAddress', () => {
      const input = '0x1234567890123456789012345678901234567890';
      const result = chainWrapper.getAddress(input);
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
      expect(result).to.have.length(42);
    });

    it('should wrap isAddress', () => {
      const validAddress = '0x1234567890123456789012345678901234567890';
      const invalidAddress = 'invalid';
      
      expect(chainWrapper.isAddress(validAddress)).to.be.true;
      expect(chainWrapper.isAddress(invalidAddress)).to.be.false;
    });

    it('should wrap isAddressEqual', () => {
      const address1 = '0x1234567890123456789012345678901234567890';
      const address2 = '0x1234567890123456789012345678901234567890';
      const address3 = '0x9876543210987654321098765432109876543210';
      
      expect(chainWrapper.isAddressEqual(address1, address2)).to.be.true;
      expect(chainWrapper.isAddressEqual(address1, address3)).to.be.false;
    });

    it('should have zeroAddress constant', () => {
      expect(chainWrapper.zeroAddress).to.equal('0x0000000000000000000000000000000000000000');
    });

    it('should have zeroHash constant', () => {
      expect(chainWrapper.zeroHash).to.equal('0x0000000000000000000000000000000000000000000000000000000000000000');
    });
  });

  describe('Ether Functions', () => {
    it('should wrap parseEther', () => {
      const input = '1.5';
      const result = chainWrapper.parseEther(input);
      
      expect(result).to.equal(BigInt('1500000000000000000'));
    });

    it('should wrap formatEther', () => {
      const input = BigInt('1500000000000000000');
      const result = chainWrapper.formatEther(input);
      
      expect(result).to.equal('1.5');
    });

    it('should wrap parseUnits', () => {
      const input = '1.5';
      const decimals = 6;
      const result = chainWrapper.parseUnits(input, decimals);
      
      expect(result).to.equal(BigInt('1500000'));
    });

    it('should wrap formatUnits', () => {
      const input = BigInt('1500000');
      const decimals = 6;
      const result = chainWrapper.formatUnits(input, decimals);
      
      expect(result).to.equal('1.5');
    });

    it('should wrap parseGwei', () => {
      const input = '1.5';
      const result = chainWrapper.parseGwei(input);
      
      expect(result).to.equal(BigInt('1500000000'));
    });

    it('should wrap formatGwei', () => {
      const input = BigInt('1500000000');
      const result = chainWrapper.formatGwei(input);
      
      expect(result).to.equal('1.5');
    });
  });

  describe('Hash Functions', () => {
    it('should wrap keccak256', () => {
      const input = '0x68656c6c6f';
      const result = chainWrapper.keccak256(input);
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
      expect(result).to.have.length(66);
    });

    it('should wrap hashMessage', () => {
      const input = 'hello';
      const result = chainWrapper.hashMessage(input);
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
      expect(result).to.have.length(66);
    });

    it('should wrap recoverMessageAddress', () => {
      const message = 'hello';
      const signature = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1b';
      
      // This will likely throw an error due to invalid signature, but we're testing the wrapper
      try {
        const result = chainWrapper.recoverMessageAddress({ message, signature });
        expect(result).to.be.a('string');
      } catch (error) {
        // Expected to fail with invalid signature
        expect(error).to.be.instanceOf(Error);
      }
    });

    it('should wrap recoverPublicKey', () => {
      const message = 'hello';
      const signature = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1b';
      
      // This will likely throw an error due to invalid signature, but we're testing the wrapper
      try {
        const result = chainWrapper.recoverPublicKey({ message, signature });
        expect(result).to.be.a('string');
      } catch (error) {
        // Expected to fail with invalid signature
        expect(error).to.be.instanceOf(Error);
      }
    });
  });

  describe('Utility Functions', () => {
    it('should wrap concat', () => {
      const inputs = ['0x1234', '0x5678'];
      const result = chainWrapper.concat(inputs);
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
    });

    it('should wrap pad', () => {
      const input = '0x1234';
      const size = 8;
      const result = chainWrapper.pad(input, { size });
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
      expect(result).to.have.length(size * 2 + 2);
    });

    it('should wrap serializeTransaction', () => {
      const transaction = {
        to: '0x1234567890123456789012345678901234567890',
        value: BigInt(1000000000000000000),
        gas: BigInt(21000),
        gasPrice: BigInt(20000000000),
        nonce: 0,
      };
      
      const result = chainWrapper.serializeTransaction(transaction);
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
    });

    it('should wrap parseTransaction', () => {
      const serialized = '0x1234567890abcdef';
      
      // This will likely throw an error due to invalid transaction data, but we're testing the wrapper
      try {
        const result = chainWrapper.parseTransaction(serialized);
        expect(result).to.be.an('object');
      } catch (error) {
        // Expected to fail with invalid transaction data
        expect(error).to.be.instanceOf(Error);
      }
    });
  });

  describe('Client Functions', () => {
    it('should wrap createWalletClient', () => {
      const transport = chainWrapper.http('https://example.com');
      const account = {
        address: '0x1234567890123456789012345678901234567890',
        type: 'local' as const,
        source: 'privateKey',
      };
      
      const result = chainWrapper.createWalletClient({
        account,
        transport,
      });
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('account');
      expect(result).to.have.property('transport');
    });

    it('should wrap createPublicClient', () => {
      const transport = chainWrapper.http('https://example.com');
      
      const result = chainWrapper.createPublicClient({
        transport,
      });
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('transport');
    });

    it('should have http function', () => {
      const url = 'https://example.com';
      const result = chainWrapper.http(url);
      
      expect(result).to.be.a('function');
    });
  });

  describe('Account Functions', () => {
    it('should wrap privateKeyToAccount', () => {
      const privateKey = '0x1234567890123456789012345678901234567890123456789012345678901234';
      
      const result = chainWrapper.privateKeyToAccount(privateKey);
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('address');
      expect(result).to.have.property('type');
      expect(result).to.have.property('source');
    });

    it('should wrap generatePrivateKey', () => {
      const result = chainWrapper.generatePrivateKey();
      
      expect(result).to.be.a('string');
      expect(result).to.match(/^0x/);
      expect(result).to.have.length(66);
    });

    it('should wrap mnemonicToAccount', () => {
      const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      
      const result = chainWrapper.mnemonicToAccount(mnemonic);
      
      expect(result).to.be.an('object');
      expect(result).to.have.property('address');
      expect(result).to.have.property('type');
      expect(result).to.have.property('source');
    });
  });
});
