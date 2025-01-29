// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {ICallExecutor} from 'interfaces/intent/ICallExecutor.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';

abstract contract DefaultValues {
  ///////////////////// HUB ARGUMENTS /////////////////////////
  uint256 constant ACCEPTANCE_DELAY = 4 days;
  uint24 constant MAX_FEE = 5000; // 5%
  uint8 constant MIN_ROUTER_SUPPORTED_DOMAINS = 2;
  uint48 constant EXPIRY_TIME_BUFFER = 12 hours;
  uint48 constant EPOCH_LENGTH_BLOCKS = 120; // ~30min (15s block)
  uint256 constant SETTLEMENT_BASE_GAS_UNITS = 40_000;
  uint256 constant AVG_GAS_UNITS_PER_SETTLEMENT = 50_000;
  uint256 constant BUFFER_DBPS = 10_000; // 10%

  ///////////////////// ACCOUNTS /////////////////////////
  address public constant OWNER = address(0x204D2396375B1e44a87846C1F9E9956F4d3AeB51);
  address public constant ADMIN = address(0x4fa832768BCE9392a05BD032ffD4119d00c87ec6);
  address public constant LIGHTHOUSE = address(0x6Eb3F471734EB2D4C271465cBe82a274a94Aba79);
  address public constant WATCHTOWER = address(0xaf7C26dF4c4aaE4a7a28b24a309A2fb54c5B7Bbe);
  address public constant ASSET_MANAGER = address(0x8a9976D3baB11aBCA75D1bB6BDE501B320edbD4C);
}

abstract contract TestnetAssets {
  ///////////////////// DEFAULT
  address public constant SEPOLIA_DEFAULT_TEST_TOKEN = address(0xd26e3540A0A368845B234736A0700E0a5A821bBA);
  address public constant BSC_DEFAULT_TEST_TOKEN = address(0x5f921E4DE609472632CEFc72a3846eCcfbed4ed8);
  address public constant OP_SEPOLIA_DEFAULT_TEST_TOKEN = address(0x7Fa13D6CB44164ea09dF8BCc673A8849092D435b);
  address public constant ARB_SEPOLIA_DEFAULT_TEST_TOKEN = address(0xaBF282c88DeD3e386701a322e76456c062468Ac2);

  ///////////////////// XERC20
  address public constant SEPOLIA_XERC20_TEST_TOKEN = address(0x8F936120b6c5557e7Cd449c69443FfCb13005751);
  address public constant BSC_XERC20_TEST_TOKEN = address(0x9064cD072D5cEfe70f854155d1b23171013be5c7);
  address public constant OP_SEPOLIA_XERC20_TEST_TOKEN = address(0xD3D4c6845e297e99e219BD8e3CaC84CA013c0770);
  address public constant ARB_SEPOLIA_XERC20_TEST_TOKEN = address(0xd6dF5E67e2DEF6b1c98907d9a09c18b2b7cd32C3);

  ///////////////////// DIFFERENT DECIMALS
  address public constant SEPOLIA_DECIMALS_TEST_TOKEN = address(0xd18C5E22E67947C8f3E112C622036E65a49773ab);
  address public constant BSC_DECIMALS_TEST_TOKEN = address(0xdef63AA35372780f8F92498a94CD0fA30A9beFbB);
  address public constant OP_SEPOLIA_DECIMALS_TEST_TOKEN = address(0x294FD6cfb1AB97Ad5EA325207fF1d0E85b9C693f);
  address public constant ARB_SEPOLIA_DECIMALS_TEST_TOKEN = address(0xDFEA0bb49bcdCaE920eb39F48156B857e817840F);
}

abstract contract EverclearSepolia {
  uint32 public constant EVERCLEAR_DOMAIN = 6398; // everclear-sepolia
  IMailbox public EVERCLEAR_SEPOLIA_MAILBOX = IMailbox(address(0x6966b0E55883d49BFB24539356a2f8A673E02039)); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/testnet_config.json#L140

  IEverclearHub public constant HUB = IEverclearHub(0x4C526917051ee1981475BB6c49361B0756F505a8);
  address public HUB_MANAGER = address(0x8cE1874D42B9b7ba31B8DCDd7Bc9d110b921A447);
  address public SETTLER = address(0xCc409C5ad27BF51Db634C9Ea3045edD501B4357D);
  address public HANDLER = 0x26a9F5f344AEcaF51A32615BfFA20Bc068544Ba4;
  address public MESSAGE_RECEIVER = 0x6759D3824d316CFD061Df96C4e1f95C2a2B5159a;
  IHubGateway public constant HUB_GATEWAY = IHubGateway(0x4b0017AD0CAbdf72106fC5d6B15e366A9A47DD25);
  string public constant HUB_RPC = 'everclear-sepolia';
  string public constant HUB_NAME = 'Everclear Sepolia';
  address public EVERCLEAR_SEPOLIA_ISM = address(0); // using default ISM
}

abstract contract EthereumSepolia {
  uint32 public constant ETHEREUM_SEPOLIA = 11_155_111;
  IMailbox public ETHEREUM_SEPOLIA_MAILBOX = IMailbox(0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766); // sepolia mailbox

  IEverclearSpoke public ETHEREUM_SEPOLIA_SPOKE = IEverclearSpoke(address(0x3650432cB5331e6dc95be8C1d8168b7c37f677e2));
  ISpokeGateway public ETHEREUM_SEPOLIA_SPOKE_GATEWAY =
    ISpokeGateway(address(0x37f1E1C89306c0e95bfa3221Ef7D364886e43047));
  address public ETHEREUM_MESSAGE_RECEIVER = 0x36042cCE2c80eAD664dFe583EF978aD5B00501EF;
  address public ETHEREUM_SEPOLIA_ISM = address(0); // using default ISM
  ICallExecutor public ETHEREUM_SEPOLIA_EXECUTOR = ICallExecutor(address(0x0FC45dF8f0bee015fB2Afe9c08483b66c402a3b1));
}

abstract contract BSCTestnet {
  uint32 public constant BSC_TESTNET = 97;
  IMailbox public BSC_MAILBOX = IMailbox(0xF9F6F5646F478d5ab4e20B0F910C92F1CCC9Cc6D); // bsc mailbox

  IEverclearSpoke public BSC_SPOKE = IEverclearSpoke(address(0xFeaaF6291E40252413aA6cb5214F486c8088207e));
  ISpokeGateway public BSC_SPOKE_GATEWAY = ISpokeGateway(address(0xCBFCE40d758564B855506Db7Ff15F1978B8E0Fa1));
  address public BSC_MESSAGE_RECEIVER = 0x19f734eE26D59307165D1063b2d523A1159B8302;
  address public BSC_SEPOLIA_ISM = address(0); // using default ISM
  ICallExecutor public BSC_EXECUTOR = ICallExecutor(address(0xbc590D5971015dfDe94e042b3F8D4Fd26c66068d));
}

abstract contract OptimismSepolia {
  uint32 public constant OP_SEPOLIA = 11_155_420;
  IMailbox public OP_SEPOLIA_MAILBOX = IMailbox(0x6966b0E55883d49BFB24539356a2f8A673E02039); // op-sepolia mailbox

  IEverclearSpoke public OP_SEPOLIA_SPOKE = IEverclearSpoke(0xf9A4d8cED1b8c53B39429BB9a8A391b74E85aE5C);
  ISpokeGateway public OP_SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(0xfea15B6F776aA3a84d70e5D98E48f19556F76eb7);
  address public OP_MESSAGE_RECEIVER = 0xF70d3124C459094D11fB99D7Acf3A4DC66192906;
  address public OP_SEPOLIA_ISM = address(0); // using default ISM
  ICallExecutor public OP_SEPOLIA_EXECUTOR = ICallExecutor(0x718e4b5019c34C83fc5446249d3B3e8ad3bC8Cd0);
}

abstract contract ArbitrumSepolia {
  uint32 public constant ARB_SEPOLIA = 421_614;
  IMailbox public ARB_SEPOLIA_MAILBOX = IMailbox(0x598facE78a4302f11E3de0bee1894Da0b2Cb71F8); // arb-sepolia mailbox

  IEverclearSpoke public ARB_SEPOLIA_SPOKE = IEverclearSpoke(0x97f24e4eeD4d05D48cb8a45ADfE5e6aF2de14F71);
  ISpokeGateway public ARB_SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(0x0A1bcEE4F09B691EbFbb3a5b83221A7Ce896c6bd);
  address public ARB_MESSAGE_RECEIVER = 0x718e4b5019c34C83fc5446249d3B3e8ad3bC8Cd0;
  address public ARB_SEPOLIA_ISM = address(0); // using default ISM
  ICallExecutor public ARB_SEPOLIA_EXECUTOR = ICallExecutor(0xfea15B6F776aA3a84d70e5D98E48f19556F76eb7);
}

abstract contract TestnetProductionDomains is
  EverclearSepolia,
  EthereumSepolia,
  OptimismSepolia,
  ArbitrumSepolia,
  BSCTestnet
{}

abstract contract TestnetProductionSupportedDomainsAndGateways is TestnetProductionDomains {
  using TypeCasts for address;

  struct DomainAndGateway {
    uint32 chainId;
    uint256 blockGasLimit;
    bytes32 gateway;
  }

  DomainAndGateway[] public SUPPORTED_DOMAINS_AND_GATEWAYS;

  constructor() {
    // TODO: check block gas limit for each domain and set it accordingly
    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: ETHEREUM_SEPOLIA,
        blockGasLimit: 30_000_000,
        gateway: address(ETHEREUM_SEPOLIA_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: BSC_TESTNET,
        blockGasLimit: 70_000_000,
        gateway: address(BSC_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: OP_SEPOLIA,
        blockGasLimit: 30_000_000,
        gateway: address(OP_SEPOLIA_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: ARB_SEPOLIA,
        blockGasLimit: 30_000_000,
        gateway: address(ARB_SEPOLIA_SPOKE_GATEWAY).toBytes32()
      })
    );
  }
}

abstract contract TestnetProductionEnvironment is
  DefaultValues,
  TestnetProductionDomains,
  TestnetAssets,
  TestnetProductionSupportedDomainsAndGateways
{
  uint32[] public SUPPORTED_DOMAINS = [ETHEREUM_SEPOLIA, BSC_TESTNET, OP_SEPOLIA, ARB_SEPOLIA];
  /**
   * @notice `EverclearHub` initialization parameters
   * @dev Some values are set as `address(0)` as they are deployed
   * in the same batch as the `EverclearSpoke`. `discountPerEpoch` is
   * not being used anymore on the Hub as it's now set per asset.
   */
  IEverclearHub.HubInitializationParams hubParams = IEverclearHub.HubInitializationParams({
    owner: OWNER,
    admin: ADMIN,
    manager: address(0), // to be deployed
    settler: address(0), // to be deployed
    handler: address(0), // to be deployed
    messageReceiver: address(0), // to be deployed
    lighthouse: LIGHTHOUSE,
    hubGateway: IHubGateway(address(0)), // to be deployed
    acceptanceDelay: ACCEPTANCE_DELAY,
    expiryTimeBuffer: EXPIRY_TIME_BUFFER,
    epochLength: EPOCH_LENGTH_BLOCKS,
    discountPerEpoch: 0, // not being used
    minSolverSupportedDomains: MIN_ROUTER_SUPPORTED_DOMAINS,
    settlementBaseGasUnits: SETTLEMENT_BASE_GAS_UNITS,
    averageGasUnitsPerSettlement: AVG_GAS_UNITS_PER_SETTLEMENT,
    bufferDBPS: BUFFER_DBPS
  });
}
