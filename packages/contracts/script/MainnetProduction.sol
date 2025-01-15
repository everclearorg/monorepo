// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

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
  uint48 constant EPOCH_LENGTH_BLOCKS = 40; // ~10min (15s block)
  uint256 constant SETTLEMENT_BASE_GAS_UNITS = 40_000;
  uint256 constant AVG_GAS_UNITS_PER_SETTLEMENT = 50_000;
  uint256 constant BUFFER_DBPS = 10_000; // 10%

  ///////////////////// ACCOUNTS /////////////////////////
  address public constant OWNER = 0xBc8988C7a4b77c1d6df7546bd876Ea4D42DF0837; // This is the deployer, owner is: 0xac7599880cB5b5eCaF416BEE57C606f15DA5beB8
  address public constant ADMIN = 0xba1c05257B3a9Bb8f822e164913a3eE1198411Ed;
  address public constant LIGHTHOUSE = 0x38f188953f1E3afE83327C78AAeF72e0498da2C6;
  address public constant WATCHTOWER = 0x6281ea3060B26352b558C4F45767C90db482c4fd;
  address public constant ASSET_MANAGER = 0xBF67dfcdC720E7bcaAdca6e1092f3A65207b7874;
  address public constant ROUTER = 0xe9Ed3751665930c112cF8e0b278C025A13C041c2;
}

abstract contract MainnetAssets {
  ///////////////////// WETH
  address public constant ETHEREUM_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant BASE_WETH = 0x4200000000000000000000000000000000000006;
  address public constant ARBITRUM_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public constant OPTIMISM_WETH = 0x4200000000000000000000000000000000000006;
  address public constant BNB_WETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
  address public constant BLAST_WETH = 0x4300000000000000000000000000000000000004;

  ///////////////////// USDT
  // NOTE: USDT is not supported on Base
  address public constant ETHEREUM_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address public constant ARBITRUM_USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
  address public constant OPTIMISM_USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
  address public constant BNB_USDT = 0x55d398326f99059fF775485246999027B3197955;

  ///////////////////// USDC
  address public constant ETHEREUM_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
  address public constant ARBITRUM_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // NOT USDC.e
  address public constant OPTIMISM_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // NOT USDC.e
  address public constant BNB_USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

  ///////////////////// xPufETH
  address public constant ETHEREUM_PUFETH = 0xD7D2802f6b19843ac4DfE25022771FD83b5A7464;
  address public constant ZIRCUIT_PUFETH = 0x9346A5043C590133FE900aec643D9622EDddBA57;

  ///////////////////// FEE RECIPIENTS
  address public constant FEE_RECIPIENT = 0xac7599880cB5b5eCaF416BEE57C606f15DA5beB8;
}

abstract contract Everclear {
  uint32 public constant EVERCLEAR_DOMAIN = 25_327; // everclear
  IMailbox public EVERCLEAR_MAILBOX = IMailbox(address(0x7f50C5776722630a0024fAE05fDe8b47571D7B39)); // https://github.com/hyperlane-xyz/hyperlane-registry/pull/187/files

  IEverclearHub public constant HUB = IEverclearHub(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  IHubGateway public constant HUB_GATEWAY = IHubGateway(0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa);

  address public HUB_MANAGER = address(0xe0F010e465f15dcD42098dF9b99F1038c11B3056);
  address public SETTLER = address(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  address public HANDLER = address(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  address public MESSAGE_RECEIVER = address(0x4e2bbbFb10058E0D248a78fe2F469562f4eDbe66);
  address public EVERCLEAR_ISM = address(0); // using default ISM
}

abstract contract Ethereum {
  uint32 public constant ETHEREUM = 1;
  IMailbox public ETHEREUM_MAILBOX = IMailbox(0xc005dc82818d67AF737725bD4bf75435d065D239); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L632C19-L632C61

  IEverclearSpoke public ETHEREUM_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public ETHEREUM_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public ETHEREUM_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
}

abstract contract ArbitrumOne {
  uint32 public constant ARBITRUM_ONE = 42_161;
  IMailbox public ARBITRUM_ONE_MAILBOX = IMailbox(0x979Ca5202784112f4738403dBec5D0F3B9daabB9); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L98

  IEverclearSpoke public ARBITRUM_ONE_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public ARBITRUM_ONE_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public ARBITRUM_ONE_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
}

abstract contract Base {
  uint32 public constant BASE = 8453;
  IMailbox public BASE_MAILBOX = IMailbox(0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L238C19-L238C61

  IEverclearSpoke public BASE_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public BASE_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public BASE_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
}

abstract contract Optimism {
  uint32 public constant OPTIMISM = 10;
  IMailbox public OPTIMISM_MAILBOX = IMailbox(0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L1383C19-L1383C61

  IEverclearSpoke public OPTIMISM_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public OPTIMISM_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public OPTIMISM_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
}

abstract contract Bnb {
  uint32 public constant BNB = 56;
  IMailbox public BNB_MAILBOX = IMailbox(0x2971b9Aec44bE4eb673DF1B88cDB57b96eefe8a4); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L427C19-L427C61

  IEverclearSpoke public BNB_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public BNB_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public BNB_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
}

abstract contract Zircuit {
  uint32 public constant ZIRCUIT = 48_900;
  IMailbox public ZIRCUIT_MAILBOX = IMailbox(0xc2FbB9411186AB3b1a6AFCCA702D1a80B48b197c); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/rust/main/config/mainnet_config.json#L3333C19-L3333C61

  IEverclearSpoke public ZIRCUIT_SPOKE = IEverclearSpoke(0xD0E86F280D26Be67A672d1bFC9bB70500adA76fe);
  ISpokeGateway public ZIRCUIT_SPOKE_GATEWAY = ISpokeGateway(0x2Ec2b2CC1813941b638D3ADBA86A1af7F6488A9E);
  ICallExecutor public ZIRCUIT_EXECUTOR = ICallExecutor(0x391BBeaffe82CCb3570F18F615AE5ab4d6eA2fc0);
}

abstract contract Blast {
  uint32 public constant BLAST = 81_457;
  IMailbox public BLAST_MAILBOX = IMailbox(0x3a867fCfFeC2B790970eeBDC9023E75B0a172aa7); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/rust/main/config/mainnet_config.json#L320C19-L320C61

  IEverclearSpoke public BLAST_SPOKE = IEverclearSpoke(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ISpokeGateway public BLAST_SPOKE_GATEWAY = ISpokeGateway(0x4e2bbbFb10058E0D248a78fe2F469562f4eDbe66);
  ICallExecutor public BLAST_EXECUTOR = ICallExecutor(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
}

abstract contract MainnetProductionDomains is Everclear, Ethereum, ArbitrumOne, Base, Optimism, Bnb, Zircuit, Blast {}

abstract contract MainnetProductionSupportedDomainsAndGateways is MainnetProductionDomains {
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
        chainId: ETHEREUM,
        blockGasLimit: 30_000_000,
        gateway: address(ETHEREUM_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: BNB, blockGasLimit: 120_000_000, gateway: address(BNB_SPOKE_GATEWAY).toBytes32()})
    );

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
      DomainAndGateway({chainId: BASE, blockGasLimit: 30_000_000, gateway: address(BASE_SPOKE_GATEWAY).toBytes32()})
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

abstract contract MainnetProductionEnvironment is
  DefaultValues,
  MainnetProductionDomains,
  MainnetAssets,
  MainnetProductionSupportedDomainsAndGateways
{
  uint32[] public SUPPORTED_DOMAINS = [ETHEREUM, ARBITRUM_ONE, OPTIMISM, BASE, BNB, ZIRCUIT, BLAST];
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
