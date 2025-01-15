import { expect } from '@chimera-monorepo/utils';
import { getQueueMethodName } from '../../../src/tasks/helpers';
import { UnknownQueueType } from '../../../src/errors';

describe('Helpers:getQueueMethodName', () => {
  describe('#getQueueMethodName', () => {
    it('should work for intents', () => {
      expect(getQueueMethodName('INTENT')).to.equal('processIntentQueueViaRelayer');
    });

    it('should work for fills', () => {
      expect(getQueueMethodName('FILL')).to.equal('processFillQueueViaRelayer');
    });

    it('should throw if unknown type', () => {
      expect(() => getQueueMethodName('UNKNOWN' as any)).to.throw(UnknownQueueType);
    });
  });
});
