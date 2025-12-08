import { expect } from 'chai';
import { reset, restore, stub } from 'sinon';
import { getTokenPriceFromChainlink, aggregatorV3InterfaceABI } from "../../../src";
import { PublicClient } from 'viem';

describe('chainlink', () => {
  let mockClient: PublicClient;

  beforeEach(() => {
    reset();
    restore();
    mockClient = {
      readContract: stub().resolves(['1', '500000000', '1', '1', '1']),
    } as any;
  });
  
  afterEach(() => {
    reset();
    restore();
  });
  
  describe('#getTokenPriceFromChainlink', () => {
    it('happy: should return price', async () => {
      const chainlinkPrice = await getTokenPriceFromChainlink('1111', '0x', mockClient);
      
      expect(chainlinkPrice).to.be.eq(5);
      expect(mockClient.readContract).to.have.been.calledOnce;
      expect(mockClient.readContract).to.have.been.calledWith({
        address: '0x',
        abi: aggregatorV3InterfaceABI,
        functionName: 'latestRoundData',
      });
    });

    it('should handle client request errors', async () => {
      (mockClient.readContract as any).rejects(new Error('RPC Error'));

      await expect(getTokenPriceFromChainlink('1111', '0x1234567890123456789012345678901234567890', mockClient))
        .to.be.rejectedWith('RPC Error');
    });
  });
});
