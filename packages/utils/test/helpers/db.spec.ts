import { expect, getMaxTxNonce, getMaxNonce, getMaxTimestamp, getMaxEpoch } from '../../src';

describe('Helpers:db', () => {
  describe('#getMaxNonce', () => {
    it('should work', () => {
      expect(getMaxNonce([{ nonce: 1 }, {} as any, { nonce: 3 }])).to.eq(3);
    });
  });
  describe('#getMaxTimestamp', () => {
    it('should work', () => {
      expect(getMaxTimestamp([{ timestamp: 1 }, {} as any, { timestamp: 3 }])).to.eq(3);
    });
  });
  describe('#getMaxTxNonce', () => {
    it('should work', () => {
      expect(getMaxTxNonce([{ txNonce: 1 }, {} as any, { txNonce: 3 }])).to.eq(3);
    });
  });
  describe('#getMaxEpoch', () => {
    it('should work', () => {
      expect(getMaxEpoch([{ epoch: 1 }, {} as any, { epoch: 3 }])).to.eq(3);
    });
  });
});
