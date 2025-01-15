import { Interface } from 'ethers/lib/utils';
import { providers } from "ethers";
import { SinonStubbedInstance, reset, restore, createStubInstance } from 'sinon';
import { getTokenPriceFromUniV2, univ2PairABI, expect } from "../../../src";

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
  let contractIface: SinonStubbedInstance<Interface>;
  beforeEach(() => {
    contractIface = createStubInstance(Interface);
  });
  afterEach(() => {
    reset();
    restore();
  });
  describe('#getTokenPriceFromUniV2', () => {
    it('happy: should return price', async () => {
      const univ2PairIface = new Interface(univ2PairABI);
      const mockEncodedResult = univ2PairIface.encodeFunctionResult('getReserves', ['100', '200', '100']);
      const mockProvider = new MockProvider();
      mockProvider.setMockCallData(mockEncodedResult);
      const token0Price = await getTokenPriceFromUniV2('1111', '0x', {} as any, {} as any, mockProvider);
      expect(token0Price).to.be.eq(2);
    });
  });
});
