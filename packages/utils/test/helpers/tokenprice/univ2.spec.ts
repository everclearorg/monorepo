import { expect } from 'chai';
import { reset, restore, stub } from 'sinon';
import { getTokenPriceFromUniV2, univ2PairABI } from "../../../src";
import { PublicClient, encodeFunctionResult } from 'viem';

describe('univ2', () => {
  let mockClient: PublicClient;

  beforeEach(() => {
    reset();
    restore();
    mockClient = {
      request: stub().resolves(''),
    } as any;
  });
  
  afterEach(() => {
    reset();
    restore();
  });
  
  describe('#getTokenPriceFromUniV2', () => {
    it('happy: should return price', async () => {
      const mockEncodedResult = encodeFunctionResult({
        abi: univ2PairABI,
        functionName: 'getReserves',
        result: ['100', '200', '100'],
      });
      
      (mockClient.request as any).resolves(mockEncodedResult);

      const token0Price = await getTokenPriceFromUniV2(
        '1111',
        '0x',
        { decimals: 18 } as any,
        { decimals: 18 } as any,
        mockClient
      );
      
      expect(token0Price).to.be.eq(2);
      expect(mockClient.request).to.have.been.calledOnce;
    });

    it('should handle client request errors', async () => {
      (mockClient.request as any).rejects(new Error('RPC Error'));

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
