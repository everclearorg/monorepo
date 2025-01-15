import { MQStatus, expect } from '@chimera-monorepo/utils';
import { MQCache } from '../../../src';

describe('MQCache', () => {
  let cache: MQCache;

  beforeEach(() => {
    cache = new MQCache({ host: 'mock', port: 1234, mock: true });
  });

  describe('#setMessageStatus / #getMessageStatus', () => {
    it('should work', async () => {
      expect(await cache.getMessageStatus('1')).to.be.eq(MQStatus.None);
      await cache.setMessageStatus('1', MQStatus.Enqueued);
      expect(await cache.getMessageStatus('1')).to.be.eq(MQStatus.Enqueued);
    });
  });
});
