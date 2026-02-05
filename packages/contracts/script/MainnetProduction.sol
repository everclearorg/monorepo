// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {ICallExecutor} from 'interfaces/intent/ICallExecutor.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';
import {IXERC20Module} from 'interfaces/intent/modules/IXERC20Module.sol';

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
  address public constant L2_FEE_SIGNER = 0xd148C7f37b346a4bD8e14f8c1f181f5f640481C8;
}

abstract contract MainnetAssets {
  ///////////////////// WETH
  address public constant ETHEREUM_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant BASE_WETH = 0x4200000000000000000000000000000000000006;
  address public constant ARBITRUM_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public constant OPTIMISM_WETH = 0x4200000000000000000000000000000000000006;
  address public constant BNB_WETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
  address public constant BLAST_WETH = 0x4300000000000000000000000000000000000004;
  address public constant LINEA_WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
  address public constant POLYGON_WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
  address public constant AVALANCHE_WETH = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB; // NOTE: WETH.e
  address public constant SCROLL_WETH = 0x5300000000000000000000000000000000000004;
  address public constant TAIKO_WETH = 0xA51894664A773981C6C112C43ce576f315d5b1B6;
  address public constant APECHAIN_WETH = 0xcF800F4948D16F23333508191B1B1591daF70438;
  address public constant MODE_WETH = 0x4200000000000000000000000000000000000006; // Mode's canonical WETH
  address public constant UNICHAIN_WETH = 0x4200000000000000000000000000000000000006;
  address public constant ZKSYNC_WETH = 0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91;
  address public constant RONIN_WETH = 0xc99a6A985eD2Cac1ef41640596C5A5f9F4E19Ef5;
  address public constant BERACHAIN_WETH = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
  address public constant MANTLE_WETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
  address public constant SONIC_WETH = 0x50c42dEAcD8Fc9773493ED674b675bE577f2634b;
  address public constant INK_WETH = 0x4200000000000000000000000000000000000006;
  bytes32 public constant SOLANA_WETH = 0x66e5188a1308a1db90b6d31f3fbdca8c3df2678c8112dfdd3d192c5a3cc457a8;
  address public constant ZIRCUIT_WETH = 0x4200000000000000000000000000000000000006;

  ///////////////////// USDT
  // NOTE: USDT is not supported on Base, Apechain
  address public constant ETHEREUM_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address public constant ARBITRUM_USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
  address public constant OPTIMISM_USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
  address public constant BNB_USDT = 0x55d398326f99059fF775485246999027B3197955;
  address public constant LINEA_USDT = 0xA219439258ca9da29E9Cc4cE5596924745e12B93;
  address public constant POLYGON_USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
  address public constant AVALANCHE_USDT = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;
  address public constant SCROLL_USDT = 0xf55BEC9cafDbE8730f096Aa55dad6D22d44099Df;
  address public constant TAIKO_USDT = 0x2DEF195713CF4a606B49D07E520e22C17899a736;
  address public constant MODE_USDT = 0xf0F161fDA2712DB8b566946122a5af183995e2eD; // Mode's USDT
  address public constant ZKSYNC_USDT = 0x493257fD37EDB34451f62EDf8D2a0C418852bA4C;
  address public constant UNICHAIN_USDT = 0x588CE4F028D8e7B53B687865d6A67b3A54C75518;
  address public constant MANTLE_USDT = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;
  address public constant SONIC_USDT = 0x6047828dc181963ba44974801FF68e538dA5eaF9;
  bytes32 public constant SOLANA_USDT = 0xce010e60afedb22717bd63192f54145a3f965a33bb82d2c7029eb2ce1e208264;
  address public constant TAC_USDT = 0xAF988C3f7CB2AceAbB15f96b19388a259b6C438f;
  address public constant BASE_USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
  address public constant TRON_USDT = 0xa614f803B6FD780986A42c78Ec9c7f77e6DeD13C;
  address public constant ZIRCUIT_USDT = 0x46dDa6a5a559d861c06EC9a95Fb395f5C3Db0742;

  ///////////////////// USDC, cannot find Apechain USDC
  address public constant ETHEREUM_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
  address public constant ARBITRUM_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // NOT USDC.e
  address public constant OPTIMISM_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // NOT USDC.e
  address public constant BNB_USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
  address public constant LINEA_USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff; // USDC.e
  address public constant POLYGON_USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
  address public constant AVALANCHE_USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
  address public constant SCROLL_USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
  address public constant TAIKO_USDC = 0x07d83526730c7438048D55A4fc0b850e2aaB6f0b;
  address public constant MODE_USDC = 0xd988097fb8612cc24eeC14542bC03424c656005f; // Mode's USDC
  address public constant UNICHAIN_USDC = 0x078D782b760474a361dDA0AF3839290b0EF57AD6;
  address public constant ZKSYNC_USDC = 0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4;
  address public constant RONIN_USDC = 0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc;
  address public constant BERACHAIN_USDC = 0x549943e04f40284185054145c6E4e9568C1D3241;
  address public constant MANTLE_USDC = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
  address public constant SONIC_USDC = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
  address public constant INK_USDC = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
  bytes32 public constant SOLANA_USDC = 0xc6fa7af3bedbad3a3d65f36aabc97431b1bbe4c2d2f6e0e47ca60203452f5d61;
  address public constant ZIRCUIT_USDC = 0x3b952c8C9C44e8Fe201e2b26F6B2200203214cfF;

  ///////////////////// xPufETH
  address public constant ETHEREUM_PUFETH = 0xD7D2802f6b19843ac4DfE25022771FD83b5A7464;
  address public constant ZIRCUIT_PUFETH = 0x9346A5043C590133FE900aec643D9622EDddBA57;
  address public constant APECHAIN_PUFETH = 0x6234E5ef39B12EFdFcbd99dd7F452F27F3fEAE3b;

  ///////////////////// CLEAR
  address public constant ETHEREUM_CLEAR = 0x58b9cB810A68a7f3e1E4f8Cb45D1B9B3c79705E8;
  address public constant ARBITRUM_CLEAR = 0x58b9cB810A68a7f3e1E4f8Cb45D1B9B3c79705E8;
  address public constant OPTIMISM_CLEAR = 0x58b9cB810A68a7f3e1E4f8Cb45D1B9B3c79705E8;
  address public constant BNB_CLEAR = 0x58b9cB810A68a7f3e1E4f8Cb45D1B9B3c79705E8;
  address public constant POLYGON_CLEAR = 0x58b9cB810A68a7f3e1E4f8Cb45D1B9B3c79705E8;
  address public constant GNOSIS_CLEAR = 0x58b9cB810A68a7f3e1E4f8Cb45D1B9B3c79705E8;

  ///////////////////// cbBTC
  address public constant ETHEREUM_CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
  address public constant ARBITRUM_CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
  address public constant BASE_CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

  //////////////////// WBTC
  address public constant ETHEREUM_WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
  address public constant ARBITRUM_WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
  address public constant BASE_WBTC = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;
  address public constant BERACHAIN_WBTC = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;
  address public constant MANTLE_WBTC = 0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2;

  //////////////////// PTSUSDE
  bytes32 public constant SOLANA_PTSUSDE = 0x05c0ad344d082fe99030a0414acc5726b24c89e1a511eac6e58d809145dd6503;

  ///////////////////// FEE RECIPIENTS
  address public constant FEE_RECIPIENT = 0xac7599880cB5b5eCaF416BEE57C606f15DA5beB8;
}

abstract contract Everclear {
  uint32 public constant EVERCLEAR_DOMAIN = 25_327; // everclear
  IMailbox public EVERCLEAR_MAILBOX = IMailbox(address(0x7f50C5776722630a0024fAE05fDe8b47571D7B39)); // https://github.com/hyperlane-xyz/hyperlane-registry/pull/187/files

  IEverclearHub public constant HUB = IEverclearHub(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  IHubGateway public constant HUB_GATEWAY = IHubGateway(0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa);
  address public constant HUB_IMPL = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  address public HUB_MANAGER = address(0xe0F010e465f15dcD42098dF9b99F1038c11B3056);
  address public SETTLER = address(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  address public HANDLER = address(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  address public MESSAGE_RECEIVER = address(0x4e2bbbFb10058E0D248a78fe2F469562f4eDbe66);
  address public EVERCLEAR_ISM = 0xcdBE2995Af304e9c14dF5B0c3d7C9CCc63D7b8B3;
}

abstract contract Ethereum {
  uint32 public constant ETHEREUM = 1;
  IMailbox public ETHEREUM_MAILBOX = IMailbox(0xc005dc82818d67AF737725bD4bf75435d065D239); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L632C19-L632C61

  IEverclearSpoke public ETHEREUM_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public ETHEREUM_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public ETHEREUM_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public ETHEREUM_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public ETHEREUM_SPOKE_IMPL = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;

  // Fee adapter constants
  address public constant ETHEREUM_ENG_MULTISIG = 0xa02a88F0bbD47045001Bd460Ad186C30F9a974d6;
  address public constant ETHEREUM_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract ArbitrumOne {
  uint32 public constant ARBITRUM_ONE = 42_161;
  IMailbox public ARBITRUM_ONE_MAILBOX = IMailbox(0x979Ca5202784112f4738403dBec5D0F3B9daabB9); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L98

  IEverclearSpoke public ARBITRUM_ONE_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public ARBITRUM_ONE_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public ARBITRUM_ONE_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public ARBITRUM_ONE_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public ARBITRUM_SPOKE_IMPL = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;

  // Fee adapter constants
  address public constant ARBITRUM_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant ARBITRUM_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract Base {
  uint32 public constant BASE = 8453;
  IMailbox public BASE_MAILBOX = IMailbox(0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L238C19-L238C61

  IEverclearSpoke public BASE_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public BASE_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public BASE_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public BASE_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public BASE_SPOKE_IMPL = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;

  // Fee adapter constants
  address public constant BASE_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant BASE_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract Optimism {
  uint32 public constant OPTIMISM = 10;
  IMailbox public OPTIMISM_MAILBOX = IMailbox(0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L1383C19-L1383C61

  IEverclearSpoke public OPTIMISM_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public OPTIMISM_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public OPTIMISM_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public OPTIMISM_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public OPTIMISM_SPOKE_IMPL = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;

  // Fee adapter constants
  address public constant OPTIMISM_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant OPTIMISM_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract Bnb {
  uint32 public constant BNB = 56;
  IMailbox public BNB_MAILBOX = IMailbox(0x2971b9Aec44bE4eb673DF1B88cDB57b96eefe8a4); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/mainnet_config.json#L427C19-L427C61

  IEverclearSpoke public BNB_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public BNB_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public BNB_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public BNB_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public BNB_SPOKE_IMPL = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;

  // Fee adapter constants
  address public constant BNB_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant BNB_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract Zircuit {
  uint32 public constant ZIRCUIT = 48_900;
  IMailbox public ZIRCUIT_MAILBOX = IMailbox(0xc2FbB9411186AB3b1a6AFCCA702D1a80B48b197c); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/rust/main/config/mainnet_config.json#L3333C19-L3333C61

  IEverclearSpoke public ZIRCUIT_SPOKE = IEverclearSpoke(0xD0E86F280D26Be67A672d1bFC9bB70500adA76fe);
  ISpokeGateway public ZIRCUIT_SPOKE_GATEWAY = ISpokeGateway(0x2Ec2b2CC1813941b638D3ADBA86A1af7F6488A9E);
  ICallExecutor public ZIRCUIT_EXECUTOR = ICallExecutor(0x391BBeaffe82CCb3570F18F615AE5ab4d6eA2fc0);
  IXERC20Module public ZIRCUIT_XERC20_MODULE = IXERC20Module(0xE4197BC6b18E2BE0BAF09c13DA8239B40005D541);
  address public ZIRCUIT_SPOKE_IMPL = 0x81fFF6085F4A77a2e1E6fd31d0F5b972fE869226;

  // Fee adapter constants
  address public constant ZIRCUIT_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant ZIRCUIT_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract Blast {
  uint32 public constant BLAST = 81_457;
  IMailbox public BLAST_MAILBOX = IMailbox(0x3a867fCfFeC2B790970eeBDC9023E75B0a172aa7); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/rust/main/config/mainnet_config.json#L320C19-L320C61

  IEverclearSpoke public BLAST_SPOKE = IEverclearSpoke(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ISpokeGateway public BLAST_SPOKE_GATEWAY = ISpokeGateway(0x4e2bbbFb10058E0D248a78fe2F469562f4eDbe66);
  ICallExecutor public BLAST_EXECUTOR = ICallExecutor(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  IXERC20Module public BLAST_XERC20_MODULE = IXERC20Module(0xdCA40903E271Cc76AECd62dF8d6c19f3Ac873E64);
  address public BLAST_SPOKE_IMPL = 0xe0F010e465f15dcD42098dF9b99F1038c11B3056;

  // Fee adapter constants
  address public constant BLAST_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant BLAST_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract Linea {
  uint32 public constant LINEA = 59_144;
  IMailbox public LINEA_MAILBOX = IMailbox(0x02d16BC51af6BfD153d67CA61754cF912E82C4d9);

  IEverclearSpoke public LINEA_SPOKE = IEverclearSpoke(0xc24dC29774fD2c1c0c5FA31325Bb9cbC11D8b751);
  ISpokeGateway public LINEA_SPOKE_GATEWAY = ISpokeGateway(0xC1E5b7bE6c62948eeAb40523B33e5d0121ccae94);
  ICallExecutor public LINEA_EXECUTOR = ICallExecutor(0x7480BAeD22695AeA229fDD280a5194d51dc54A21);
  IXERC20Module public LINEA_XERC20_MODULE = IXERC20Module(0xBBd3546f8FB1A335E2Cc1AeE5d7f3FC696D853aB);
  address public LINEA_SPOKE_IMPL = 0x9aA2Ecad5C77dfcB4f34893993f313ec4a370460;

  // Fee adapter constants
  address public constant LINEA_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant LINEA_FEE_ADAPTER = 0x1B0Dc9CB7EadDa36f4CcFB8130B0Ad967b0A3508;
}

abstract contract Polygon {
  uint32 public constant POLYGON = 137;
  IMailbox public POLYGON_MAILBOX = IMailbox(0x5d934f4e2f797775e53561bB72aca21ba36B96BB);

  IEverclearSpoke public POLYGON_SPOKE = IEverclearSpoke(0x7189C59e245135696bFd2906b56607755F84F3fD);
  ISpokeGateway public POLYGON_SPOKE_GATEWAY = ISpokeGateway(0x26CFF54f11608Cd3060408690803AB4a43f462f2);
  ICallExecutor public POLYGON_EXECUTOR = ICallExecutor(0xd08c4718A58bf1f13F540dAEB170f22533d292b7);
  IXERC20Module public POLYGON_XERC20_MODULE = IXERC20Module(0x4aade9F812d2160A1b3c6e77f30f1bF14eC7e2a5);
  address public POLYGON_SPOKE_IMPL = 0x5d81D204FbbC606526A73C11d02C127Ce46B488F;

  // Fee adapter constants
  address public constant POLYGON_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant POLYGON_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract Avalanche {
  uint32 public constant AVALANCHE = 43_114;
  IMailbox public AVALANCHE_MAILBOX = IMailbox(0xFf06aFcaABaDDd1fb08371f9ccA15D73D51FeBD6);

  IEverclearSpoke public AVALANCHE_SPOKE = IEverclearSpoke(0x9aA2Ecad5C77dfcB4f34893993f313ec4a370460);
  ISpokeGateway public AVALANCHE_SPOKE_GATEWAY = ISpokeGateway(0x7EB63a646721de65eBa79ffe91c55DCE52b73c12);
  ICallExecutor public AVALANCHE_EXECUTOR = ICallExecutor(0xC1E5b7bE6c62948eeAb40523B33e5d0121ccae94);
  IXERC20Module public AVALANCHE_XERC20_MODULE = IXERC20Module(0x255aba6E7f08d40B19872D11313688c2ED65d1C9);
  address public AVALANCHE_SPOKE_IMPL = 0xD385Af1A209890AEE184BDf75f328aC396d52fB6;

  // Fee adapter constants
  address public constant AVALANCHE_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant AVALANCHE_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract Scroll {
  uint32 public constant SCROLL = 534_352;
  IMailbox public SCROLL_MAILBOX = IMailbox(0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7);

  IEverclearSpoke public SCROLL_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public SCROLL_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public SCROLL_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public SCROLL_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public SCROLL_SPOKE_IMPL = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  // Fee adapter constants
  address public constant SCROLL_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant SCROLL_FEE_ADAPTER = 0x8ad36C1aCB23b47Db6573A51a8a3009D4A4bC3b1;
}

abstract contract Taiko {
  uint32 public constant TAIKO = 167_000;
  IMailbox public TAIKO_MAILBOX = IMailbox(0x28EFBCadA00A7ed6772b3666F3898d276e88CAe3);

  IEverclearSpoke public TAIKO_SPOKE = IEverclearSpoke(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ISpokeGateway public TAIKO_SPOKE_GATEWAY = ISpokeGateway(0x4e2bbbFb10058E0D248a78fe2F469562f4eDbe66);
  ICallExecutor public TAIKO_EXECUTOR = ICallExecutor(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  IXERC20Module public TAIKO_XERC20_MODULE = IXERC20Module(0xdCA40903E271Cc76AECd62dF8d6c19f3Ac873E64);
  address public TAIKO_SPOKE_IMPL = 0xe0F010e465f15dcD42098dF9b99F1038c11B3056;

  // Fee adapter constants
  address public constant TAIKO_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant TAIKO_FEE_ADAPTER = 0x8ad36C1aCB23b47Db6573A51a8a3009D4A4bC3b1;
}

abstract contract Apechain {
  uint32 public constant APECHAIN = 33_139;
  IMailbox public APECHAIN_MAILBOX = IMailbox(0x7f50C5776722630a0024fAE05fDe8b47571D7B39);

  IEverclearSpoke public APECHAIN_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public APECHAIN_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public APECHAIN_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public APECHAIN_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public APECHAIN_SPOKE_IMPL = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  // Fee adapter constants
  address public constant APECHAIN_ENG_MULTISIG = 0xAF986F36D0471002ff2A64bAF0653c9F6F3A925B;
  address public constant APECHAIN_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract ZkSync {
  uint32 public constant ZKSYNC = 324;
  IMailbox public ZKSYNC_MAILBOX = IMailbox(0x6bD0A2214797Bc81e0b006F7B74d6221BcD8cb6E);

  IEverclearSpoke public ZKSYNC_SPOKE = IEverclearSpoke(0x7F5e085981C93C579c865554B9b723B058AaE4D3);
  ISpokeGateway public ZKSYNC_SPOKE_GATEWAY = ISpokeGateway(0xbD82E5503461913a70566E66a454465a46F5C903);
  ICallExecutor public ZKSYNC_EXECUTOR = ICallExecutor(0xd2cC1a32430B1b81b0ed6327bc37670a26ca4568);
  IXERC20Module public ZKSYNC_XERC20_MODULE = IXERC20Module(0x6ACf19603C8588885250F7a02F0EaFFa4FcafB04);
  address public ZKSYNC_SPOKE_IMPL = 0x6019f814FDa7fbF4037fe967C608f979b782b834;

  // Fee adapter constants
  address public constant ZKSYNC_ENG_MULTISIG = 0x227a7aC43503c15fe7ab31901468DA07108eA967;
  address public constant ZKSYNC_FEE_ADAPTER = 0x80EF3ee093aE3B5aDd1B213628875A4C73F640AF;
}

abstract contract Mode {
  uint32 public constant MODE = 34_443; // Mode Mainnet chain ID
  IMailbox public MODE_MAILBOX = IMailbox(0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7); // Mode's Hyperlane Mailbox

  IEverclearSpoke public MODE_SPOKE = IEverclearSpoke(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  ISpokeGateway public MODE_SPOKE_GATEWAY = ISpokeGateway(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  ICallExecutor public MODE_EXECUTOR = ICallExecutor(0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa);
  IXERC20Module public MODE_XERC20_MODULE = IXERC20Module(0x7B435CCF350DBC773e077410e8FEFcd46A1cDfAA);
  address public MODE_SPOKE_IMPL = 0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7;

  // Fee adapter constants
  address public constant MODE_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant MODE_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract Unichain {
  uint32 public constant UNICHAIN = 130;
  IMailbox public UNICHAIN_MAILBOX = IMailbox(0x3a464f746D23Ab22155710f44dB16dcA53e0775E);

  IEverclearSpoke public UNICHAIN_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public UNICHAIN_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public UNICHAIN_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public UNICHAIN_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public UNICHAIN_SPOKE_IMPL = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  // Fee adapter constants
  address public constant UNICHAIN_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant UNICHAIN_FEE_ADAPTER = 0x8ad36C1aCB23b47Db6573A51a8a3009D4A4bC3b1;
}

abstract contract Ronin {
  uint32 public constant RONIN = 2020;
  IMailbox public RONIN_MAILBOX = IMailbox(0x3a464f746D23Ab22155710f44dB16dcA53e0775E);

  IEverclearSpoke public RONIN_SPOKE = IEverclearSpoke(0xdCA40903E271Cc76AECd62dF8d6c19f3Ac873E64);
  ISpokeGateway public RONIN_SPOKE_GATEWAY = ISpokeGateway(0x1FC1f47a6a7c61f53321643A14bEc044213AbF95);
  ICallExecutor public RONIN_EXECUTOR = ICallExecutor(0xdC30374790080dA7AFc5b2dFc300029eDE9BfE71);
  IXERC20Module public RONIN_XERC20_MODULE = IXERC20Module(0x92dcaf947DB325ac023b105591d76315743883eD);
  address public RONIN_SPOKE_IMPL = 0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa;

  // Fee adapter constants
  address public constant RONIN_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant RONIN_FEE_ADAPTER = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
}

abstract contract Gnosis {
  uint32 public constant GNOSIS = 100;
  IMailbox public GNOSIS_MAILBOX = IMailbox(0xaD09d78f4c6b9dA2Ae82b1D34107802d380Bb74f);

  IEverclearSpoke public GNOSIS_SPOKE = IEverclearSpoke(0xe0F010e465f15dcD42098dF9b99F1038c11B3056);
  ISpokeGateway public GNOSIS_SPOKE_GATEWAY = ISpokeGateway(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  ICallExecutor public GNOSIS_EXECUTOR = ICallExecutor(0x4e2bbbFb10058E0D248a78fe2F469562f4eDbe66);
  IXERC20Module public GNOSIS_XERC20_MODULE = IXERC20Module(0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa);
  address public GNOSIS_SPOKE_IMPL = 0xa05A3380889115bf313f1Db9d5f335157Be4D816;

  // Fee adapter constants
  address public constant GNOSIS_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public GNOSIS_FEE_ADAPTER = 0x6Dea30929A575B8b29F459AaE1B3b85E52a723F4;
}

abstract contract Berachain {
  uint32 public constant BERACHAIN = 80_094;
  IMailbox public BERACHAIN_MAILBOX = IMailbox(0x7f50C5776722630a0024fAE05fDe8b47571D7B39);

  IEverclearSpoke public BERACHAIN_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public BERACHAIN_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public BERACHAIN_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public BERACHAIN_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public BERACHAIN_SPOKE_IMPL = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  // Fee adapter constants
  address public constant BERACHAIN_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant BERACHAIN_FEE_ADAPTER = 0x6Dea30929A575B8b29F459AaE1B3b85E52a723F4;
}

abstract contract Mantle {
  uint32 public constant MANTLE = 5000;
  IMailbox public MANTLE_MAILBOX = IMailbox(0x398633D19f4371e1DB5a8EFE90468eB70B1176AA);

  IEverclearSpoke public MANTLE_SPOKE = IEverclearSpoke(0xe0F010e465f15dcD42098dF9b99F1038c11B3056);
  ISpokeGateway public MANTLE_SPOKE_GATEWAY = ISpokeGateway(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  ICallExecutor public MANTLE_EXECUTOR = ICallExecutor(0x4e2bbbFb10058E0D248a78fe2F469562f4eDbe66);
  IXERC20Module public MANTLE_XERC20_MODULE = IXERC20Module(0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa);
  address public MANTLE_SPOKE_IMPL = 0xa05A3380889115bf313f1Db9d5f335157Be4D816;

  // Fee adapter constants
  address public constant MANTLE_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant MANTLE_FEE_ADAPTER = 0x6Dea30929A575B8b29F459AaE1B3b85E52a723F4;
}

abstract contract Sonic {
  uint32 public constant SONIC = 146;
  IMailbox public SONIC_MAILBOX = IMailbox(0x3a464f746D23Ab22155710f44dB16dcA53e0775E);

  IEverclearSpoke public SONIC_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public SONIC_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public SONIC_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public SONIC_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public SONIC_SPOKE_IMPL = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  // Fee adapter constants
  address public constant SONIC_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant SONIC_FEE_ADAPTER = 0x6Dea30929A575B8b29F459AaE1B3b85E52a723F4;
}

abstract contract Ink {
  uint32 public constant INK = 57_073;
  IMailbox public INK_MAILBOX = IMailbox(0x7f50C5776722630a0024fAE05fDe8b47571D7B39);

  IEverclearSpoke public INK_SPOKE = IEverclearSpoke(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  ISpokeGateway public INK_SPOKE_GATEWAY = ISpokeGateway(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7);
  ICallExecutor public INK_EXECUTOR = ICallExecutor(0xeFa6Ac3F931620fD0449eC8c619f2A14A0A78E99);
  IXERC20Module public INK_XERC20_MODULE = IXERC20Module(0xD1daF260951B8d350a4AeD5C80d74Fd7298C93F4);
  address public INK_SPOKE_IMPL = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  // Fee adapter constants
  address public constant INK_ENG_MULTISIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant INK_FEE_ADAPTER = 0x6Dea30929A575B8b29F459AaE1B3b85E52a723F4;
}

abstract contract Solana {
  uint32 public constant SOLANA = 1_399_811_149;

  bytes32 public SOLANA_SPOKE = 0x09b727b9209c8539f72647d10dd4f4670b53960ba169f034c513c758db0e9656;
  bytes32 public SOLANA_SPOKE_GATEWAY = 0x09b727b9209c8539f72647d10dd4f4670b53960ba169f034c513c758db0e9656;
}

abstract contract Tac {
  uint32 public constant TAC = 239;
  IMailbox public TAC_MAILBOX = IMailbox(0x3a464f746D23Ab22155710f44dB16dcA53e0775E);

  IEverclearSpoke public TAC_SPOKE = IEverclearSpoke(0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa);
  ISpokeGateway public TAC_SPOKE_GATEWAY = ISpokeGateway(0x7B435CCF350DBC773e077410e8FEFcd46A1cDfAA);
  ICallExecutor public TAC_EXECUTOR = ICallExecutor(0x1FC1f47a6a7c61f53321643A14bEc044213AbF95);
  IXERC20Module public TAC_XERC20_MODULE = IXERC20Module(0x92dcaf947DB325ac023b105591d76315743883eD);
  address public TAC_SPOKE_IMPL = 0x315bCf956e887378836f6E57bC735F0cf7022352;

  // Fee adapter constants
  address public constant TAC_ENG_MULTISIG = 0x1F08FACb1b2FD7859250e896400180691EA39763;
  address public constant TAC_FEE_ADAPTER = 0xA388d644241A2185440EAf0ADd41C9Da30958ba5;
}

abstract contract Tron {
  uint32 public constant TRON = 728_126_428;
  IEverclearSpoke public TRON_SPOKE = IEverclearSpoke(0x9b266df36C882A73D45B18876104D5728424828f);
  ISpokeGateway public TRON_SPOKE_GATEWAY = ISpokeGateway(0x8Fd8a4D1980FA73f060A37AF5Bf23d8fb2B68A0b);
  IXERC20Module public TRON_XERC20_MODULE = IXERC20Module(0x9b266df36C882A73D45B18876104D5728424828f);
}

abstract contract MainnetProductionDomains is
  Everclear,
  Ethereum,
  ArbitrumOne,
  Base,
  Optimism,
  Bnb,
  Mode,
  Zircuit,
  Blast,
  Linea,
  Polygon,
  Avalanche,
  ZkSync,
  Taiko,
  Scroll,
  Apechain,
  Unichain,
  Ronin,
  Gnosis,
  Berachain,
  Mantle,
  Sonic,
  Ink,
  Solana,
  Tac,
  Tron
{}

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
        chainId: ETHEREUM, blockGasLimit: 30_000_000, gateway: address(ETHEREUM_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: BNB, blockGasLimit: 120_000_000, gateway: address(BNB_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: OPTIMISM, blockGasLimit: 30_000_000, gateway: address(OPTIMISM_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: ARBITRUM_ONE, blockGasLimit: 30_000_000, gateway: address(ARBITRUM_ONE_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: BASE, blockGasLimit: 30_000_000, gateway: address(BASE_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: ZIRCUIT, blockGasLimit: 30_000_000, gateway: address(ZIRCUIT_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: BLAST, blockGasLimit: 30_000_000, gateway: address(BLAST_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: LINEA, blockGasLimit: 24_000_000, gateway: address(LINEA_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: POLYGON, blockGasLimit: 30_000_000, gateway: address(POLYGON_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: AVALANCHE, blockGasLimit: 15_000_000, gateway: address(AVALANCHE_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: SCROLL, blockGasLimit: 10_000_000, gateway: address(SCROLL_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: TAIKO, blockGasLimit: 30_000_000, gateway: address(TAIKO_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: APECHAIN, blockGasLimit: 30_000_000, gateway: address(APECHAIN_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: MODE, blockGasLimit: 30_000_000, gateway: address(MODE_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: UNICHAIN, blockGasLimit: 30_000_000, gateway: address(UNICHAIN_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: ZKSYNC, blockGasLimit: 30_000_000, gateway: address(ZKSYNC_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: RONIN, blockGasLimit: 30_000_000, gateway: address(RONIN_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: GNOSIS, blockGasLimit: 17_000_000, gateway: address(GNOSIS_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: BERACHAIN, blockGasLimit: 30_000_000, gateway: address(BERACHAIN_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: MANTLE, blockGasLimit: 250_000_000, gateway: address(MANTLE_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({
        chainId: SONIC, blockGasLimit: 5_000_000_000, gateway: address(SONIC_SPOKE_GATEWAY).toBytes32()
      })
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: INK, blockGasLimit: 30_000_000, gateway: address(INK_SPOKE_GATEWAY).toBytes32()})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: SOLANA, blockGasLimit: 48_000_000, gateway: SOLANA_SPOKE_GATEWAY})
    );

    SUPPORTED_DOMAINS_AND_GATEWAYS.push(
      DomainAndGateway({chainId: TAC, blockGasLimit: 30_000_000, gateway: address(TAC_SPOKE_GATEWAY).toBytes32()})
    );
  }
}

abstract contract MainnetProductionEnvironment is
  DefaultValues,
  MainnetProductionDomains,
  MainnetAssets,
  MainnetProductionSupportedDomainsAndGateways
{
  uint32[] public SUPPORTED_DOMAINS = [
    ETHEREUM,
    ARBITRUM_ONE,
    OPTIMISM,
    BASE,
    BNB,
    ZIRCUIT,
    BLAST,
    LINEA,
    POLYGON,
    AVALANCHE,
    TAIKO,
    SCROLL,
    APECHAIN,
    MODE,
    UNICHAIN,
    ZKSYNC,
    RONIN,
    GNOSIS,
    BERACHAIN,
    MANTLE,
    SONIC,
    INK,
    SOLANA
  ];

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
