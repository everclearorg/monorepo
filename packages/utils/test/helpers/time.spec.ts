import { expect, getNtpTimeSeconds } from '../../src';

describe('Helpers:time', () => {
  describe('#getNtpTimeSeconds', () => {
    it('should work', () => {
      const time = Date.now();
      expect(getNtpTimeSeconds()).to.be.lte(time / 1000);
    });
  });
});
