import { expect } from 'chai';
import { reset, restore, stub } from 'sinon';
import { getTokenPriceFromUniV2, univ2PairABI } from "../../../src";
import { PublicClient } from 'viem';

describe('univ2', () => {
  let mockClient: PublicClient;

  beforeEach(() => {
    reset();
    restore();
    mockClient = {
      readContract: stub().resolves(['100', '200', '100']),
    } as any;
  });
  
  afterEach(() => {
    reset();
    restore();
  });
  
  describe('#getTokenPriceFromUniV2', () => {
    it('happy: should return price', async () => {
      const token0Price = await getTokenPriceFromUniV2(
        '1111',
        '0x',
        { decimals: 18 } as any,
        { decimals: 18 } as any,
        mockClient
      );
      
      expect(token0Price).to.be.eq(2);
      expect(mockClient.readContract).to.have.been.calledOnce;
      expect(mockClient.readContract).to.have.been.calledWith({
        address: '0x',
        abi: univ2PairABI,
        functionName: 'getReserves',
      });
    });

    it('should handle client request errors', async () => {
      (mockClient.readContract as any).rejects(new Error('RPC Error'));

      await expect(getTokenPriceFromUniV2(
        '1111',
        '0x',
        { decimals: 18 } as any,
        { decimals: 18 } as any,
        mockClient
      )).to.be.rejectedWith('RPC Error');
    });
  });
});
