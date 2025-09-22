/* eslint-disable @typescript-eslint/no-explicit-any */
import { expect } from '@chimera-monorepo/utils';
import { restore, reset } from 'sinon';

import { SolanaProvider } from '../../../../src/shared/rpc/solana/provider';

describe('SolanaProvider', () => {
  const SOLANA_NATIVE_ASSET_ID = '11111111111111111111111111111111';
  const TEST_BLOCKHEIGHT = 12345;

  let provider: SolanaProvider;
  let mockRpc: any;

  beforeEach(() => {
    provider = new SolanaProvider('http://solana.test');

    mockRpc = {
      getBlockHeight: () => ({ send: async () => TEST_BLOCKHEIGHT }),
      getTransaction: () => ({
        send: async () => ({
          slot: 42,
          meta: { fee: 5000, err: null, logMessages: ['log-1', 'log-2'] },
          transaction: { message: { recentBlockhash: 'recent-blockhash-abc' } },
        }),
      }),
      getRecentPrioritizationFees: () => ({
        send: async () => [
          { prioritizationFee: 100n },
          { prioritizationFee: 300n },
        ],
      }),
      getBlock: () => ({
        send: async () => ({
          blockhash: 'blockhash-123',
          previousBlockhash: 'parenthash-122',
          blockHeight: 123,
          blockTime: 1710000000,
        }),
      }),
      getBalance: () => ({
        send: async () => ({ value: 321n }),
      }),
      getTokenAccountBalance: () => ({
        send: async () => ({ value: { amount: '999' } }),
      }),
      simulateTransaction: () => ({ send: async () => ({ value: { returnData: { data: '0x' } } }) }),
    };

    (provider as any).rpc = mockRpc;
  });

  afterEach(() => {
    restore();
    reset();
  });

  it('has correct default values', () => {
    expect((provider as any).name).to.equal('SolanaProvider');
    expect(provider.synced).to.be.false;
    expect(provider.syncedBlockNumber).to.equal(0);
    expect(provider.priority).to.equal(0);
    expect(provider.lag).to.equal(0);
    expect(provider.reliability).to.equal(1);
    expect(provider.latency).to.equal(0);
    expect(provider.cps).to.equal(0);
  });

  describe('#sync', () => {
    it('should retrieve and set current block height', async () => {
      await provider.sync();
      expect(provider.synced).to.be.true;
      expect(provider.syncedBlockNumber).to.equal(TEST_BLOCKHEIGHT);
    });

    it('should set synced=false and rethrow on error', async () => {
      (provider as any).rpc.getBlockHeight = () => ({ send: async () => { throw new Error('rpc error'); } });
      await expect(provider.sync()).to.be.rejectedWith('rpc error');
      expect(provider.synced).to.be.false;
    });
  });

  describe('#getTransaction', () => {
    it('should format transaction response', async () => {
      const res = await provider.getTransaction('sig-123');
      expect(res).to.deep.equal({
        hash: 'sig-123',
        confirmations: 1000,
        nonce: 0,
        gasPrice: '1',
        gasLimit: '5000',
      });
    });
  });

  describe('#getTransactionReceipt', () => {
    it('should format receipt with logs', async () => {
      const receipt = await provider.getTransactionReceipt('sig-abc');
      expect(receipt.transactionHash).to.equal('sig-abc');
      expect(receipt.blockNumber).to.equal(42);
      expect(receipt.status).to.equal(1);
      expect(receipt.confirmations).to.equal(1000);
      expect(receipt.logs.length).to.equal(2);
      expect(receipt.logs[0]).to.deep.include({
        blockNumber: 42,
        blockHash: 'recent-blockhash-abc',
        transactionHash: 'sig-abc',
        logIndex: 0,
      });
    });
  });

  describe('#getGasPrice', () => {
    it('should return average recent prioritization fee', async () => {
      const price = await provider.getGasPrice();
      expect(price).to.equal('200'); // (100 + 300) / 2
    });
  });

  describe('#getBlock', () => {
    it('should return formatted block', async () => {
      const block = await provider.getBlock(123);
      expect(block).to.deep.equal({
        hash: 'blockhash-123',
        parentHash: 'parenthash-122',
        number: 123,
        timestamp: 1710000000,
      });
    });

    it('should throw if block not found', async () => {
      (provider as any).rpc.getBlock = () => ({ send: async () => undefined });
      await expect(provider.getBlock(999)).to.be.rejectedWith('Block not found');
    });
  });

  describe('#getBlockNumber', () => {
    it('should return current block height', async () => {
      (provider as any).rpc.getBlockHeight = () => ({ send: async () => 42n });
      const n = await provider.getBlockNumber();
      expect(n).to.equal(42);
    });
  });

  describe('#getBalance', () => {
    it('should return native SOL balance for system program id', async () => {
      const bal = await provider.getBalance('SomeAddress', SOLANA_NATIVE_ASSET_ID);
      expect(bal).to.equal('321');
    });
  });
});
