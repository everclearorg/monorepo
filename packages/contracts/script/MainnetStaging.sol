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
  uint256 constant ACCEPTANCE_DELAY = 1 days;
  uint24 constant MAX_FEE = 5000; // 5%
  uint8 constant MIN_ROUTER_SUPPORTED_DOMAINS = 2;
  uint48 constant EXPIRY_TIME_BUFFER = 12 hours;
  uint48 constant EPOCH_LENGTH_BLOCKS = 120; // ~30min (15s block)
  uint256 constant SETTLEMENT_BASE_GAS_UNITS = 40_000;
  uint256 constant AVG_GAS_UNITS_PER_SETTLEMENT = 50_000;
  uint256 constant BUFFER_DBPS = 10_000; // 10%

  ///////////////////// ACCOUNTS /////////////////////////
  address public constant OWNER = 0xeb19B3Bdad53A775EB2d94d57D5a46c5260B0044;
  address public constant ADMIN = 0xbBc0a29458eD4b2d489F2B564fE482C9086006F6;
  address public constant LIGHTHOUSE = 0x68F44CD6b4cd9c4F723E00b1734E667bfaF72042;
  address public constant WATCHTOWER = 0xc687BadC2CD8Da70eCACC748D6c27D06115a7de6;
  address public constant ASSET_MANAGER = 0xF47aA74BDe8eB56674748ba9D7090abf7447c747;
  address public constant ROUTER = 0x340c6F9E08CD50208d036a0BbCe6e244882B0E78;
}

abstract contract MainnetAssets {
  ///////////////////// WETH -- Not whitelisted
  address public constant ZIRCUIT_WETH = 0x4200000000000000000000000000000000000006;
  address public constant ETHEREUM_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  ///////////////////// WETH -- Whitelisted ✅
  address public constant ARBITRUM_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public constant OPTIMISM_WETH = 0x4200000000000000000000000000000000000006;
  address public constant BLAST_WETH = 0x4300000000000000000000000000000000000004;

  ///////////////////// USDT -- Not whitelisted
  // NOTE: USDT is not supported on Base
  address public constant ARBITRUM_USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
  address public constant OPTIMISM_USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;

  ///////////////////// USDC -- Not whitelisted
  address public constant ARBITRUM_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // NOT USDC.e
  address public constant OPTIMISM_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // NOT USDC.e

  ///////////////////// xTEST (xERC20) -- Whitelisted ✅
  address public constant ARBITRUM_XTEST = 0xCDFAb2b2fA913385056E713D104c1b268e4898A5;
  address public constant ZIRCUIT_XTEST = 0xad560465f00fCcf3F10Ad3474cb8440A143b16Df;
}

abstract contract Everclear {
  uint32 public constant EVERCLEAR_DOMAIN = 25_327; // everclear
  IMailbox public EVERCLEAR_MAILBOX = IMailbox(address(0x7f50C5776722630a0024fAE05fDe8b47571D7B39)); // https://github.com/hyperlane-xyz/hyperlane-registry/pull/187/files

  IEverclearHub public constant HUB = IEverclearHub(0x372396818F125b8f3AA5a73e70C30F54c6195331);
  IHubGateway public constant HUB_GATEWAY = IHubGateway(0xe5F2F4afAd6211cfBD6a882D5a6a435530Ee3909);

  address public HUB_MANAGER = address(0x53c91cFc48a3B9e30C3E73a6eDCb584917C19Ab4);
  address public SETTLER = address(0xcebcc29F32C5f23251Dd218e28485e3a02e83bED);
  address public HANDLER = address(0x4faba0EB79E710C58C568090c08157D34b4367ED);
  address public MESSAGE_RECEIVER = address(0xd66338f1DEc85f7012c4B31F02b22bb01a9EAC3f);
  address public EVERCLEAR_ISM = address(0); // using default ISM
}

abstract contract Ethereum {
  uint32 public constant ETHEREUM = 1;
  IMailbox public ETHEREUM_MAILBOX = IMailbox(0xc005dc82818d67AF737725bD4bf75435d065D239); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L632C19-L632C61

  IEverclearSpoke public ETHEREUM_SPOKE = IEverclearSpoke(0xD95Ff203bAAd65A8Fafd5C3dB695FC0a77A809a3);
  ISpokeGateway public ETHEREUM_SPOKE_GATEWAY = ISpokeGateway(0xF712520F89d295dFdcC4d71B7E8787c060f44e39);
  ICallExecutor public ETHEREUM_EXECUTOR = ICallExecutor(0xcA48aCE7387574a6120392722eB6f2018C60eF3B);
  address public ETHEREUM_SPOKE_IMPL = 0x8B5401516fBf40621fec17A3b8D15D5E16754107;
}

abstract contract ArbitrumOne {
  uint32 public constant ARBITRUM_ONE = 42_161;
  IMailbox public ARBITRUM_ONE_MAILBOX = IMailbox(0x979Ca5202784112f4738403dBec5D0F3B9daabB9); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L98

  IEverclearSpoke public ARBITRUM_ONE_SPOKE = IEverclearSpoke(0x91c40B4135eFea3c5A200388CfE316aa0B172b30);
  ISpokeGateway public ARBITRUM_ONE_SPOKE_GATEWAY = ISpokeGateway(0xe051C7AdB6F24Ee8c9d94DD23106C51D94858d12);
  ICallExecutor public ARBITRUM_ONE_EXECUTOR = ICallExecutor(0x81fFF6085F4A77a2e1E6fd31d0F5b972fE869226);
  address public ARBITRUM_SPOKE_IMPL = 0xdC30374790080dA7AFc5b2dFc300029eDE9BfE71;
}

abstract contract Optimism {
  uint32 public constant OPTIMISM = 10;
  IMailbox public OPTIMISM_MAILBOX = IMailbox(0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L1383C19-L1383C61

  IEverclearSpoke public OPTIMISM_SPOKE = IEverclearSpoke(0x91c40B4135eFea3c5A200388CfE316aa0B172b30);
  ISpokeGateway public OPTIMISM_SPOKE_GATEWAY = ISpokeGateway(0xe051C7AdB6F24Ee8c9d94DD23106C51D94858d12);
  ICallExecutor public OPTIMISM_EXECUTOR = ICallExecutor(0x81fFF6085F4A77a2e1E6fd31d0F5b972fE869226);
  address public OPTIMISM_SPOKE_IMPL = 0xdC30374790080dA7AFc5b2dFc300029eDE9BfE71;
}

abstract contract Zircuit {
  uint32 public constant ZIRCUIT = 48_900;
  IMailbox public ZIRCUIT_MAILBOX = IMailbox(0xc2FbB9411186AB3b1a6AFCCA702D1a80B48b197c); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/rust/main/config/mainnet_config.json#L3324C19-L3324C61

  IEverclearSpoke public ZIRCUIT_SPOKE = IEverclearSpoke(0x9d3DE64eC0491251306a3B30d0a385C3a005B9F4);
  ISpokeGateway public ZIRCUIT_SPOKE_GATEWAY = ISpokeGateway(0x1D93B833baa7907bf385dAda4cf64dd8e04939BB);
  ICallExecutor public ZIRCUIT_EXECUTOR = ICallExecutor(0x2579200bBDcF73c5Eb7A147f786d5f2cA8a5Ab03);
}

abstract contract Blast {
  uint32 public constant BLAST = 81_457;
  IMailbox public BLAST_MAILBOX = IMailbox(0x3a867fCfFeC2B790970eeBDC9023E75B0a172aa7); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/rust/main/config/mainnet_config.json#L320C19-L320C61

  IEverclearSpoke public BLAST_SPOKE = IEverclearSpoke(0xf1D5d2D7C6c3D125eBbf137BE5093c0C5D7Fa032);
  ISpokeGateway public BLAST_SPOKE_GATEWAY = ISpokeGateway(0xACab998fab4aea61057640ef75c28B1625921462);
  ICallExecutor public BLAST_EXECUTOR = ICallExecutor(0x88F16B8Cc37f0b07794e6c720DBeA3E792043966);
}

abstract contract MainnetStagingDomains is Everclear, ArbitrumOne, Optimism, Zircuit, Blast, Ethereum {}

abstract contract MainnetStagingSupportedDomainsAndGateways is MainnetStagingDomains {
  using TypeCasts for address;

  struct DomainAndGateway {
    uint32 chainId;
    uint256 blockGasLimit;
    bytes32 gateway;
  }

  DomainAndGateway[] public SUPPORTED_DOMAINS_AND_GATEWAYS;

  constructor() {
    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: OPTIMISM,
        blockGasLimit: 30_000_000,
        gateway: address(OPTIMISM_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: ARBITRUM_ONE,
        blockGasLimit: 30_000_000,
        gateway: address(ARBITRUM_ONE_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: ZIRCUIT,
        blockGasLimit: 30_000_000,
        gateway: address(ZIRCUIT_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: BLAST, blockGasLimit: 30_000_000, gateway: address(BLAST_SPOKE_GATEWAY).toBytes32()})
    );
  }
}

abstract contract MainnetStagingEnvironment is
  DefaultValues,
  MainnetStagingDomains,
  MainnetAssets,
  MainnetStagingSupportedDomainsAndGateways
{
  uint32[] public SUPPORTED_DOMAINS = [ARBITRUM_ONE, OPTIMISM, ZIRCUIT, BLAST];
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
