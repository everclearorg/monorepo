import { stub, SinonStub } from 'sinon';
import {
  expect,
  getTriageToolHandlers,
  QueueType,
  TriageToolHandler,
} from '@chimera-monorepo/utils';

import { configureTriageToolHandlers } from '../src/triage-tools';
import { mock, getContextStub } from './globalTestHook';
import * as assetHelpers from '../src/helpers/asset';
import * as intentHelpers from '../src/helpers/intent';
import * as solanaHelpers from '../src/helpers/solana';
import * as hyperlaneHelpers from '../src/helpers/hyperlane';

describe('triage-tools', () => {
  let handlers: Record<string, TriageToolHandler>;
  let getCustodiedStub: SinonStub;
  let getCurrentEpochStub: SinonStub;
  let getLastSolanaNonceStub: SinonStub;
  let getMessageStatusStub: SinonStub;

  beforeEach(() => {
    getCustodiedStub = stub(assetHelpers, 'getCustodiedAssetsFromHubContract').resolves('1000');
    getCurrentEpochStub = stub(intentHelpers, 'getCurrentEpoch').resolves(42);
    getLastSolanaNonceStub = stub(solanaHelpers, 'getLastSolanaIntentNonce').resolves(10);
    getMessageStatusStub = stub(hyperlaneHelpers, 'getMessageStatus').resolves({ status: 'delivered' });

    configureTriageToolHandlers();
    handlers = getTriageToolHandlers();
  });

  // -----------------------------------------------------------------------
  // Validation helpers (exercised indirectly via tool handler args)
  // -----------------------------------------------------------------------

  describe('toStringArg', () => {
    it('throws when value is not a string', async () => {
      await expect(handlers.check_rpc_health({ domain: 123 })).to.be.rejectedWith('Missing required tool arg');
    });

    it('throws when value is an empty string', async () => {
      await expect(handlers.check_rpc_health({ domain: '' })).to.be.rejectedWith('Missing required tool arg');
    });
  });

  describe('toDomainArg', () => {
    it('throws for non-numeric domain', async () => {
      await expect(handlers.check_rpc_health({ domain: 'abc' })).to.be.rejectedWith('Invalid domain');
    });

    it('throws for unsupported domain', async () => {
      await expect(handlers.check_rpc_health({ domain: '9999' })).to.be.rejectedWith('Unsupported domain');
    });
  });

  describe('toAddressArg', () => {
    it('throws for invalid address', async () => {
      await expect(
        handlers.get_gas_balance({ domain: '1337', address: 'not-an-address' }),
      ).to.be.rejectedWith('Invalid address');
    });

    it('throws for address with wrong length', async () => {
      await expect(
        handlers.get_gas_balance({ domain: '1337', address: '0x1234' }),
      ).to.be.rejectedWith('Invalid address');
    });
  });

  // -----------------------------------------------------------------------
  // check_rpc_health
  // -----------------------------------------------------------------------

  describe('check_rpc_health', () => {
    it('returns health info for a valid domain', async () => {
      const ctx = mock.context();
      (ctx.adapters.chainreader.getBlock as SinonStub).resolves({ number: 100, timestamp: 1000 });
      getContextStub.returns(ctx);

      const result = await handlers.check_rpc_health({ domain: '1337' });
      expect(result).to.deep.include({
        domain: '1337',
        healthy: true,
        blockNumber: 100,
        timestamp: 1000,
      });
    });

    it('sets rpcOrigin when provided as string', async () => {
      const ctx = mock.context();
      (ctx.adapters.chainreader.getBlock as SinonStub).resolves({ number: 1, timestamp: 2 });
      getContextStub.returns(ctx);

      const result: any = await handlers.check_rpc_health({ domain: '1337', rpcOrigin: 'alchemy' });
      expect(result.rpcOrigin).to.eq('alchemy');
    });

    it('sets rpcOrigin to undefined when not a string', async () => {
      const ctx = mock.context();
      (ctx.adapters.chainreader.getBlock as SinonStub).resolves({ number: 1, timestamp: 2 });
      getContextStub.returns(ctx);

      const result: any = await handlers.check_rpc_health({ domain: '1337', rpcOrigin: 42 });
      expect(result.rpcOrigin).to.be.undefined;
    });
  });

  // -----------------------------------------------------------------------
  // get_gas_balance
  // -----------------------------------------------------------------------

  describe('get_gas_balance', () => {
    it('returns balance for valid domain and address', async () => {
      const ctx = mock.context();
      (ctx.adapters.chainreader.getBalance as SinonStub).resolves(BigInt(500));
      getContextStub.returns(ctx);

      const result = await handlers.get_gas_balance({
        domain: '1337',
        address: '0x' + 'ab'.repeat(20),
      });
      expect(result).to.deep.include({
        domain: '1337',
        address: '0x' + 'ab'.repeat(20),
        balanceWei: '500',
      });
    });
  });

  // -----------------------------------------------------------------------
  // get_block_numbers
  // -----------------------------------------------------------------------

  describe('get_block_numbers', () => {
    it('returns rpc and subgraph block numbers', async () => {
      const ctx = mock.context();
      (ctx.adapters.chainreader.getBlockNumber as SinonStub).resolves(200);
      const subgraphMap = new Map([['1337', 190]]);
      (ctx.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(subgraphMap);
      getContextStub.returns(ctx);

      const result: any = await handlers.get_block_numbers({ domain: '1337' });
      expect(result.rpcBlockNumber).to.eq(200);
      expect(result.subgraphBlockNumber).to.eq(190);
      expect(result.lagBlocks).to.eq(10);
    });

    it('defaults subgraph block number to 0 when missing', async () => {
      const ctx = mock.context();
      (ctx.adapters.chainreader.getBlockNumber as SinonStub).resolves(200);
      (ctx.adapters.subgraph.getLatestBlockNumber as SinonStub).resolves(new Map());
      getContextStub.returns(ctx);

      const result: any = await handlers.get_block_numbers({ domain: '1337' });
      expect(result.subgraphBlockNumber).to.eq(0);
      expect(result.lagBlocks).to.eq(200);
    });
  });

  // -----------------------------------------------------------------------
  // get_queue_depth
  // -----------------------------------------------------------------------

  describe('get_queue_depth', () => {
    describe('deposit queue', () => {
      it('returns empty deposit queue', async () => {
        const ctx = mock.context();
        (ctx.adapters.database.getAllEnqueuedDeposits as SinonStub).resolves([]);
        getContextStub.returns(ctx);

        const result: any = await handlers.get_queue_depth({ queueFamily: 'deposit', domain: '1337' });
        expect(result.depth).to.eq(0);
        expect(result.oldestTimestamp).to.eq(0);
      });

      it('computes oldest timestamp skipping zero timestamps', async () => {
        const ctx = mock.context();
        (ctx.adapters.database.getAllEnqueuedDeposits as SinonStub).resolves([
          { enqueuedTimestamp: 0 },
          { enqueuedTimestamp: 300 },
          { enqueuedTimestamp: 100 },
        ]);
        getContextStub.returns(ctx);

        const result: any = await handlers.get_queue_depth({ queueFamily: 'deposit', domain: '1337' });
        expect(result.depth).to.eq(3);
        expect(result.oldestTimestamp).to.eq(100);
      });

      it('handles all-zero timestamps in deposits', async () => {
        const ctx = mock.context();
        (ctx.adapters.database.getAllEnqueuedDeposits as SinonStub).resolves([
          { enqueuedTimestamp: 0 },
        ]);
        getContextStub.returns(ctx);

        const result: any = await handlers.get_queue_depth({ queueFamily: 'deposit', domain: '1337' });
        expect(result.oldestTimestamp).to.eq(0);
      });
    });

    describe('settlement queue', () => {
      it('returns empty settlement queue', async () => {
        const ctx = mock.context();
        (ctx.adapters.database.getAllQueuedSettlements as SinonStub).resolves(new Map());
        getContextStub.returns(ctx);

        const result: any = await handlers.get_queue_depth({ queueFamily: 'settlement', domain: '1337' });
        expect(result.depth).to.eq(0);
        expect(result.oldestTimestamp).to.eq(0);
      });

      it('computes oldest timestamp for settlements', async () => {
        const ctx = mock.context();
        const settlementsMap = new Map([
          ['1337', [
            { settlementEnqueuedTimestamp: 500 },
            { settlementEnqueuedTimestamp: 200 },
          ]],
        ]);
        (ctx.adapters.database.getAllQueuedSettlements as SinonStub).resolves(settlementsMap);
        getContextStub.returns(ctx);

        const result: any = await handlers.get_queue_depth({ queueFamily: 'settlement', domain: '1337' });
        expect(result.depth).to.eq(2);
        expect(result.oldestTimestamp).to.eq(200);
      });

      it('skips settlements with null/zero timestamp', async () => {
        const ctx = mock.context();
        const settlementsMap = new Map([
          ['1337', [
            { settlementEnqueuedTimestamp: null },
            { settlementEnqueuedTimestamp: 0 },
            { settlementEnqueuedTimestamp: 400 },
          ]],
        ]);
        (ctx.adapters.database.getAllQueuedSettlements as SinonStub).resolves(settlementsMap);
        getContextStub.returns(ctx);

        const result: any = await handlers.get_queue_depth({ queueFamily: 'settlement', domain: '1337' });
        expect(result.oldestTimestamp).to.eq(400);
      });
    });

    describe('intent queue', () => {
      it('returns intent queue depth', async () => {
        const ctx = mock.context();
        const queueMap = new Map([['1337', [{ id: '1' }, { id: '2' }]]]);
        (ctx.adapters.database.getMessageQueueContents as SinonStub).resolves(queueMap);
        getContextStub.returns(ctx);

        const result: any = await handlers.get_queue_depth({ queueFamily: 'intent', domain: '1337' });
        expect(result.depth).to.eq(2);
        expect(result.queueFamily).to.eq('intent');
      });

      it('defaults to empty when domain not in queue map', async () => {
        const ctx = mock.context();
        (ctx.adapters.database.getMessageQueueContents as SinonStub).resolves(new Map());
        getContextStub.returns(ctx);

        const result: any = await handlers.get_queue_depth({ queueFamily: 'intent', domain: '1337' });
        expect(result.depth).to.eq(0);
      });
    });

    describe('execution queue', () => {
      it('returns execution (Fill) queue depth', async () => {
        const ctx = mock.context();
        const queueMap = new Map([['1337', [{ id: '1' }]]]);
        (ctx.adapters.database.getMessageQueueContents as SinonStub).resolves(queueMap);
        getContextStub.returns(ctx);

        const result: any = await handlers.get_queue_depth({ queueFamily: 'execution', domain: '1337' });
        expect(result.depth).to.eq(1);
        expect(result.queueFamily).to.eq('execution');
      });
    });

    describe('unsupported queue family', () => {
      it('throws for unsupported queue family', async () => {
        await expect(
          handlers.get_queue_depth({ queueFamily: 'unknown', domain: '1337' }),
        ).to.be.rejectedWith('Unsupported queue family');
      });
    });

    it('is case-insensitive for queue family', async () => {
      const ctx = mock.context();
      (ctx.adapters.database.getAllEnqueuedDeposits as SinonStub).resolves([]);
      getContextStub.returns(ctx);

      const result: any = await handlers.get_queue_depth({ queueFamily: 'DEPOSIT', domain: '1337' });
      expect(result.queueFamily).to.eq('deposit');
    });
  });

  // -----------------------------------------------------------------------
  // get_custodied_balance
  // -----------------------------------------------------------------------

  describe('get_custodied_balance', () => {
    const validHash = '0x' + 'ab'.repeat(32);

    it('returns custodied balance for valid asset hash', async () => {
      const result: any = await handlers.get_custodied_balance({ assetHash: validHash });
      expect(result.assetHash).to.eq(validHash);
      expect(result.custodiedBalance).to.eq('1000');
      expect(getCustodiedStub.calledOnce).to.be.true;
    });

    it('throws for invalid asset hash', async () => {
      await expect(
        handlers.get_custodied_balance({ assetHash: '0x1234' }),
      ).to.be.rejectedWith('Invalid assetHash');
    });

    it('throws for missing asset hash', async () => {
      await expect(
        handlers.get_custodied_balance({ assetHash: '' }),
      ).to.be.rejectedWith('Missing required tool arg');
    });
  });

  // -----------------------------------------------------------------------
  // get_current_epoch
  // -----------------------------------------------------------------------

  describe('get_current_epoch', () => {
    it('returns the current epoch', async () => {
      const result: any = await handlers.get_current_epoch({});
      expect(result.epoch).to.eq(42);
    });
  });

  // -----------------------------------------------------------------------
  // get_hyperlane_message_status
  // -----------------------------------------------------------------------

  describe('get_hyperlane_message_status', () => {
    const validMessageId = '0x' + 'cd'.repeat(32);

    it('returns message status for valid messageId', async () => {
      const result: any = await handlers.get_hyperlane_message_status({ messageId: validMessageId });
      expect(result.messageId).to.eq(validMessageId);
      expect(result.status).to.eq('delivered');
    });

    it('throws for invalid messageId', async () => {
      await expect(
        handlers.get_hyperlane_message_status({ messageId: '0xshort' }),
      ).to.be.rejectedWith('Invalid messageId');
    });

    it('throws for missing messageId', async () => {
      await expect(
        handlers.get_hyperlane_message_status({ messageId: 123 }),
      ).to.be.rejectedWith('Missing required tool arg');
    });
  });

  // -----------------------------------------------------------------------
  // get_solana_nonce_status
  // -----------------------------------------------------------------------

  describe('get_solana_nonce_status', () => {
    it('returns nonce status with default checkpointKey', async () => {
      const ctx = mock.context();
      (ctx.adapters.database.getOriginIntentsLastNonce as SinonStub).resolves(8);
      (ctx.adapters.database.getCheckPoint as SinonStub).resolves(7);
      getContextStub.returns(ctx);

      const result: any = await handlers.get_solana_nonce_status({});
      expect(result.chainNonce).to.eq(10);
      expect(result.localNonce).to.eq(8);
      expect(result.checkpoint).to.eq(7);
      expect(result.isDelayed).to.be.true;
    });

    it('returns nonce status with explicit checkpointKey', async () => {
      const ctx = mock.context();
      (ctx.adapters.database.getOriginIntentsLastNonce as SinonStub).resolves(10);
      (ctx.adapters.database.getCheckPoint as SinonStub).resolves(10);
      getContextStub.returns(ctx);

      const result: any = await handlers.get_solana_nonce_status({ checkpointKey: 'solana_intent_nonce' });
      expect(result.chainNonce).to.eq(10);
      expect(result.isDelayed).to.be.false;
    });

    it('throws for unsupported checkpointKey', async () => {
      await expect(
        handlers.get_solana_nonce_status({ checkpointKey: 'other_key' }),
      ).to.be.rejectedWith('Unsupported checkpointKey');
    });

    it('defaults checkpointKey when arg is not a string', async () => {
      const ctx = mock.context();
      (ctx.adapters.database.getOriginIntentsLastNonce as SinonStub).resolves(10);
      (ctx.adapters.database.getCheckPoint as SinonStub).resolves(10);
      getContextStub.returns(ctx);

      // non-string falls through to default 'solana_intent_nonce'
      const result: any = await handlers.get_solana_nonce_status({ checkpointKey: 42 });
      expect(result.chainNonce).to.eq(10);
    });
  });
});
