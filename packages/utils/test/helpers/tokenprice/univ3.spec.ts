import { expect } from 'chai';
import { reset, restore, stub } from 'sinon';
import { getTokenPriceFromUniV3, univ3PoolABI, chainWrapper } from '../../../src';

describe('univ3', () => {
  let chainReaderReadTx: ReturnType<typeof stub>;
  let encodeFunctionDataStub: ReturnType<typeof stub>;
  let decodeFunctionResultStub: ReturnType<typeof stub>;

  beforeEach(() => {
    reset();
    restore();
    chainReaderReadTx = stub().resolves('0x000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000027100000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000');
    encodeFunctionDataStub = stub(chainWrapper, 'encodeFunctionData').returns('0xencoded' as `0x${string}`);
    decodeFunctionResultStub = stub(chainWrapper, 'decodeFunctionResult').returns(['1', '10000', '1', '1', '1', '1', false] as any);
  });
  
  afterEach(() => {
    restore();
  });
  
  describe('#getTokenPriceFromUniV3', () => {
    it('happy: should return price', async () => {
      const token0Price = await getTokenPriceFromUniV3(
        '1111', 
        '0x',
        { decimals: 18 } as any, 
        { decimals: 18 } as any, 
        chainReaderReadTx,
        1111
      );
      
      const P = 1.0001;
      const price0 = Math.pow(P, 10000);
      expect(token0Price).to.be.eq(price0);
      expect(chainReaderReadTx).to.have.been.calledOnce;
      expect(encodeFunctionDataStub).to.have.been.calledWith({
        abi: univ3PoolABI,
        functionName: 'slot0',
      });
      expect(decodeFunctionResultStub).to.have.been.calledWith({
        abi: univ3PoolABI,
        functionName: 'slot0',
        data: '0x000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000027100000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`,
      });
    });

    it('should handle chainReaderReadTx errors', async () => {
      chainReaderReadTx.rejects(new Error('RPC Error'));

      await expect(getTokenPriceFromUniV3(
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