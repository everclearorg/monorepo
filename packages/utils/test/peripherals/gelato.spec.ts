import { expect, getGelatoRelayerAddress } from '../../src';

describe('Peripherals:Gelato', () => {
  describe('#getGelatoRelayerAddress', () => {
    it('happy', () => {
      // zkSync networks
      expect(getGelatoRelayerAddress('280')).to.be.eq('0x0c1B63765Be752F07147ACb80a7817A8b74d9831');
      expect(getGelatoRelayerAddress('324')).to.be.eq('0x0c1B63765Be752F07147ACb80a7817A8b74d9831');
      
      // Unichain
      expect(getGelatoRelayerAddress('130')).to.be.eq('0xC6e576260853e8eDb7a683Ff1233747Ad9904f16');
      
      // Other networks
      expect(getGelatoRelayerAddress('1')).to.be.eq('0xF9D64d54D32EE2BDceAAbFA60C4C438E224427d0');
    });
  });
});
