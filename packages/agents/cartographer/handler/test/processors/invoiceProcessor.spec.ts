import { expect, mkBytes32, TIntentStatus } from '@chimera-monorepo/utils';
import { SinonStubbedInstance } from 'sinon';
import { Database } from '@chimera-monorepo/database';
import { AppContext } from '@chimera-monorepo/cartographer-core';

import { processHubInvoice, processHubDeposit } from '../../src/processors/invoiceProcessor';
import { createAppContext, MockSubgraphReader } from '../mock';

describe('invoiceProcessor', () => {
  let context: AppContext;
  let database: SinonStubbedInstance<Database>;
  let subgraph: MockSubgraphReader;

  beforeEach(() => {
    context = createAppContext();
    database = context.adapters.database as unknown as SinonStubbedInstance<Database>;
    subgraph = context.adapters.subgraph as unknown as MockSubgraphReader;
  });

  describe('#processHubInvoice', () => {
    it('should use subgraph data when available', async () => {
      const intentId = mkBytes32('0xabc');
      const fullInvoice = {
        id: intentId,
        amount: '1000000',
        tickerHash: mkBytes32('0xdef'),
        owner: mkBytes32('0x123'),
        entryEpoch: 5,
        txNonce: 42,
        timestamp: 1700000000,
        blockNumber: 100,
      };
      const fullIntent = {
        id: intentId,
        status: 'ADDED',
        domain: '1339',
      };

      subgraph.getHubInvoiceById.resolves(fullInvoice);
      subgraph.getHubIntentById.resolves(fullIntent);

      const payload = { intent: intentId, amount: '1000000' };

      await processHubInvoice(payload, context);

      expect(subgraph.getHubInvoiceById.callCount).to.equal(1);
      expect(database.saveHubInvoices.callCount).to.equal(1);
      const savedInvoice = database.saveHubInvoices.getCall(0).args[0][0];
      expect(savedInvoice.id).to.equal(intentId);
      expect(savedInvoice.amount).to.equal('1000000');
    });

    it('should update hub intent status to Invoiced when subgraph has full intent', async () => {
      const intentId = mkBytes32('0xabc');
      const fullInvoice = {
        id: intentId,
        amount: '500',
      };
      const fullIntent = {
        id: intentId,
        status: 'ADDED',
        domain: '1339',
      };

      subgraph.getHubInvoiceById.resolves(fullInvoice);
      subgraph.getHubIntentById.resolves(fullIntent);

      const payload = { intent: intentId, amount: '500' };

      await processHubInvoice(payload, context);

      expect(database.saveHubIntents.callCount).to.equal(1);
      const intentUpdate = database.saveHubIntents.getCall(0).args[0][0];
      expect(intentUpdate.id).to.equal(intentId);
      expect(intentUpdate.status).to.equal(TIntentStatus.Invoiced);
    });

    it('should fall back to webhook data when subgraph returns undefined', async () => {
      const intentId = mkBytes32('0xabc');
      const payload = {
        intent: intentId,
        amount: '1000000',
        ticker_hash: mkBytes32('0xdef'),
        owner: mkBytes32('0x123'),
        entry_epoch: 5,
        tx_nonce: 42,
        block_timestamp: 1700000000,
        block_number: 100,
      };

      await processHubInvoice(payload, context);

      expect(database.saveHubInvoices.callCount).to.equal(1);
      const savedInvoice = database.saveHubInvoices.getCall(0).args[0][0];
      expect(savedInvoice.id).to.equal(intentId);
      expect(savedInvoice.amount).to.equal('1000000');
      expect(savedInvoice.entryEpoch).to.equal(5);
    });

    it('should update hub intent status to Invoiced in fallback path', async () => {
      const intentId = mkBytes32('0xabc');
      const payload = { intent: intentId, amount: '500' };

      await processHubInvoice(payload, context);

      expect(database.saveHubIntents.callCount).to.equal(1);
      const intentUpdate = database.saveHubIntents.getCall(0).args[0][0];
      expect(intentUpdate.id).to.equal(intentId);
      expect(intentUpdate.status).to.equal(TIntentStatus.Invoiced);
    });

    it('should handle base64-encoded intent field', async () => {
      // Encode a 32-byte hex as base64
      const hexId = 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
      const b64Id = Buffer.from(hexId, 'hex').toString('base64');
      const payload = { intent: b64Id, amount: '100' };

      await processHubInvoice(payload, context);

      const savedInvoice = database.saveHubInvoices.getCall(0).args[0][0];
      expect(savedInvoice.id).to.equal('0x' + hexId);
    });
  });

  describe('#processHubDeposit', () => {
    it('should use subgraph data for enqueued deposit', async () => {
      const intentId = mkBytes32('0x111');
      const fullDeposit = {
        id: mkBytes32('0xdep'),
        intentId,
        amount: '2000',
        tickerHash: mkBytes32('0xdef'),
        domain: '1339',
        epoch: 3,
        txNonce: 10,
        timestamp: 1700000000,
        blockNumber: 100,
        status: TIntentStatus.Invoiced,
      };

      subgraph.getHubDepositEnqueuedById.resolves(fullDeposit);

      const payload = { intent_id: intentId, amount: '2000' };

      await processHubDeposit(payload, context, 'enqueued');

      expect(subgraph.getHubDepositEnqueuedById.callCount).to.equal(1);
      expect(database.saveHubDeposits.callCount).to.equal(1);
    });

    it('should fall back to webhook data for enqueued deposit', async () => {
      const intentId = mkBytes32('0x111');
      const payload = {
        id: mkBytes32('0xdep'),
        intent_id: intentId,
        amount: '2000',
        ticker_hash: mkBytes32('0xdef'),
        domain: '1339',
        epoch: 3,
        tx_nonce: 10,
        block_timestamp: 1700000000,
      };

      await processHubDeposit(payload, context, 'enqueued');

      expect(database.saveHubDeposits.callCount).to.equal(1);
    });

    it('should use subgraph data for processed deposit', async () => {
      const intentId = mkBytes32('0x222');
      const fullDeposit = {
        id: mkBytes32('0xdep2'),
        intentId,
        amount: '3000',
        domain: '1339',
        epoch: 4,
        txNonce: 20,
        processedTxNonce: 25,
        processedTimestamp: 1700001000,
        processedBlockNumber: 200,
        timestamp: 1700000000,
        blockNumber: 150,
        status: TIntentStatus.DepositProcessed,
      };

      subgraph.getHubDepositProcessedById.resolves(fullDeposit);

      const payload = { intent_id: intentId, amount: '3000' };

      await processHubDeposit(payload, context, 'processed');

      expect(subgraph.getHubDepositProcessedById.callCount).to.equal(1);
      expect(database.saveHubDeposits.callCount).to.equal(1);
    });

    it('should fall back to webhook data for processed deposit', async () => {
      const intentId = mkBytes32('0x222');
      const payload = {
        id: mkBytes32('0xdep2'),
        intent_id: intentId,
        amount: '3000',
        domain: '1339',
        epoch: 4,
        tx_nonce: 20,
        processed_tx_nonce: 25,
        processed_timestamp: 1700001000,
        processed_block_number: 200,
        block_timestamp: 1700000000,
      };

      await processHubDeposit(payload, context, 'processed');

      const savedDeposit = database.saveHubDeposits.getCall(0).args[0][0];
      expect(savedDeposit.processedTxNonce).to.equal(25);
    });

    it('should update hub intent status', async () => {
      const intentId = mkBytes32('0x333');
      const payload = {
        id: mkBytes32('0xdep3'),
        intent_id: intentId,
        amount: '4000',
        domain: '1339',
      };

      await processHubDeposit(payload, context, 'enqueued');

      expect(database.saveHubIntents.callCount).to.equal(1);
      const intentUpdate = database.saveHubIntents.getCall(0).args[0][0];
      expect(intentUpdate.id).to.equal(intentId);
      expect(intentUpdate.domain).to.equal(context.config.hub.domain);
    });

    it('should still save deposit when intentId fields are missing', async () => {
      const payload = {
        id: mkBytes32('0xdep4'),
        amount: '5000',
        domain: '1339',
      };

      await processHubDeposit(payload, context, 'enqueued');

      expect(database.saveHubDeposits.callCount).to.equal(1);
    });
  });
});
