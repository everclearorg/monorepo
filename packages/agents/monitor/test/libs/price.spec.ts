import { Interface } from 'ethers/lib/utils';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { SinonStubbedInstance, reset, restore, createStubInstance, stub, SinonStub } from 'sinon';
import { getContextStub, mock } from '../globalTestHook';
import { AssetConfig, expect, mkAddress, univ2PairABI } from '@chimera-monorepo/utils';
import { createProcessEnv } from '../mock';
import { getTokenPrice } from "../../src/libs";
import * as MockableFns from "../../src/mockable";

let mockAsset: AssetConfig;

const mockBaseAsset: AssetConfig = {
    symbol: "MockStable",
    address: mkAddress("0x222"),
    decimals: 18,
    isNative: false,
    price: {
        isStable: true,
        priceFeed: mkAddress("0xa111"),
        univ2: {
            pair: mkAddress("0xb111"),
        },
        univ3:  {
            pool: mkAddress("0xc111")
        }
    }
}
describe('price', () => {
  let chainreader: SinonStubbedInstance<ChainReader>;
  let contractIface: SinonStubbedInstance<Interface>;

  let getBestProviderStub: SinonStub;
  let getTokenPriceFromChainlinkStub: SinonStub;
  let getTokenPriceFromUniV2Stub: SinonStub;
  let getTokenPriceFromUniV3Stub: SinonStub;
  let getTokenPriceFromCoingeckoStub: SinonStub;
  beforeEach(() => {
    stub(process, 'env').value({
      ...process.env,
      ...createProcessEnv(),
    });
    chainreader = mock.instances.chainreader() as SinonStubbedInstance<ChainReader>;
    contractIface = createStubInstance(Interface);
    getContextStub.returns({
    ...mock.context(),
    config: { ...mock.config(), chains: {  
        '1337': {
            providers: ['http://rpc-1337:8545'],
            subgraphUrls: ['http://1337.mocksubgraph.com'],
            deployments: {
            everclear: mkAddress('0x1337ccc'),
            gateway: mkAddress('0x1337fff'),
            },
            confirmations: 3,
            assets: {
                "Mock": mockAsset,
                "MockBase": mockBaseAsset
            },
        },
        '1338': {
            providers: ['http://rpc-1338:8545'],
            subgraphUrls: ['http://1338.mocksubgraph.com'],
            deployments: {
            everclear: mkAddress('0x1338ccc'),
            gateway: mkAddress('0x1338fff'),
            },
            confirmations: 3,
            assets: {},
        },
        '1': {
            providers: ['http://rpc-1:8545'],
            subgraphUrls: ['http://1.mocksubgraph.com'],
            deployments: {
            everclear: mkAddress('0x1ccc'),
            gateway: mkAddress('0x1fff'),
            },
            confirmations: 3,
            assets: {
                "MockBase": mockBaseAsset
            },
        }        
        }},
    });

    getBestProviderStub = stub(MockableFns, 'getBestProvider');
    getTokenPriceFromChainlinkStub = stub(MockableFns, 'getTokenPriceFromChainlink');
    getTokenPriceFromUniV2Stub = stub(MockableFns, "getTokenPriceFromUniV2");
    getTokenPriceFromUniV3Stub = stub(MockableFns, "getTokenPriceFromUniV3");
    getTokenPriceFromCoingeckoStub = stub(MockableFns, "getTokenPriceFromCoingecko");

    mockAsset = {
        symbol: "Mock",
        address: mkAddress("0x111"),
        decimals: 18,
        isNative: false,
        price: {
            isStable: false,
            priceFeed: mkAddress("0xa111"),
            univ2: {
                pair: mkAddress("0xb111"),
            },
            univ3:  {
                pool: mkAddress("0xc111")
            },
            coingeckoId: "11111"
        }
    }
  });
  afterEach(() => {
    reset();
    restore();
  });
  describe('#getTokenPrice', () => {
    it('happy: should return stable token price', async () => {
      mockAsset.price.isStable = true;
      const tokenPrice = await getTokenPrice('1337', mockAsset);
      expect(tokenPrice).to.be.eq(1);
    });

    it('happy: should return chainlink price', async () => {
        getBestProviderStub.resolves("rpc");
        getTokenPriceFromChainlinkStub.resolves(100);
        mockAsset.price.isStable = false;
        const tokenPrice = await getTokenPrice('1337', mockAsset);
        expect(tokenPrice).to.be.eq(100);
    });   

    it('happy: should return mainnetEquivalent price', async () => {
        getBestProviderStub.resolves("rpc");
        getTokenPriceFromChainlinkStub.resolves(100);
        mockAsset.price.isStable = false;
        mockAsset.price.priceFeed = undefined;
        mockAsset.price.mainnetEquivalent = mockBaseAsset.address;
        const tokenPrice = await getTokenPrice('1337', mockAsset);
        expect(tokenPrice).to.be.eq(1);
    });    

    it('happy: should return univ2 price', async () => {
        getBestProviderStub.resolves("rpc");

        const mockPrice = 3000;
        getTokenPriceFromUniV2Stub.resolves(mockPrice);

        const univ2PairIface = new Interface(univ2PairABI);
        const mockEncodedResultOfToken0 = univ2PairIface.encodeFunctionResult('token0', [mockAsset.address]);
        const mockEncodedResultOfToken1 = univ2PairIface.encodeFunctionResult('token1', [mockBaseAsset.address]);
        chainreader.readTx.onFirstCall().resolves(mockEncodedResultOfToken0);
        chainreader.readTx.onSecondCall().resolves(mockEncodedResultOfToken1);

        mockAsset.price.isStable = false;
        mockAsset.price.priceFeed = undefined;
        mockAsset.price.mainnetEquivalent = undefined;
        const tokenPrice = await getTokenPrice('1337', mockAsset);
        expect(tokenPrice).to.be.eq(mockPrice);
    });    
    
    it('happy: should return univ3 price', async () => {
        getBestProviderStub.resolves("rpc");

        const mockPrice = 3000;
        getTokenPriceFromUniV3Stub.resolves(mockPrice);

        const univ2PairIface = new Interface(univ2PairABI);
        const mockEncodedResultOfToken0 = univ2PairIface.encodeFunctionResult('token0', [mockAsset.address]);
        const mockEncodedResultOfToken1 = univ2PairIface.encodeFunctionResult('token1', [mockBaseAsset.address]);
        chainreader.readTx.onFirstCall().resolves(mockEncodedResultOfToken0);
        chainreader.readTx.onSecondCall().resolves(mockEncodedResultOfToken1);

        mockAsset.price.isStable = false;
        mockAsset.price.priceFeed = undefined;
        mockAsset.price.mainnetEquivalent = undefined;
        mockAsset.price.univ2 = undefined;
        const tokenPrice = await getTokenPrice('1337', mockAsset);
        expect(tokenPrice).to.be.eq(mockPrice);
    });    
    
    it('happy: should return coingecko price', async () => {
        getBestProviderStub.resolves("rpc");

        const mockPrice = 3000;
        getTokenPriceFromCoingeckoStub.resolves(mockPrice);

        const univ2PairIface = new Interface(univ2PairABI);
        const mockEncodedResultOfToken0 = univ2PairIface.encodeFunctionResult('token0', [mockAsset.address]);
        const mockEncodedResultOfToken1 = univ2PairIface.encodeFunctionResult('token1', [mockBaseAsset.address]);
        chainreader.readTx.onFirstCall().resolves(mockEncodedResultOfToken0);
        chainreader.readTx.onSecondCall().resolves(mockEncodedResultOfToken1);

        mockAsset.price.isStable = false;
        mockAsset.price.priceFeed = undefined;
        mockAsset.price.mainnetEquivalent = undefined;
        mockAsset.price.univ2 = undefined;
        mockAsset.price.univ3 = undefined;
        const tokenPrice = await getTokenPrice('1337', mockAsset);
        expect(tokenPrice).to.be.eq(mockPrice);
    });        
  });
});