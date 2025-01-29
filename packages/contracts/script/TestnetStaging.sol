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
  uint256 constant ACCEPTANCE_DELAY = 5 minutes;
  uint24 constant MAX_FEE = 1000;
  uint8 constant MIN_ROUTER_SUPPORTED_DOMAINS = 2;
  uint48 constant EXPIRY_TIME_BUFFER = 3 hours;
  uint48 constant EPOCH_LENGTH_BLOCKS = 100;
  uint256 constant SETTLEMENT_BASE_GAS_UNITS = 40_000;
  uint256 constant AVG_GAS_UNITS_PER_SETTLEMENT = 50_000;
  uint256 constant BUFFER_DBPS = 30_000;

  ///////////////////// ACCOUNTS /////////////////////////
  address public constant OWNER = 0xbb8012544f64AdAC48357eE474e6B8e641151dad;
  address public constant ADMIN = 0x4D9C788517D628cb8bD9eE709Dd25abAddEcFC45;
  address public constant LIGHTHOUSE = 0xab104322A8350fD31Cb4B798e42390Ee014776A3;
  address public constant WATCHTOWER = 0x7CF5bAA98E8Bd5F7DD54d02a8E328C13D6266061;
  address public constant ASSET_MANAGER = 0xEA021291CB1E204B2eAB2a5d5BEbb12286c45Da5;
  address public constant ROUTER = 0x3acEB2dB94b34af0406C8245F035C47Ab05D7269;
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

  IEverclearHub public constant HUB = IEverclearHub(0xd05a33e7C55551D7D0015aa156b006531Fc33ED2);
  IHubGateway public constant HUB_GATEWAY = IHubGateway(0x63A8fAF04b492b9c418D24C38159CbDF61613466);

  address public HUB_MANAGER = 0x1826aADB275B2A8436c99004584000D2D16c79cE;
  address public SETTLER = 0x125F31D1ba76bA22D5567A6925fD23aA65955ca4;
  address public HANDLER = 0x42DdEd2281890cb4B48de74C035406Ce95cEdDF0;
  address public MESSAGE_RECEIVER = 0xF7dc65B19bbD113edC4E4EeeE3A39e97C7002a14;
  address public EVERCLEAR_SEPOLIA_ISM = address(0); // using default ISM
}

abstract contract EthereumSepolia {
  uint32 public constant ETHEREUM_SEPOLIA = 11_155_111;
  IMailbox public ETHEREUM_SEPOLIA_MAILBOX = IMailbox(0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766); // sepolia mailbox

  IEverclearSpoke public ETHEREUM_SEPOLIA_SPOKE = IEverclearSpoke(0xda058E1bD948457EB166D304a2680Fe1c813AC21);
  ISpokeGateway public ETHEREUM_SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(0x645219a36CB7254Ea367B645ED3eA512e14BBbEA);
  ICallExecutor public ETHEREUM_SEPOLIA_EXECUTOR = ICallExecutor(0xb7123127cbcC652e49C1DB4B9A5054ED3B6A6D91);
}

abstract contract BSCTestnet {
  uint32 public constant BSC_TESTNET = 97;
  IMailbox public BSC_MAILBOX = IMailbox(0xF9F6F5646F478d5ab4e20B0F910C92F1CCC9Cc6D); // bsc mailbox

  IEverclearSpoke public BSC_SPOKE = IEverclearSpoke(0xda058E1bD948457EB166D304a2680Fe1c813AC21);
  ISpokeGateway public BSC_SPOKE_GATEWAY = ISpokeGateway(0x645219a36CB7254Ea367B645ED3eA512e14BBbEA);
  ICallExecutor public BSC_EXECUTOR = ICallExecutor(0xb7123127cbcC652e49C1DB4B9A5054ED3B6A6D91);
}

abstract contract OptimismSepolia {
  uint32 public constant OP_SEPOLIA = 11_155_420;
  IMailbox public OP_SEPOLIA_MAILBOX = IMailbox(0x6966b0E55883d49BFB24539356a2f8A673E02039); // op-sepolia mailbox

  IEverclearSpoke public OP_SEPOLIA_SPOKE = IEverclearSpoke(0xda058E1bD948457EB166D304a2680Fe1c813AC21);
  ISpokeGateway public OP_SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(0x645219a36CB7254Ea367B645ED3eA512e14BBbEA);
  ICallExecutor public OP_SEPOLIA_EXECUTOR = ICallExecutor(0xb7123127cbcC652e49C1DB4B9A5054ED3B6A6D91);
}

abstract contract ArbitrumSepolia {
  uint32 public constant ARB_SEPOLIA = 421_614;
  IMailbox public ARB_SEPOLIA_MAILBOX = IMailbox(0x598facE78a4302f11E3de0bee1894Da0b2Cb71F8); // arb-sepolia mailbox

  IEverclearSpoke public ARB_SEPOLIA_SPOKE = IEverclearSpoke(0xda058E1bD948457EB166D304a2680Fe1c813AC21);
  ISpokeGateway public ARB_SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(0x645219a36CB7254Ea367B645ED3eA512e14BBbEA);
  ICallExecutor public ARB_SEPOLIA_EXECUTOR = ICallExecutor(0xb7123127cbcC652e49C1DB4B9A5054ED3B6A6D91);
}

abstract contract TestnetStagingDomains is
  EverclearSepolia,
  EthereumSepolia,
  OptimismSepolia,
  ArbitrumSepolia,
  BSCTestnet
{}

abstract contract TestnetStagingSupportedDomainsAndGateways is TestnetStagingDomains {
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

abstract contract TestnetStagingEnvironment is
  DefaultValues,
  TestnetStagingDomains,
  TestnetAssets,
  TestnetStagingSupportedDomainsAndGateways
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
