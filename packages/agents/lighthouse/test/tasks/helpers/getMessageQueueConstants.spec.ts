import { expect } from 'chai';
import { getQueueMethodName, getTypeHash } from './../../../src/tasks/helpers';
import { UnknownQueueType } from '../../../src/errors';

describe('getSpokeQueueConstants', () => {
  describe('getQueueMethodName', () => {
    it('should return correct method name for INTENT type', () => {
      const result = getQueueMethodName('INTENT');
      expect(result).to.equal('processIntentQueueViaRelayer');
    });

    it('should return correct method name for FILL type', () => {
      const result = getQueueMethodName('FILL');
      expect(result).to.equal('processFillQueueViaRelayer');
    });

    it('should return correct method name for SETTLEMENT type', () => {
      const result = getQueueMethodName('SETTLEMENT');
      expect(result).to.equal('processSettlementQueueViaRelayer');
    });

    it('should throw UnknownQueueType for unknown types', () => {
      expect(() => getQueueMethodName('UNKNOWN' as any)).to.throw(UnknownQueueType);
    });
  });

  describe('getTypeHash', () => {
    it('should return correct type hash for INTENT', () => {
      const result = getTypeHash('INTENT');
      expect(result).to.equal('0xf3f51acca0066ef7defe3ea640de2b9e07d96fade5fb959604a014440ab3d7cc');
    });

    it('should return correct type hash for FILL', () => {
      const result = getTypeHash('FILL');
      expect(result).to.equal('0xce1faaeef1bc26cbe90f4e1a23cfed5940bbac04f28982812ae07a8d0ad23c39');
    });

    it('should return correct type hash for SETTLEMENT', () => {
      const result = getTypeHash('SETTLEMENT');
      expect(result).to.equal('0x9ee676d393dd5facc07ae4ba72101da49596c33d1358807aba1cc4687c098eb9');
    });

    it('should throw UnknownQueueType for unknown types', () => {
      expect(() => getTypeHash('UNKNOWN' as any)).to.throw(UnknownQueueType);
    });
  });
});
