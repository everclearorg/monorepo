import { expect, mkBytes32 } from '@chimera-monorepo/utils';
import { SinonStubbedInstance } from 'sinon';
import { Database } from '@chimera-monorepo/database';
import { AppContext } from '@chimera-monorepo/cartographer-core';

import { base64ToHex, verifySecret, routeWebhook } from '../../src/webhooks/webhookHandler';
import { createAppContext } from '../mock';

describe('webhookHandler', () => {
  describe('#base64ToHex', () => {
    it('should convert base64 to 0x-prefixed hex', () => {
      // 0xdeadbeef in base64 = "3q2+7w=="
      const b64 = Buffer.from('deadbeef', 'hex').toString('base64');
      expect(base64ToHex(b64)).to.equal('0xdeadbeef');
    });

    it('should handle empty string', () => {
      expect(base64ToHex('')).to.equal('0x');
    });
  });

  describe('#verifySecret', () => {
    const secret = 'my-webhook-secret-123';

    it('should return true for matching secret', () => {
      expect(verifySecret(secret, secret)).to.be.true;
    });

    it('should return false for mismatched secret', () => {
      expect(verifySecret('wrong-secret', secret)).to.be.false;
    });

    it('should return false for undefined header', () => {
      expect(verifySecret(undefined, secret)).to.be.false;
    });

    it('should return false for empty header', () => {
      expect(verifySecret('', secret)).to.be.false;
    });

    it('should return false for different length secrets', () => {
      expect(verifySecret('short', secret)).to.be.false;
    });
  });

  describe('#routeWebhook', () => {
    let context: AppContext;
    let database: SinonStubbedInstance<Database>;

    beforeEach(() => {
      context = createAppContext();
      database = context.adapters.database as unknown as SinonStubbedInstance<Database>;
    });

    it('should route hub-invoice webhook', async () => {
      const intentHex = mkBytes32('0xabc');
      const payload = {
        _gs_gid: 'test-id-1',
        intent: intentHex,
        amount: '1000',
        ticker_hash: mkBytes32('0xdef'),
        owner: mkBytes32('0x123'),
        entry_epoch: 1,
        tx_nonce: 100,
        block_timestamp: 1700000000,
      };

      const result = await routeWebhook(payload, 'hub-invoice', context);

      expect(result.processed).to.be.true;
      expect(result.webhookId).to.equal('test-id-1');
      expect(database.saveHubInvoices.callCount).to.equal(1);
      expect(database.saveHubIntents.callCount).to.equal(1);
      expect(database.refreshInvoicesView.callCount).to.equal(1);
    });

    it('should route origin-intent webhook', async () => {
      const payload = {
        _gs_gid: 'test-id-2',
        id: mkBytes32('0xaaa'),
        origin: '1337',
        destinations: ['1338'],
        input_asset: mkBytes32('0xbbb'),
        output_asset: mkBytes32('0xccc'),
        amount: '5000',
        status: 'ADDED',
      };

      const result = await routeWebhook(payload, 'origin-intent', context);

      expect(result.processed).to.be.true;
      expect(database.saveOriginIntents.callCount).to.equal(1);
      expect(database.refreshIntentsView.callCount).to.equal(1);
    });

    it('should route hub-message webhook', async () => {
      const payload = {
        _gs_gid: 'test-id-3',
        id: mkBytes32('0xfff'),
        type: 'Settlement',
        intent_ids: [mkBytes32('0x111')],
        origin_domain: '1339',
        destination_domain: '1337',
        settlement_domain: '1337',
        settlement_type: 'Settled',
      };

      const result = await routeWebhook(payload, 'hub-message', context);

      expect(result.processed).to.be.true;
      expect(database.saveMessages.callCount).to.equal(1);
    });

    it('should route settlement-queue webhook', async () => {
      const payload = {
        _gs_gid: 'test-id-4',
        id: 'queue-1',
        domain: '1337',
        size: 10,
        first: 0,
        last: 9,
        last_processed: 5,
      };

      const result = await routeWebhook(payload, 'settlement-queue', context);

      expect(result.processed).to.be.true;
      expect(database.saveQueues.callCount).to.equal(1);
    });

    it('should route deposit-queue webhook', async () => {
      const payload = { _gs_gid: 'test-id-5', id: 'queue-2', domain: '1339', size: 5 };

      const result = await routeWebhook(payload, 'deposit-queue', context);

      expect(result.processed).to.be.true;
      expect(database.saveQueues.callCount).to.equal(1);
    });

    it('should route hub-meta webhook', async () => {
      const payload = { _gs_gid: 'test-id-6', domain: '1339', epoch: 5, last_processed_nonce: 100 };

      const result = await routeWebhook(payload, 'hub-meta', context);

      expect(result.processed).to.be.true;
      expect(database.saveHubMeta.callCount).to.equal(1);
    });

    it('should route spoke-meta webhook', async () => {
      const payload = { _gs_gid: 'test-id-7', domain: '1337', epoch: 3, last_processed_nonce: 50 };

      const result = await routeWebhook(payload, 'spoke-meta', context);

      expect(result.processed).to.be.true;
      expect(database.saveSpokeMeta.callCount).to.equal(1);
    });

    it('should route hub-token webhook', async () => {
      const payload = {
        _gs_gid: 'test-id-8',
        id: mkBytes32('0xtoken'),
        ticker_hash: mkBytes32('0xtick'),
        ticker: 'USDC',
        priority_fee: '100',
        fee_token: mkBytes32('0xfee'),
      };

      const result = await routeWebhook(payload, 'hub-token', context);

      expect(result.processed).to.be.true;
      expect(database.saveTokens.callCount).to.equal(1);
    });

    it('should return processed=false for unknown webhook', async () => {
      const result = await routeWebhook({}, 'unknown-webhook', context);

      expect(result.processed).to.be.false;
      expect(result.message).to.include('Unknown webhook type');
    });

    it('should generate webhookId from _gs_gid', async () => {
      const payload = { _gs_gid: 'custom-gid-123', domain: '1339', epoch: 1 };
      const result = await routeWebhook(payload, 'hub-meta', context);
      expect(result.webhookId).to.equal('custom-gid-123');
    });

    it('should generate fallback webhookId when _gs_gid is missing', async () => {
      const payload = { domain: '1339', epoch: 1 };
      const result = await routeWebhook(payload, 'hub-meta', context);
      expect(result.webhookId).to.match(/^mirror-/);
    });

    it('should throw when processor throws', async () => {
      database.saveHubInvoices.rejects(new Error('DB error'));
      const payload = { intent: mkBytes32('0xabc'), amount: '1000' };
      await expect(routeWebhook(payload, 'hub-invoice', context)).to.be.rejectedWith('DB error');
    });
  });
});
