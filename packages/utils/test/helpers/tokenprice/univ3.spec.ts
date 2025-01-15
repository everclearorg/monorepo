import { Interface } from 'ethers/lib/utils';
import { providers } from "ethers";
import { SinonStubbedInstance, reset, restore, createStubInstance, stub } from 'sinon';
import { getTokenPriceFromUniV3, univ3PoolABI, expect } from '../../../src';

class MockProvider extends providers.JsonRpcProvider {
  private mockCallData = "0x";

  async setMockCallData(_mockCallData: string) {
    this.mockCallData = _mockCallData;
  }

  async call(): Promise<any> {
    return this.mockCallData;
  }
}

describe('univ2', () => {
  let providerIface: SinonStubbedInstance<providers.JsonRpcProvider>;
  beforeEach(() => {
    providerIface = createStubInstance(providers.JsonRpcProvider);
  });
  afterEach(() => {
    reset();
    restore();
  });
  describe('#getTokenPriceFromUniV3', () => {
    it('happy: should return price', async () => {
      const univ3PoolIface = new Interface(univ3PoolABI);
      const mockEncodedResult = univ3PoolIface.encodeFunctionResult('slot0', ['1', '10000', '1', '1', '1', '1', 0]);
      const mockProvider = new MockProvider();
      mockProvider.setMockCallData(mockEncodedResult);
      const token0Price = await getTokenPriceFromUniV3('1111', '0x', { decimals: 18 } as any, { decimals: 18 } as any, mockProvider);
      const P = 1.0001;
      const price0 = Math.pow(P, 10000);
      expect(token0Price).to.be.eq(price0);
    });
  });
});
