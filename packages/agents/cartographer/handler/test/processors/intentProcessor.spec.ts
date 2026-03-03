import { expect, mkAddress, mkBytes32 } from '@chimera-monorepo/utils';
import { SinonStubbedInstance } from 'sinon';
import { Database } from '@chimera-monorepo/database';
import { AppContext, CartographerConfig } from '@chimera-monorepo/cartographer-core';

import {
  processOriginIntent,
  processDestinationIntent,
  processHubIntent,
  processSettlementIntent,
  processOrder,
} from '../../src/processors/intentProcessor';
import { createAppContext, MockSubgraphReader } from '../mock';

describe('intentProcessor', () => {
  let context: AppContext;
  let database: SinonStubbedInstance<Database>;
  let subgraph: MockSubgraphReader;

  beforeEach(() => {
    context = createAppContext();
    database = context.adapters.database as unknown as SinonStubbedInstance<Database>;
    subgraph = context.adapters.subgraph as unknown as MockSubgraphReader;
  });

  describe('#processOriginIntent', () => {
    it('should use subgraph data when available', async () => {
      const intentId = mkBytes32('0xaaa');
      const fullIntent = {
        id: intentId,
        origin: '1337',
        destinations: ['1338'],
        inputAsset: mkAddress('0xa0b86991'),
        outputAsset: mkAddress('0xaf88d065'),
        amount: '10000',
        status: 'ADDED',
        initiator: mkAddress('0x111'),
        receiver: mkAddress('0x222'),
        transactionHash: mkBytes32('0xtx'),
        blockNumber: 50,
        gasLimit: '21000',
        gasPrice: '100',
        txOrigin: mkAddress('0x111'),
        txNonce: 5,
        timestamp: 1700000000,
        nonce: 1,
        data: '0x',
        amountOutMin: '0',
        ttl: 3600,
        queueIdx: 0,
        isSwap: undefined,
      };

      subgraph.getOriginIntentById.resolves(fullIntent);
      const payload = { id: intentId, origin: '1337' };

      await processOriginIntent(payload, context);

      expect(subgraph.getOriginIntentById.callCount).to.equal(1);
      expect(subgraph.getOriginIntentById.getCall(0).args).to.deep.equal(['1337', intentId]);
      expect(database.saveOriginIntents.callCount).to.equal(1);
      const saved = database.saveOriginIntents.getCall(0).args[0][0];
      expect(saved.id).to.equal(intentId);
      expect(saved.transactionHash).to.equal(mkBytes32('0xtx'));
    });

    it('should fall back to webhook data when subgraph returns undefined', async () => {
      subgraph.getOriginIntentById.resolves(undefined);

      const payload = {
        id: mkBytes32('0xaaa'),
        origin: '1337',
        destinations: ['1338'],
        input_asset: mkAddress('0xa0b86991'),
        output_asset: mkAddress('0xaf88d065'),
        amount: '10000',
        status: 'ADDED',
        initiator: mkAddress('0x111'),
        receiver: mkAddress('0x222'),
      };

      await processOriginIntent(payload, context);

      expect(database.saveOriginIntents.callCount).to.equal(1);
      const saved = database.saveOriginIntents.getCall(0).args[0][0];
      expect(saved.id).to.equal(mkBytes32('0xaaa'));
      expect(saved.origin).to.equal('1337');
      expect(saved.amount).to.equal('10000');
      // isSwap defaults to false when no asset configs are found in the test config
      expect(saved.isSwap).to.equal(false);
    });

    it('should set isSwap=true when asset ticker hashes differ', async () => {
      subgraph.getOriginIntentById.resolves(undefined);

      const usdcTickerHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      const wethTickerHash = '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

      context.config.chains['1337'].assets = {
        USDC: {
          symbol: 'USDC',
          address: mkAddress('0xa0b86991'),
          decimals: 6,
          isNative: false,
          price: { isStable: true },
          tickerHash: usdcTickerHash,
        },
      };
      context.config.chains['1338'].assets = {
        WETH: {
          symbol: 'WETH',
          address: mkAddress('0x82af4944'),
          decimals: 18,
          isNative: false,
          price: { isStable: false },
          tickerHash: wethTickerHash,
        },
      };

      const payload = {
        id: mkBytes32('0xbbb'),
        origin: '1337',
        destinations: ['1338'],
        input_asset: mkAddress('0xa0b86991'),
        output_asset: mkAddress('0x82af4944'),
        amount: '10000',
        status: 'ADDED',
      };

      await processOriginIntent(payload, context);

      const saved = database.saveOriginIntents.getCall(0).args[0][0];
      expect(saved.isSwap).to.equal(true);
    });

    it('should set isSwap=false when asset ticker hashes match', async () => {
      subgraph.getOriginIntentById.resolves(undefined);

      const usdcTickerHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

      context.config.chains['1337'].assets = {
        USDC: {
          symbol: 'USDC',
          address: mkAddress('0xa0b86991'),
          decimals: 6,
          isNative: false,
          price: { isStable: true },
          tickerHash: usdcTickerHash,
        },
      };
      context.config.chains['1338'].assets = {
        USDC: {
          symbol: 'USDC',
          address: mkAddress('0xaf88d065'),
          decimals: 6,
          isNative: false,
          price: { isStable: true },
          tickerHash: usdcTickerHash,
        },
      };

      const payload = {
        id: mkBytes32('0xccc'),
        origin: '1337',
        destinations: ['1338'],
        input_asset: mkAddress('0xa0b86991'),
        output_asset: mkAddress('0xaf88d065'),
        amount: '10000',
        status: 'ADDED',
      };

      await processOriginIntent(payload, context);

      const saved = database.saveOriginIntents.getCall(0).args[0][0];
      expect(saved.isSwap).to.equal(false);
    });
  });

  describe('#processDestinationIntent', () => {
    it('should use subgraph data when available', async () => {
      const intentId = mkBytes32('0xddd');
      const fullIntent = {
        id: intentId,
        destination: '1338',
        receiver: mkAddress('0x222'),
        amount: '9900',
        solver: mkAddress('0x333'),
        status: 'FILLED',
        transactionHash: mkBytes32('0xtx'),
        blockNumber: 100,
        gasLimit: '21000',
        gasPrice: '100',
        txOrigin: mkAddress('0x333'),
        txNonce: 10,
        timestamp: 1700000000,
      };

      subgraph.getDestinationIntentById.resolves(fullIntent);
      const payload = { id: intentId };

      await processDestinationIntent(payload, context, '1338');

      expect(subgraph.getDestinationIntentById.callCount).to.equal(1);
      expect(database.saveDestinationIntents.callCount).to.equal(1);
      const saved = database.saveDestinationIntents.getCall(0).args[0][0];
      expect(saved.id).to.equal(intentId);
    });

    it('should fall back to webhook data and set domain from param', async () => {
      subgraph.getDestinationIntentById.resolves(undefined);

      const payload = {
        id: mkBytes32('0xddd'),
        receiver: mkAddress('0x222'),
        amount: '9900',
        filler: mkAddress('0x333'),
        status: 'FILLED',
      };

      await processDestinationIntent(payload, context, '1338');

      expect(database.saveDestinationIntents.callCount).to.equal(1);
      const saved = database.saveDestinationIntents.getCall(0).args[0][0];
      expect(saved.id).to.equal(mkBytes32('0xddd'));
      expect(saved.destination).to.equal('1338');
    });
  });

  describe('#processHubIntent', () => {
    it('should use subgraph data when available', async () => {
      const intentId = mkBytes32('0xeee');
      const fullIntent = {
        id: intentId,
        status: 'ADDED',
        domain: '1339',
        addedTimestamp: 1700000000,
        addedTxNonce: 42,
      };

      subgraph.getHubIntentById.resolves(fullIntent);
      const payload = { id: intentId, status: 'ADDED', domain: '1339' };

      await processHubIntent(payload, context);

      expect(subgraph.getHubIntentById.callCount).to.equal(1);
      expect(database.saveHubIntents.callCount).to.equal(1);
    });

    it('should fall back with status column when subgraph unavailable and only status present', async () => {
      subgraph.getHubIntentById.resolves(undefined);

      const payload = {
        id: mkBytes32('0xeee'),
        status: 'ADDED',
        domain: '1339',
      };

      await processHubIntent(payload, context);

      expect(database.saveHubIntents.callCount).to.equal(1);
      const updateColumns = database.saveHubIntents.getCall(0).args[1];
      expect(updateColumns).to.deep.equal(['status']);
    });

    it('should include added timestamp columns when addedTimestamp present (fallback)', async () => {
      subgraph.getHubIntentById.resolves(undefined);

      const payload = {
        id: mkBytes32('0xfff'),
        status: 'ADDED',
        domain: '1339',
        added_timestamp: 1700000000,
        added_tx_nonce: 42,
      };

      await processHubIntent(payload, context);

      const updateColumns = database.saveHubIntents.getCall(0).args[1];
      expect(updateColumns).to.include('added_timestamp');
      expect(updateColumns).to.include('added_tx_nonce');
      expect(updateColumns).to.include('status');
    });

    it('should include filled timestamp columns when filledTimestamp present (fallback)', async () => {
      subgraph.getHubIntentById.resolves(undefined);

      const payload = {
        id: mkBytes32('0x111'),
        status: 'FILLED',
        domain: '1339',
        filled_timestamp: 1700001000,
        filled_tx_nonce: 50,
      };

      await processHubIntent(payload, context);

      const updateColumns = database.saveHubIntents.getCall(0).args[1];
      expect(updateColumns).to.include('filled_timestamp');
      expect(updateColumns).to.include('filled_tx_nonce');
      expect(updateColumns).to.include('status');
    });

    it('should include settlement enqueued columns when present (fallback)', async () => {
      subgraph.getHubIntentById.resolves(undefined);

      const payload = {
        id: mkBytes32('0x222'),
        status: 'DISPATCHED',
        domain: '1339',
        settlement_enqueued_timestamp: 1700002000,
        settlement_enqueued_tx_nonce: 60,
        settlement_enqueued_block_number: 300,
        settlement_domain: '1337',
        settlement_amount: '9500',
        settlement_epoch: 7,
        queue_idx: 3,
      };

      await processHubIntent(payload, context);

      const updateColumns = database.saveHubIntents.getCall(0).args[1];
      expect(updateColumns).to.include('settlement_enqueued_timestamp');
      expect(updateColumns).to.include('settlement_domain');
      expect(updateColumns).to.include('settlement_amount');
      expect(updateColumns).to.include('queue_idx');
    });
  });

  describe('#processSettlementIntent', () => {
    it('should use subgraph data when available', async () => {
      const intentId = mkBytes32('0x333');
      const fullIntent = {
        intentId,
        domain: '1337',
        amount: '9500',
        asset: mkAddress('0xaf88d065'),
        recipient: mkAddress('0x444'),
        status: 'SETTLED',
        transactionHash: mkBytes32('0xtx'),
        blockNumber: 400,
        gasLimit: '21000',
        gasPrice: '100',
        txOrigin: mkAddress('0x444'),
        txNonce: 70,
        timestamp: 1700003000,
      };

      subgraph.getSettlementIntentById.resolves(fullIntent);
      const payload = { id: intentId };

      await processSettlementIntent(payload, context, '1337');

      expect(subgraph.getSettlementIntentById.callCount).to.equal(1);
      expect(database.saveSettlementIntents.callCount).to.equal(1);
      const saved = database.saveSettlementIntents.getCall(0).args[0][0];
      expect(saved.intentId).to.equal(intentId);
    });

    it('should fall back to webhook data and set domain from param', async () => {
      subgraph.getSettlementIntentById.resolves(undefined);

      const payload = {
        id: mkBytes32('0x333'),
        amount: '9500',
        asset: mkAddress('0xaf88d065'),
        recipient: mkAddress('0x444'),
        status: 'SETTLED',
      };

      await processSettlementIntent(payload, context, '1337');

      expect(database.saveSettlementIntents.callCount).to.equal(1);
      const saved = database.saveSettlementIntents.getCall(0).args[0][0];
      expect(saved.intentId).to.equal(mkBytes32('0x333'));
      expect(saved.domain).to.equal('1337');
    });
  });

  describe('#processOrder', () => {
    it('should parse and save order', async () => {
      const payload = {
        id: mkBytes32('0x444'),
        initiator: mkAddress('0x555'),
        intent_ids: [mkBytes32('0xabc')],
        token_fee: '8000',
        native_fee: '100',
        tx_nonce: 80,
        block_timestamp: 1700004000,
        block_number: 500,
        transaction_hash: mkBytes32('0xtx'),
      };

      await processOrder(payload, context);

      expect(database.saveOrders.callCount).to.equal(1);
      const saved = database.saveOrders.getCall(0).args[0][0];
      expect(saved.id).to.equal(mkBytes32('0x444'));
      expect(saved.tokenFee).to.equal('8000');
      expect(saved.intentIds).to.deep.equal([mkBytes32('0xabc')]);
    });
  });
});
