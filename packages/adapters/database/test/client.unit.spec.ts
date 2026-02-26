/* eslint-disable @typescript-eslint/no-explicit-any */
import { expect } from 'chai';
import { stub, restore } from 'sinon';

import {
  isTriageFingerprintProcessed,
  tryReserveTriageFingerprint,
  finalizeTriageFingerprint,
  setTriageAutoResolveOutcome,
  pruneExpiredTriageFingerprints,
  saveOriginIntents,
  saveDestinationIntents,
  saveSettlementIntents,
  saveHubIntents,
  saveHubDeposits,
  getAllEnqueuedDeposits,
  saveHubInvoices,
  saveMessages,
  saveProtocolUpdateLogs,
  saveHubTokenUpdateLogs,
  saveHubAssetUpdateLogs,
  saveHubMeta,
  saveSpokeMeta,
  saveQueues,
  saveAssets,
  getAssets,
  getHubInvoices,
  getHubInvoicesByIntentIds,
  saveTokens,
  getTokens,
  saveDepositors,
  saveBalances,
  saveCheckPoint,
  getCheckPoint,
  getMessageQueues,
  getMessageQueueContents,
  getAllQueuedSettlements,
  getOriginIntentsByStatus,
  getOriginIntentsById,
  getDestinationIntentsByStatus,
  getHubIntentsByStatus,
  getInvoicesByStatus,
  getMessagesByIntentIds,
  getMessagesByIds,
  getMessagesByStatus,
  updateMessageStatus,
  getExpiredIntents,
  getOpenTransfers,
  getLatestInvoicesByTickerHash,
  getLatestHubInvoicesByTickerHash,
  refreshIntentsView,
  refreshInvoicesView,
  getLatestTimestamp,
  getVotes,
  getTokenomicsEvents,
  getMerkleTrees,
  getLatestMerkleTree,
  saveMerkleTrees,
  saveRewards,
  saveEpochResults,
  getNewLockPositionEvents,
  getLockPositions,
  saveLockPositions,
  saveOrders,
  getOrders,
  getOriginIntentsLastNonce,
  getDeliveredSettlements,
  updateSettlementStatus,
  updateSolanaMessageStatuses,
  getSettledIntentsInEpoch,
} from '../src/client';
import { TriageFingerprintLog } from '../src';

/**
 * Mock pool that mimics pg.Pool for zapatos.
 * Zapatos wraps SELECT in jsonb_agg, selectOne uses to_jsonb,
 * and raw sql/upsert/insert/update use standard pg result format.
 */
const createMockPool = () => ({
  query: stub().callsFake(async (q: any) => {
    const text = typeof q === 'string' ? q : q?.text ?? '';
    // zapatos SELECT: wraps in jsonb_agg, expects single row with result column
    if (text.includes('jsonb_agg')) {
      return { rows: [{ result: [] }], rowCount: 1 };
    }
    // zapatos selectOne: wraps in to_jsonb, expects single row with result column
    if (text.includes('to_jsonb')) {
      return { rows: [], rowCount: 0 };
    }
    return { rows: [], rowCount: 0 };
  }),
});

describe('Database Client (unit)', () => {
  let mockPool: ReturnType<typeof createMockPool>;

  beforeEach(() => {
    mockPool = createMockPool();
  });

  afterEach(() => {
    restore();
  });

  // ---- Triage functions (use pool.query directly) ----

  describe('isTriageFingerprintProcessed', () => {
    it('returns true when rows found', async () => {
      mockPool.query.resolves({ rowCount: 1 });
      const result = await isTriageFingerprintProcessed('fp-1', mockPool as any);
      expect(result).to.be.true;
    });

    it('returns false when no rows found', async () => {
      mockPool.query.resolves({ rowCount: 0 });
      const result = await isTriageFingerprintProcessed('fp-1', mockPool as any);
      expect(result).to.be.false;
    });

    it('returns false when rowCount is null', async () => {
      mockPool.query.resolves({ rowCount: null });
      const result = await isTriageFingerprintProcessed('fp-1', mockPool as any);
      expect(result).to.be.false;
    });
  });

  describe('tryReserveTriageFingerprint', () => {
    const makeLog = (overrides: Partial<TriageFingerprintLog> = {}): TriageFingerprintLog => ({
      fingerprint: 'fp-1',
      reportType: 'test',
      severity: 'high',
      env: 'test',
      network: 'testnet',
      ids: ['id1'],
      reason: 'test reason',
      triageMode: 'auto',
      expiresAt: new Date(),
      ...overrides,
    });

    it('returns true when row inserted', async () => {
      mockPool.query.resolves({ rowCount: 1 });
      const result = await tryReserveTriageFingerprint(makeLog(), mockPool as any);
      expect(result).to.be.true;
    });

    it('returns false on conflict', async () => {
      mockPool.query.resolves({ rowCount: 0 });
      const result = await tryReserveTriageFingerprint(makeLog(), mockPool as any);
      expect(result).to.be.false;
    });

    it('handles optional fields with defaults', async () => {
      mockPool.query.resolves({ rowCount: 1 });
      await tryReserveTriageFingerprint(makeLog({ triageResult: { action: 'alert' } }), mockPool as any);
      const args = mockPool.query.firstCall.args[1];
      expect(args[8]).to.equal('{"action":"alert"}');
      expect(args[9]).to.be.null;
      expect(args[10]).to.be.null;
    });

    it('passes through optional fields when provided', async () => {
      mockPool.query.resolves({ rowCount: 1 });
      await tryReserveTriageFingerprint(
        makeLog({
          triageResult: { x: 1 },
          providerUsed: 'anthropic',
          modelUsed: 'claude',
          triageLatencyMs: 100,
          autoResolveAttempted: true,
          autoResolveSucceeded: true,
          autoResolveReasonCode: 'ok',
          toolCallsMade: 3,
          toolNamesUsed: ['tool1', 'tool2'],
        }),
        mockPool as any,
      );
      const args = mockPool.query.firstCall.args[1];
      expect(args[9]).to.equal('anthropic');
      expect(args[10]).to.equal('claude');
      expect(args[11]).to.equal(100);
      expect(args[12]).to.be.true;
      expect(args[13]).to.be.true;
      expect(args[14]).to.equal('ok');
      expect(args[15]).to.equal(3);
      expect(args[16]).to.deep.equal(['tool1', 'tool2']);
    });
  });

  describe('finalizeTriageFingerprint', () => {
    const makeLog = (overrides: Partial<TriageFingerprintLog> = {}): TriageFingerprintLog => ({
      fingerprint: 'fp-1',
      reportType: 'test',
      severity: 'high',
      env: 'test',
      network: 'testnet',
      ids: ['id1'],
      reason: 'test reason',
      triageMode: 'auto',
      expiresAt: new Date(),
      ...overrides,
    });

    it('calls query with correct parameters', async () => {
      mockPool.query.resolves({ rowCount: 1 });
      await finalizeTriageFingerprint(makeLog(), mockPool as any);
      expect(mockPool.query.calledOnce).to.be.true;
    });

    it('handles optional fields with defaults', async () => {
      mockPool.query.resolves({ rowCount: 1 });
      await finalizeTriageFingerprint(makeLog(), mockPool as any);
      const args = mockPool.query.firstCall.args[1];
      expect(args[1]).to.be.null;
      expect(args[2]).to.be.null;
    });

    it('passes triageResult as JSON when provided', async () => {
      mockPool.query.resolves({ rowCount: 1 });
      await finalizeTriageFingerprint(makeLog({ triageResult: { action: 'resolve' } }), mockPool as any);
      const args = mockPool.query.firstCall.args[1];
      expect(args[1]).to.equal('{"action":"resolve"}');
    });
  });

  describe('setTriageAutoResolveOutcome', () => {
    it('calls query with correct parameters', async () => {
      mockPool.query.resolves({ rowCount: 1 });
      await setTriageAutoResolveOutcome('fp-1', true, 'dispatched', mockPool as any);
      const args = mockPool.query.firstCall.args[1];
      expect(args[0]).to.equal('fp-1');
      expect(args[1]).to.be.true;
      expect(args[2]).to.equal('dispatched');
    });

    it('defaults reasonCode to null', async () => {
      mockPool.query.resolves({ rowCount: 1 });
      await setTriageAutoResolveOutcome('fp-1', false, undefined, mockPool as any);
      const args = mockPool.query.firstCall.args[1];
      expect(args[2]).to.be.null;
    });
  });

  describe('pruneExpiredTriageFingerprints', () => {
    it('returns count of pruned rows', async () => {
      mockPool.query.resolves({ rowCount: 5 });
      const result = await pruneExpiredTriageFingerprints(mockPool as any);
      expect(result).to.equal(5);
    });

    it('returns 0 when rowCount is null', async () => {
      mockPool.query.resolves({ rowCount: null });
      const result = await pruneExpiredTriageFingerprints(mockPool as any);
      expect(result).to.equal(0);
    });
  });

  // ---- Zapatos-based save functions ----

  describe('save functions (zapatos)', () => {
    it('saveOriginIntents completes without error', async () => {
      await saveOriginIntents([], mockPool as any);
    });

    it('saveDestinationIntents completes without error', async () => {
      await saveDestinationIntents([], mockPool as any);
    });

    it('saveSettlementIntents completes without error', async () => {
      await saveSettlementIntents([], mockPool as any);
    });

    it('saveHubIntents completes without error', async () => {
      await saveHubIntents([], ['status'] as any, mockPool as any);
    });

    it('saveHubDeposits completes without error', async () => {
      await saveHubDeposits([], mockPool as any);
    });

    it('saveHubInvoices completes without error', async () => {
      await saveHubInvoices([], mockPool as any);
    });

    it('saveProtocolUpdateLogs completes without error', async () => {
      await saveProtocolUpdateLogs([], mockPool as any);
    });

    it('saveHubTokenUpdateLogs completes without error', async () => {
      await saveHubTokenUpdateLogs([], mockPool as any);
    });

    it('saveHubAssetUpdateLogs completes without error', async () => {
      await saveHubAssetUpdateLogs([], mockPool as any);
    });

    it('saveHubMeta completes without error', async () => {
      await saveHubMeta([], mockPool as any);
    });

    it('saveSpokeMeta completes without error', async () => {
      await saveSpokeMeta([], mockPool as any);
    });

    it('saveQueues completes without error', async () => {
      await saveQueues([], mockPool as any);
    });

    it('saveAssets completes without error', async () => {
      await saveAssets([], mockPool as any);
    });

    it('saveTokens completes without error', async () => {
      await saveTokens([], mockPool as any);
    });

    it('saveDepositors completes without error', async () => {
      await saveDepositors([], mockPool as any);
    });

    it('saveBalances completes without error', async () => {
      await saveBalances([], mockPool as any);
    });

    it('saveCheckPoint completes without error', async () => {
      await saveCheckPoint('test', 100, mockPool as any);
    });

    it('saveOrders completes without error', async () => {
      await saveOrders([], mockPool as any);
    });

    it('saveMerkleTrees completes without error', async () => {
      await saveMerkleTrees([], mockPool as any);
    });

    it('saveRewards completes without error', async () => {
      await saveRewards([], mockPool as any);
    });

    it('saveEpochResults completes without error', async () => {
      await saveEpochResults([], mockPool as any);
    });

    it('saveMessages with updates completes', async () => {
      const originUpdates = [{ id: '1', messageId: 'm1', status: 'DISPATCHED' as any }];
      const destUpdates = [{ id: '2', messageId: 'm2', status: 'DISPATCHED' as any }];
      const hubUpdates = [{ id: '3', messageId: 'm3', status: 'DISPATCHED' as any, settlementDomain: '1337' }];

      await saveMessages([], originUpdates, destUpdates, hubUpdates, mockPool as any);
    });

    it('saveMessages with empty updates completes', async () => {
      await saveMessages([], [], [], [], mockPool as any);
    });
  });

  // ---- Zapatos-based get functions ----

  describe('get functions (zapatos)', () => {
    it('getAssets returns empty array', async () => {
      const result = await getAssets(['0x123'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getHubInvoices returns empty array', async () => {
      const result = await getHubInvoices(['0x123'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getHubInvoicesByIntentIds returns empty array', async () => {
      const result = await getHubInvoicesByIntentIds(['0x123'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getTokens returns empty array', async () => {
      const result = await getTokens(['0x123'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getMessageQueues returns empty array', async () => {
      const result = await getMessageQueues('FILL' as any, ['1337'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getOriginIntentsByStatus returns empty array', async () => {
      const result = await getOriginIntentsByStatus('ADDED' as any, ['1337'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getDestinationIntentsByStatus returns empty array', async () => {
      const result = await getDestinationIntentsByStatus('ADDED' as any, ['1337'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getHubIntentsByStatus returns empty array', async () => {
      const result = await getHubIntentsByStatus('ADDED' as any, ['1337'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getInvoicesByStatus returns empty array', async () => {
      const result = await getInvoicesByStatus('ADDED' as any, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getMessagesByIds returns empty array', async () => {
      const result = await getMessagesByIds(['0x123'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getMessagesByStatus returns empty array', async () => {
      const result = await getMessagesByStatus(['none'] as any, 0, 10, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getOrders returns empty array', async () => {
      const result = await getOrders(['0x123'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getDeliveredSettlements returns empty array', async () => {
      const result = await getDeliveredSettlements('1337', mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getAllEnqueuedDeposits returns empty array', async () => {
      const result = await getAllEnqueuedDeposits(['1337'], mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getOpenTransfers returns empty array', async () => {
      const result = await getOpenTransfers(['1337'], 0, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getNewLockPositionEvents returns empty array', async () => {
      const result = await getNewLockPositionEvents(0, 100, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getMerkleTrees returns empty array', async () => {
      const result = await getMerkleTrees(1000, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getLatestMerkleTree returns empty array', async () => {
      const result = await getLatestMerkleTree('ETH', 1000, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getVotes returns empty array', async () => {
      const result = await getVotes(1, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('getTokenomicsEvents returns empty array', async () => {
      const result = await getTokenomicsEvents('vote_cast', new Date(), 100, mockPool as any);
      expect(result).to.deep.equal([]);
    });
  });

  describe('getCheckPoint', () => {
    it('returns 0 when not found', async () => {
      const result = await getCheckPoint('test', mockPool as any);
      expect(result).to.equal(0);
    });

    it('returns checkpoint value when found', async () => {
      mockPool.query.callsFake(async () => ({ rows: [{ result: { check_point: 42 } }], rowCount: 1 }));
      const result = await getCheckPoint('test', mockPool as any);
      expect(result).to.equal(42);
    });
  });

  describe('getOriginIntentsById', () => {
    it('returns undefined when not found', async () => {
      const result = await getOriginIntentsById('0x123', mockPool as any);
      expect(result).to.be.undefined;
    });
  });

  describe('updateMessageStatus', () => {
    it('completes without error', async () => {
      await updateMessageStatus('msg-1', 'delivered' as any, mockPool as any);
    });
  });

  describe('updateSettlementStatus', () => {
    it('completes without error', async () => {
      await updateSettlementStatus('intent-1', 'SETTLED' as any, mockPool as any);
    });
  });

  describe('refreshIntentsView', () => {
    it('completes without error', async () => {
      await refreshIntentsView(mockPool as any);
    });
  });

  describe('refreshInvoicesView', () => {
    it('completes without error', async () => {
      await refreshInvoicesView(mockPool as any);
    });
  });

  describe('updateSolanaMessageStatuses', () => {
    it('returns count of updated rows', async () => {
      mockPool.query.callsFake(async () => ({ rows: [{ id: '1' }, { id: '2' }], rowCount: 2 }));
      const result = await updateSolanaMessageStatuses(mockPool as any);
      expect(result).to.equal(2);
    });
  });

  describe('getMessagesByIntentIds', () => {
    it('returns empty array', async () => {
      const result = await getMessagesByIntentIds(['0x123'], mockPool as any);
      expect(result).to.deep.equal([]);
    });
  });

  describe('getMessageQueueContents', () => {
    it('handles FILL type', async () => {
      const result = await getMessageQueueContents('FILL' as any, ['1337'], mockPool as any);
      expect(result).to.be.instanceOf(Map);
      expect(result.get('1337')).to.deep.equal([]);
    });

    it('handles SETTLEMENT type', async () => {
      const result = await getMessageQueueContents('SETTLEMENT' as any, ['1337'], mockPool as any);
      expect(result).to.be.instanceOf(Map);
    });

    it('handles INTENT type', async () => {
      const result = await getMessageQueueContents('INTENT' as any, ['1337'], mockPool as any);
      expect(result).to.be.instanceOf(Map);
    });

    it('throws for unsupported type', async () => {
      try {
        await getMessageQueueContents('INVALID' as any, ['1337'], mockPool as any);
        expect.fail('should have thrown');
      } catch (e: any) {
        expect(e.message).to.include('Unsupported message queue type');
      }
    });
  });

  describe('getAllQueuedSettlements', () => {
    it('returns empty map for no results', async () => {
      const result = await getAllQueuedSettlements('6398', mockPool as any);
      expect(result).to.be.instanceOf(Map);
      expect(result.size).to.equal(0);
    });
  });

  describe('getLatestInvoicesByTickerHash', () => {
    it('handles empty status filter', async () => {
      const result = await getLatestInvoicesByTickerHash(['0xabc'], [], 10, mockPool as any);
      expect(result).to.be.instanceOf(Map);
      expect(result.get('0xabc')).to.deep.equal([]);
    });

    it('handles non-empty status filter', async () => {
      const result = await getLatestInvoicesByTickerHash(['0xabc'], ['ADDED' as any], 10, mockPool as any);
      expect(result).to.be.instanceOf(Map);
    });
  });

  describe('getLatestHubInvoicesByTickerHash', () => {
    it('returns map of results', async () => {
      const result = await getLatestHubInvoicesByTickerHash(['0xabc'], 10, mockPool as any);
      expect(result).to.be.instanceOf(Map);
    });
  });

  describe('getLatestTimestamp', () => {
    it('returns epoch 0 when no results', async () => {
      const result = await getLatestTimestamp(['table1'], 'insert_timestamp', mockPool as any);
      expect(result.getTime()).to.equal(0);
    });
  });

  describe('getLockPositions', () => {
    it('returns results with no filters', async () => {
      const result = await getLockPositions(undefined, undefined, undefined, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('applies user filter', async () => {
      const result = await getLockPositions('0xuser', undefined, undefined, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('applies expiryFrom filter', async () => {
      const result = await getLockPositions(undefined, 1000, undefined, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('applies startBefore filter', async () => {
      const result = await getLockPositions(undefined, undefined, 2000, mockPool as any);
      expect(result).to.deep.equal([]);
    });

    it('applies all filters', async () => {
      const result = await getLockPositions('0xuser', 1000, 2000, mockPool as any);
      expect(result).to.deep.equal([]);
    });
  });

  describe('getOriginIntentsLastNonce', () => {
    it('returns 0 when no results', async () => {
      const result = await getOriginIntentsLastNonce('1337', mockPool as any);
      expect(result).to.equal(0);
    });
  });

  describe('getExpiredIntents', () => {
    it('returns empty when no results', async () => {
      const result = await getExpiredIntents('6398', ['1337'], '300', mockPool as any);
      expect(result).to.deep.equal([]);
    });
  });

  describe('getSettledIntentsInEpoch', () => {
    it('returns empty map when no results', async () => {
      const result = await getSettledIntentsInEpoch('1337', 0, 1000, mockPool as any);
      expect(result).to.be.instanceOf(Map);
      expect(result.size).to.equal(0);
    });
  });
});
