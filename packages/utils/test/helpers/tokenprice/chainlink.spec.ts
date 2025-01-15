import { Interface } from 'ethers/lib/utils';
import { providers } from "ethers";
import { SinonStubbedInstance, reset, restore, createStubInstance } from 'sinon';
import { getTokenPriceFromChainlink, aggregatorV3InterfaceABI, expect } from "../../../src";

class MockProvider extends providers.JsonRpcProvider {
  private mockCallData = "0x";

  async setMockCallData(_mockCallData: string) {
    this.mockCallData = _mockCallData;
  }

  async call(): Promise<any> {
    return this.mockCallData;
  }
}

describe('chainlink', () => {
  let contractIface: SinonStubbedInstance<Interface>;
  let providerIface: SinonStubbedInstance<MockProvider>;
  beforeEach(() => {
    contractIface = createStubInstance(Interface);
    providerIface = createStubInstance(MockProvider);
  });
  afterEach(() => {
    reset();
    restore();
  });
  describe('#getTokenPriceFromChainlink', () => {
    it('happy: should return price', async () => {
      const feedIface = new Interface(aggregatorV3InterfaceABI);
      const mockEncodedResult = feedIface.encodeFunctionResult('latestRoundData', ['1', '500000000', '1', '1', '1']);
      const mockProvider = new MockProvider();
      mockProvider.setMockCallData(mockEncodedResult);
      const chainlinkPrice = await getTokenPriceFromChainlink('1111', '0x', mockProvider);
      expect(chainlinkPrice).to.be.eq(5);
    });
  });
});
