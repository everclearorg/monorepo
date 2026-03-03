import {
  expect,
  mkBytes32,
  HyperlaneStatus,
  SOLANA_CHAINID,
  TIntentStatus,
  TMessageType,
  TSettlementMessageType,
  QueueType,
} from '@chimera-monorepo/utils';
import { SinonStubbedInstance } from 'sinon';
import { Database } from '@chimera-monorepo/database';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { AppContext } from '@chimera-monorepo/cartographer-core';

import {
  processHubMessage,
  processSpokeMessage,
  processQueue,
  processHubMeta,
  processSpokeMeta,
  processSettlementEnqueued,
  processHubMetaUpdate,
  processHubTokenUpdate,
  processHubAssetUpdate,
} from '../../src/processors/monitorProcessor';
import { createAppContext, MockSubgraphReader } from '../mock';

describe('monitorProcessor', () => {
  let context: AppContext;
  let database: SinonStubbedInstance<Database>;
  let subgraph: MockSubgraphReader;
  let chainreader: SinonStubbedInstance<ChainReader>;

  beforeEach(() => {
    context = createAppContext();
    database = context.adapters.database as unknown as SinonStubbedInstance<Database>;
    subgraph = context.adapters.subgraph as unknown as MockSubgraphReader;
    chainreader = context.adapters.chainreader as unknown as SinonStubbedInstance<ChainReader>;
  });

  describe('#processHubMessage', () => {
    it('should save settlement message with pending status and hub intent updates', async () => {
      const intentId = mkBytes32('0xaaa');
      const payload = {
        id: mkBytes32('0xmsg1'),
        type: TMessageType.Settlement,
        intent_ids: [intentId],
        origin_domain: '1339',
        destination_domain: '1337',
        settlement_domain: '1337',
        settlement_type: TSettlementMessageType.Settled,
        tx_nonce: 5,
        block_timestamp: 1700000000,
      };

      await processHubMessage(payload, context);

      expect(database.saveMessages.callCount).to.equal(1);

      // Check message saved with pending status
      const savedMessage = database.saveMessages.getCall(0).args[0][0];
      expect(savedMessage.status).to.equal(HyperlaneStatus.pending);
      expect(savedMessage.id).to.equal(mkBytes32('0xmsg1'));

      // Check hub intent updates (4th arg)
      const hubIntentUpdates = database.saveMessages.getCall(0).args[3];
      expect(hubIntentUpdates).to.have.length(1);
      expect(hubIntentUpdates[0].id).to.equal(intentId);
      expect(hubIntentUpdates[0].status).to.equal(TIntentStatus.Dispatched);
    });

    it('should use DispatchedUnsupported status for non-Settled settlement types', async () => {
      const payload = {
        id: mkBytes32('0xmsg2'),
        type: TMessageType.Settlement,
        intent_ids: [mkBytes32('0xbbb')],
        origin_domain: '1339',
        destination_domain: '1337',
        settlement_domain: '1337',
        settlement_type: 'Unsupported',
        tx_nonce: 6,
      };

      await processHubMessage(payload, context);

      const hubIntentUpdates = database.saveMessages.getCall(0).args[3];
      expect(hubIntentUpdates[0].status).to.equal(TIntentStatus.DispatchedUnsupported);
    });

    it('should pass empty hub intent updates for non-Settlement messages', async () => {
      const payload = {
        id: mkBytes32('0xmsg3'),
        type: TMessageType.Intent,
        intent_ids: [mkBytes32('0xccc')],
        origin_domain: '1339',
        destination_domain: '1337',
        tx_nonce: 7,
      };

      await processHubMessage(payload, context);

      const hubIntentUpdates = database.saveMessages.getCall(0).args[3];
      expect(hubIntentUpdates).to.have.length(0);
    });

    it('should query Hyperlane delivery status via chainreader', async () => {
      const payload = {
        id: mkBytes32('0xmsg7'),
        type: TMessageType.Settlement,
        intent_ids: [mkBytes32('0xddd')],
        origin_domain: '1339',
        destination_domain: '1337',
        settlement_domain: '1337',
        settlement_type: TSettlementMessageType.Settled,
        tx_nonce: 20,
      };

      await processHubMessage(payload, context);

      // chainreader.readTx should be called to check delivery status
      expect(chainreader.readTx.callCount).to.be.greaterThan(0);
    });

    it('should skip Hyperlane status check for Solana destination', async () => {
      const payload = {
        id: mkBytes32('0xmsg8'),
        type: TMessageType.Settlement,
        intent_ids: [mkBytes32('0xeee')],
        origin_domain: '1339',
        destination_domain: SOLANA_CHAINID,
        settlement_domain: SOLANA_CHAINID,
        settlement_type: TSettlementMessageType.Settled,
        tx_nonce: 21,
      };

      await processHubMessage(payload, context);

      // chainreader.readTx should NOT be called for Solana
      expect(chainreader.readTx.callCount).to.equal(0);
      const savedMessage = database.saveMessages.getCall(0).args[0][0];
      expect(savedMessage.status).to.equal(HyperlaneStatus.pending);
    });
  });

  describe('#processSpokeMessage', () => {
    it('should save Intent-type message with origin intent updates', async () => {
      const intentId = mkBytes32('0xddd');
      const payload = {
        id: mkBytes32('0xmsg4'),
        type: TMessageType.Intent,
        intent_ids: [intentId],
        origin_domain: '1337',
        destination_domain: '1339',
        tx_nonce: 10,
        block_timestamp: 1700001000,
      };

      await processSpokeMessage(payload, context);

      expect(database.saveMessages.callCount).to.equal(1);

      // Check origin intent updates (2nd arg)
      const originIntentUpdates = database.saveMessages.getCall(0).args[1];
      expect(originIntentUpdates).to.have.length(1);
      expect(originIntentUpdates[0].id).to.equal(intentId);
      expect(originIntentUpdates[0].status).to.equal(TIntentStatus.Dispatched);

      // Check destination intent updates are empty (3rd arg)
      const destIntentUpdates = database.saveMessages.getCall(0).args[2];
      expect(destIntentUpdates).to.have.length(0);
    });

    it('should save Fill-type message with destination intent updates', async () => {
      const intentId = mkBytes32('0xeee');
      const payload = {
        id: mkBytes32('0xmsg5'),
        type: TMessageType.Fill,
        intent_ids: [intentId],
        origin_domain: '1338',
        destination_domain: '1339',
        tx_nonce: 11,
      };

      await processSpokeMessage(payload, context);

      // Check origin intent updates are empty (2nd arg)
      const originIntentUpdates = database.saveMessages.getCall(0).args[1];
      expect(originIntentUpdates).to.have.length(0);

      // Check destination intent updates (3rd arg)
      const destIntentUpdates = database.saveMessages.getCall(0).args[2];
      expect(destIntentUpdates).to.have.length(1);
      expect(destIntentUpdates[0].id).to.equal(intentId);
      expect(destIntentUpdates[0].status).to.equal(TIntentStatus.Dispatched);
    });

    it('should default destinationDomain to hub domain when missing', async () => {
      const payload = {
        id: mkBytes32('0xmsg6'),
        type: TMessageType.Intent,
        intent_ids: [mkBytes32('0xfff')],
        origin_domain: '1337',
        tx_nonce: 12,
      };

      await processSpokeMessage(payload, context);

      const savedMessage = database.saveMessages.getCall(0).args[0][0];
      expect(savedMessage.destinationDomain).to.equal(context.config.hub.domain);
    });

    it('should query Hyperlane delivery status via chainreader', async () => {
      const payload = {
        id: mkBytes32('0xmsg9'),
        type: TMessageType.Intent,
        intent_ids: [mkBytes32('0x123')],
        origin_domain: '1337',
        destination_domain: '1339',
        tx_nonce: 30,
      };

      await processSpokeMessage(payload, context);

      // chainreader.readTx should be called to check delivery status
      expect(chainreader.readTx.callCount).to.be.greaterThan(0);
    });
  });

  describe('#processQueue', () => {
    it('should parse and save queue', async () => {
      const payload = {
        id: 'queue-test-1',
        domain: '1337',
        size: 15,
        first: 0,
        last: 14,
        last_processed: 10,
        block_number: 1000,
      };

      await processQueue(payload, context, QueueType.Settlement);

      expect(database.saveQueues.callCount).to.equal(1);
      const saved = database.saveQueues.getCall(0).args[0][0];
      expect(saved.id).to.equal('queue-test-1');
      expect(saved.size).to.equal(15);
      expect(saved.type).to.equal(QueueType.Settlement);
    });
  });

  describe('#processHubMeta', () => {
    it('should parse and save hub meta', async () => {
      const payload = { id: '1339', domain: '1339', paused: false, gateway: mkBytes32('0xgateway') };

      await processHubMeta(payload, context);

      expect(database.saveHubMeta.callCount).to.equal(1);
      const saved = database.saveHubMeta.getCall(0).args[0][0];
      expect(saved.domain).to.equal('1339');
      expect(saved.paused).to.equal(false);
      expect(saved.gateway).to.equal(mkBytes32('0xgateway'));
    });
  });

  describe('#processSpokeMeta', () => {
    it('should parse and save spoke meta', async () => {
      const payload = { domain: '1337', epoch: 5, last_processed_nonce: 200, block_number: 1500 };

      await processSpokeMeta(payload, context);

      expect(database.saveSpokeMeta.callCount).to.equal(1);
      const saved = database.saveSpokeMeta.getCall(0).args[0][0];
      expect(saved.domain).to.equal('1337');
    });
  });

  describe('#processSettlementEnqueued', () => {
    it('should use subgraph data when available', async () => {
      const intentId = mkBytes32('0xabc');
      const fullIntent = {
        id: intentId,
        status: 'ADDED',
        domain: '1339',
        addedTimestamp: 1700000000,
        addedTxNonce: 42,
      };

      subgraph.getHubIntentById.resolves(fullIntent);
      const payload = { intent: intentId };

      await processSettlementEnqueued(payload, context);

      expect(subgraph.getHubIntentById.callCount).to.equal(1);
      expect(database.saveHubIntents.callCount).to.equal(1);
      const update = database.saveHubIntents.getCall(0).args[0][0];
      expect(update.id).to.equal(intentId);
      expect(update.status).to.equal(TIntentStatus.Dispatched);
    });

    it('should fall back to minimal update when subgraph unavailable', async () => {
      const intentId = mkBytes32('0xabc');
      const payload = { intent: intentId };

      await processSettlementEnqueued(payload, context);

      expect(database.saveHubIntents.callCount).to.equal(1);
      const update = database.saveHubIntents.getCall(0).args[0][0];
      expect(update.id).to.equal(intentId);
      expect(update.status).to.equal(TIntentStatus.Dispatched);
    });

    it('should handle base64-encoded intent id', async () => {
      const hexId = 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
      const b64 = Buffer.from(hexId, 'hex').toString('base64');
      const payload = { intent: b64 };

      await processSettlementEnqueued(payload, context);

      expect(database.saveHubIntents.callCount).to.equal(1);
      const update = database.saveHubIntents.getCall(0).args[0][0];
      expect(update.id).to.equal('0x' + hexId);
    });

    it('should not save when intent is missing', async () => {
      await processSettlementEnqueued({}, context);
      expect(database.saveHubIntents.callCount).to.equal(0);
    });
  });

  describe('#processHubMetaUpdate', () => {
    it('should parse and save protocol update log', async () => {
      const payload = {
        id: 'update-1',
        domain: '1339',
        kind: 'FeeUpdate',
        key: 'fee',
        value: '500',
        caller: mkBytes32('0xcaller'),
        block_number: 3000,
        tx_hash: mkBytes32('0xtx'),
        block_timestamp: 1700005000,
      };

      await processHubMetaUpdate(payload, context);

      expect(database.saveProtocolUpdateLogs.callCount).to.equal(1);
      const saved = database.saveProtocolUpdateLogs.getCall(0).args[0][0];
      expect(saved.id).to.equal('update-1');
      expect(saved.event).to.equal('FeeUpdate');
      expect(saved.updated).to.equal('500');
    });
  });

  describe('#processHubTokenUpdate', () => {
    it('should parse and save hub token update log', async () => {
      const payload = {
        id: 'token-update-1',
        domain: '1339',
        ticker_hash: mkBytes32('0xticker'),
        kind: 'priorityFee',
        fee_recipients: ['0x111'],
        fee_amounts: ['100'],
        max_discount_bps: 50,
        discount_per_epoch: 10,
        prioritized_strategy: 'default',
        block_number: 3100,
        tx_hash: mkBytes32('0xtx2'),
        block_timestamp: 1700006000,
      };

      await processHubTokenUpdate(payload, context);

      expect(database.saveHubTokenUpdateLogs.callCount).to.equal(1);
      const saved = database.saveHubTokenUpdateLogs.getCall(0).args[0][0];
      expect(saved.kind).to.equal('priorityFee');
      expect(saved.tickerHash).to.equal(mkBytes32('0xticker'));
    });
  });

  describe('#processHubAssetUpdate', () => {
    it('should parse and save hub asset update log', async () => {
      const payload = {
        id: 'asset-update-1',
        ticker_hash: mkBytes32('0xticker'),
        domain: '1337',
        asset_id: mkBytes32('0xasset'),
        kind: 'approval',
        asset_hash: mkBytes32('0xhash'),
        adopted: mkBytes32('0xadopted'),
        approval: true,
        strategy: 'default',
        block_number: 3200,
        tx_hash: mkBytes32('0xtx3'),
        block_timestamp: 1700007000,
      };

      await processHubAssetUpdate(payload, context);

      expect(database.saveHubAssetUpdateLogs.callCount).to.equal(1);
      const saved = database.saveHubAssetUpdateLogs.getCall(0).args[0][0];
      expect(saved.domain).to.equal('1337');
      expect(saved.kind).to.equal('approval');
      expect(saved.assetId).to.equal(mkBytes32('0xasset'));
    });
  });
});
