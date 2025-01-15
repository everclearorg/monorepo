import { expect, mkBytes32 } from '@chimera-monorepo/utils';
import {
  getDestinationIntentFilledQuery,
  getDestinationIntentsByIdsQuery,
  getHubIntentAddedQuery,
  getOriginIntentAddedQuery,
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
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(',intent_: {destination_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work with empty destinations', () => {
      const ret = getOriginIntentAddedQuery(1, [], 1, 'asc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.not.contain(',intent_: {destination_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without maxBlockNumber', () => {
      const ret = getOriginIntentAddedQuery(1, ['1338', '1339'], undefined, 'asc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(',intent_: {destination_in: [1338,1339]}');
      expect(ret).to.not.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without order direction', () => {
      const ret = getOriginIntentAddedQuery(1, ['1338', '1339'], 1, undefined, 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(',intent_: {destination_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without limit', () => {
      const ret = getOriginIntentAddedQuery(1, ['1338', '1339'], 1, 'desc');
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(',intent_: {destination_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 200');
      expect(ret).to.contain('orderDirection: desc');
    });
  });

  describe('#getSpokeMessagesQuery', () => {
    it('should work with all input', () => {
      const ret = getSpokeMessagesQuery(1, 1, 'desc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain('blockNumber_lte: 1');
      expect(ret).to.contain('orderDirection: desc');
      expect(ret).to.contain('first: 1');
    });

    it('should work without maxBlockNumber', () => {
      const ret = getSpokeMessagesQuery(1, undefined, 'desc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.not.contain('blockNumber_lte: 1');
      expect(ret).to.contain('orderDirection: desc');
      expect(ret).to.contain('first: 1');
    });

    it('should work without orderDirection', () => {
      const ret = getSpokeMessagesQuery(1, 1, undefined, 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain('blockNumber_lte: 1');
      expect(ret).to.contain('orderDirection: asc');
      expect(ret).to.contain('first: 1');
    });

    it('should work without limit', () => {
      const ret = getSpokeMessagesQuery(1, 1, 'desc');
      expect(ret).to.contain('txNonce_gte: 1');
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
      expect(ret).to.contain(`meta(id: "SPOKE_META_ID"){`);
      expect(ret).to.contain(`${SPOKE_META_ENTITY}`);
    });
  });

  describe('getDestinationIntentFilledQuery', () => {
    it('should work with all input', () => {
      const ret = getDestinationIntentFilledQuery(1, ['1338', '1339'], 1, 'desc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(',intent_: {origin_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work with empty origins', () => {
      const ret = getDestinationIntentFilledQuery(1, [], 1, 'desc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.not.contain(',intent_: {origin_in: [1338,1339]}');
      expect(ret).to.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without maxBlockNumber', () => {
      const ret = getDestinationIntentFilledQuery(1, ['1338', '1339'], undefined, 'asc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(',intent_: {origin_in: [1338,1339]}');
      expect(ret).to.not.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without order direction', () => {
      const ret = getDestinationIntentFilledQuery(1, ['1338', '1339'], undefined, undefined, 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(',intent_: {origin_in: [1338,1339]}');
      expect(ret).to.not.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without limit', () => {
      const ret = getDestinationIntentFilledQuery(1, ['1338', '1339']);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(',intent_: {origin_in: [1338,1339]}');
      expect(ret).to.not.contain(', blockNumber_lte: 1');
      expect(ret).to.contain('first: 200');
      expect(ret).to.contain('orderDirection: desc');
    });
  });

  describe('getSettlementMessagesQuery', () => {
    it('should work with all input', () => {
      const ret = getSettlementMessagesQuery(1, 10, 'desc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work with empty blockNumber', () => {
      const ret = getSettlementMessagesQuery(1, undefined, 'desc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.not.contain(', blockNumber_lte:');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without orderDirection', () => {
      const ret = getSettlementMessagesQuery(1, 10, undefined, 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without limit', () => {
      const ret = getSettlementMessagesQuery(1, 10, 'desc');
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 200');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });
  });

  describe('getSettlementMessagesQuery', () => {
    it('should work with all input', () => {
      const ret = getSettlementEnqueuedQuery(1, 10, 'desc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work with empty blockNumber', () => {
      const ret = getSettlementEnqueuedQuery(1, undefined, 'desc', 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.not.contain(', blockNumber_lte:');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without orderDirection', () => {
      const ret = getSettlementEnqueuedQuery(1, 10, undefined, 1);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 1');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work without limit', () => {
      const ret = getSettlementEnqueuedQuery(1, 10, 'desc');
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain(', blockNumber_lte: 10');
      expect(ret).to.contain('first: 200');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });
  });

  describe('getHubIntentAddedQuery', () => {
    it('should work with all input', () => {
      const ret = getHubIntentAddedQuery(1, 2, 'desc', 12);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain('blockNumber_lte: 2');
      expect(ret).to.contain('first: 12');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without maxBlockNumber', async () => {
      const ret = getHubIntentAddedQuery(1, undefined, 'desc', 12);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.not.contain('blockNumber_lte: 2');
      expect(ret).to.contain('first: 12');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: desc');
    });

    it('should work without order direction', () => {
      const ret = getHubIntentAddedQuery(1, 2, undefined, 12);
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain('blockNumber_lte: 2');
      expect(ret).to.contain('first: 12');
      expect(ret).to.contain('orderBy: txNonce');
      expect(ret).to.contain('orderDirection: asc');
    });

    it('should work withought limit', () => {
      const ret = getHubIntentAddedQuery(1, 2, 'desc');
      expect(ret).to.contain('txNonce_gte: 1');
      expect(ret).to.contain('blockNumber_lte: 2');
    });
  });
});
