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
      expect(result).to.equal('0x8104c8a42e1531612796e696e327ea52a475d9583ee6d64ffdefcafad22c0b24');
    });

    it('should return correct type hash for FILL', () => {
      const result = getTypeHash('FILL');
      expect(result).to.equal('0x0afae807991f914b71165fd92589f1dc28648cb9fb1f8558f3a6c7507d56deff');
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
