import { expect } from 'chai';
import { reset, restore, stub } from 'sinon';
import { getTokenPriceFromUniV3, univ3PoolABI } from '../../../src';
import { PublicClient } from 'viem';

describe('univ3', () => {
  let mockClient: PublicClient;

  beforeEach(() => {
    reset();
    restore();
    mockClient = {
      readContract: stub().resolves(['1', '10000', '1', '1', '1', '1', false]),
    } as any;
  });
  
  afterEach(() => {
    reset();
    restore();
  });
  
  describe('#getTokenPriceFromUniV3', () => {
    it('happy: should return price', async () => {
      const token0Price = await getTokenPriceFromUniV3(
        '1111', 
        '0x',
        { decimals: 18 } as any, 
        { decimals: 18 } as any, 
        mockClient
      );
      
      const P = 1.0001;
      const price0 = Math.pow(P, 10000);
      expect(token0Price).to.be.eq(price0);
      expect(mockClient.readContract).to.have.been.calledOnce;
      expect(mockClient.readContract).to.have.been.calledWith({
        address: '0x',
        abi: univ3PoolABI,
        functionName: 'slot0',
      });
    });

    it('should handle client request errors', async () => {
      (mockClient.readContract as any).rejects(new Error('RPC Error'));

      await expect(getTokenPriceFromUniV3(
        '1111', 
        '0x',
        { decimals: 18 } as any, 
        { decimals: 18 } as any, 
        mockClient
      )).to.be.rejectedWith('RPC Error');
    });
  });
});