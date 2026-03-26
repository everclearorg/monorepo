import { expect, getGelatoRelayerAddress } from '../../src';

describe('Peripherals:Gelato', () => {
  describe('#getGelatoRelayerAddress', () => {
    afterEach(() => {
      delete process.env.GELATO_RELAYER_ADDRESS;
    });

    it('happy', () => {
      // zkSync networks
      expect(getGelatoRelayerAddress('280')).to.be.eq('0x30532F63B02c5bBb6D6f684Cbc7bebfC5deF407B');
      expect(getGelatoRelayerAddress('324')).to.be.eq('0x30532F63B02c5bBb6D6f684Cbc7bebfC5deF407B');

      // Other networks — Gelato executor EOA
      expect(getGelatoRelayerAddress('1')).to.be.eq('0xE2D4A7ff2b7bB9f92AD5d1eDd438224C1646733C');
    });

    it('should use env var override when set', () => {
      const customAddress = '0x1234567890123456789012345678901234567890';
      process.env.GELATO_RELAYER_ADDRESS = customAddress;
      expect(getGelatoRelayerAddress('1')).to.be.eq(customAddress);
      expect(getGelatoRelayerAddress('324')).to.be.eq(customAddress);
    });
  });
});
