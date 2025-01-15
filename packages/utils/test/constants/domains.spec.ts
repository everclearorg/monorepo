import { chainIdToDomain, expect, isTestnetDomain, domainToChainId, isMainnetDomain } from '../../src';

describe('Domains', () => {
  describe('#chainIdToDomain', () => {
    it('should throw if it cannot find corresponding domain for chainId', () => {
      const chain = 10101010;
      expect(() => chainIdToDomain(chain)).to.throw(`Cannot find corresponding domain for chainId ${chain}`);
    });

    it('should work', () => {
      expect(chainIdToDomain(1)).to.equal(1);
    });
  });

  describe('#domainToChainId', () => {
    it('should throw if cannot find corresponding chainId for domain', () => {
      const domain = 10101010;
      expect(() => domainToChainId(domain)).to.throw(`Cannot find corresponding chainId for domain ${domain}`);
    });

    it('should work', () => {
      expect(domainToChainId(1)).to.equal(1);
    });
  });

  describe('#isMainnetDomain', () => {
    it('should work', () => {
      expect(isMainnetDomain(1)).to.be.true;
      expect(isMainnetDomain(1337)).to.be.false;
    });
  });

  describe('#isTestnetDomain', () => {
    it('should work', () => {
      expect(isTestnetDomain(1)).to.be.false;
      expect(isTestnetDomain(97)).to.be.true;
    });
  });
});
