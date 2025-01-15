import { Pool } from 'pg';
import {
  getAssets,
  getBalancesByAccount,
  getCheckPoint,
  getDestinationIntentsByStatus,
  getExpiredIntents,
  getHubIntentsByStatus,
  getMessageQueues,
  getMessagesByIntentIds,
  getOriginIntentsByStatus,
  getTokens,
  getHubInvoices,
  saveAssets,
  saveBalances,
  saveCheckPoint,
  saveDepositors,
  saveDestinationIntents,
  saveHubIntents,
  saveMessages,
  saveOriginIntents,
  saveQueues,
  saveTokens,
  saveHubInvoices,
  refreshIntentsView,
  refreshInvoicesView,
  getAllQueuedSettlements,
  getOpenTransfers,
  getMessageQueueContents,
  getAllEnqueuedDeposits,
  saveHubDeposits,
  getMessagesByStatus,
  updateMessageStatus,
  getLatestInvoicesByTickerHash,
  getLatestHubInvoicesByTickerHash,
  getHubInvoicesByIntentIds,
  getOriginIntentsById,
  saveSettlementIntents,
  getSettlementIntentsByStatus,
  getMessagesByIds,
  getLatestTimestamp,
  getShadowEvents,
  getVotes,
  getTokenomicsEvents,
  saveMerkleTrees,
  getMerkleTrees,
  getLatestMerkleTree,
  getNewLockPositionEvents,
  saveLockPositions,
  getLockPositions,
} from '../src/client';
import {
  expect,
  getNtpTimeSeconds,
  mkAddress,
  mkBytes32,
  TIntentStatus,
  QueueType,
  HyperlaneStatus,
  mkHash,
  ShadowEvent,
  TokenomicsEvent,
  NewLockPositionEvent,
  LockPosition,
} from '@chimera-monorepo/utils';
import {
  createAssets,
  createDestinationIntent,
  createDestinationIntents,
  createHubIntent,
  createHubIntents,
  createIntentMessageUpdate,
  createMessages,
  createOriginIntent,
  createOriginIntents,
  createQueues,
  createTokens,
  createHubInvoices,
  createHubDeposits,
  createSettlementIntents,
  createInvoices,
  createShadowEvent,
  createTokenomicsEvent,
  createMerkleTree,
  createNewLockPositionEvent,
  createLockPosition,
} from './mock';

describe('Database Adapter:Client', () => {
  const defaultDbUri = 'postgres://postgres:qwerty@localhost:5432/everclear';
  let pool: Pool;

  before(async () => {
    pool = new Pool({
      connectionString: process.env.DATABASE_URL || defaultDbUri,
      idleTimeoutMillis: 3000,
      allowExitOnIdle: true,
    });
    await pool.query('CREATE TABLE tokenomics.vote_cast(domain numeric, votes numeric, epoch numeric)');

    await pool.query('CREATE TABLE tokenomics.reward_claimed(block_number numeric, block_timestamp numeric, transaction_hash bytea, insert_timestamp timestamp, latency interval)');
    await pool.query('CREATE TRIGGER reward_claimed_set_timestamp_and_latency BEFORE INSERT ON tokenomics.reward_claimed FOR EACH ROW EXECUTE FUNCTION tokenomics.set_timestamp_and_latency()');
    await pool.query('CREATE INDEX reward_claimed_timestamp_idx ON tokenomics.reward_claimed(insert_timestamp)');

    await pool.query('CREATE TABLE tokenomics.new_lock_position(vid bigint, "user" bytea, new_total_amount_locked numeric, block_timestamp numeric, expiry numeric)');
  });

  after(async () => {
    await pool.query('DROP TABLE tokenomics.vote_cast');
    await pool.query('DROP TABLE tokenomics.reward_claimed');
    await pool.query('DROP TABLE tokenomics.new_lock_position');
    await pool.end();
  });

  afterEach(async () => {
    await pool.query('DELETE FROM balances CASCADE');
    await pool.query('DELETE FROM depositors CASCADE');
    await pool.query('DELETE FROM assets CASCADE');
    await pool.query('DELETE FROM tokens CASCADE');
    await pool.query('DELETE FROM queues CASCADE');
    await pool.query('DELETE FROM messages CASCADE');
    await pool.query('DELETE FROM hub_intents CASCADE');
    await pool.query('DELETE FROM hub_invoices CASCADE');
    await pool.query('DELETE FROM hub_deposits CASCADE');
    await pool.query('DELETE FROM destination_intents CASCADE');
    await pool.query('DELETE FROM origin_intents CASCADE');
    await pool.query('DELETE FROM settlement_intents CASCADE');
    await pool.query('DELETE FROM checkpoints CASCADE');
    await pool.query('DELETE FROM merkle_trees CASCADE');
    await pool.query('DELETE FROM lock_positions CASCADE');
    await pool.query('DELETE FROM shadow.closedepochsprocessed_fa915858_73f6f386 CASCADE');
    await pool.query('DELETE FROM shadow.depositenqueued_2f2b1630_73f6f386 CASCADE');
    await pool.query('REFRESH MATERIALIZED VIEW closedepochsprocessed');
    await pool.query('REFRESH MATERIALIZED VIEW depositenqueued');
  });

  describe('#saveOriginIntents / #getOriginIntents', () => {
    const intents = createOriginIntents(3, [
      { status: 'ADDED', origin: '1337' },
      { status: 'ADDED_AND_FILLED', origin: '1337' },
      { status: 'ADDED', origin: '1339' },
    ]);

    it('should work', async () => {
      expect(await getOriginIntentsByStatus('ADDED', ['1337'], pool)).to.be.deep.eq([]);
      await saveOriginIntents(intents, pool);
      expect(await getOriginIntentsByStatus('ADDED', ['1337'], pool)).to.be.deep.eq([intents[0]]);
      expect(await getOriginIntentsByStatus('ADDED_AND_FILLED', ['1337'], pool)).to.be.deep.eq([intents[1]]);
      expect(await getOriginIntentsByStatus('ADDED', ['1339'], pool)).to.be.deep.eq([intents[2]]);
    });
  });

  describe('#saveDestinationIntents / #getDestinationIntents', () => {
    const intents = createDestinationIntents(3, [
      { status: 'ADDED', destination: '1337' },
      { status: 'ADDED_AND_FILLED', destination: '1337' },
      { status: 'ADDED', destination: '1339' },
    ]);

    it('should work', async () => {
      expect(await getDestinationIntentsByStatus('ADDED', ['1337'], pool)).to.be.deep.eq([]);
      await saveDestinationIntents(intents, pool);
      expect(await getDestinationIntentsByStatus('ADDED', ['1337'], pool)).to.be.deep.eq([intents[0]]);
      expect(await getDestinationIntentsByStatus('ADDED_AND_FILLED', ['1337'], pool)).to.be.deep.eq([intents[1]]);
      expect(await getDestinationIntentsByStatus('ADDED', ['1339'], pool)).to.be.deep.eq([intents[2]]);
    });
  });

  describe('#getMessageQueueContents', () => {
    it('should work for hub intents', async () => {
      const intent = createHubIntent({
        status: TIntentStatus.Settled,
        settlementDomain: '1337',
      });
      await saveHubIntents(
        [intent],
        [
          'settlement_enqueued_timestamp',
          'settlement_enqueued_tx_nonce',
          'status',
          'queue_idx',
          'settlement_domain',
          'settlement_epoch',
        ],
        pool,
      );
      const result = await getMessageQueueContents('SETTLEMENT', ['1337'], pool);
      expect([...result.entries()]).to.be.deep.eq([
        ...new Map([intent].map((i) => [i.settlementDomain, [i]])).entries(),
      ]);
    });

    it('should work for origin intents', async () => {
      const intent = createOriginIntent({
        status: TIntentStatus.Added,
        origin: '1337',
      });
      await saveOriginIntents([intent], pool);
      const result = await getMessageQueueContents('INTENT', ['1337'], pool);
      expect([...result.entries()]).to.be.deep.eq([...new Map([intent].map((i) => [i.origin, [i]])).entries()]);
    });

    it('should work for destination intents', async () => {
      const intent = createDestinationIntent({
        status: TIntentStatus.Added,
        destination: '1338',
      });
      await saveDestinationIntents([intent], pool);
      const result = await getMessageQueueContents(QueueType.Fill, ['1338'], pool);
      expect([...result.entries()]).to.be.deep.eq([...new Map([intent].map((i) => [i.destination, [i]])).entries()]);
    });
  });

  describe('#saveHubIntents / #getHubIntents', () => {
    const intents = createHubIntents(3, [
      { status: 'ADDED', domain: '1337' },
      { status: 'ADDED_AND_FILLED', domain: '1337' },
      { status: 'ADDED', domain: '1339' },
    ]);
    const updateColumns = ['message_id'];

    it('should work', async () => {
      expect(await getHubIntentsByStatus('ADDED', ['1337'], pool)).to.be.deep.eq([]);
      await saveHubIntents(intents, updateColumns, pool);
      expect(await getHubIntentsByStatus('ADDED', ['1337'], pool)).to.be.deep.eq([intents[0]]);
      expect(await getHubIntentsByStatus('ADDED_AND_FILLED', ['1337'], pool)).to.be.deep.eq([intents[1]]);
      expect(await getHubIntentsByStatus('ADDED', ['1339'], pool)).to.be.deep.eq([intents[2]]);
    });
  });

  describe('#saveSettlementIntents', () => {
    const intents = createSettlementIntents(3, [
      { status: 'SETTLED', domain: '1337' },
      { status: 'SETTLED', domain: '1338' },
      { status: 'SETTLED_AND_MANUALLY_EXECUTED', domain: '1339' },
    ]);

    it('should work', async () => {
      expect(await getSettlementIntentsByStatus('SETTLED', pool)).to.be.deep.eq([]);
      await saveSettlementIntents(intents, pool);
      expect(await getSettlementIntentsByStatus('SETTLED', pool)).to.be.deep.eq([intents[0], intents[1]]);
      expect(await getSettlementIntentsByStatus('SETTLED_AND_MANUALLY_EXECUTED', pool)).to.be.deep.eq([intents[2]]);
    });
  });

  describe('#saveHubDeposits / #getAllEnqueuedDeposits', () => {
    const deposits = createHubDeposits(3, [{ domain: '1337' }, { domain: '1338' }, { domain: '1339' }]);

    it('should work', async () => {
      expect(await getAllEnqueuedDeposits(['1337'], pool)).to.be.deep.eq([]);
      await saveHubDeposits(deposits, pool);
      expect(await getAllEnqueuedDeposits(['1337'], pool)).to.be.deep.eq([deposits[0]]);
      expect(await getAllEnqueuedDeposits(['1338'], pool)).to.be.deep.eq([deposits[1]]);
      expect(await getAllEnqueuedDeposits(['1339'], pool)).to.be.deep.eq([deposits[2]]);
    });
  });

  describe('#saveMessages / #getMessages', () => {
    const updates = Array(3)
      .fill(0)
      .map((_, i) =>
        createIntentMessageUpdate({ id: mkBytes32(`0x${i + 1}${i + 1}${i + 1}`), messageId: mkBytes32(`0x${i + 1}`) }),
      );

    const [originUpdate, destinationUpdate, hubUpdate] = updates;
    const messages = createMessages(
      updates.length,
      updates.map((update) => ({ id: update.messageId, intentIds: [update.id] })),
    );
    const hubIntent = createHubIntent({ id: hubUpdate.id, messageId: hubUpdate.messageId, status: hubUpdate.status });

    it('should work', async () => {
      const updateColumns = ['message_id'];
      await saveHubIntents([hubIntent], updateColumns, pool);
      expect(
        await getMessagesByIntentIds(
          updates.map((update) => update.id),
          pool,
        ),
      ).to.be.deep.eq([]);
      await saveMessages(
        messages,
        [originUpdate],
        [destinationUpdate],
        [{ ...hubUpdate, settlementDomain: '1337' }],
        pool,
      );
      expect(
        await getMessagesByIntentIds(
          updates.map((update) => update.id),
          pool,
        ),
      ).to.be.deep.eq(messages);
      expect(await getHubIntentsByStatus(hubUpdate.status, [hubIntent.domain], pool)).to.containSubset([
        {
          settlementDomain: '1337',
          messageId: hubUpdate.messageId,
        },
      ]);
      expect(
        await getMessagesByIds(
          messages.map((m) => m.id),
          pool,
        ),
      ).to.be.deep.eq(messages);
    });
  });

  describe('#saveQueues / #getSettlementQueues / #getIntentQueues', () => {
    const [settlement, intent] = createQueues(2, [{ type: 'SETTLEMENT' }, { type: 'INTENT' }]);
    it('should work', async () => {
      expect(await getMessageQueues(intent.type, [intent.domain], pool)).to.be.deep.eq([]);
      expect(await getMessageQueues(settlement.type, [settlement.domain], pool)).to.be.deep.eq([]);

      await saveQueues([settlement, intent], pool);
      expect(await getMessageQueues(intent.type, [intent.domain], pool)).to.be.deep.eq([intent]);
      expect(await getMessageQueues(settlement.type, [settlement.domain], pool)).to.be.deep.eq([settlement]);
    });
  });

  describe('#getAllQueuedSettlements', () => {
    const hubIntent = createHubIntent({ status: 'DISPATCHED' });
    const originIntent = createOriginIntent({ id: hubIntent.id, status: 'DISPATCHED' });

    it('should work', async () => {
      expect(await getAllQueuedSettlements(hubIntent.domain, pool)).to.be.deep.eq(new Map());
      await saveHubIntents([hubIntent], [], pool);
      await saveOriginIntents([originIntent], pool);
      const result = await getAllQueuedSettlements(hubIntent.domain, pool);
      expect(result).to.be.deep.eq(new Map());
    });
  });

  describe('#getOriginIntentsById', () => {
    const originIntent = createOriginIntent({ status: 'DISPATCHED' });

    it('should work', async () => {
      expect(await getOriginIntentsById(originIntent.id, pool)).to.be.eq(undefined);
      await saveOriginIntents([originIntent], pool);
      expect(await getOriginIntentsById(originIntent.id, pool)).to.be.deep.eq(originIntent);
    });
  });

  describe('#getOpenTransfers', () => {
    const intent = createOriginIntent();

    it('should work', async () => {
      await saveOriginIntents([intent], pool);
      const [result] = await getOpenTransfers([intent.origin], 0, pool);
      expect(result).to.deep.eq(intent);
    });
  });

  describe('#saveBalances / #saveDepositors / #getBalancesByAccount', () => {
    const account = mkAddress('0x123');
    const balances = new Array(2).fill(0).map((_, i) => ({
      id: mkBytes32(`0x${i + 1}${i + 1}${i + 1}`),
      account,
      asset: mkAddress(`0x${i + 1}`),
      amount: `${i + 1}00000000`,
    }));

    it('should fail if depositors dont exist', async () => {
      try {
        await saveBalances(balances, pool);
        expect(false).to.be.true;
      } catch (e) {
        expect(e).to.exist;
      }
    });

    it('should work', async () => {
      expect(await getBalancesByAccount(account, pool)).to.be.deep.eq([]);
      await saveDepositors([{ id: account }], pool);
      await saveBalances(balances, pool);
      expect(await getBalancesByAccount(account, pool)).to.be.deep.eq(balances);
    });
  });

  describe('#saveCheckPoint / #getCheckPoint', () => {
    const checkpoint = 'test';
    const value = 100;
    it('should handle null case', async () => {
      expect(await getCheckPoint(checkpoint, pool)).to.be.eq(0);
    });

    it('should work', async () => {
      await saveCheckPoint(checkpoint, value, pool);
      expect(await getCheckPoint(checkpoint, pool)).to.be.eq(value);
    });
  });

  describe('#saveAssets', () => {
    const assets = createAssets(2);

    it('should work', async () => {
      expect(
        await getAssets(
          assets.map((a) => a.token),
          pool,
        ),
      ).to.be.deep.eq([]);
      await saveAssets(assets, pool);
      expect(
        await getAssets(
          assets.map((a) => a.token),
          pool,
        ),
      ).to.be.deep.eq(assets);
    });
  });

  describe('#saveHubInvoices / #getHubInvoices', () => {
    const invoices = createHubInvoices(2);

    it('should work with empty table', async () => {
      expect(
        await getHubInvoices(
          invoices.map((a) => a.id),
          pool,
        ),
      ).to.be.deep.eq([]);
    });

    it('should work with valid data', async () => {
      await saveHubInvoices(invoices, pool);
      expect(
        await getHubInvoices(
          invoices.map((a) => a.id),
          pool,
        ),
      ).to.be.deep.eq(invoices);
      expect(
        await getHubInvoicesByIntentIds(
          invoices.map((a) => a.intentId),
          pool,
        ),
      ).to.be.deep.eq(invoices);
    });
  });

  describe('#getLatestInvoicesByTickerHash', () => {
    const ticker1 = mkHash('0x123');
    const ticker2 = mkHash('0x456');
    const hubInvoices = createHubInvoices(4, [
      { tickerHash: ticker1, intentId: mkHash('0x1'), enqueuedTxNonce: 1 },
      { tickerHash: ticker2, intentId: mkHash('0x2'), enqueuedTxNonce: 2 },
      { tickerHash: ticker1, intentId: mkHash('0x3'), enqueuedTxNonce: 3 },
      { tickerHash: ticker2, intentId: mkHash('0x4'), enqueuedTxNonce: 4 },
    ]);
    const originIntents = createOriginIntents(4, [
      { status: 'ADDED', origin: '1337' },
      { status: 'ADDED_AND_FILLED', origin: '1337' },
      { status: 'ADDED', origin: '1339' },
      { status: 'ADDED', origin: '1339' },
    ]);
    const hubIntents = createHubIntents(4, [
      { status: 'ADDED', domain: '1337' },
      { status: 'ADDED_AND_FILLED', domain: '1337' },
      { status: 'ADDED', domain: '1339' },
      { status: 'ADDED', domain: '1339' },
    ]);

    const invoices = createInvoices(4,
      [...Array(4).keys()].map(i => ({
        id: hubInvoices[i].id,
        originIntent: originIntents[i],
        hubInvoiceAmount: hubInvoices[i].amount,
        hubInvoiceEnqueuedTimestamp: hubInvoices[i].enqueuedTimestamp,
        hubInvoiceEnqueuedTxNonce: hubInvoices[i].enqueuedTxNonce,
        hubInvoiceTickerHash: hubInvoices[i].tickerHash,
        hubInvoiceEntryEpoch: hubInvoices[i].entryEpoch,
        hubInvoiceId: hubInvoices[i].id,
        hubInvoiceIntentId: hubInvoices[i].intentId,
        hubInvoiceOwner: hubInvoices[i].owner,
        hubStatus: hubIntents[i].status,
        hubSettlementEpoch: hubIntents[i].settlementEpoch,
      }))
    );

    beforeEach(async () => {
      await saveHubInvoices(hubInvoices, pool);
      await saveOriginIntents(originIntents, pool);
      await saveHubIntents(hubIntents, [
        'settlement_enqueued_timestamp',
        'settlement_enqueued_tx_nonce',
        'status',
        'queue_idx',
        'settlement_domain',
        'settlement_epoch',
      ], pool);
      await refreshInvoicesView(pool);
    });

    it('should work', async () => {
      const ret = await getLatestInvoicesByTickerHash([ticker1, ticker2], [], 10, pool);
      expect(ret.size).to.be.eq(2);
      expect(ret.get(ticker1)?.sort((a, b) => a.id.localeCompare(b.id))).to.be.deep.eq(
        invoices.filter((i) => i.hubInvoiceTickerHash === ticker1).sort((a, b) => a.id.localeCompare(b.id)),
      );
      expect(ret.get(ticker2)?.sort((a, b) => a.id.localeCompare(b.id))).to.be.deep.eq(
        invoices.filter((i) => i.hubInvoiceTickerHash === ticker2).sort((a, b) => a.id.localeCompare(b.id)),
      );
    })

    it('should be able to filter via status', async () => {
      const ret = await getLatestInvoicesByTickerHash([ticker1, ticker2], ['ADDED'], 10, pool);
      expect(ret.size).to.be.eq(2);
      expect(ret.get(ticker1)?.length).to.be.eq(2);
      expect(ret.get(ticker2)?.length).to.be.eq(1);
      expect(ret.get(ticker1)?.sort((a, b) => a.id.localeCompare(b.id))).to.be.deep.eq(
        invoices.filter((i) => i.hubInvoiceTickerHash === ticker1 && i.hubStatus == 'ADDED').sort((a, b) => a.id.localeCompare(b.id)),
      );
      expect(ret.get(ticker2)?.sort((a, b) => a.id.localeCompare(b.id))).to.be.deep.eq(
        invoices.filter((i) => i.hubInvoiceTickerHash === ticker2 && i.hubStatus == 'ADDED').sort((a, b) => a.id.localeCompare(b.id)),
      );
    });

    it('should respect the limit', async () => {
      const ret = await getLatestInvoicesByTickerHash([ticker1, ticker2], [], 1, pool);
      expect(ret.size).to.be.eq(2);
      expect(ret.get(ticker1)).to.be.deep.eq([invoices[2]]);
      expect(ret.get(ticker2)).to.be.deep.eq([invoices[3]]);
    });
  });

  describe('#getLatestHubInvoicesByTickerHash', () => {
    const ticker1 = mkHash('0x123');
    const ticker2 = mkHash('0x456');
    const invoices = createHubInvoices(4, [
      { tickerHash: ticker1, id: mkHash('0x1'), enqueuedTxNonce: 1 },
      { tickerHash: ticker2, id: mkHash('0x2'), enqueuedTxNonce: 2 },
      { tickerHash: ticker1, id: mkHash('0x3'), enqueuedTxNonce: 3 },
      { tickerHash: ticker2, id: mkHash('0x4'), enqueuedTxNonce: 4 },
    ]);

    beforeEach(async () => {
      await saveHubInvoices(invoices, pool);
    });

    it('should work', async () => {
      const ret = await getLatestHubInvoicesByTickerHash([ticker1, ticker2], 10, pool);
      expect(ret.size).to.be.eq(2);
      expect(ret.get(ticker1)?.sort((a, b) => a.id.localeCompare(b.id))).to.be.deep.eq(
        invoices.filter((i) => i.tickerHash === ticker1).sort((a, b) => a.id.localeCompare(b.id)),
      );
      expect(ret.get(ticker2)?.sort((a, b) => a.id.localeCompare(b.id))).to.be.deep.eq(
        invoices.filter((i) => i.tickerHash === ticker2).sort((a, b) => a.id.localeCompare(b.id)),
      );
    });

    it('should respect the limit', async () => {
      const ret = await getLatestHubInvoicesByTickerHash([ticker1, ticker2], 1, pool);
      expect(ret.size).to.be.eq(2);
      expect(ret.get(ticker1)).to.be.deep.eq([invoices[2]]);
      expect(ret.get(ticker2)).to.be.deep.eq([invoices[3]]);
    });
  });

  describe('#saveTokens / #getTokens', () => {
    const tokens = createTokens(2);

    it('should work', async () => {
      expect(
        await getTokens(
          tokens.map((a) => a.id),
          pool,
        ),
      ).to.be.deep.eq([]);
      await saveTokens(tokens, pool);
      expect(
        await getTokens(
          tokens.map((a) => a.id),
          pool,
        ),
      ).to.be.deep.eq(tokens);
    });
  });

  describe('#getExpiredIntents', () => {
    const expiryBuffer = 500;

    it('should work', async () => {
      await refreshIntentsView(pool);
      expect(await getExpiredIntents('1339', ['1337', '1338'], expiryBuffer.toString(), pool)).to.be.deep.eq([]);

      const originIntent = createOriginIntent({
        status: 'DISPATCHED',
        origin: '1337',
        ttl: 1,
        timestamp: getNtpTimeSeconds() - expiryBuffer * 10,
      });
      const hub = createHubIntent({
        ...originIntent,
        status: 'DEPOSIT_PROCESSED',
        settlementEnqueuedTimestamp: 1231232,
        domain: '1339',
      });

      await saveHubIntents([hub], ['status', 'domain'], pool);
      await saveOriginIntents([originIntent], pool);

      await refreshIntentsView(pool);

      const ret = await getExpiredIntents('1339', ['1337', '1338'], expiryBuffer.toString(), pool);
      expect(ret.length).to.be.eq(1);
      expect(ret).to.be.deep.eq([originIntent]);
    });
  });

  describe('#refreshIntentsView', () => {
    it('should work', async () => {
      expect(await refreshIntentsView(pool)).to.not.throw;
    });
  });

  describe('#refreshInvoicesView', () => {
    it('should refresh the invoices view without errors', async () => {
      expect(await refreshInvoicesView(pool)).to.not.throw;
    });
  });

  describe('#getMessagesByIntentIds', () => {
    const updates = Array(3)
      .fill(0)
      .map((_, i) =>
        createIntentMessageUpdate({ id: mkBytes32(`0x${i + 1}${i + 1}${i + 1}`), messageId: mkBytes32(`0x${i + 1}`) }),
      );
    const messages = createMessages(
      updates.length,
      updates.map((update) => ({ id: update.messageId, intentIds: [update.id] })),
    );

    it('should retrieve messages by intentIds', async () => {
      await saveMessages(messages, [updates[0]], [], [], pool);
      const result = await getMessagesByIntentIds([updates[0].id], pool);
      expect(result).to.deep.eq([messages[0]]);
    });

    it('should return empty array for non-existent intentIds', async () => {
      const result = await getMessagesByIntentIds([mkBytes32('0xnothinghere')], pool);
      expect(result).to.deep.eq([]);
    });
  });

  describe('#getMessagesByStatus', () => {
    const updates = Array(3)
      .fill(0)
      .map((_, i) =>
        createIntentMessageUpdate({ id: mkBytes32(`0x${i + 1}${i + 1}${i + 1}`), messageId: mkBytes32(`0x${i + 1}`) }),
      );
    const messages = createMessages(
      updates.length,
      updates.map((update) => ({ id: update.messageId, intentIds: [update.id] })),
    );
    it('happy case', async () => {
      await saveMessages(messages, [updates[0]], [], [], pool);
      const result = await getMessagesByStatus([HyperlaneStatus.none], 0, 100, pool);
      expect(result.length).to.be.eq(3);
    });
  });

  describe('#updateMessageStatus', () => {
    const updates = Array(3)
      .fill(0)
      .map((_, i) =>
        createIntentMessageUpdate({ id: mkBytes32(`0x${i + 1}${i + 1}${i + 1}`), messageId: mkBytes32(`0x${i + 1}`) }),
      );
    const messages = createMessages(
      updates.length,
      updates.map((update) => ({ id: update.messageId, intentIds: [update.id] })),
    );
    it('happy case', async () => {
      await saveMessages(messages, [updates[0]], [], [], pool);
      await updateMessageStatus(messages[0].id, HyperlaneStatus.delivered, pool);
      const deliveredMsgs = await getMessagesByStatus([HyperlaneStatus.delivered], 0, 100, pool);
      expect(deliveredMsgs.length).to.be.eq(1);
      expect(deliveredMsgs[0].id).to.be.eq(messages[0].id);
      const noneMsgs = await getMessagesByStatus([HyperlaneStatus.none], 0, 100, pool);
      expect(noneMsgs.length).to.be.eq(2);
    });
  });

  const saveShadowEvent = async (event: ShadowEvent, table: string) => {
    await pool.query(`INSERT INTO shadow.${table}
      (address, block_hash, block_number, block_timestamp, chain, network, topic_0, transaction_hash, transaction_index, transaction_log_index)
      VALUES ('${event.address}', '${event.blockHash}', ${event.blockNumber}, '${event.blockTimestamp.toUTCString()}', '${event.chain}', '${event.network}',
              '${event.topic0}', '${event.transactionHash}', ${event.transactionIndex}, ${event.transactionLogIndex})`);
  };

  describe('#getLatestTimestamp', () => {
    it('should work', async () => {
      const event = createShadowEvent();
      await saveShadowEvent(event, 'depositenqueued_2f2b1630_73f6f386');
      event.transactionHash = mkBytes32('0x2');
      await saveShadowEvent(event, 'depositenqueued_2f2b1630_73f6f386');
      event.transactionHash = mkBytes32('0x3');
      await saveShadowEvent(event, 'depositenqueued_2f2b1630_73f6f386');
      event.transactionHash = mkBytes32('0x4');
      await saveShadowEvent(event, 'closedepochsprocessed_fa915858_73f6f386');
      await pool.query('REFRESH MATERIALIZED VIEW closedepochsprocessed');
      await pool.query('REFRESH MATERIALIZED VIEW depositenqueued');

      const result = await pool.query('SELECT timestamp FROM closedepochsprocessed');
      const expectedTimestamp = result.rows[0].timestamp;

      const tables = [
        'closedepochsprocessed',
        'depositenqueued',
        'depositprocessed',
        'finddepositdomain',
        'findinvoicedomain',
        'invoiceenqueued',
        'matchdeposit',
        'settledeposit',
        'settlementenqueued',
        'settlementqueueprocessed',
        'settlementsent'
      ];

      expect((await getLatestTimestamp(tables, 'timestamp', pool)).getTime()).to.be.eq(expectedTimestamp.getTime());
    });
  });

  const sleep = async (ms: number) => {
    return new Promise(resolve => setTimeout(resolve, ms));
  };

  describe('#getShadowEvents', () => {
    it('respects timestamp and limit', async () => {
      const event = createShadowEvent();
      await saveShadowEvent(event, 'closedepochsprocessed_fa915858_73f6f386');
      event.transactionHash = mkBytes32('0x2');
      await saveShadowEvent(event, 'closedepochsprocessed_fa915858_73f6f386');

      await sleep(100);
      const from = new Date();

      event.transactionHash = mkBytes32('0x3');
      await saveShadowEvent(event, 'closedepochsprocessed_fa915858_73f6f386');
      event.transactionHash = mkBytes32('0x4');
      await saveShadowEvent(event, 'closedepochsprocessed_fa915858_73f6f386');
      event.transactionHash = mkBytes32('0x5');
      event.blockTimestamp = new Date(Date.parse('2004-10-24 10:23:54.1111'));
      await saveShadowEvent(event, 'closedepochsprocessed_fa915858_73f6f386');

      await pool.query('REFRESH MATERIALIZED VIEW closedepochsprocessed');

      const events = await getShadowEvents('closedepochsprocessed', from, 2, pool);

      expect(events.length).to.be.eq(2);
      expect(events[0].transactionHash).to.be.eq(mkBytes32('0x3'));
      expect(events[1].transactionHash).to.be.eq(mkBytes32('0x4'));
    });
  });

  describe('#getVotes', () => {
    it('no data', async () => {
      const votes = await getVotes(1, pool);

      expect(votes).to.be.empty;
    });

    it('happy case', async () => {
      const saveVotes = async (domain: number, epoch: number, votes: number) => {
        await pool.query(`INSERT INTO tokenomics.vote_cast (domain, epoch, votes) VALUES (${domain}, ${epoch}, ${votes})`);
      };
      await saveVotes(10, 1, 1234);
      await saveVotes(10, 2, 2345);
      await saveVotes(10, 1, 3456);
      await saveVotes(421614, 1, 4567);
      await saveVotes(421614, 2, 5678);
      await saveVotes(421614, 1, 6789);
      await saveVotes(421614, 1, 7890);

      const votes = await getVotes(1, pool);

      expect(votes).to.be.deep.eq([
        { domain: 10, votes: "4690" },
        { domain: 421614, votes: "19246" },
      ]);
    });
  });

  const saveTokenomicsEvent = async (event: TokenomicsEvent, table: string) => {
    await pool.query({
      text: `INSERT INTO tokenomics.${table} (block_number, block_timestamp, transaction_hash) VALUES ($1, $2, $3)`,
      values: [ event.blockNumber, event.blockTimestamp, Buffer.from(event.transactionHash.slice(2), 'hex') ],
  });
  };

  describe('#getTokenomicsEvents', () => {
    it('respects timestamp and limit', async () => {
      const event = createTokenomicsEvent();
      await saveTokenomicsEvent(event, 'reward_claimed');
      event.transactionHash = mkBytes32('0x2');
      await saveTokenomicsEvent(event, 'reward_claimed');

      await sleep(100);
      const from = new Date();

      event.transactionHash = mkBytes32('0x3');
      await saveTokenomicsEvent(event, 'reward_claimed');
      event.transactionHash = mkBytes32('0x4');
      await saveTokenomicsEvent(event, 'reward_claimed');
      event.transactionHash = mkBytes32('0x5');
      event.blockTimestamp = Date.now() / 1000 - 5000;
      await saveTokenomicsEvent(event, 'reward_claimed');

      const events = await getTokenomicsEvents('reward_claimed', from, 2, pool);

      expect(events.length).to.be.eq(2);
      expect(events[0].transactionHash).to.be.eq(mkBytes32('0x3'));
      expect(events[1].transactionHash).to.be.eq(mkBytes32('0x4'));
    });
  });

  describe('#saveMerkleTrees / #getMerkleTrees', () => {
    const timestamp = 1000000000;
    const tree = createMerkleTree({
      epochEndTimestamp: new Date(timestamp * 1000),
    });

    it('should work', async () => {
      await saveMerkleTrees([tree], pool);
      expect(
        await getMerkleTrees(
          timestamp,
          pool,
        ),
      ).to.be.deep.eq([tree]);
    });
  })

  describe('#saveMerkleTrees / #getLatestMerkleTree', () => {
    const timestamp = 1000000000;
    const asset = mkAddress('0xa');
    const tree1 = createMerkleTree({
      asset,
      epochEndTimestamp: new Date(timestamp * 1000),
      root: mkBytes32('0x1'),
    });
    const tree2 = createMerkleTree({
      asset,
      epochEndTimestamp: new Date(2 * timestamp * 1000),
      root: mkBytes32('0x2'),
    });
    const tree3 = createMerkleTree({
      asset: mkAddress('0xb'),
      epochEndTimestamp: new Date(2 * timestamp * 1000),
      root: mkBytes32('0x3'),
    });

    it('should work', async () => {
      await saveMerkleTrees([tree1, tree2, tree3], pool);
      expect(
        await getLatestMerkleTree(
          asset,
          timestamp * 1000,
          pool,
        ),
      ).to.be.deep.eq([tree2]);
    });

    it('respects epoch end timestamp', async () => {
      await saveMerkleTrees([tree1, tree2, tree3], pool);
      expect(
        await getLatestMerkleTree(
          asset,
          2 * timestamp * 1000,
          pool,
        ),
      ).to.be.empty;
    });
  })

  describe('#getNewLockPositionEvents', () => {
    const saveNewLockPositionEvent = async (event: NewLockPositionEvent) => {
      const user = '\\x000000000000000000000000' + event.user.slice(2)
      await pool.query(`INSERT INTO tokenomics.new_lock_position
        (vid, "user", new_total_amount_locked, block_timestamp, expiry)
        VALUES ('${event.vid}', '${user}', '${event.newTotalAmountLocked}', '${event.blockTimestamp}', '${event.expiry}')`);
    };
    const saveNewLockPositionEvents = async (count: number) => {
      let events: NewLockPositionEvent[] = [];
      for (let i = 0; i < count; ++i) {
        const event = createNewLockPositionEvent({ vid: i, user: mkAddress(`0x${i}`) });
        await saveNewLockPositionEvent(event);
        events.push(event);
      }

      return events;
    };
    it('respects checkpoint and limit', async () => {
      const events = await saveNewLockPositionEvents(10);
      const from = 4;
      const limit = 3;
      let expectedEvents: NewLockPositionEvent[] = [];
      for (let i = from + 1; i < from + 1 + limit; ++i)
        expectedEvents.push(events[i]);

      const actualEvents = await getNewLockPositionEvents(from, limit, pool);

      expect(actualEvents).to.be.deep.eq(expectedEvents);
    });
    it('should work with large exp representation', async () => {
      const event = createNewLockPositionEvent({ vid: 21, user: mkAddress(`0x1`), newTotalAmountLocked: '4500000000000000000000000' });
      await saveNewLockPositionEvent(event);

      const actualEvents = await getNewLockPositionEvents(20, 1, pool);
      expect(actualEvents.length).to.be.eq(1);
      expect(actualEvents[0]).to.be.deep.eq(event);
    })
  });

  describe('#saveLockPositions / #getLockPositions', () => {
    it('should work', async () => {
      let lockPositions: LockPosition[] = [];
      for (let i = 1; i <= 5; ++i)
        lockPositions.push(createLockPosition({
          user: mkAddress(`0x${i % 2 + 1}`),
          amountLocked: i.toString(),
          start: i,
          expiry: i * 10,
        }));

      await saveLockPositions('lock_position_test', 1, lockPositions, pool);
      expect(await getLockPositions(undefined, undefined, undefined, pool)).to.be.deep.eq(lockPositions);
      expect(await getLockPositions(undefined, lockPositions[1].expiry, undefined, pool)).to.be.deep.eq([ lockPositions[2], lockPositions[3], lockPositions[4] ]);
      expect(await getLockPositions(mkAddress(`0x1`), undefined, undefined, pool)).to.be.deep.eq([ lockPositions[1], lockPositions[3] ]);
      expect(await getLockPositions(mkAddress(`0x1`), lockPositions[2].expiry, undefined, pool)).to.be.deep.eq([ lockPositions[3] ]);
      expect(await getLockPositions(mkAddress(`0x2`), undefined, undefined, pool)).to.be.deep.eq([ lockPositions[0], lockPositions[2], lockPositions[4] ]);
      expect(await getLockPositions(mkAddress(`0x2`), lockPositions[1].expiry, undefined, pool)).to.be.deep.eq([ lockPositions[2], lockPositions[4] ]);
      expect(await getLockPositions(undefined, lockPositions[1].expiry, lockPositions[2].start, pool)).to.be.deep.eq([]);
      expect(await getLockPositions(undefined, lockPositions[1].expiry, lockPositions[3].start, pool)).to.be.deep.eq([ lockPositions[2] ]);


      lockPositions[0].amountLocked = '0';
      lockPositions[1].amountLocked = '0';

      await saveLockPositions('lock_position_test', 2, lockPositions, pool);
      expect(await getLockPositions(undefined, undefined, undefined, pool)).to.be.deep.eq(lockPositions.slice(2));
    });
  });
});
