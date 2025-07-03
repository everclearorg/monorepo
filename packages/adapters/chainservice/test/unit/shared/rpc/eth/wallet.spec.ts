import { expect } from 'chai';
import { stub, SinonStub } from 'sinon';
import { providers, utils, BigNumber, Wallet } from 'ethers';
import { EthWallet, ITransactionRequest } from '../../../../../src';

describe('EthWallet', () => {
  const privateKey = '0x1234567890123456789012345678901234567890123456789012345678901234';
  const wallet = new EthWallet(privateKey);

  describe('constructor', () => {
    it('should create an EthWallet instance with private key', () => {
      const newWallet = new EthWallet(privateKey);
      expect(newWallet).to.be.instanceOf(EthWallet);
      expect(newWallet.privateKey).to.equal(privateKey);
    });

    it('should create an EthWallet instance from another wallet', () => {
      const originalWallet = new EthWallet(privateKey);
      const newWallet = new EthWallet(originalWallet);
      expect(newWallet).to.be.instanceOf(EthWallet);
      expect(newWallet.privateKey).to.equal(privateKey);
    });
  });

  describe('fromMnemonic', () => {
    it('should create an EthWallet from mnemonic', () => {
      const mnemonic = 'test test test test test test test test test test test junk';
      const newWallet = EthWallet.fromMnemonic(mnemonic);
      
      expect(newWallet).to.be.instanceOf(EthWallet);
      expect(newWallet.mnemonic?.phrase).to.equal(mnemonic);
    });

    it('should create an EthWallet from mnemonic with custom path', () => {
      const mnemonic = 'test test test test test test test test test test test junk';
      const path = "m/44'/60'/0'/0/1";
      const newWallet = EthWallet.fromMnemonic(mnemonic, path);
      
      expect(newWallet).to.be.instanceOf(EthWallet);
      expect(newWallet.mnemonic?.phrase).to.equal(mnemonic);
      expect(newWallet.mnemonic?.path).to.equal(path);
    });

    it('should create an EthWallet from mnemonic with wordlist', () => {
      const mnemonic = 'test test test test test test test test test test test junk';
      const newWallet = EthWallet.fromMnemonic(mnemonic);
      
      expect(newWallet).to.be.instanceOf(EthWallet);
      expect(newWallet.mnemonic?.phrase).to.equal(mnemonic);
    });
  });

  describe('createRandom', () => {
    it('should create a random EthWallet', () => {
      const newWallet = EthWallet.createRandom();

      expect(newWallet).to.be.instanceOf(EthWallet);
    });

    it('should create a random EthWallet with options', () => {
      const options = { extraEntropy: utils.toUtf8Bytes('test entropy') };
      const newWallet = EthWallet.createRandom(options);

      expect(newWallet).to.be.instanceOf(EthWallet);
    });
  });

  describe('sendTransaction', () => {
    const to =   '0x1234567890123456789012345678901234567890';
    const from = '0x0987654321098765432109876543210987654321';
    const data = '0xa9059cbb000000000000000000000000742d35Cc6634C0532925a3b844Bc454e4438f44e';
    const value = '1000000000000000000';
    const gasLimit = '21000';
    const gasPrice = '20000000000';
    const mockTransactionResponse = {
      hash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      confirmations: 0,
      from,
      nonce: 1,
      gasLimit: BigNumber.from(21000),
      gasPrice: BigNumber.from(20000000000),
      data: '0x',
      value: BigNumber.from(0),
      chainId: 1,
      wait: stub().resolves({
        transactionHash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        blockNumber: 12345,
        gasUsed: BigNumber.from(21000),
        cumulativeGasUsed: BigNumber.from(21000),
        effectiveGasPrice: BigNumber.from(20000000000),
        status: 1,
        logs: [],
        to,
        from,
        contractAddress: null,
        transactionIndex: 0,
        blockHash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        logsBloom: '0x',
        byzantium: true,
        type: 0,
      }),
    } as providers.TransactionResponse;
    let sendTransactionStub: SinonStub;

    beforeEach(() => {
      sendTransactionStub = stub(Wallet.prototype, 'sendTransaction');
      sendTransactionStub.resolves(mockTransactionResponse);
    });

    afterEach(() => {
      sendTransactionStub.restore();
    });

    it('should send transaction without funcSig', async () => {
      const transaction: ITransactionRequest = {
        to,
        data,
        value,
        gasLimit,
        gasPrice,
        funcSig: 'transfer(address,uint256)',
      };

      const result = await wallet.sendTransaction(transaction);

      expect(result).to.equal(mockTransactionResponse);
      expect(sendTransactionStub.calledOnce).to.be.true;

      // Verify that funcSig was excluded from the transaction passed to super.sendTransaction
      const callArgs = sendTransactionStub.firstCall.args[0];
      expect(callArgs).to.not.have.property('funcSig');
      expect(callArgs.to).to.equal(transaction.to);
      expect(callArgs.data).to.equal(transaction.data);
      expect(callArgs.value).to.equal(transaction.value);
    });

    it('should handle standard ethers TransactionRequest', async () => {
      const transaction: providers.TransactionRequest = {
        to,
        data,
        value,
        gasLimit,
        gasPrice,
      };

      const result = await wallet.sendTransaction(transaction);

      expect(result).to.equal(mockTransactionResponse);
      expect(sendTransactionStub.calledOnce).to.be.true;

      const callArgs = sendTransactionStub.firstCall.args[0];
      expect(callArgs).to.deep.equal(transaction);
    });
  });

  describe('connect', () => {
    it('should connect wallet to provider', () => {
      // Use a real provider instance instead of a mock
      const provider = new providers.JsonRpcProvider();
      const connectedWallet = wallet.connect(provider);

      expect(connectedWallet).to.be.instanceOf(EthWallet);
      expect(connectedWallet).to.not.equal(wallet);
      expect(connectedWallet.privateKey).to.equal(wallet.privateKey);
      expect(connectedWallet.provider).to.equal(provider);
    });
  });
}); 