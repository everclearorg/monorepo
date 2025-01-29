// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';
import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';

import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';

import {ICallExecutor} from 'interfaces/intent/ICallExecutor.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';

abstract contract TestnetAssets {
  ///////////////////// ASSETS /////////////////////////
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

abstract contract TestnetStagingEnv is TestnetAssets {
  ///////////////////// HUB ARGUMENTS /////////////////////////
  uint256 ACCEPTANCE_DELAY = 5 minutes; // delay to accept a proposed ownerhsip
  uint24 MAX_FEE = 1000; // 100 bps
  uint8 MIN_ROUTER_SUPPORTED_DOMAINS = 2; // the min amount of different domains a solver must support
  uint48 EXPIRY_TIME_BUFFER = 3 hours;
  uint48 EPOCH_LENGTH = 100; // blocks
  uint24 DISCOUNT_PER_EPOCH = 8; // 0.8 BPS

  ///////////////////// ACCOUNTS /////////////////////////
  address public constant OWNER = 0xbb8012544f64AdAC48357eE474e6B8e641151dad;
  address public constant ADMIN = 0x4D9C788517D628cb8bD9eE709Dd25abAddEcFC45;
  address public constant LIGHTHOUSE = 0xab104322A8350fD31Cb4B798e42390Ee014776A3;
  address public constant WATCHTOWER = 0x7CF5bAA98E8Bd5F7DD54d02a8E328C13D6266061;
  address public constant ASSET_MANAGER = 0xEA021291CB1E204B2eAB2a5d5BEbb12286c45Da5;
  address public constant ROUTER = 0x3acEB2dB94b34af0406C8245F035C47Ab05D7269;

  ///////////////////// EVERCLEAR DOMAIN /////////////////////////
  uint32 public constant EVERCLEAR_DOMAIN = 6398; // everclear-sepolia
  IEverclearHub public constant HUB = IEverclearHub(0xd05a33e7C55551D7D0015aa156b006531Fc33ED2);
  IHubGateway public constant HUB_GATEWAY = IHubGateway(0x63A8fAF04b492b9c418D24C38159CbDF61613466);
  address public HUB_MANAGER = 0x1826aADB275B2A8436c99004584000D2D16c79cE;
  address public SETTLER = 0x125F31D1ba76bA22D5567A6925fD23aA65955ca4;
  address public ISM = 0x8FdBfCdB9862E7aE67B5364cA197C147c99e9a15;
  IMailbox public EVERCLEAR_SEPOLIA_MAILBOX = IMailbox(address(0x6966b0E55883d49BFB24539356a2f8A673E02039));
  string public constant HUB_RPC = 'everclear-sepolia';
  string public constant HUB_NAME = 'Everclear Sepolia';

  ///////////////////// ETHEREUM SEPOLIA /////////////////////////
  uint32 public constant SEPOLIA = 11_155_111;
  IMailbox public SEPOLIA_MAILBOX = IMailbox(0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766); // sepolia mailbox

  IEverclearSpoke public SEPOLIA_SPOKE = IEverclearSpoke(0xda058E1bD948457EB166D304a2680Fe1c813AC21);
  ISpokeGateway public SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(0x645219a36CB7254Ea367B645ED3eA512e14BBbEA);
  IInterchainSecurityModule public SEPOLIA_ISM = IInterchainSecurityModule(0xAFc260a61cF54bCb0A05E88c078f7C818da12241);
  ICallExecutor public SEPOLIA_EXECUTOR = ICallExecutor(0xb7123127cbcC652e49C1DB4B9A5054ED3B6A6D91);

  ///////////////////// BSC TESTNET /////////////////////////
  uint32 public constant BSC_TESTNET = 97;
  IMailbox public BSC_MAILBOX = IMailbox(0xF9F6F5646F478d5ab4e20B0F910C92F1CCC9Cc6D); // bsc mailbox

  IEverclearSpoke public BSC_SPOKE = IEverclearSpoke(0xda058E1bD948457EB166D304a2680Fe1c813AC21);
  ISpokeGateway public BSC_SPOKE_GATEWAY = ISpokeGateway(0x645219a36CB7254Ea367B645ED3eA512e14BBbEA);
  IInterchainSecurityModule public BSC_ISM = IInterchainSecurityModule(0x2cDE906b6b618f928Ca2aF4cFce808d41426616F);
  ICallExecutor public BSC_EXECUTOR = ICallExecutor(0xb7123127cbcC652e49C1DB4B9A5054ED3B6A6D91);

  ///////////////////// OPTIMISM SEPOLIA /////////////////////////
  uint32 public constant OP_SEPOLIA = 11_155_420;
  IMailbox public OP_SEPOLIA_MAILBOX = IMailbox(0x6966b0E55883d49BFB24539356a2f8A673E02039); // op-sepolia mailbox

  IEverclearSpoke public OP_SEPOLIA_SPOKE = IEverclearSpoke(0xda058E1bD948457EB166D304a2680Fe1c813AC21);
  ISpokeGateway public OP_SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(0x645219a36CB7254Ea367B645ED3eA512e14BBbEA);
  IInterchainSecurityModule public OP_SEPOLIA_ISM =
    IInterchainSecurityModule(0x0F95bF69938535C22299CDd121FAF8521A5221E3);
  ICallExecutor public OP_SEPOLIA_EXECUTOR = ICallExecutor(0xb7123127cbcC652e49C1DB4B9A5054ED3B6A6D91);

  ///////////////////// ARBITRUM SEPOLIA /////////////////////////
  uint32 public constant ARB_SEPOLIA = 421_614;
  IMailbox public ARB_SEPOLIA_MAILBOX = IMailbox(0x598facE78a4302f11E3de0bee1894Da0b2Cb71F8); // arb-sepolia mailbox

  IEverclearSpoke public ARB_SEPOLIA_SPOKE = IEverclearSpoke(0xda058E1bD948457EB166D304a2680Fe1c813AC21);
  ISpokeGateway public ARB_SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(0x645219a36CB7254Ea367B645ED3eA512e14BBbEA);
  IInterchainSecurityModule public ARB_SEPOLIA_ISM =
    IInterchainSecurityModule(0x0F95bF69938535C22299CDd121FAF8521A5221E3);
  ICallExecutor public ARB_SEPOLIA_EXECUTOR = ICallExecutor(0xb7123127cbcC652e49C1DB4B9A5054ED3B6A6D91);

  uint32[] public SUPPORTED_DOMAINS = [SEPOLIA, BSC_TESTNET, OP_SEPOLIA, ARB_SEPOLIA];
}

abstract contract TestnetProductionEnv is TestnetAssets {
  ///////////////////// HUB ARGUMENTS /////////////////////////
  uint256 ACCEPTANCE_DELAY = 5 minutes; // delay to accept a proposed ownerhsip
  uint24 MAX_FEE = 500;
  uint8 MIN_SUPPORTED_DOMAINS = 2; // the min amount of different domains a solver must support
  uint48 EXPIRY_TIME_BUFFER = 3 hours;
  uint48 EPOCH_LENGTH = 100; // 15s block-numbers, 25min
  uint24 DISCOUNT_PER_EPOCH = 8; // 0.8 BPS

  ///////////////////// ACCOUNTS /////////////////////////
  address public constant OWNER = address(0x204D2396375B1e44a87846C1F9E9956F4d3AeB51);
  address public constant ADMIN = address(0x4fa832768BCE9392a05BD032ffD4119d00c87ec6);
  address public constant LIGHTHOUSE = address(0x6Eb3F471734EB2D4C271465cBe82a274a94Aba79);
  address public constant WATCHTOWER = address(0xaf7C26dF4c4aaE4a7a28b24a309A2fb54c5B7Bbe);
  address public constant ASSET_MANAGER = address(0x8a9976D3baB11aBCA75D1bB6BDE501B320edbD4C);

  ///////////////////// EVERCLEAR DOMAIN /////////////////////////
  uint32 public constant EVERCLEAR_DOMAIN = 6398; // everclear-sepolia
  IMailbox public EVERCLEAR_SEPOLIA_MAILBOX = IMailbox(address(0x6966b0E55883d49BFB24539356a2f8A673E02039)); // https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/cfb890dc6bf66c62e7d3176cc01197f334ba96cf/rust/config/testnet_config.json#L140

  IEverclearHub public constant HUB = IEverclearHub(0x02cfc75A2C24Cf698AFb53017c1a19e16C4f14da);
  IHubGateway public constant HUB_GATEWAY = IHubGateway(0x0b6241a74D521d947E02a12D1f409Bad563c7833);
  address public HUB_MANAGER = address(0x67d0040082497cB8D3099297F7d7e05B6aA11E98);
  address public SETTLER = address(0xAC87a2Aa5969F8F933D3B01F6B9D11B8378AF2Db);
  address public ISM = address(0x812a92B1074d782E75bAB7964f71f14fE343f965);
  string public constant HUB_RPC = 'everclear-sepolia';
  string public constant HUB_NAME = 'Everclear Sepolia';

  ///////////////////// ETHEREUM SEPOLIA /////////////////////////
  uint32 public constant SEPOLIA = 11_155_111;
  IMailbox public SEPOLIA_MAILBOX = IMailbox(0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766); // sepolia mailbox

  IEverclearSpoke public SEPOLIA_SPOKE = IEverclearSpoke(address(0x83d58be7DAbd2C12df29FE80d24a0A661BC88B11));
  ISpokeGateway public SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(address(0x557A0AF3F73Ee8627e60ec813d6CF29cA0f90c77));
  IInterchainSecurityModule public SEPOLIA_ISM =
    IInterchainSecurityModule(address(0xB341AFc5e06CbDC54D7fB581C6f881dAFE584cd2));
  ICallExecutor public SEPOLIA_EXECUTOR = ICallExecutor(address(0xb06244d2501a926E57D26da5DDaCaDaDeE24374D));

  // ///////////////////// ARB1 TESTNET /////////////////////////
  // uint32 public constant ARBITRUM_ONE_TESTNET = 97;
  // IMailbox public ARBITRUM_ONE_MAILBOX = IMailbox(); // arb mailbox

  // IEverclearSpoke public ARBITRUM_ONE_SPOKE = IEverclearSpoke();
  // ISpokeGateway public ARBITRUM_ONE_SPOKE_GATEWAY = ISpokeGateway();
  // IInterchainSecurityModule public ARBITRUM_ONE_ISM = IInterchainSecurityModule();
  // ICallExecutor public ARBITRUM_ONE_EXECUTOR = ICallExecutor();

  ///////////////////// BSC TESTNET /////////////////////////
  uint32 public constant BSC_TESTNET = 97;
  IMailbox public BSC_MAILBOX = IMailbox(0xF9F6F5646F478d5ab4e20B0F910C92F1CCC9Cc6D); // bsc mailbox

  IEverclearSpoke public BSC_SPOKE = IEverclearSpoke(address(0x83d58be7DAbd2C12df29FE80d24a0A661BC88B11));
  ISpokeGateway public BSC_SPOKE_GATEWAY = ISpokeGateway(address(0x557A0AF3F73Ee8627e60ec813d6CF29cA0f90c77));
  IInterchainSecurityModule public BSC_ISM =
    IInterchainSecurityModule(address(0xB341AFc5e06CbDC54D7fB581C6f881dAFE584cd2));
  ICallExecutor public BSC_EXECUTOR = ICallExecutor(address(0xb06244d2501a926E57D26da5DDaCaDaDeE24374D));

  ///////////////////// OPTIMISM SEPOLIA /////////////////////////
  uint32 public constant OP_SEPOLIA = 11_155_420;
  IMailbox public OP_SEPOLIA_MAILBOX = IMailbox(0x6966b0E55883d49BFB24539356a2f8A673E02039); // op-sepolia mailbox

  IEverclearSpoke public OP_SEPOLIA_SPOKE = IEverclearSpoke(0xd18C5E22E67947C8f3E112C622036E65a49773ab);
  ISpokeGateway public OP_SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(0x688a75702c4cF772164b7a448df3Db018199D414);
  IInterchainSecurityModule public OP_SEPOLIA_ISM =
    IInterchainSecurityModule(0xbFa2A898c850586Bfd5BEC7D596e12439b9B3C0f);
  ICallExecutor public OP_SEPOLIA_EXECUTOR = ICallExecutor(0xa41996EAe78535cb8Ce2D46ab230370f94f2512C);

  ///////////////////// ARBITRUM SEPOLIA /////////////////////////
  uint32 public constant ARB_SEPOLIA = 421_614;
  IMailbox public ARB_SEPOLIA_MAILBOX = IMailbox(0x598facE78a4302f11E3de0bee1894Da0b2Cb71F8); // arb-sepolia mailbox

  IEverclearSpoke public ARB_SEPOLIA_SPOKE = IEverclearSpoke(0xd18C5E22E67947C8f3E112C622036E65a49773ab);
  ISpokeGateway public ARB_SEPOLIA_SPOKE_GATEWAY = ISpokeGateway(0x688a75702c4cF772164b7a448df3Db018199D414);
  IInterchainSecurityModule public ARB_SEPOLIA_ISM =
    IInterchainSecurityModule(0xbFa2A898c850586Bfd5BEC7D596e12439b9B3C0f);
  ICallExecutor public ARB_SEPOLIA_EXECUTOR = ICallExecutor(0xa41996EAe78535cb8Ce2D46ab230370f94f2512C);

  uint32[] public SUPPORTED_DOMAINS = [ARB_SEPOLIA];
}
