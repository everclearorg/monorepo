import { expect, mkBytes32, TIntentStatus } from '@chimera-monorepo/utils';
import { SinonStubbedInstance } from 'sinon';
import { Database } from '@chimera-monorepo/database';
import { AppContext } from '@chimera-monorepo/cartographer-core';

import { processHubInvoice, processHubDeposit } from '../../src/processors/invoiceProcessor';
import { createAppContext } from '../mock';

describe('invoiceProcessor', () => {
  let context: AppContext;
  let database: SinonStubbedInstance<Database>;

  beforeEach(() => {
    context = createAppContext();
    database = context.adapters.database as unknown as SinonStubbedInstance<Database>;
  });

  describe('#processHubInvoice', () => {
    it('should parse webhook payload and save invoice', async () => {
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
      expect(savedInvoice.intentId).to.equal(intentId);
      expect(savedInvoice.amount).to.equal('1000000');
      expect(savedInvoice.entryEpoch).to.equal(5);
    });

    it('should update hub intent status to Invoiced', async () => {
      const intentId = mkBytes32('0xabc');
      const payload = { intent: intentId, amount: '500' };

      await processHubInvoice(payload, context);

      expect(database.saveHubIntents.callCount).to.equal(1);
      const intentUpdate = database.saveHubIntents.getCall(0).args[0][0];
      expect(intentUpdate.id).to.equal(intentId);
      expect(intentUpdate.status).to.equal(TIntentStatus.Invoiced);
    });

    it('should skip when intent ID is missing', async () => {
      const payload = { amount: '100' };

      await processHubInvoice(payload, context);

      expect(database.saveHubInvoices.callCount).to.equal(0);
    });

    it('should handle base64-encoded intent field', async () => {
      // Encode a 32-byte hex as base64
      const hexId = 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
      const b64Id = Buffer.from(hexId, 'hex').toString('base64');
      const payload = { intent: b64Id, amount: '100' };

      await processHubInvoice(payload, context);

      const savedInvoice = database.saveHubInvoices.getCall(0).args[0][0];
      expect(savedInvoice.intentId).to.equal('0x' + hexId);
    });
  });

  describe('#processHubDeposit', () => {
    it('should parse and save enqueued deposit', async () => {
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

    it('should parse and save processed deposit', async () => {
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

      expect(database.saveHubDeposits.callCount).to.equal(1);
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

    it('should set DepositProcessed status for processed type', async () => {
      const intentId = mkBytes32('0x444');
      const payload = {
        id: mkBytes32('0xdep4'),
        intent_id: intentId,
        amount: '5000',
      };

      await processHubDeposit(payload, context, 'processed');

      const intentUpdate = database.saveHubIntents.getCall(0).args[0][0];
      expect(intentUpdate.status).to.equal(TIntentStatus.DepositProcessed);
    });

    it('should skip when intentId is missing', async () => {
      const payload = {
        id: mkBytes32('0xdep5'),
        amount: '5000',
        domain: '1339',
      };

      await processHubDeposit(payload, context, 'enqueued');

      expect(database.saveHubDeposits.callCount).to.equal(0);
    });
  });
});
