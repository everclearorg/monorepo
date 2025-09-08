import { expect } from 'chai';
import { reset, restore, stub } from 'sinon';
import { getTokenPriceFromChainlink, aggregatorV3InterfaceABI } from "../../../src";
import { PublicClient, encodeFunctionResult } from 'viem';

describe('chainlink', () => {
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
  
  describe('#getTokenPriceFromChainlink', () => {
    it('happy: should return price', async () => {
      const mockEncodedResult = encodeFunctionResult({
        abi: aggregatorV3InterfaceABI,
        functionName: 'latestRoundData',
        result: ['1', '500000000', '1', '1', '1']
      });
      
      (mockClient.request as any).resolves(mockEncodedResult);

      const chainlinkPrice = await getTokenPriceFromChainlink('1111', '0x', mockClient);
      
      expect(chainlinkPrice).to.be.eq(5);
      expect(mockClient.request).to.have.been.calledOnce;
    });

    it('should handle client request errors', async () => {
      (mockClient.request as any).rejects(new Error('RPC Error'));

      await expect(getTokenPriceFromChainlink('1111', '0x1234567890123456789012345678901234567890', mockClient))
        .to.be.rejectedWith('RPC Error');
    });
  });
});
