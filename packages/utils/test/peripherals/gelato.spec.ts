import { expect, getGelatoRelayerAddress } from '../../src';

describe('Peripherals:Gelato', () => {
  describe('#getGelatoRelayerAddress', () => {
    it('happy', () => {
      expect(getGelatoRelayerAddress('2053862260')).to.be.eq('0x0c1B63765Be752F07147ACb80a7817A8b74d9831');
      expect(getGelatoRelayerAddress('2053862243')).to.be.eq('0x0c1B63765Be752F07147ACb80a7817A8b74d9831');
      expect(getGelatoRelayerAddress('6648936')).to.be.eq('0xF9D64d54D32EE2BDceAAbFA60C4C438E224427d0');
      expect(getGelatoRelayerAddress('1735353714')).to.be.eq('0xF9D64d54D32EE2BDceAAbFA60C4C438E224427d0');
    });
  });
});
