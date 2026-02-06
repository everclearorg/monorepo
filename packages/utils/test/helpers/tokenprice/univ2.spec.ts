import { expect } from 'chai';
import { reset, restore, stub } from 'sinon';
import { getTokenPriceFromUniV2, univ2PairABI, chainWrapper } from "../../../src";

describe('univ2', () => {
  let chainReaderReadTx: ReturnType<typeof stub>;
  let encodeFunctionDataStub: ReturnType<typeof stub>;
  let decodeFunctionResultStub: ReturnType<typeof stub>;
  let formatUnitsStub: ReturnType<typeof stub>;

  beforeEach(() => {
    reset();
    restore();
    chainReaderReadTx = stub().resolves('0x000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000c80000000000000000000000000000000000000000000000000000000000000064');
    encodeFunctionDataStub = stub(chainWrapper, 'encodeFunctionData').returns('0xencoded' as `0x${string}`);
    decodeFunctionResultStub = stub(chainWrapper, 'decodeFunctionResult').returns(['100', '200', '100'] as any);
    formatUnitsStub = stub(chainWrapper, 'formatUnits');
    formatUnitsStub.onFirstCall().returns('100');
    formatUnitsStub.onSecondCall().returns('200');
  });
  
  afterEach(() => {
    restore();
  });
  
  describe('#getTokenPriceFromUniV2', () => {
    it('happy: should return price', async () => {
      const token0Price = await getTokenPriceFromUniV2(
        '1111',
        '0x',
        { decimals: 18 } as any,
        { decimals: 18 } as any,
        chainReaderReadTx,
        1111
      );
      
      expect(token0Price).to.be.eq(2);
      expect(chainReaderReadTx).to.have.been.calledOnce;
      expect(encodeFunctionDataStub).to.have.been.calledWith({
        abi: univ2PairABI,
        functionName: 'getReserves',
      });
      expect(decodeFunctionResultStub).to.have.been.calledWith({
        abi: univ2PairABI,
        functionName: 'getReserves',
        data: '0x000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000000000000000000000000000000000000000c80000000000000000000000000000000000000000000000000000000000000064' as `0x${string}`,
      });
    });

    it('should handle chainReaderReadTx errors', async () => {
      chainReaderReadTx.rejects(new Error('RPC Error'));

      await expect(getTokenPriceFromUniV2(
        '1111',
        '0x',
        { decimals: 18 } as any,
        { decimals: 18 } as any,
        chainReaderReadTx,
        1111
      )).to.be.rejectedWith('RPC Error');
    });
  });
});
