import { expect, mkBytes32 } from '@chimera-monorepo/utils';
import {
  getDestinationIntentFilledQuery,
  getDestinationIntentsByIdsQuery,
  getHubAssetUpdatesQuery,
  getHubIntentAddedQuery,
  getHubIntentFilledQuery,
  getHubMetaUpdatesQuery,
  getHubTokenUpdatesQuery,
  getInvoiceEnqueuedByIntentId,
  getInvoiceEnqueuedQuery,
  getOrdersByNonce,
  getOriginIntentAddedQuery,
  getSpokeMetaUpdatesQuery,
  getSettlementEnqueuedQuery,
  getSettlementMessagesQuery,
  getSpokeMessagesQuery,
  getSpokeMetaQuery,
} from '../../src/lib/operations/queries';
import { SPOKE_META_ENTITY } from '../../src/lib/operations/entities';

describe('Subgraph Adapter - queries', () => {
  describe('#getOriginIntentAddedQuery', () => {
    it('should work with all input', () => {
      const ret = getOriginIntentAddedQuery(1, ['1338', '1339'], 1, 'asc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(',intent_: {destination_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work with empty destinations', () => {
      const ret = getOriginIntentAddedQuery(1, [], 1, 'asc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.not.contain(',intent_: {destination_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without maxBlockNumber', () => {
      const ret = getOriginIntentAddedQuery(1, ['1338', '1339'], undefined, 'asc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(',intent_: {destination_in: [1338,1339]}');
      expect(ret).to.not.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without order direction', () => {
      const ret = getOriginIntentAddedQuery(1, ['1338', '1339'], 1, undefined, 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(',intent_: {destination_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without limit', () => {
      const ret = getOriginIntentAddedQuery(1, ['1338', '1339'], 1, 'desc');
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(',intent_: {destination_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 200');
      expect(ret).to.contain('orderDirection: desc');
    });
  });

  describe('#getSpokeMessagesQuery', () => {
    it('should work with all input', () => {
      const ret = getSpokeMessagesQuery(1, 1, 'desc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain('blockNumber_lte: 1');
      expect(ret).to.contain('orderDirection: desc');
      expect(ret).to.contain('first: 1');
    });

    it('should work without maxBlockNumber', () => {
      const ret = getSpokeMessagesQuery(1, undefined, 'desc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.not.contain('blockNumber_lte: 1');
      expect(ret).to.contain('orderDirection: desc');
      expect(ret).to.contain('first: 1');
    });

    it('should work without orderDirection', () => {
      const ret = getSpokeMessagesQuery(1, 1, undefined, 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain('blockNumber_lte: 1');
      expect(ret).to.contain('orderDirection: asc');
      expect(ret).to.contain('first: 1');
    });

    it('should work without limit', () => {
      const ret = getSpokeMessagesQuery(1, 1, 'desc');
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain('blockNumber_lte: 1');
      expect(ret).to.contain('orderDirection: desc');
      expect(ret).to.contain('first: 200');
    });
  });

  describe('getDestinationIntentsByIdsQuery', () => {
    it('should work', async () => {
      const ids = ['0x1', '0x2'];
      const ret = getDestinationIntentsByIdsQuery(ids);
      expect(ret).to.contain('id_in: ["0x1","0x2"]');
    });

    it('should work with empty ids', async () => {
      const ret = getDestinationIntentsByIdsQuery([]);
      expect(ret).to.not.contain('id_in: ["0x1","0x2"]');
    });
  });

  describe('getSpokeMetaQuery', () => {
    it('should work', async () => {
      const ret = getSpokeMetaQuery();
      expect(ret).to.contain(`meta(id: "0x53504f4b455f4d4554415f4944"){`);
      expect(ret).to.contain(`${SPOKE_META_ENTITY}`);
    });
  });

  describe('getDestinationIntentFilledQuery', () => {
    it('should work with all input', () => {
      const ret = getDestinationIntentFilledQuery(1, ['1338', '1339'], 1, 'desc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(',intent_: {origin_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work with empty origins', () => {
      const ret = getDestinationIntentFilledQuery(1, [], 1, 'desc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.not.contain(',intent_: {origin_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without maxBlockNumber', () => {
      const ret = getDestinationIntentFilledQuery(1, ['1338', '1339'], undefined, 'asc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(',intent_: {origin_in: [1338,1339]}');
      expect(ret).to.not.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without order direction', () => {
      const ret = getDestinationIntentFilledQuery(1, ['1338', '1339'], undefined, undefined, 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(',intent_: {origin_in: [1338,1339]}');
      expect(ret).to.not.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without limit', () => {
      const ret = getDestinationIntentFilledQuery(1, ['1338', '1339']);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(',intent_: {origin_in: [1338,1339]}');
      expect(ret).to.not.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 200');
      expect(ret).to.contain('orderDirection: desc');
    });
  });

  describe('getSettlementMessagesQuery', () => {
    it('should work with all input', () => {
      const ret = getSettlementMessagesQuery(1, 10, 'desc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work with empty blockNumber', () => {
      const ret = getSettlementMessagesQuery(1, undefined, 'desc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.not.contain(', blockNumber_lte:');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without orderDirection', () => {
      const ret = getSettlementMessagesQuery(1, 10, undefined, 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without limit', () => {
      const ret = getSettlementMessagesQuery(1, 10, 'desc');
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 200');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });
  });

  describe('getSettlementMessagesQuery', () => {
    it('should work with all input', () => {
      const ret = getSettlementEnqueuedQuery(1, 10, 'desc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work with empty blockNumber', () => {
      const ret = getSettlementEnqueuedQuery(1, undefined, 'desc', 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.not.contain(', blockNumber_lte:');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without orderDirection', () => {
      const ret = getSettlementEnqueuedQuery(1, 10, undefined, 1);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without limit', () => {
      const ret = getSettlementEnqueuedQuery(1, 10, 'desc');
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 200');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });
  });

  describe('getHubIntentAddedQuery', () => {
    it('should work with all input', () => {
      const ret = getHubIntentAddedQuery(1, 2, 'desc', 12);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain('blockNumber_lte: 2');
      expect(ret).to.contain('first: 12');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without maxBlockNumber', async () => {
      const ret = getHubIntentAddedQuery(1, undefined, 'desc', 12);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.not.contain('blockNumber_lte: 2');
      expect(ret).to.contain('first: 12');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without order direction', () => {
      const ret = getHubIntentAddedQuery(1, 2, undefined, 12);
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain('blockNumber_lte: 2');
      expect(ret).to.contain('first: 12');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work withought limit', () => {
      const ret = getHubIntentAddedQuery(1, 2, 'desc');
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain('blockNumber_lte: 2');
    });
  });

  describe('getHubIntentFilledQuery', () => {
    it('should include maxBlockNumber when provided', () => {
      const ret = getHubIntentFilledQuery(1, 2, 'desc', 12);
      expect(ret).to.contain('intentFillEvents');
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain('blockNumber_lte: 2');
      expect(ret).to.contain('first: 12');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should omit maxBlockNumber when not provided', () => {
      const ret = getHubIntentFilledQuery(1, undefined, 'asc', 12);
      expect(ret).to.contain('intentFillEvents');
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.not.contain('blockNumber_lte:');
      expect(ret).to.contain('orderDirection: asc');
    });
  });

  describe('hub meta update queries', () => {
    it('getHubMetaUpdatesQuery should work', () => {
      const ret = getHubMetaUpdatesQuery(100, 10, 'desc');
      expect(ret).to.contain('hubMetaUpdates');
      expect(ret).to.contain('blockNumber_gte: 100');
      expect(ret).to.contain('first: 10');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('getSpokeMetaUpdatesQuery should work', () => {
      const ret = getSpokeMetaUpdatesQuery(200, 20, 'asc');
      expect(ret).to.contain('spokeMetaUpdates');
      expect(ret).to.contain('blockNumber_gte: 200');
      expect(ret).to.contain('first: 20');
      expect(ret).to.contain('orderDirection: asc');
    });
  });

  describe('hub asset/token update queries', () => {
    it('getHubTokenUpdatesQuery should work', () => {
      const ret = getHubTokenUpdatesQuery(300);
      expect(ret).to.contain('hubTokenUpdates');
      expect(ret).to.contain('blockNumber_gte: 300');
      expect(ret).to.contain('first: 200');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('getHubAssetUpdatesQuery should work', () => {
      const ret = getHubAssetUpdatesQuery(400, 50, 'desc');
      expect(ret).to.contain('hubAssetUpdates');
      expect(ret).to.contain('blockNumber_gte: 400');
      expect(ret).to.contain('first: 50');
      expect(ret).to.contain('orderDirection: desc');
    });
  });

  describe('invoice queries', () => {
    it('getInvoiceEnqueuedQuery should include maxBlockNumber when provided', () => {
      const ret = getInvoiceEnqueuedQuery(1, 999, 'desc', 5);
      expect(ret).to.contain('invoiceEnqueuedEvents');
      expect(ret).to.contain('txNonce_gt: 1');
      expect(ret).to.contain('blockNumber_lte: 999');
      expect(ret).to.contain('first: 5');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('getInvoiceEnqueuedByIntentId should filter by intent id', () => {
      const intentId = mkBytes32('0xintent');
      const ret = getInvoiceEnqueuedByIntentId(intentId);
      expect(ret).to.contain('invoiceEnqueuedEvents');
      expect(ret).to.contain(`intent_: {id: "${intentId}"}`);
      expect(ret).to.contain('first: 1');
    });
  });

  describe('getOrdersByNonce', () => {
    it('should include maxBlockNumber when provided', () => {
      const ret = getOrdersByNonce(10, 123, 'desc', 7);
      expect(ret).to.contain('orderCreateds');
      expect(ret).to.contain('txNonce_gt: 10');
      expect(ret).to.contain('blockNumber_lte: 123');
      expect(ret).to.contain('first: 7');
      expect(ret).to.contain('orderDirection: desc');
    });
  });
});
