// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IAcrossSpokePool, IRoleModule, ISafe, IStargatePool, IWETH} from './IHelpers.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import 'forge-std/Test.sol';
import {IFeeAdapter} from 'interfaces/intent/IFeeAdapter.sol';

///////////////////////////////// Ethereum /////////////////////////////////////////
abstract contract Ethereum {
  address public constant ETHEREUM_STAGING_ROLE_MODULE = 0x1B61aD319e5Aa9EDcEa8ae3a99cd7f624E628d5A;
  address public constant ETHEREUM_PROD_ROLE_MODULE = 0xDc4c839BA1F94E492b7fE9c008890d015080Bd3B;
  bytes32 public constant ETHEREUM_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f6d61696e6e657400000000000000;

  // Bridges
  address public constant ETHEREUM_ACROSS_SPOKE_POOL = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
  address public constant ETHEREUM_STARGATE_WETH_POOL = 0x77b2043768d28E9C9aB44E1aBfC95944bcE57931;
  address public constant ETHEREUM_STARGATE_USDC_POOL = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7;
  address public constant ETHEREUM_STARGATE_USDT_POOL = 0x933597a323Eb81cAe705C5bC29985172fd5A3973;
}

abstract contract EthereumStaging is Ethereum {
  // API Inputs
  uint256 public constant ETHEREUM_FEE = 0;
  uint256 public constant ETHEREUM_DEADLINE = 1_747_218_384;
  bytes public constant ETHEREUM_SIG =
    hex'23bb8e3e64bce059f3545ba0e026b0b9ee4155e369d2c70a33f8fd18f4670f2d1742d9e24e660b12108843bd37fa5026304efb75a267007ca93f862c420b15e31c';
  uint256 public constant ETHEREUM_FIXED_BLOCK = 22_480_748;
}

abstract contract EthereumProduction is Ethereum {
  // API Inputs
  uint256 public constant ETHEREUM_FEE = 0;
  uint256 public constant ETHEREUM_DEADLINE = 1_748_857_065;
  bytes public constant ETHEREUM_SIG =
    hex'639772df946ecc9c79ec939c79eba11e14254a8969bc59f8621b9316066bc32251af1c6bf9830c2a2e5e2a6c2a731a424e95721315e29961fe8e4252bbff95541b';
  uint256 public constant ETHEREUM_FIXED_BLOCK = 22_616_104;
}

///////////////////////////////// Arbitrum /////////////////////////////////////////
abstract contract Arbitrum {
  address public constant ARBITRUM_STAGING_ROLE_MODULE = 0xfc62b8FBC8fdDdd1997130923fD44BB785033B12;
  address public constant ARBITRUM_PROD_ROLE_MODULE = 0x76fCd80859Ef20440BEba00240467733D2482375;
  bytes32 public constant ARBITRUM_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f6172620000000000000000000000;

  // Bridges
  address public constant ARBITRUM_ACROSS_SPOKE_POOL = 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A;
  address public constant ARBITRUM_STARGATE_WETH_POOL = 0xA45B5130f36CDcA45667738e2a258AB09f4A5f7F;
  address public constant ARBITRUM_STARGATE_USDC_POOL = 0xe8CDF27AcD73a434D661C84887215F7598e7d0d3;
  address public constant ARBITRUM_STARGATE_USDT_POOL = 0xcE8CcA271Ebc0533920C83d39F417ED6A0abB7D0;
}

abstract contract ArbitrumStaging is Arbitrum {
  // API Inputs
  uint256 public constant ARBITRUM_FEE = 0;
  uint256 public constant ARBITRUM_DEADLINE = 1_747_061_416;
  bytes public constant ARBITRUM_SIG =
    hex'3742402cc4e0c9c3f8f0afc5f253b353cd7412579e9939c341feeb458e711c9a588e5547fbfc4096efc52fe6fd364bdc9548549a9c612f8f15f8d04223cac7431c';
  uint256 public constant ARBITRUM_FIXED_BLOCK = 335_940_880;
}

abstract contract ArbitrumProduction is Arbitrum {
  // API Inputs
  uint256 public constant ARBITRUM_FEE = 0;
  uint256 public constant ARBITRUM_DEADLINE = 1_748_859_652;
  bytes public constant ARBITRUM_SIG =
    hex'075f688399aaa2842ac0ed482614a63d1af58f3e3afd4b09b1659e1f46a783050de3cb047ed2c2dfffbd061f53f88b7ffa3bb57f137ff0856d53c270f689bd851c';
  uint256 public constant ARBITRUM_FIXED_BLOCK = 343_097_778;
}

///////////////////////////////// Optimism /////////////////////////////////////////
abstract contract Optimism {
  address public constant OPTIMISM_STAGING_ROLE_MODULE = 0x14b940d7128237CDA825fD3f2Ab5063B9DFC0613;
  address public constant OPTIMISM_PROD_ROLE_MODULE = 0x04ee2500c19B2F86EC4928Cd39fEc46DD37c5859;
  bytes32 public constant OPTIMISM_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6F70000000000000000000000000;

  // Bridges
  address public constant OPTIMISM_ACROSS_SPOKE_POOL = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
  address public constant OPTIMISM_STARGATE_WETH_POOL = 0xe8CDF27AcD73a434D661C84887215F7598e7d0d3;
  address public constant OPTIMISM_STARGATE_USDC_POOL = 0xcE8CcA271Ebc0533920C83d39F417ED6A0abB7D0;
  address public constant OPTIMISM_STARGATE_USDT_POOL = 0x19cFCE47eD54a88614648DC3f19A5980097007dD;
}

abstract contract OptimismStaging is Optimism {
  // API Inputs
  uint256 public constant OPTIMISM_FEE = 0;
  uint256 public constant OPTIMISM_DEADLINE = 1_747_128_274;
  bytes public constant OPTIMISM_SIG =
    hex'e329e3ed7e89ece8a250eb4d946e715da2f5716aaff56da95490f9ebb972bb1251a4be40c5c2535b2de9d3512dab22c4a9ff3254c91e78fdc368c41fff5ff6a01b';
  uint256 public constant OPTIMISM_FIXED_BLOCK = 135_764_105;
}

abstract contract OptimismProduction is Optimism {
  // API Inputs
  uint256 public constant OPTIMISM_FEE = 0;
  uint256 public constant OPTIMISM_DEADLINE = 1_748_859_907;
  bytes public constant OPTIMISM_SIG =
    hex'93bf6b7bbd199d3f8391ba97f87ea42c74058ec0dbd2931fbec138a4caa5bc0a0cbd44aa662df2fb98782fdd8f0936508d63c9a70ecf4208c6f187db7386ed1c1c';
  uint256 public constant OPTIMISM_FIXED_BLOCK = 136_630_273;
}

///////////////////////////////// Polygon /////////////////////////////////////////
abstract contract Polygon {
  address public constant POLYGON_STAGING_ROLE_MODULE = 0x5d03263e18CB9623e0bbE9FBf7cf3347Bb7d551f;
  address public constant POLYGON_PROD_ROLE_MODULE = 0x17C6AFf10a4e66170e2F61d19D10bf92A1DaedD7;
  bytes32 public constant POLYGON_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f706f6c79676f6e00000000000000;

  // Bridges
  address public constant POLYGON_ACROSS_SPOKE_POOL = 0x9295ee1d8C5b022Be115A2AD3c30C72E34e7F096;
  address public constant POLYGON_STARGATE_USDC_POOL = 0x9Aa02D4Fae7F58b8E8f34c66E756cC734DAc7fe4;
  address public constant POLYGON_STARGATE_USDT_POOL = 0xd47b03ee6d86Cf251ee7860FB2ACf9f91B9fD4d7;
}

abstract contract PolygonStaging is Polygon {
  // API Inputs
  uint256 public constant POLYGON_FEE = 0.000107 ether;
  uint256 public constant POLYGON_DEADLINE = 1_747_130_983;
  bytes public constant POLYGON_SIG =
    hex'daa784afa9790cf081561d1b807b8ace402e05cdc915827248bcaf047c25a0e42e4b8a17dd6c2ceda7ce443fc58f6bd2488d461b7a73fe756798d595e3d803e21b';
  uint256 public constant POLYGON_FIXED_BLOCK = 71_461_569;
}

abstract contract PolygonProduction is Polygon {
  // API Inputs
  uint256 public constant POLYGON_FEE = 0.0 ether;
  uint256 public constant POLYGON_DEADLINE = 1_748_860_461;
  bytes public constant POLYGON_SIG =
    hex'9647949db2c6b3071c006eea4f60a6df6d9455e12c913358cd9a40dfe74164e46dbdf1fa9f8f9eeea58d134bbe65b24c663e666287dea12ad1973a47cc919bd91c';
  uint256 public constant POLYGON_FIXED_BLOCK = 72_269_016;
}

///////////////////////////////// Base /////////////////////////////////////////
abstract contract Base {
  address public constant BASE_STAGING_ROLE_MODULE = 0x5818a6540c2591BD990B24fA180Ca3217A2f9Cd4;
  address public constant BASE_PROD_ROLE_MODULE = 0x5B664ef3826c473134F88dA1eA213Af825c09E91;
  bytes32 public constant BASE_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6261736500000000000000000000;

  // Bridges
  address public constant BASE_ACROSS_SPOKE_POOL = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
  address public constant BASE_STARGATE_WETH_POOL = 0xdc181Bd607330aeeBEF6ea62e03e5e1Fb4B6F7C7;
  address public constant BASE_STARGATE_USDC_POOL = 0x27a16dc786820B16E5c9028b75B99F6f604b5d26;
}

abstract contract BaseStaging is Base {
  // API Inputs
  uint256 public constant BASE_FEE = 0;
  uint256 public constant BASE_DEADLINE = 1_747_215_864;
  bytes public constant BASE_SIG =
    hex'dc5cde8e23110bfdc9ace00e3098517a3a657f2b68d70222061583e00d9c497e13e93758e04ed658ee767e26bb77aac8b58a4c6b446373fd420e8683763501bf1b';
  uint256 public constant BASE_FIXED_BLOCK = 30_212_943;
}

abstract contract BaseProduction is Base {
  // API Inputs
  uint256 public constant BASE_FEE = 0;
  uint256 public constant BASE_DEADLINE = 1_748_860_591;
  bytes public constant BASE_SIG =
    hex'17801c4a8bfd2f8c5d2bf13127878997fd338ea575b40c7b92a497f8f44b06ed1d213d3f0240ab6f9b1d7fbea4a551be47687ca649c1f50a5d2cdee60196f2911c';
  uint256 public constant BASE_FIXED_BLOCK = 31_035_330;
}

///////////////////////////////// BSC /////////////////////////////////////////
abstract contract Bsc {
  address public constant BSC_STAGING_ROLE_MODULE = 0x5f67084B92abaB83002fE562Be9E761Ba99603E1;
  address public constant BSC_PROD_ROLE_MODULE = 0xAFf14A306Ca6F0b7e4E46125405A2d8B4e32bae8;
  bytes32 public constant BSC_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6273630000000000000000000000;

  // Bridges
  address public constant BSC_STARGATE_USDC_POOL = 0x962Bd449E630b0d928f308Ce63f1A21F02576057;
  address public constant BSC_STARGATE_USDT_POOL = 0x138EB30f73BC423c6455C53df6D89CB01d9eBc63;
}

abstract contract BscStaging is Bsc {
  // API Inputs
  uint256 public constant BSC_FEE = 0;
  uint256 public constant BSC_DEADLINE = 1_747_132_224;
  bytes public constant BSC_SIG =
    hex'7210553206854228e610016ca7ad380827380ff168df9fc4df922a448f2be19e39df872152a134287ffe24f7a265653d2af8ef7082776a0dda298449e4aa73991c';
  uint256 public constant BSC_FIXED_BLOCK = 49_592_231;
}

abstract contract BscProduction is Bsc {
  // API Inputs
  uint256 public constant BSC_FEE = 0;
  uint256 public constant BSC_DEADLINE = 1_748_860_777;
  bytes public constant BSC_SIG =
    hex'd778458520627d5f6b2581508d0f1bbaee0e0ce790679ee84763c137a78a48792a2840d8142c508f8e6ada61bca2e77af3cb335e9c375723a12c7bfd50aa2e7d1c';
  uint256 public constant BSC_FIXED_BLOCK = 50_744_214;
}

///////////////////////////////// Sonic /////////////////////////////////////////
abstract contract Sonic {
  address public constant SONIC_STAGING_ROLE_MODULE = 0x439DF7B8Fd25a8815Be21b6f4E6039f31F3564E5;
  address public constant SONIC_PROD_ROLE_MODULE = 0x27a66A95EddC977a202981Ea5f6b4a0E0b63fDbE;
  bytes32 public constant SONIC_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F736F6E6963000000000000000000;

  // Bridges
  address public constant SONIC_STARGATE_USDC_POOL = 0xA272fFe20cFfe769CdFc4b63088DCD2C82a2D8F9;
}

abstract contract SonicStaging is Sonic {
  // API Inputs
  uint256 public constant SONIC_FEE = 0.0005 ether;
  uint256 public constant SONIC_DEADLINE = 1_747_140_590;
  bytes public constant SONIC_SIG =
    hex'd4872710689698da774f1feb601fdc13544ce49c00360e8353101b062e539ebf5584b24c49cf4f05453b4e5f8ecab4c451879c5dd8c79d42570c3dc62b9b1f391b';
  uint256 public constant SONIC_FIXED_BLOCK = 26_492_120;
}

abstract contract SonicProduction is Sonic {
  // API Inputs
  uint256 public constant SONIC_FEE = 0.0 ether;
  uint256 public constant SONIC_DEADLINE = 1_748_861_421;
  bytes public constant SONIC_SIG =
    hex'ad74cf50f2857af923cc268b8cca4f52d954fda8466021ecd066bb138cdd1b58378308afc0dbad7e76c8161bc6f69ff6024eaffcb614a367565b628c405a40cd1b';
  uint256 public constant SONIC_FIXED_BLOCK = 31_310_691;
}

///////////////////////////////// Berachain /////////////////////////////////////////
abstract contract Berachain {
  address public constant BERACHAIN_STAGING_ROLE_MODULE = 0xF8e6e260b83d9665901311063bCF7E6042FcaB70;
  address public constant BERACHAIN_PROD_ROLE_MODULE = 0x3BD24C518291CBe4D64ea7de23F177c883727E5D;
  bytes32 public constant BERACHAIN_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6265726100000000000000000000;

  // Bridges
  address public constant BERACHAIN_STARGATE_WETH_POOL = 0x45f1A95A4D3f3836523F5c83673c797f4d4d263B;
  address public constant BERACHAIN_STARGATE_USDC_POOL = 0xAF54BE5B6eEc24d6BFACf1cce4eaF680A8239398;
}

abstract contract BerachainStaging is Berachain {
  // API Inputs
  uint256 public constant BERACHAIN_FEE = 0.0001 ether;
  uint256 public constant BERACHAIN_DEADLINE = 1_747_141_728;
  bytes public constant BERACHAIN_SIG =
    hex'7dde6fbef7b5130cd8920872ef23db6fefc9bcedef97ece4a81e19cbab67d7ae03e1041a4cf59862b839842d03c56c4b4f5e36646e0ffb58bac365e51f9cb2c11b';
  uint256 public constant BERACHAIN_FIXED_BLOCK = 4_956_737;
}

abstract contract BerachainProduction is Berachain {
  // API Inputs
  uint256 public constant BERACHAIN_FEE = 0.0 ether;
  uint256 public constant BERACHAIN_DEADLINE = 1_748_861_774;
  bytes public constant BERACHAIN_SIG =
    hex'44a52681594bb8d4eb2b71f2a6ecdb12add6ceafc08132ee5522179eb353924947110ef29bac3f53660b0705da7cf80c26d9e2b039c1e31c2936a6008bab68961b';
  uint256 public constant BERACHAIN_FIXED_BLOCK = 5_833_923;
}

///////////////////////////////// Mantle /////////////////////////////////////////
abstract contract Mantle {
  address public constant MANTLE_STAGING_ROLE_MODULE = 0x0098084D57e6Db1522215BE2776554E42f4a65d7;
  address public constant MANTLE_PROD_ROLE_MODULE = 0xe96FbdfCA933aeEB73bB7b5017bdb9534fBaB187;
  bytes32 public constant MANTLE_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6D616E746C650000000000000000;

  // Bridges
  address public constant MANTLE_STARGATE_WETH_POOL = 0x4c1d3Fc3fC3c177c3b633427c2F769276c547463;
  address public constant MANTLE_STARGATE_USDC_POOL = 0xAc290Ad4e0c891FDc295ca4F0a6214cf6dC6acDC;
  address public constant MANTLE_STARGATE_USDT_POOL = 0xB715B85682B731dB9D5063187C450095c91C57FC;
}

abstract contract MantleStaging is Mantle {
  // Api Inputs
  uint256 public constant MANTLE_FEE = 0.0005 ether;
  uint256 public constant MANTLE_DEADLINE = 1_747_142_792;
  bytes public constant MANTLE_SIG =
    hex'dfb617378ce7f2e9ba6ac15e6b18a3e39a412184cbbb1a41498dc928c21381cf45e11745613395ea890923856f0c24b7827746e20fb3e0b0896baa468b0511f21b';
  uint256 public constant MANTLE_FIXED_BLOCK = 79_505_646;
}

abstract contract MantleProduction is Mantle {
  // Api Inputs
  uint256 public constant MANTLE_FEE = 0.0 ether;
  uint256 public constant MANTLE_DEADLINE = 1_748_861_883;
  bytes public constant MANTLE_SIG =
    hex'2ad78fe17890fb30826f322bf93da1896e7dad7503518296f1ec7f34279d2b1c250602be572721084903cf883a3effc0c3d6bc74fcb9d0736ac9d028f73aa8cb1c';
  uint256 public constant MANTLE_FIXED_BLOCK = 80_365_499;
}

///////////////////////////////// Blast /////////////////////////////////////////
abstract contract Blast {
  address public constant BLAST_STAGING_ROLE_MODULE = 0x14bc534044B557bBb5E9A63473e761176bE665f6;
  address public constant BLAST_PROD_ROLE_MODULE = 0x6F7110b88F7a111Be53FbE95aFd40C2587CD2629;
  bytes32 public constant BLAST_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f626c617374000000000000000000;

  // Active Addresses used due to sstore writing issues with deal on fork
  address public constant BLAST_WHALE = 0xC748532C202828969b2Ee68E0F8487E69cC1d800;

  // Bridges
  address public constant BLAST_ACROSS_SPOKE_POOL = 0x2D509190Ed0172ba588407D4c2df918F955Cc6E1;
}

abstract contract BlastStaging is Blast {
  // API Inputs
  uint256 public constant BLAST_FEE = 0.006 ether;
  uint256 public constant BLAST_DEADLINE = 1_747_138_533;
  bytes public constant BLAST_SIG =
    hex'22787bcfef8f160a81c38f2cea4ac8200b366dab215909406f993c3d963e12120d4afc2b00a13ead8897e926536dfdf6e67eb52abd4a960cc6e72a49114117ff1b';
  uint256 public constant BLAST_FIXED_BLOCK = 19_164_041;
}

abstract contract BlastProduction is Blast {
  // API Inputs
  uint256 public constant BLAST_FEE = 0.0 ether;
  uint256 public constant BLAST_DEADLINE = 1_748_867_578;
  bytes public constant BLAST_SIG =
    hex'c6e1208b32a538bb2936287c13955e895208185b4801a795b896d3df4976e34f64d5daf2a7ad4891bc84a99cb0c0e44546307879a878eb4db22667f5cd0fc68e1c';
  uint256 public constant BLAST_FIXED_BLOCK = 20_028_594;
}

///////////////////////////////// Scroll /////////////////////////////////////////
abstract contract Scroll {
  address public constant SCROLL_STAGING_ROLE_MODULE = 0xfFbA1Fef54b229705Aacf2A8431D7B7d2D2000A0;
  address public constant SCROLL_PROD_ROLE_MODULE = 0xB9E4680CE7a3b67CB0C9FB74329b463D0C552D2C;
  bytes32 public constant SCROLL_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F7363726F6C6C0000000000000000;

  // Bridges
  address public constant SCROLL_ACROSS_SPOKE_POOL = 0x9295ee1d8C5b022Be115A2AD3c30C72E34e7F096;
  address public constant SCROLL_STARGATE_WETH_POOL = 0xC2b638Cb5042c1B3c5d5C969361fB50569840583;
  address public constant SCROLL_STARGATE_USDC_POOL = 0x3Fc69CC4A842838bCDC9499178740226062b14E4;
}

abstract contract ScrollStaging is Scroll {
  // Api Inputs
  uint256 public constant SCROLL_FEE = 0.000106 ether;
  uint256 public constant SCROLL_DEADLINE = 1_747_139_007;
  bytes public constant SCROLL_SIG =
    hex'44dbf68f2a10df230f0d0dd340621a6b17fd5b415235cb3d3e156c2328f32d805c44bff82374cc0ee526964e940be68c80be58898852eb92ad2fda33ca3a38361c';
  uint256 public constant SCROLL_FIXED_BLOCK = 15_411_273;
}

abstract contract ScrollProduction is Scroll {
  // Api Inputs
  uint256 public constant SCROLL_FEE = 0.0 ether;
  uint256 public constant SCROLL_DEADLINE = 1_748_862_172;
  bytes public constant SCROLL_SIG =
    hex'95360e8a51c76f24cde27addd1d536db3cda6289af26d19b254830133217caa716d8a19e71f915d9f0c4c62c8ac60bb92268d3f6569adda4947a1e47b145c91c1c';
  uint256 public constant SCROLL_FIXED_BLOCK = 16_167_846;
}

///////////////////////////////// Ink /////////////////////////////////////////
abstract contract Ink {
  address public constant INK_STAGING_ROLE_MODULE = 0x647Fe289E2D746Ee1eA88d1a3b6a95c5BAde2f17;
  address public constant INK_PROD_ROLE_MODULE = 0x4C0f90BaB08C92b88a4bf9e20Aa90882991e275A;
  bytes32 public constant INK_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f696e6b0000000000000000000000;

  // Bridges
  address public constant INK_ACROSS_SPOKE_POOL = 0xeF684C38F94F48775959ECf2012D7E864ffb9dd4;
  address public constant INK_STARGATE_USDC_POOL = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
}

abstract contract InkStaging is Ink {
  // Api Inputs
  uint256 public constant INK_FEE = 0.0001 ether;
  uint256 public constant INK_DEADLINE = 1_747_143_461;
  bytes public constant INK_SIG =
    hex'70fd6cac50837d6a3686b10312e428f953e2877ab2de38149b22cacb6161fb5953611fea0136f12cbb09d058253d4a52aeaaf06873e681d9131ab95b8c87af621b';
  uint256 public constant INK_FIXED_BLOCK = 13_644_402;
}

abstract contract InkProduction is Ink {
  // Api Inputs
  uint256 public constant INK_FEE = 0.0 ether;
  uint256 public constant INK_DEADLINE = 1_748_862_242;
  bytes public constant INK_SIG =
    hex'e8d07b1a60c32a6852f2e4cea0d5eb2aa88b303be324a9539f234419430d1e6d020ce3742af66a4da699801e997e223bc5e955ba596d0d510d63a745a18b22fa1c';
  uint256 public constant INK_FIXED_BLOCK = 15_363_260;
}

///////////////////////////////// Unichain /////////////////////////////////////////
abstract contract Unichain {
  address public constant UNICHAIN_STAGING_ROLE_MODULE = 0x715302b659804c40CF83eb5D2e33Bb4b35c8A854;
  address public constant UNICHAIN_PROD_ROLE_MODULE = 0xA7d61d5a488A2502F1193ae8aAb710C67239c192;
  bytes32 public constant UNICHAIN_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F756E69636861696E000000000000;

  // Bridges
  address public constant UNICHAIN_ACROSS_SPOKE_POOL = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
  address public constant UNICHAIN_STARGATE_WETH_POOL = 0xe9aBA835f813ca05E50A6C0ce65D0D74390F7dE7;
}

abstract contract UnichainStaging is Unichain {
  // Api Inputs
  uint256 public constant UNICHAIN_FEE = 0.0007 ether;
  uint256 public constant UNICHAIN_DEADLINE = 1_747_144_179;
  bytes public constant UNICHAIN_SIG =
    hex'0359d8bbb660e4448ae753d19d850109c52c3add6a7baab32f4a3f8f59bc3a3b77809a80f30af6b4d4f0c85f54846a01df93e634c4133e5c4afd07c770ba6cbe1b';
  uint256 public constant UNICHAIN_FIXED_BLOCK = 16_395_066;
}

abstract contract UnichainProduction is Unichain {
  // Api Inputs
  uint256 public constant UNICHAIN_FEE = 0.0 ether;
  uint256 public constant UNICHAIN_DEADLINE = 1_748_867_094;
  bytes public constant UNICHAIN_SIG =
    hex'24ad6a6a47ec86289c35700646cff903faadc8b8b282b5efcdc6c6a5b01111a551362fd8e57ac85d8f7008d6951c2195f5bd6a1c0ad1c68311ed40fb9aae9ca31b';
  uint256 public constant UNICHAIN_FIXED_BLOCK = 18_118_164;
}

///////////////////////////////// Mode /////////////////////////////////////////
abstract contract Mode {
  address public constant MODE_STAGING_ROLE_MODULE = 0x3CACE76d4b1da3a7e7D2643073710aB9F27807E0;
  address public constant MODE_PROD_ROLE_MODULE = 0xeF708DaE471348a015d8bC083A14022ea174Ea7a;
  bytes32 public constant MODE_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f6d6f646500000000000000000000;

  // Bridges
  address public constant MODE_ACROSS_SPOKE_POOL = 0x3baD7AD0728f9917d1Bf08af5782dCbD516cDd96;
}

abstract contract ModeStaging is Mode {
  // Api Inputs
  uint256 public constant MODE_FEE = 0.004 ether;
  uint256 public constant MODE_DEADLINE = 1_747_145_892;
  bytes public constant MODE_SIG =
    hex'19638a66549be0110f38c58e3175dbb6890cfd4b0fbecaa8826dfa02c9218edc0394aaaefbafb923841c0e1e53f54f1ad589e4fbe098de0a3020fda36cd455091b';
  uint256 public constant MODE_FIXED_BLOCK = 23_488_838;
}

abstract contract ModeProduction is Mode {
  // Api Inputs
  uint256 public constant MODE_FEE = 0.0 ether;
  uint256 public constant MODE_DEADLINE = 1_748_867_230;
  bytes public constant MODE_SIG =
    hex'e42103156e712e5a55362c0299787edc77902220ef2a5950e87b47a4b87f57ad751978d71c0f656b276d0b69471313dd8843612157444bf04940f64563efb3d21c';
  uint256 public constant MODE_FIXED_BLOCK = 24_349_642;
}

///////////////////////////////// Ronin /////////////////////////////////////////
abstract contract Ronin {
  address public constant RONIN_STAGING_ROLE_MODULE = 0xF6436435d715e027B42e6300BCE122C02611b788;
  address public constant RONIN_PROD_ROLE_MODULE = 0xe225d8499f263E60F5D76F33375D77A461b5c63d;
  bytes32 public constant RONIN_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f726f6e696e000000000000000000;
}

abstract contract RoninStaging is Ronin {
  // Api Inputs
  uint256 public constant RONIN_FEE = 0.00025 ether;
  uint256 public constant RONIN_DEADLINE = 1_747_151_912;
  bytes public constant RONIN_SIG =
    hex'008201aa7243e8492a8aede88d19cbd95c7bd863c414ef0f522c052a487014f56e7075961313b22ccf22c0c5f4b52a316ad32024808354ed271bb7b94bedd59c1b';
  uint256 public constant RONIN_FIXED_BLOCK = 45_099_362;
}

abstract contract RoninProduction is Ronin {
  // Api Inputs
  uint256 public constant RONIN_FEE = 0.0 ether;
  uint256 public constant RONIN_DEADLINE = 1_748_868_475;
  bytes public constant RONIN_SIG =
    hex'6c3505c857b7a88158d6a7cd356ee73fae234538cdb265273d8b04fa66f8197c60faf0763f1ab16995f5e3479581bd8151281f63d14730f162a32b5b386396801c';
  uint256 public constant RONIN_FIXED_BLOCK = 45_671_551;
}

///////////////////////////////// Avalanche /////////////////////////////////////////
abstract contract Avalanche {
  address public constant AVALANCHE_STAGING_ROLE_MODULE = 0x4900c96157283032FF0C1e680960505E2831386A;
  address public constant AVALANCHE_PROD_ROLE_MODULE = 0x2A801Ebd0345C86a8Ed4CD7887B6197faC0c2D45;
  bytes32 public constant AVALANCHE_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f6176617800000000000000000000;

  // Bridges
  address public constant AVALANCHE_STARGATE_USDC_POOL = 0x5634c4a5FEd09819E3c46D86A965Dd9447d86e47;
  address public constant AVALANCHE_STARGATE_USDT_POOL = 0x12dC9256Acc9895B076f6638D628382881e62CeE;
}

abstract contract AvalancheStaging is Avalanche {
  // Api Inputs
  uint256 public constant AVALANCHE_FEE = 0.00025 ether;
  uint256 public constant AVALANCHE_DEADLINE = 1_747_228_398;
  bytes public constant AVALANCHE_SIG =
    hex'3866c3de5bbcda9fffc32292b35abd1df99a5f478614c964e782fe9750005e3c51f0260d252da42f191f7c35b82f333abf75054c036aad079bc03d144ef9e05a1b';
  uint256 public constant AVALANCHE_FIXED_BLOCK = 62_017_749;
}

abstract contract AvalancheProduction is Avalanche {
  // Api Inputs
  uint256 public constant AVALANCHE_FEE = 0.0 ether;
  uint256 public constant AVALANCHE_DEADLINE = 1_748_867_706;
  bytes public constant AVALANCHE_SIG =
    hex'21ec1bf427a7d0f40083abdc0e1140bd06e310c4600ef95cc4b57b4c7f7b24ff77d212cef13e685d7d35db7f2e9efc387bde1e603f1b4464ee7a2bd3235ed9dc1c';
  uint256 public constant AVALANCHE_FIXED_BLOCK = 63_174_337;
}

// // NOTE: Unsupported in the API
// abstract contract Apechain {
//   address public constant APECHAIN_STAGING_ROLE_MODULE = 0x409687604697aE845b7dd2204C50F3a0bDC09e84;
//   address public constant APECHAIN_PROD_ROLE_MODULE = 0x404a75E5C484ffd2cd013c0D0F9CBf0b5eb08cF9
//   bytes32 public constant APECHAIN_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f617065636861696e000000000000;

//   // Api Inputs
//   uint256 public constant APECHAIN_FEE = 0 ether;
//   uint256 public constant APECHAIN_DEADLINE = ;
//   bytes public constant APECHAIN_SIG =
//     hex'';
//   uint256 public constant APECHAIN_FIXED_BLOCK = 15620102;
// }

// NOTE: Zodiac Roles contract compilation issue - <shanghai version
// abstract contract Linea {
//   address public constant LINEA_STAGING_ROLE_MODULE = ;
//   bytes32 public constant LINEA_ROLE_KEY = ;

//   // Api Inputs
//     uint256 public constant LINEA_FEE = 0 ether;
//   uint256 public constant LINEA_DEADLINE = ;
//   bytes public constant LINEA_SIG =
//     hex'';
// }

// abstract contract Taiko {
//   address public constant TAIKO_STAGING_ROLE_MODULE = ;
//   bytes32 public constant TAIKO_ROLE_KEY = ;

//   // Api Inputs
//     uint256 public constant TAIKO_FEE = 0 ether;
//   uint256 public constant TAIKO_DEADLINE = ;
//   bytes public constant TAIKO_SIG =
//     hex'';
// }

// abstract contract Zircuit {
//   address public constant ZIRCUIT_STAGING_ROLE_MODULE = ;
//   bytes32 public constant ZIRCUIT_ROLE_KEY = ;

//   // Api Inputs
//     uint256 public constant ZIRCUIT_FEE = 0 ether;
//   uint256 public constant ZIRCUIT_DEADLINE = ;
//   bytes public constant ZIRCUIT_SIG =
//     hex'';
// }

abstract contract ZodiacProductionEnvironment is
  EthereumProduction,
  ArbitrumProduction,
  BlastProduction,
  OptimismProduction,
  PolygonProduction,
  BaseProduction,
  SonicProduction,
  ScrollProduction,
  BerachainProduction,
  BscProduction,
  MantleProduction,
  InkProduction,
  UnichainProduction,
  ModeProduction,
  RoninProduction,
  AvalancheProduction
{}

abstract contract ZodiacStagingEnvironment is
  EthereumStaging,
  ArbitrumStaging,
  BlastStaging,
  OptimismStaging,
  PolygonStaging,
  BaseStaging,
  SonicStaging,
  ScrollStaging,
  BerachainStaging,
  BscStaging,
  MantleStaging,
  InkStaging,
  UnichainStaging,
  ModeStaging,
  RoninStaging,
  AvalancheStaging
{}

abstract contract ZodiacHelper is Test {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  struct ZodiacConfiguration {
    address safeAddress;
    address roleModule;
    address feeAdapter;
    bytes32 roleKey;
    uint256 validFee;
    uint256 validDeadline;
    bytes validSignature;
    address weth;
    address usdc;
    address usdt;
    uint256 fixedBlock;
  }

  struct ExternalAddresses {
    address across;
    address stargateWeth;
    address stargateUsdc;
    address stargateUsdt;
    address cbBTC;
  }

  struct BridgeParams {
    uint256 destination;
    address asset;
    address caller;
    address receiver;
    address depositor;
    address inputToken;
    uint256 inputAmount;
    uint256 outputAmount;
    uint32 quoteTimestamp;
    uint32 fillDeadline;
    address exclusiveRelayer;
    uint32 exclusivityDeadline;
    address across;
    uint256 nativeFee;
    bytes message;
  }

  // Constants
  address public constant BINANCE_EVM_ADDRESS = 0x815c54AbEdD9f4dB64f8B0Da39513f6bFB11eA03;
  address public constant BYBIT_EVM_ADDRESS = 0x0e35B40A780DfEe1D3fE9955602C3cF65c7A6a16;
  address public constant SAFE_TEST_ADDRESS = 0x2eEd1440842990Fa61F0c396f981375Fa6004131;
  address public constant APPROVED_CALLER = SAFE_TEST_ADDRESS;
  address public constant STAGING_MULTI_SIG_ADDRESS = 0xC55749A006f6B2098dF802b1711522498b83Fae3;
  address public constant PROD_MULTI_SIG_ADDRESS = 0xe569ea3158bB89aD5CFD8C06f0ccB3aD69e0916B;
  address public constant STAGING_RONIN_SAFE_ADDRESS = 0x1B1435cc68074bc8DC7BD798498b4d90DB0A94B0;
  address public constant PROD_RONIN_SAFE_ADDRESS = 0x1d09f3b11A8FF71F4177da1969A53658A801dC0e;
  uint256 public constant EXPECTED_THRESHOLD = 1;
  bytes4 public constant NEW_INTENT_ADDRESS_SELECTOR =
    bytes4(keccak256('newIntent(uint32[],address,address,address,uint256,uint24,uint48,bytes,(uint256,uint256,bytes))'));
  address public constant INVALID_CALLER = address(0x123);
  address public constant INVALID_SPENDER = address(0x456);
  address public constant INVALID_RECEIVER = address(0x789);
  address public constant PROPOSER_1 = 0xb60d0C2E8309518373b40f8Eaa2CAd0d1De3deCb;
  address public constant PROPOSER_2 = 0xbB318a1ab8E46DFd93b3B0Bca3d0EBF7d00187B9;
  bytes32 public constant INVALID_ROLE_KEY = bytes32(0x1000000000000000000000000000000000000000000000000000000000000001);
  uint48 public constant ZERO_TTL = 0;
  uint24 public constant ZERO_FEE = 0;
  uint48 public constant NONZERO_TTL = 1 days;
  uint24 public constant NONZERO_FEE = 100;

  IFeeAdapter public feeAdapter;
  IRoleModule public roleModule;

  mapping(uint256 => ZodiacConfiguration) public _zodiacConfig;
  mapping(uint256 => ExternalAddresses) public _addressConfig;

  ///////////////////////////////////////////// Helper Functions /////////////////////////////////////////////
  function _checkRolesConfiguration(
    ZodiacConfiguration memory config
  ) public view {
    assertEq(roleModule.owner(), config.safeAddress);
    assertEq(roleModule.avatar(), config.safeAddress);
    assertEq(roleModule.target(), config.safeAddress);
  }

  function _checkSafeConfiguration(
    ZodiacConfiguration memory config
  ) public view {
    ISafe safe = ISafe(config.safeAddress);
    assertEq(safe.getThreshold(), EXPECTED_THRESHOLD);
    assertEq(safe.isModuleEnabled(config.roleModule), true);
  }

  function _approveAsset(
    address _asset,
    address _caller,
    address _spender,
    ZodiacConfiguration memory _config,
    uint256 _amount,
    bool _expectRevert
  ) public {
    // Configuring the calldata
    bytes memory approveCalldata = abi.encodeWithSelector(IERC20.approve.selector, _spender, _amount);

    // Calling the module
    vm.startPrank(_caller);
    if (_expectRevert) vm.expectRevert();
    roleModule.execTransactionWithRole(_asset, 0, approveCalldata, 0, _config.roleKey, true);
    vm.stopPrank();
  }

  function _transferEth(
    address _caller,
    address _receiver,
    uint256 _amount,
    bytes32 _roleKey,
    bool _expectRevert
  ) public {
    // Calling the module
    vm.startPrank(_caller);
    if (_expectRevert) vm.expectRevert();
    roleModule.execTransactionWithRole(_receiver, _amount, '', 0, _roleKey, true);
    vm.stopPrank();
  }

  function _transferAsset(
    address _asset,
    address _caller,
    address _receiver,
    ZodiacConfiguration memory _config,
    uint256 _amount,
    bool _expectRevert
  ) public {
    // Configuring the calldata
    bytes memory transferCalldata = abi.encodeWithSelector(IERC20.transfer.selector, _receiver, _amount);

    // Calling the module
    vm.startPrank(_caller);
    if (_expectRevert) vm.expectRevert();
    roleModule.execTransactionWithRole(_asset, 0, transferCalldata, 0, _config.roleKey, true);
    vm.stopPrank();
  }

  function _dealFunds(address _asset, uint256[] memory _amounts, uint256 _fee, address _safeAddress) public {
    // summing amounts and dealing to safe
    uint256 _totalAmount = _fee;
    for (uint256 i = 0; i < _amounts.length; i++) {
      _totalAmount += _amounts[i];
    }
    deal(_asset, _safeAddress, _totalAmount);
  }

  function _dealFundsFromActive(address _asset, uint256 _amount, address _from, address _to) internal {
    vm.startPrank(_from);
    IERC20(_asset).transfer(_to, _amount);
    vm.stopPrank();
  }

  function _unwrapWETH(address _weth, uint256 _amount, bytes32 _roleKey, address _caller, bool _expectRevert) internal {
    vm.startPrank(_caller);
    if (_expectRevert) vm.expectRevert();
    bytes memory withdrawCalldata = abi.encodeWithSelector(IWETH.withdraw.selector, _amount);
    roleModule.execTransactionWithRole(_weth, 0, withdrawCalldata, 0, _roleKey, true);
    vm.stopPrank();
  }

  function _wrapWETH(address _weth, uint256 _ethAmount, bytes32 _roleKey, address _caller, bool _expectRevert) internal {
    vm.startPrank(_caller);
    if (_expectRevert) vm.expectRevert();
    bytes memory depositCalldata = abi.encodeWithSelector(IWETH.deposit.selector);
    roleModule.execTransactionWithRole(_weth, _ethAmount, depositCalldata, 0, _roleKey, true);
    vm.stopPrank();
  }

  function _sendStargate(
    BridgeParams memory _params,
    ZodiacConfiguration memory _config,
    address _refundAddress,
    address _stargate,
    bool _expectRevert
  ) internal {
    _sendStargate(_params, _config, _refundAddress, _stargate, _expectRevert, '', '');
  }

  function _sendStargate(
    BridgeParams memory _params,
    ZodiacConfiguration memory _config,
    address _refundAddress,
    address _stargate,
    bool _expectRevert,
    bytes memory _extraOptions,
    bytes memory _composeMsg
  ) internal {
    // configuring the calldata
    bytes memory sendCalldata = abi.encodeWithSelector(
      IStargatePool.send.selector,
      IStargatePool.SendParams({
        dstEid: uint32(_params.destination),
        to: _params.receiver.toBytes32(),
        amountLD: _params.inputAmount,
        minAmountLD: _params.outputAmount,
        extraOptions: _extraOptions,
        composeMsg: _composeMsg,
        oftCmd: ''
      }),
      IStargatePool.MessagingFee({nativeFee: _params.nativeFee, lzTokenFee: 0}),
      _refundAddress
    );

    // calling the module
    vm.startPrank(_params.caller);
    if (_expectRevert) vm.expectRevert();
    roleModule.execTransactionWithRole(_stargate, _params.nativeFee, sendCalldata, 0, _config.roleKey, true);
    vm.stopPrank();
  }

  function _sendStargateWeth(
    BridgeParams memory _params,
    ZodiacConfiguration memory _config,
    address _refundAddress,
    address _stargate,
    bool _expectRevert
  ) internal {
    // configuring the calldata
    bytes memory sendCalldata = abi.encodeWithSelector(
      IStargatePool.send.selector,
      IStargatePool.SendParams({
        dstEid: uint32(_params.destination),
        to: _params.receiver.toBytes32(),
        amountLD: _params.inputAmount,
        minAmountLD: _params.outputAmount,
        extraOptions: '',
        composeMsg: '',
        oftCmd: ''
      }),
      IStargatePool.MessagingFee({nativeFee: _params.nativeFee, lzTokenFee: 0}),
      _refundAddress
    );

    // calling the module
    vm.startPrank(_params.caller);
    if (_expectRevert) vm.expectRevert();
    roleModule.execTransactionWithRole(
      _stargate, _params.inputAmount + _params.nativeFee, sendCalldata, 0, _config.roleKey, true
    );
    vm.stopPrank();
  }

  function _sendDepositV3(BridgeParams memory _params, ZodiacConfiguration memory _config, bool _expectRevert) internal {
    // configuring the calldata
    bytes memory depositCalldata = abi.encodeWithSelector(
      IAcrossSpokePool.depositV3.selector,
      _params.depositor,
      _params.receiver,
      _params.inputToken,
      address(0),
      _params.inputAmount,
      _params.outputAmount,
      _params.destination,
      _params.exclusiveRelayer,
      _params.quoteTimestamp,
      _params.fillDeadline,
      _params.exclusivityDeadline,
      _params.message
    );

    // calling the module
    vm.startPrank(_params.caller);
    if (_expectRevert) vm.expectRevert();
    roleModule.execTransactionWithRole(_params.across, 0, depositCalldata, 0, _config.roleKey, true);
    vm.stopPrank();
  }

  function _sendNewIntent(
    uint32[] memory _destinations,
    uint256[] memory _amounts,
    ZodiacConfiguration memory config,
    address _asset,
    address _caller,
    address _receiver,
    bool _expectRevert
  ) public {
    _sendNewIntent(_destinations, _amounts, config, _asset, _caller, _receiver, _expectRevert, 0, 0);
  }

  function _sendNewIntent(
    uint32[] memory _destinations,
    uint256[] memory _amounts,
    ZodiacConfiguration memory config,
    address _asset,
    address _caller,
    address _receiver,
    bool _expectRevert,
    uint48 _ttl,
    uint24 _maxFee
  ) public {
    // Configuring the calldata
    IFeeAdapter.FeeParams memory feeParams =
      IFeeAdapter.FeeParams({fee: config.validFee, deadline: config.validDeadline, sig: config.validSignature});
    bytes memory newIntentCalldata = abi.encodeWithSelector(
      NEW_INTENT_ADDRESS_SELECTOR, _destinations, _receiver, _asset, address(0), 1 ether, _ttl, _maxFee, '', feeParams
    );

    // Calling the module
    vm.startPrank(_caller);
    if (_expectRevert) vm.expectRevert();
    roleModule.execTransactionWithRole(config.feeAdapter, 0, newIntentCalldata, 0, config.roleKey, true);
    vm.stopPrank();
  }

  function _sendNewOrder(
    uint32[] memory _destinations,
    uint256[] memory _amounts,
    ZodiacConfiguration memory config,
    address _asset,
    address _caller,
    address _receiver,
    bool _expectRevert
  ) public {
    _sendNewOrder(_destinations, _amounts, config, _asset, _caller, _receiver, _expectRevert, 0, 0);
  }

  function _sendNewOrder(
    uint32[] memory _destinations,
    uint256[] memory _amounts,
    ZodiacConfiguration memory config,
    address _asset,
    address _caller,
    address _receiver,
    bool _expectRevert,
    uint48 _ttl,
    uint24 _maxFee
  ) public {
    // Configuring the order params
    IFeeAdapter.OrderParameters[] memory _orderParams = new IFeeAdapter.OrderParameters[](2);
    _orderParams[0] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: _receiver,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: _maxFee,
      ttl: _ttl,
      data: ''
    });
    _orderParams[1] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: _receiver,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[1],
      maxFee: _maxFee,
      ttl: _ttl,
      data: ''
    });

    // Configuring the calldata
    bytes memory newOrderCalldata = abi.encodeWithSelector(
      IFeeAdapter.newOrder.selector, config.validFee, config.validDeadline, config.validSignature, _orderParams
    );

    // Calling the module
    vm.startPrank(_caller);
    if (_expectRevert) vm.expectRevert();
    roleModule.execTransactionWithRole(config.feeAdapter, 0, newOrderCalldata, 0, config.roleKey, true);
    vm.stopPrank();
  }

  function _sendNewOrderInvalidFirstArrayReceiver(
    uint32[] memory _destinations,
    uint256[] memory _amounts,
    ZodiacConfiguration memory config,
    address _asset,
    address _caller
  ) public {
    // Configuring the order params
    IFeeAdapter.OrderParameters[] memory _orderParams = new IFeeAdapter.OrderParameters[](2);
    _orderParams[0] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: INVALID_RECEIVER,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[1] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[1],
      maxFee: 0,
      ttl: 0,
      data: ''
    });

    // Configuring the calldata
    bytes memory newOrderCalldata = abi.encodeWithSelector(
      IFeeAdapter.newOrder.selector, config.validFee, config.validDeadline, config.validSignature, _orderParams
    );

    // Calling the module
    vm.startPrank(_caller);
    vm.expectRevert();
    roleModule.execTransactionWithRole(config.feeAdapter, 0, newOrderCalldata, 0, config.roleKey, true);
    vm.stopPrank();
  }

  function _sendNewOrderInvalidSecondArrayReceiver(
    uint32[] memory _destinations,
    uint256[] memory _amounts,
    ZodiacConfiguration memory config,
    address _asset,
    address _caller
  ) public {
    // Configuring the order params
    IFeeAdapter.OrderParameters[] memory _orderParams = new IFeeAdapter.OrderParameters[](2);
    _orderParams[0] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[1] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: INVALID_RECEIVER,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[1],
      maxFee: 0,
      ttl: 0,
      data: ''
    });

    // Configuring the calldata
    bytes memory newOrderCalldata = abi.encodeWithSelector(
      IFeeAdapter.newOrder.selector, config.validFee, config.validDeadline, config.validSignature, _orderParams
    );

    // Calling the module
    vm.startPrank(_caller);
    vm.expectRevert();
    roleModule.execTransactionWithRole(config.feeAdapter, 0, newOrderCalldata, 0, config.roleKey, true);
    vm.stopPrank();
  }

  function _sendNewOrderInvalidFifthArrayReceiver(
    uint32[] memory _destinations,
    uint256[] memory _amounts,
    ZodiacConfiguration memory config,
    address _asset,
    address _caller
  ) public {
    // Configuring the order params
    IFeeAdapter.OrderParameters[] memory _orderParams = new IFeeAdapter.OrderParameters[](5);
    _orderParams[0] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[1] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[2] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[3] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[4] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: INVALID_RECEIVER,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[1],
      maxFee: 0,
      ttl: 0,
      data: ''
    });

    // Configuring the calldata
    bytes memory newOrderCalldata = abi.encodeWithSelector(
      IFeeAdapter.newOrder.selector, config.validFee, config.validDeadline, config.validSignature, _orderParams
    );

    // Calling the module
    vm.startPrank(_caller);
    vm.expectRevert();
    roleModule.execTransactionWithRole(config.feeAdapter, 0, newOrderCalldata, 0, config.roleKey, true);
    vm.stopPrank();
  }

  function _sendNewOrderInvalidFifthArrayTtl(
    uint32[] memory _destinations,
    uint256[] memory _amounts,
    ZodiacConfiguration memory config,
    address _asset,
    address _caller
  ) public {
    // Configuring the order params
    IFeeAdapter.OrderParameters[] memory _orderParams = new IFeeAdapter.OrderParameters[](5);
    _orderParams[0] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[1] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[2] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[3] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[4] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[1],
      maxFee: 0,
      ttl: NONZERO_TTL, // Invalid TTL
      data: ''
    });

    // Configuring the calldata
    bytes memory newOrderCalldata = abi.encodeWithSelector(
      IFeeAdapter.newOrder.selector, config.validFee, config.validDeadline, config.validSignature, _orderParams
    );

    // Calling the module
    vm.startPrank(_caller);
    vm.expectRevert();
    roleModule.execTransactionWithRole(config.feeAdapter, 0, newOrderCalldata, 0, config.roleKey, true);
    vm.stopPrank();
  }

  function _sendNewOrderInvalidFifthArrayMaxFee(
    uint32[] memory _destinations,
    uint256[] memory _amounts,
    ZodiacConfiguration memory config,
    address _asset,
    address _caller,
    address _receiver
  ) public {
    // Configuring the order params
    IFeeAdapter.OrderParameters[] memory _orderParams = new IFeeAdapter.OrderParameters[](5);
    _orderParams[0] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[1] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[2] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[3] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[0],
      maxFee: 0,
      ttl: 0,
      data: ''
    });
    _orderParams[4] = IFeeAdapter.OrderParameters({
      destinations: _destinations,
      receiver: config.safeAddress,
      inputAsset: _asset,
      outputAsset: address(0),
      amount: _amounts[1],
      maxFee: NONZERO_FEE, // Invalid fee
      ttl: 0,
      data: ''
    });

    // Configuring the calldata
    bytes memory newOrderCalldata = abi.encodeWithSelector(
      IFeeAdapter.newOrder.selector, config.validFee, config.validDeadline, config.validSignature, _orderParams
    );

    // Calling the module
    vm.startPrank(_caller);
    vm.expectRevert();
    roleModule.execTransactionWithRole(config.feeAdapter, 0, newOrderCalldata, 0, config.roleKey, true);
    vm.stopPrank();
  }
}
