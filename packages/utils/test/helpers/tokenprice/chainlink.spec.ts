import { expect } from 'chai';
import { reset, restore, stub } from 'sinon';
import { getTokenPriceFromChainlink, aggregatorV3InterfaceABI, chainWrapper } from "../../../src";

describe('chainlink', () => {
  let chainReaderReadTx: ReturnType<typeof stub>;
  let encodeFunctionDataStub: ReturnType<typeof stub>;
  let decodeFunctionResultStub: ReturnType<typeof stub>;

  beforeEach(() => {
    reset();
    restore();
    chainReaderReadTx = stub().resolves('0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000001dcd650000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001');
    encodeFunctionDataStub = stub(chainWrapper, 'encodeFunctionData').returns('0xencoded' as `0x${string}`);
    decodeFunctionResultStub = stub(chainWrapper, 'decodeFunctionResult').returns(['1', '500000000', '1', '1', '1'] as any);
  });
  
  afterEach(() => {
    restore();
  });
  
  describe('#getTokenPriceFromChainlink', () => {
    it('happy: should return price', async () => {
      const chainlinkPrice = await getTokenPriceFromChainlink('1111', '0x', chainReaderReadTx, 1111);
      
      expect(chainlinkPrice).to.be.eq(5);
      expect(chainReaderReadTx).to.have.been.calledOnce;
      expect(encodeFunctionDataStub).to.have.been.calledWith({
        abi: aggregatorV3InterfaceABI,
        functionName: 'latestRoundData',
      });
      expect(decodeFunctionResultStub).to.have.been.calledWith({
        abi: aggregatorV3InterfaceABI,
        functionName: 'latestRoundData',
        data: '0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000001dcd650000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001' as `0x${string}`,
      });
    });

    it('should handle chainReaderReadTx errors', async () => {
      chainReaderReadTx.rejects(new Error('RPC Error'));

      await expect(getTokenPriceFromChainlink('1111', '0x1234567890123456789012345678901234567890', chainReaderReadTx, 1111))
        .to.be.rejectedWith('RPC Error');
    });
  });
});
