import { expect } from 'chai';
import { stub, restore } from 'sinon';
import * as sinon from 'sinon';
import { SyncProvider, RpcError } from '../../../../../src';
import { chainWrapper } from '@chimera-monorepo/utils';

describe('SyncProvider', () => {
  let provider: SyncProvider;
  let mockClient: any;
  let mockPublicClient: any;

  beforeEach(() => {
    // Mock the viem client
    mockClient = {
      request: stub(),
      getGasPrice: stub(),
      getBlock: stub(),
      getBlockNumber: stub(),
      getCode: stub(),
      getTransaction: stub(),
      getTransactionReceipt: stub(),
      estimateGas: stub(),
      call: stub(),
      getBalance: stub(),
      getTransactionCount: stub(),
      readContract: stub(),
    };

    mockPublicClient = {
      request: mockClient.request,
      getGasPrice: mockClient.getGasPrice,
      getBlock: mockClient.getBlock,
      getBlockNumber: mockClient.getBlockNumber,
      getCode: mockClient.getCode,
      getTransaction: mockClient.getTransaction,
      getTransactionReceipt: mockClient.getTransactionReceipt,
      estimateGas: mockClient.estimateGas,
      call: mockClient.call,
      getBalance: mockClient.getBalance,
      getTransactionCount: mockClient.getTransactionCount,
      readContract: mockClient.readContract,
    };

    // Stub chainWrapper functions
    stub(chainWrapper, 'createPublicClient').returns(mockPublicClient);
    stub(chainWrapper, 'http').returns({} as any);
    stub(chainWrapper, 'zeroAddress').value('0x0000000000000000000000000000000000000000');

    provider = new SyncProvider('https://test-rpc.com', 1337, 5000, true);
  });

  afterEach(() => {
    restore();
  });

  describe('constructor', () => {
    it('should initialize with string URL', () => {
      const testProvider = new SyncProvider('https://test-rpc.com', 1337);
      expect(testProvider.name).to.be.a('string');
      expect(testProvider.url).to.equal('https://test-rpc.com');
    });

    it('should initialize with connection info object', () => {
      const testProvider = new SyncProvider({ url: 'https://test-rpc.com' }, 1337);
      expect(testProvider.name).to.be.a('string');
      expect(testProvider.url).to.equal('https://test-rpc.com');
    });

    it('should set default stall timeout', () => {
      const testProvider = new SyncProvider('https://test-rpc.com', 1337);
      expect(testProvider.stallTimeout).to.equal(10000);
    });

    it('should set custom stall timeout', () => {
      const testProvider = new SyncProvider('https://test-rpc.com', 1337, 5000);
      expect(testProvider.stallTimeout).to.equal(5000);
    });
  });

  describe('sync', () => {
    it('should sync provider with latest block number', async () => {
      mockClient.getBlockNumber.resolves(BigInt(12345));
      
      await provider.sync();
      
      expect(mockClient.getBlockNumber.calledOnce).to.be.true;
      expect(provider.syncedBlockNumber).to.equal(12345);
    });

    it('should handle sync errors gracefully', async () => {
      mockClient.getBlockNumber.rejects(new Error('Network error'));
      
      try {
        await provider.sync();
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
      }
    });
  });

  describe('send', () => {
    it('should throw error when provider is not synced', async () => {
      provider.synced = false;
      
      try {
        await provider.send('eth_blockNumber', []);
        expect.fail('Should have thrown RpcError');
      } catch (error) {
        expect(error).to.be.instanceOf(RpcError);
        expect((error as RpcError).reason).to.equal(RpcError.reasons.OutOfSync);
      }
    });

    it('should successfully send RPC request when synced', async () => {
      provider.synced = true;
      mockClient.request.resolves('0x1234');
      
      const result = await provider.send('eth_blockNumber', []);
      
      expect(result).to.equal('0x1234');
      expect(mockClient.request.calledOnce).to.be.true;
    });

    it('should retry on RpcError', async () => {
      provider.synced = true;
      const rpcError = new RpcError(RpcError.reasons.ConnectionReset, {});
      
      mockClient.request
        .onFirstCall().rejects(rpcError)
        .onSecondCall().resolves('0x1234');
      
      const result = await provider.send('eth_blockNumber', []);
      
      expect(result).to.equal('0x1234');
      expect(mockClient.request.calledTwice).to.be.true;
    });

    it('should throw immediately on non-RpcError', async () => {
      provider.synced = true;
      const nonRpcError = new Error('Non-RPC error');
      
      mockClient.request.rejects(nonRpcError);
      
      try {
        await provider.send('eth_blockNumber', []);
        expect.fail('Should have thrown error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
        expect(mockClient.request.calledOnce).to.be.true;
      }
    });

    it('should handle stall timeout', async () => {
      provider.synced = true;
      mockClient.request.returns(new Promise(() => {})); // Never resolves
      
      try {
        await provider.send('eth_blockNumber', []);
        expect.fail('Should have timed out');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
        expect(error.message).to.include('Request stalled and timed out');
      }
    });

    it('should throw FailedToSend after max retries', async () => {
      provider.synced = true;
      const rpcError = new RpcError(RpcError.reasons.ConnectionReset, {});
      mockClient.request.rejects(rpcError);
      
      try {
        await provider.send('eth_blockNumber', []);
        expect.fail('Should have thrown FailedToSend error');
      } catch (error) {
        expect(error).to.be.instanceOf(RpcError);
        expect((error as RpcError).reason).to.equal(RpcError.reasons.FailedToSend);
        expect(mockClient.request.callCount).to.equal(5);
      }
    });
  });

  describe('getGasPrice', () => {
    it('should return gas price as string', async () => {
      mockClient.getGasPrice.resolves(BigInt(20000000000));
      
      const result = await provider.getGasPrice();
      
      expect(result).to.equal('20000000000');
      expect(mockClient.getGasPrice.calledOnce).to.be.true;
    });
  });

  describe('getBlock', () => {
    it('should get block by number', async () => {
      const mockBlock = {
        hash: '0x123',
        parentHash: '0x456',
        number: BigInt(12345),
        timestamp: BigInt(1640995200),
      };
      mockClient.getBlock.resolves(mockBlock);
      
      const result = await provider.getBlock(12345);
      
      expect(result.number).to.equal(12345);
      expect(result.hash).to.equal('0x123');
      expect(mockClient.getBlock.calledWith({
        blockNumber: BigInt(12345),
        blockHash: undefined,
      })).to.be.true;
    });

    it('should get block by hash', async () => {
      const mockBlock = {
        hash: '0x123',
        parentHash: '0x456',
        number: BigInt(12345),
        timestamp: BigInt(1640995200),
      };
      mockClient.getBlock.resolves(mockBlock);
      
      const result = await provider.getBlock('0x123');
      
      expect(result.number).to.equal(12345);
      expect(mockClient.getBlock.calledWith({
        blockHash: '0x123',
        blockNumber: undefined,
      })).to.be.true;
    });

    it('should handle block not found', async () => {
      mockClient.getBlock.resolves(null);
      
      try {
        await provider.getBlock(12345);
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error).to.be.instanceOf(Error);
      }
    });
  });

  describe('getBlockNumber', () => {
    it('should return block number as number', async () => {
      mockClient.getBlockNumber.resolves(BigInt(12345));
      
      const result = await provider.getBlockNumber();
      
      expect(result).to.equal(12345);
      expect(mockClient.getBlockNumber.calledOnce).to.be.true;
    });
  });

  describe('getCode', () => {
    it('should return contract code', async () => {
      mockClient.getCode.resolves('0x608060405234801561001057600080fd5b50');
      
      const result = await provider.getCode('0x123');
      
      expect(result).to.equal('0x608060405234801561001057600080fd5b50');
      expect(mockClient.getCode.calledWith({ address: '0x123' })).to.be.true;
    });

    it('should return 0x for empty code', async () => {
      mockClient.getCode.resolves(null);
      
      const result = await provider.getCode('0x123');
      
      expect(result).to.equal('0x');
    });
  });

  describe('getTransaction', () => {
    it('should return transaction when found', async () => {
      const mockTx = {
        hash: '0x123',
        nonce: BigInt(5),
        gas: BigInt(21000),
        gasPrice: BigInt(20000000000),
      };
      mockClient.getTransaction.resolves(mockTx);
      
      const result = await provider.getTransaction('0x123');
      
      expect(result?.hash).to.equal('0x123');
      expect(result?.nonce).to.equal(5);
      expect(mockClient.getTransaction.calledWith({ hash: '0x123' })).to.be.true;
    });

    it('should return undefined when transaction not found', async () => {
      mockClient.getTransaction.resolves(null);
      
      const result = await provider.getTransaction('0x123');
      
      expect(result).to.be.undefined;
    });

    it('should return undefined on error', async () => {
      mockClient.getTransaction.rejects(new Error('Transaction not found'));
      
      const result = await provider.getTransaction('0x123');
      
      expect(result).to.be.undefined;
    });
  });

  describe('getTransactionReceipt', () => {
    it('should return transaction receipt', async () => {
      const mockReceipt = {
        transactionHash: '0x123',
        blockNumber: BigInt(12345),
        status: 'success',
        logs: [{
          address: '0x456',
          topics: ['0x789'],
          data: '0xabc',
          blockNumber: BigInt(12345),
          transactionHash: '0x123',
          transactionIndex: BigInt(0),
          logIndex: BigInt(0),
          blockHash: '0xdef',
          removed: false,
        }],
      };
      mockClient.getTransactionReceipt.resolves(mockReceipt);
      
      const result = await provider.getTransactionReceipt('0x123');
      
      expect(result.transactionHash).to.equal('0x123');
      expect(result.status).to.equal(1);
      expect(result.logs).to.have.length(1);
      expect(mockClient.getTransactionReceipt.calledWith({ hash: '0x123' })).to.be.true;
    });

    it('should handle failed transaction status', async () => {
      const mockReceipt = {
        transactionHash: '0x123',
        blockNumber: BigInt(12345),
        status: 'reverted',
        logs: [],
      };
      mockClient.getTransactionReceipt.resolves(mockReceipt);
      
      const result = await provider.getTransactionReceipt('0x123');
      
      expect(result.status).to.equal(0);
    });
  });

  describe('estimateGas', () => {
    it('should estimate gas for transaction', async () => {
      mockClient.estimateGas.resolves(BigInt(21000));
      
      const tx = {
        domain: 1337,
        funcSig: '0x123',
        from: '0x456',
        to: '0x789',
        value: '1000000000000000000',
        data: '0xabc',
      };
      
      const result = await provider.estimateGas(tx);
      
      expect(result).to.equal('21000');
      expect(mockClient.estimateGas.calledOnce).to.be.true;
    });

    it('should handle transaction without value', async () => {
      mockClient.estimateGas.resolves(BigInt(21000));
      
      const tx = {
        domain: 1337,
        funcSig: '0x123',
        from: '0x456',
        to: '0x789',
        data: '0xabc',
      };
      
      const result = await provider.estimateGas(tx);
      
      expect(result).to.equal('21000');
    });
  });

  describe('call', () => {
    it('should make contract call', async () => {
      mockClient.call.resolves('0x123');
      
      const tx = {
        domain: 1337,
        funcSig: '0x123',
        from: '0x456',
        to: '0x789',
        value: '1000000000000000000',
        data: '0xabc',
      };
      
      const result = await provider.call(tx, 'latest');
      
      expect(result).to.equal('0x123');
      expect(mockClient.call.calledOnce).to.be.true;
    });

    it('should handle call without value', async () => {
      mockClient.call.resolves('0x123');
      
      const tx = {
        domain: 1337,
        funcSig: '0x123',
        from: '0x456',
        to: '0x789',
        data: '0xabc',
      };
      
      const result = await provider.call(tx, 12345);
      
      expect(result).to.equal('0x123');
    });

    it('should return 0x for empty result', async () => {
      mockClient.call.resolves(null);
      
      const tx = {
        domain: 1337,
        funcSig: '0x123',
        from: '0x456',
        to: '0x789',
        data: '0xabc',
      };
      
      const result = await provider.call(tx, 'latest');
      
      expect(result).to.equal('0x');
    });
  });

  describe('getBalance', () => {
    it('should return native token balance', async () => {
      mockClient.getBalance.resolves(BigInt(1000000000000000000));
      
      const result = await provider.getBalance('0x123', '0x0000000000000000000000000000000000000000');
      
      expect(result).to.equal('1000000000000000000');
      expect(mockClient.getBalance.calledWith({ address: '0x123' })).to.be.true;
    });

    it('should return ERC20 token balance using readContract', async () => {
      mockClient.readContract.resolves(BigInt(500000000000000000));
      
      const result = await provider.getBalance('0x123', '0x456');
      
      expect(result).to.equal('500000000000000000');
      expect(mockClient.readContract.calledWith({
        address: '0x456',
        abi: sinon.match.any,
        functionName: 'balanceOf',
        args: ['0x123'],
      })).to.be.true;
    });

    it('should fallback to RPC call when readContract fails', async () => {
      mockClient.readContract.rejects(new Error('Contract call failed'));
      mockClient.request.resolves('0x0000000000000000000000000000000000000000000000000de0b6b3a7640000');
      
      const result = await provider.getBalance('0x123', '0x456');
      
      expect(result).to.equal('0x0000000000000000000000000000000000000000000000000de0b6b3a7640000');
      expect(mockClient.request.calledWith({
        method: 'eth_call',
        params: [{
          to: '0x456',
          data: '0x70a082310000000000000000000000000000000000000000000000000000000000000000000000000000000000000123'
        }, 'latest']
      })).to.be.true;
    });
  });

  describe('getDecimals', () => {
    it('should return decimals using readContract', async () => {
      mockClient.readContract.resolves(18);
      
      const result = await provider.getDecimals('0x456');
      
      expect(result).to.equal(18);
      expect(mockClient.readContract.calledWith({
        address: '0x456',
        abi: sinon.match.any,
        functionName: 'decimals',
      })).to.be.true;
    });

    it('should fallback to RPC call when readContract fails', async () => {
      mockClient.readContract.rejects(new Error('Contract call failed'));
      mockClient.request.resolves('0x12'); // 18 in hex
      
      const result = await provider.getDecimals('0x456');
      
      expect(result).to.equal(18);
      expect(mockClient.request.calledWith({
        method: 'eth_call',
        params: [{
          to: '0x456',
          data: '0x313ce567'
        }, 'latest']
      })).to.be.true;
    });
  });

  describe('getTransactionCount', () => {
    it('should return transaction count', async () => {
      mockClient.getTransactionCount.resolves(BigInt(5));
      
      const result = await provider.getTransactionCount('0x123', 'latest');
      
      expect(result).to.equal(5);
      expect(mockClient.getTransactionCount.calledWith({ 
        address: '0x123', 
        blockTag: 'latest' 
      })).to.be.true;
    });

    it('should handle numeric block parameter', async () => {
      mockClient.getTransactionCount.resolves(BigInt(5));
      
      const result = await provider.getTransactionCount('0x123', 12345);
      
      expect(result).to.equal(5);
      expect(mockClient.getTransactionCount.calledWith({ 
        address: '0x123', 
        blockTag: '12345' 
      })).to.be.true;
    });
  });

  describe('getSigner', () => {
    it('should create EthWallet from private key string', async () => {
      // Mock EthWallet constructor
      const EthWalletStub = stub().returns({
        sendTransaction: () => {},
        getAddress: () => '0x123',
      });
      
      // Replace the EthWallet import temporarily
      const originalEthWallet = require('../../../../../src/shared/rpc/eth/wallet').EthWallet;
      require('../../../../../src/shared/rpc/eth/wallet').EthWallet = EthWalletStub;
      
      const signer = await provider.getSigner('0x1234567890123456789012345678901234567890123456789012345678901234');
      
      expect(signer).to.be.an('object');
      expect(signer).to.have.property('sendTransaction');
      
      // Restore original EthWallet
      require('../../../../../src/shared/rpc/eth/wallet').EthWallet = originalEthWallet;
    });

    it('should return existing signer', async () => {
      const existingSigner = { sendTransaction: () => {} } as any;
      const signer = await provider.getSigner(existingSigner);
      
      expect(signer).to.equal(existingSigner);
    });
  });

  describe('connect', () => {
    it('should delegate to getSigner', async () => {
      const getSignerStub = stub(provider, 'getSigner').resolves({} as any);
      
      await provider.connect('0x123');
      
      expect(getSignerStub.calledWith('0x123')).to.be.true;
    });
  });

  describe('url property', () => {
    it('should get URL from provider', () => {
      expect(provider.url).to.equal('https://test-rpc.com');
    });

    it('should set URL on provider', () => {
      provider.url = 'https://new-rpc.com';
      expect(provider.url).to.equal('https://new-rpc.com');
    });

    it('should handle undefined provider', () => {
      const testProvider = new SyncProvider('https://test-rpc.com', 1337);
      // Access internal provider to test edge case
      const internalProvider = testProvider.internalProvider;
      expect(internalProvider).to.be.an('object');
    });
  });

  describe('metrics and reliability', () => {
    it('should track CPS timestamps', () => {
      const now = Date.now();
      provider.internalProvider.cpsTimestamps = [
        now - 5000, // 5 seconds ago
        now - 3000, // 3 seconds ago
        now - 1000, // 1 second ago
      ];

      const cps = provider.cps;
      expect(cps).to.equal(0.3); // 3 calls over 10 seconds
    });

    it('should filter old CPS timestamps', () => {
      const now = Date.now();
      provider.internalProvider.cpsTimestamps = [
        now - 15000, // 15 seconds ago (should be filtered)
        now - 5000,  // 5 seconds ago
        now - 1000,  // 1 second ago
      ];

      const cps = provider.cps;
      expect(cps).to.equal(0.2); // 2 calls over 10 seconds
      expect(provider.internalProvider.cpsTimestamps).to.have.length(2);
    });

    it('should calculate latency', () => {
      provider.internalProvider.latencies = [0.1, 0.2, 0.3];
      
      const latency = provider.latency;
      expect(latency).to.be.closeTo(0.2, 0.01); // Allow for floating point precision
    });

    it('should return 0 latency when no samples', () => {
      provider.internalProvider.latencies = [];
      
      const latency = provider.latency;
      expect(latency).to.equal(0.0);
    });

    it('should limit latency samples to N_SAMPLES', () => {
      // Create more than N_SAMPLES (100) latency entries
      const latencies = Array.from({ length: 150 }, (_, i) => i * 0.01);
      provider.internalProvider.latencies = latencies;
      
      const latency = provider.latency;
      expect(provider.internalProvider.latencies).to.have.length(100);
    });
  });
});
