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
      expect(result).to.equal('0x87c42ffc42ddf0cd52b5e8a0b1fa6c45338db7d6e7c93f9d2943eb42b2706aca');
    });

    it('should return correct type hash for FILL', () => {
      const result = getTypeHash('FILL');
      expect(result).to.equal('0xfff2306b4d1a2b16ba8a4ba32d8ed8136d2cc882aea58ada6b2baedcde647f57');
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
