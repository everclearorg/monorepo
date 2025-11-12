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
      expect(result).to.equal('0x09b3b633d13dee4d3dded11a692b0a71b91231547cf1117793ee8fdf9d09f017');
    });

    it('should throw UnknownQueueType for unknown types', () => {
      expect(() => getTypeHash('UNKNOWN' as any)).to.throw(UnknownQueueType);
    });
  });
});
