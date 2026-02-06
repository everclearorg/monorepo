import { expect } from 'chai';
import { stub } from 'sinon';
import { EthWallet, ITransactionRequest } from '../../../../../src';

describe('EthWallet', () => {
  const privateKey = '0x1234567890123456789012345678901234567890123456789012345678901234';
  const privateKeyWithoutPrefix = '1234567890123456789012345678901234567890123456789012345678901234';

  describe('constructor', () => {
    it('should create an EthWallet instance with private key', () => {
      const newWallet = new EthWallet(privateKey);
      expect(newWallet).to.be.instanceOf(EthWallet);
      expect(newWallet.address).to.be.a('string');
      expect(newWallet.address).to.have.length(42); // 0x + 40 hex chars
    });

    it('should automatically add 0x prefix to private key if not present', () => {
      const wallet1 = new EthWallet(privateKey);
      const wallet2 = new EthWallet(privateKeyWithoutPrefix);

      // Both should generate the same address
      expect(wallet1.address).to.equal(wallet2.address);
      expect(wallet1.privateKey).to.equal(wallet2.privateKey);
    });
  });

  describe('fromMnemonic', () => {
    it('should create an EthWallet instance from mnemonic', () => {
      const mnemonic = 'test test test test test test test test test test test junk';
      const wallet = EthWallet.fromMnemonic(mnemonic);
      
      expect(wallet).to.be.instanceOf(EthWallet);
      expect(wallet.address).to.be.a('string');
      expect(wallet.address).to.have.length(42);
    });

    it('should create an EthWallet instance from mnemonic with custom path', () => {
      const mnemonic = 'test test test test test test test test test test test junk';
      const customPath = "m/44'/60'/0'/0/1";
      const wallet = EthWallet.fromMnemonic(mnemonic, customPath);
      
      expect(wallet).to.be.instanceOf(EthWallet);
      expect(wallet.address).to.be.a('string');
      expect(wallet.address).to.have.length(42);
    });
  });

  describe('createRandom', () => {
    it('should create a random EthWallet instance', () => {
      const wallet = EthWallet.createRandom();
      
      expect(wallet).to.be.instanceOf(EthWallet);
      expect(wallet.address).to.be.a('string');
      expect(wallet.address).to.have.length(42);
      expect(wallet.privateKey).to.be.a('string');
      expect(wallet.privateKey).to.match(/^0x[a-fA-F0-9]{64}$/);
    });
  });

  describe('getAddress', () => {
    it('should return the wallet address', async () => {
      const wallet = new EthWallet(privateKey);
      const address = await wallet.getAddress();
      
      expect(address).to.equal(wallet.address);
      expect(address).to.be.a('string');
      expect(address).to.have.length(42);
    });
  });

  describe('getPublicKey', () => {
    it('should return the public key', async () => {
      const wallet = new EthWallet(privateKey);
      const publicKey = await wallet.getPublicKey();
      
      expect(publicKey).to.be.a('string');
      expect(publicKey).to.have.length(132); // 0x + 130 hex chars
    });
  });

  describe('signMessage', () => {
    const expectedSignature = '0x285568c8924deb6930e4368ae6be0e2814cc4cb3c0e6671a760a8861a81ab182681adff40234bec60387646c31078418e85cab5da70dbb3829ce8daf05b773061b';

    it('should sign a string message', async () => {
      const wallet = new EthWallet(privateKey);
      const message = 'Hello, World!';
      const signature = await wallet.signMessage(message);
      
      expect(signature).to.be.equal(expectedSignature);
    });

    it('should sign a Uint8Array message', async () => {
      const wallet = new EthWallet(privateKey);
      const message = new Uint8Array([72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33]); // "Hello, World!" in utf8 bytes
      const signature = await wallet.signMessage(message);

      expect(signature).to.be.equal(expectedSignature);
    });
  });

  describe('sendTransaction', () => {
    const to =   '0x1234567890123456789012345678901234567890';
    const data = '0xa9059cbb000000000000000000000000742d35Cc6634C0532925a3b844Bc454e4438f44e';
    const value = '1000000000000000000';
    const gasLimit = '21000';
    const gasPrice = '20000000000';

    it('should work', async () => {
      const wallet = new EthWallet(privateKey, { rpcUrls: ['https://eth.llamarpc.com'] });
      
      // Stub the walletClient.sendTransaction method
      const mockHash = '0x1234567890123456789012345678901234567890123456789012345678901234';
      const sendTransactionStub = stub((wallet as any).walletClient, 'sendTransaction').resolves(mockHash);
      
      const transaction: ITransactionRequest = {
        to,
        data,
        value,
        gasLimit,
        gasPrice,
        funcSig: 'transfer(address,uint256)',
      };

      const result = await wallet.sendTransaction(transaction);
      console.warn(result);

      expect(result.hash).to.equal(mockHash);
      expect(result.confirmations).to.equal(0);
      expect(result).to.have.property('confirmations');
      expect(result).to.have.property('nonce');
      expect(result).to.have.property('gasPrice');
      expect(result).to.have.property('gasLimit');
      expect(result.gasPrice).to.equal(BigInt(gasPrice));
      expect(result.gasLimit).to.equal(BigInt(gasLimit));

      // Verify sendTransaction was called with correct parameters
      expect(sendTransactionStub.calledOnce).to.be.true;
      const callArgs = sendTransactionStub.getCall(0).args[0];
      expect(callArgs).to.have.property('to', to);
      expect(callArgs).to.have.property('data', data);
      expect(callArgs).to.have.property('value', BigInt(value));
    });

    it('should include chainId when provided for EIP-155 compliance', async () => {
      const wallet = new EthWallet(privateKey, { rpcUrls: ['https://eth.llamarpc.com'] });

      // Stub the walletClient.sendTransaction method
      const mockHash = '0x1234567890123456789012345678901234567890123456789012345678901234';
      const sendTransactionStub = stub((wallet as any).walletClient, 'sendTransaction').resolves(mockHash);

      const chainId = 1; // Ethereum mainnet
      const transaction: ITransactionRequest = {
        to,
        data,
        value,
        gasLimit,
        gasPrice,
        funcSig: 'transfer(address,uint256)',
        chainId,
      };

      const result = await wallet.sendTransaction(transaction);

      expect(result.hash).to.equal(mockHash);

      // Verify chainId was included in the transaction sent to walletClient
      expect(sendTransactionStub.calledOnce).to.be.true;
      const callArgs = sendTransactionStub.getCall(0).args[0];
      expect(callArgs).to.have.property('chainId', chainId);
      expect(callArgs).to.have.property('to', to);
      expect(callArgs).to.have.property('data', data);
      expect(callArgs).to.have.property('value', BigInt(value));
    });
  });

  describe('connect', () => {
    it('should connect wallet to provider', () => {
      const wallet = new EthWallet(privateKey);
      const config = { rpcUrls: ['https://eth.llamarpc.com'] };
      const connectedWallet = wallet.connect(config);

      expect((connectedWallet as any).walletClient).to.exist;
      expect((connectedWallet as any).walletClient).to.be.an('object');
      expect(connectedWallet).to.not.equal(wallet);
      expect(connectedWallet.address).to.equal(wallet.address);
    });
  });

  describe('privateKey getter/setter', () => {
    it('should get the private key', () => {
      const wallet = new EthWallet(privateKey);
      expect(wallet.privateKey).to.equal(privateKey);
    });

    it('should set the private key and update account', () => {
      const wallet = new EthWallet(privateKey);
      const originalAddress = wallet.address;
      
      const newPrivateKey = '0x9876543210987654321098765432109876543210987654321098765432109876';
      wallet.privateKey = newPrivateKey;
      
      expect(wallet.privateKey).to.equal(newPrivateKey);
      expect(wallet.address).to.not.equal(originalAddress);
    });

    it('should automatically add 0x prefix when setting private key', () => {
      const wallet = new EthWallet(privateKey);
      const newPrivateKeyWithoutPrefix = '9876543210987654321098765432109876543210987654321098765432109876';
      
      wallet.privateKey = newPrivateKeyWithoutPrefix;
      
      expect(wallet.privateKey).to.equal(`0x${newPrivateKeyWithoutPrefix}`);
    });
  });
}); 