import { getRandomBytes32, expect, canonizeId, evmId } from '../../src';

import { utils } from 'ethers';

describe('Helpers:Hex', () => {
  const address = '0x0100546f2cd4c9d97f798ffc9755e47865ff7ee6';
  const bytes32 = '0x0000000000000000000000000100546f2cd4c9d97f798ffc9755e47865ff7ee6';
  describe('#getRandomBytes32', () => {
    it('happy case: should generate random bytes32 string', () => {
      const random = getRandomBytes32();
      expect(utils.hexDataLength(random)).to.be.eq(32);
    });
  });

  describe('#canonizeId', () => {
    it('should throw if input is undefined', () => {
      expect(() => canonizeId()).to.throw('Bad input. Undefined');
    });

    it('should throw if input is too long', () => {
      expect(() => canonizeId('0x' + 'ff'.repeat(33))).to.throw('Too long');
    });

    it('should throw if input is not 20 or 32 bytes long', () => {
      expect(() => canonizeId('0x' + 'ff'.repeat(21))).to.throw('bad input, expect address or bytes32');
    });

    it('should work', () => {
      expect(canonizeId(utils.hexlify(address))).to.be.eq(bytes32);
    });
  });

  describe('#evmId', () => {
    it('should throw if input is not 20 or 32 bytes long', () => {
      try {
        evmId('0x' + 'ff'.repeat(21));
      } catch (e) {
        expect(e.message).to.be.eq('Invalid id length. expected 20 or 32. Got 21');
      }
    });

    it('should work', () => {
      expect(evmId(bytes32)).to.be.eq(address);
    });
  });
});
