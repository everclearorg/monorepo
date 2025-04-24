import { expect, getGelatoRelayerAddress } from '../../src';

describe('Peripherals:Gelato', () => {
  describe('#getGelatoRelayerAddress', () => {
    it('happy', () => {
      // zkSync networks
      expect(getGelatoRelayerAddress('280')).to.be.eq('0x0c1B63765Be752F07147ACb80a7817A8b74d9831');
      expect(getGelatoRelayerAddress('324')).to.be.eq('0x30532F63B02c5bBb6D6f684Cbc7bebfC5deF407B');

      // Other networks
      expect(getGelatoRelayerAddress('1')).to.be.eq('0xceA8aAa918bc6C19e5B77841ebD77ff3188385AF');
    });
  });
});
