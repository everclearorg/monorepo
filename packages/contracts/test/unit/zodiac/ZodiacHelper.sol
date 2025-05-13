// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IAcrossSpokePool, IRoleModule, ISafe, IStargatePool, IWETH} from './IHelpers.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import 'forge-std/Test.sol';
import {IFeeAdapter} from 'interfaces/intent/IFeeAdapter.sol';

abstract contract Arbitrum {
  address public constant ARBITRUM_ROLE_MODULE = 0xfc62b8FBC8fdDdd1997130923fD44BB785033B12;
  bytes32 public constant ARBITRUM_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f6172620000000000000000000000;

  // API Inputs
  uint256 public constant ARBITRUM_FEE = 0;
  uint256 public constant ARBITRUM_DEADLINE = 1_747_061_416;
  bytes public constant ARBITRUM_SIG =
    hex'3742402cc4e0c9c3f8f0afc5f253b353cd7412579e9939c341feeb458e711c9a588e5547fbfc4096efc52fe6fd364bdc9548549a9c612f8f15f8d04223cac7431c';
  uint256 public constant ARBITRUM_FIXED_BLOCK = 335_940_880;

  // Bridges
  address public constant ARBITRUM_ACROSS_SPOKE_POOL = 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A;
  address public constant ARBITRUM_STARGATE_WETH_POOL = 0xA45B5130f36CDcA45667738e2a258AB09f4A5f7F;
  address public constant ARBITRUM_STARGATE_USDC_POOL = 0xe8CDF27AcD73a434D661C84887215F7598e7d0d3;
  address public constant ARBITRUM_STARGATE_USDT_POOL = 0xcE8CcA271Ebc0533920C83d39F417ED6A0abB7D0;
}

abstract contract Optimism {
  address public constant OPTIMISM_ROLE_MODULE = 0x14b940d7128237CDA825fD3f2Ab5063B9DFC0613;
  bytes32 public constant OPTIMISM_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6F70000000000000000000000000;

  // API Inputs
  uint256 public constant OPTIMISM_FEE = 0;
  uint256 public constant OPTIMISM_DEADLINE = 1_747_128_274;
  bytes public constant OPTIMISM_SIG =
    hex'e329e3ed7e89ece8a250eb4d946e715da2f5716aaff56da95490f9ebb972bb1251a4be40c5c2535b2de9d3512dab22c4a9ff3254c91e78fdc368c41fff5ff6a01b';
  uint256 public constant OPTIMISM_FIXED_BLOCK = 135_764_105;

  // Bridges
  address public constant OPTIMISM_ACROSS_SPOKE_POOL = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
  address public constant OPTIMISM_STARGATE_WETH_POOL = 0xe8CDF27AcD73a434D661C84887215F7598e7d0d3;
  address public constant OPTIMISM_STARGATE_USDC_POOL = 0xcE8CcA271Ebc0533920C83d39F417ED6A0abB7D0;
  address public constant OPTIMISM_STARGATE_USDT_POOL = 0x19cFCE47eD54a88614648DC3f19A5980097007dD;
}

// abstract contract Ethereum {
//   address public constant ETHEREUM_ROLE_MODULE = ;
//   bytes32 public constant ETHEREUM_ROLE_KEY = ;

//   // API Inputs
//   uint256 public constant ETHEREUM_FEE = 0;
//   uint256 public constant ETHEREUM_DEADLINE = 0;
//   bytes public constant ETHEREUM_SIG =
//     hex'';
// }

abstract contract Polygon {
  address public constant POLYGON_ROLE_MODULE = 0x5d03263e18CB9623e0bbE9FBf7cf3347Bb7d551f;
  bytes32 public constant POLYGON_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f706f6c79676f6e00000000000000;

  // API Inputs
  uint256 public constant POLYGON_FEE = 0.000107 ether;
  uint256 public constant POLYGON_DEADLINE = 1_747_130_983;
  bytes public constant POLYGON_SIG =
    hex'daa784afa9790cf081561d1b807b8ace402e05cdc915827248bcaf047c25a0e42e4b8a17dd6c2ceda7ce443fc58f6bd2488d461b7a73fe756798d595e3d803e21b';
  uint256 public constant POLYGON_FIXED_BLOCK = 71_461_569;

  // Bridges
  address public constant POLYGON_ACROSS_SPOKE_POOL = 0x9295ee1d8C5b022Be115A2AD3c30C72E34e7F096;
  address public constant POLYGON_STARGATE_USDC_POOL = 0x9Aa02D4Fae7F58b8E8f34c66E756cC734DAc7fe4;
  address public constant POLYGON_STARGATE_USDT_POOL = 0xd47b03ee6d86Cf251ee7860FB2ACf9f91B9fD4d7;
}

abstract contract Bsc {
  address public constant BSC_ROLE_MODULE = 0x5f67084B92abaB83002fE562Be9E761Ba99603E1;
  bytes32 public constant BSC_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6273630000000000000000000000;

  // API Inputs
  uint256 public constant BSC_FEE = 0;
  uint256 public constant BSC_DEADLINE = 1_747_132_224;
  bytes public constant BSC_SIG =
    hex'7210553206854228e610016ca7ad380827380ff168df9fc4df922a448f2be19e39df872152a134287ffe24f7a265653d2af8ef7082776a0dda298449e4aa73991c';
  uint256 public constant BSC_FIXED_BLOCK = 49_592_231;

  // Bridges
  address public constant BSC_STARGATE_USDC_POOL = 0x962Bd449E630b0d928f308Ce63f1A21F02576057;
  address public constant BSC_STARGATE_USDT_POOL = 0x138EB30f73BC423c6455C53df6D89CB01d9eBc63;
}

abstract contract Base {
  address public constant BASE_ROLE_MODULE = 0x5818a6540c2591BD990B24fA180Ca3217A2f9Cd4;
  bytes32 public constant BASE_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6261736500000000000000000000;

  // API Inputs
  uint256 public constant BASE_FEE = 0;
  uint256 public constant BASE_DEADLINE = 1_747_131_509;
  bytes public constant BASE_SIG =
    hex'40e9f2f1d36a837078ab8e72880c565f816f289fa05277f0fb22b6cc34690f84027c3d891dfe3452eaa8e8253641afde0d69f90509e94ebd05daa9b780c293141c';
  uint256 public constant BASE_FIXED_BLOCK = 30_170_741;

  // Bridges
  address public constant BASE_ACROSS_SPOKE_POOL = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
  address public constant BASE_STARGATE_WETH_POOL = 0xdc181Bd607330aeeBEF6ea62e03e5e1Fb4B6F7C7;
  address public constant BASE_STARGATE_USDC_POOL = 0x27a16dc786820B16E5c9028b75B99F6f604b5d26;
}

abstract contract Sonic {
  address public constant SONIC_ROLE_MODULE = 0x439DF7B8Fd25a8815Be21b6f4E6039f31F3564E5;
  bytes32 public constant SONIC_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F736F6E6963000000000000000000;

  // API Inputs
  uint256 public constant SONIC_FEE = 0.0005 ether;
  uint256 public constant SONIC_DEADLINE = 1_747_140_590;
  bytes public constant SONIC_SIG =
    hex'd4872710689698da774f1feb601fdc13544ce49c00360e8353101b062e539ebf5584b24c49cf4f05453b4e5f8ecab4c451879c5dd8c79d42570c3dc62b9b1f391b';
  uint256 public constant SONIC_FIXED_BLOCK = 26_492_120;

  // Bridges
  address public constant SONIC_STARGATE_USDC_POOL = 0xA272fFe20cFfe769CdFc4b63088DCD2C82a2D8F9;
}

abstract contract Berachain {
  address public constant BERACHAIN_ROLE_MODULE = 0xF8e6e260b83d9665901311063bCF7E6042FcaB70;
  bytes32 public constant BERACHAIN_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6265726100000000000000000000;

  // API Inputs
  uint256 public constant BERACHAIN_FEE = 0.0001 ether;
  uint256 public constant BERACHAIN_DEADLINE = 1_747_141_728;
  bytes public constant BERACHAIN_SIG =
    hex'7dde6fbef7b5130cd8920872ef23db6fefc9bcedef97ece4a81e19cbab67d7ae03e1041a4cf59862b839842d03c56c4b4f5e36646e0ffb58bac365e51f9cb2c11b';
  uint256 public constant BERACHAIN_FIXED_BLOCK = 4_956_737;

  // Bridges
  address public constant BERACHAIN_STARGATE_WETH_POOL = 0x45f1A95A4D3f3836523F5c83673c797f4d4d263B;
  address public constant BERACHAIN_STARGATE_USDC_POOL = 0xAF54BE5B6eEc24d6BFACf1cce4eaF680A8239398;
}

abstract contract Mantle {
  address public constant MANTLE_ROLE_MODULE = 0x0098084D57e6Db1522215BE2776554E42f4a65d7;
  bytes32 public constant MANTLE_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6D616E746C650000000000000000;

  // Api Inputs
  uint256 public constant MANTLE_FEE = 0.0005 ether;
  uint256 public constant MANTLE_DEADLINE = 1747142792;
  bytes public constant MANTLE_SIG =
    hex'dfb617378ce7f2e9ba6ac15e6b18a3e39a412184cbbb1a41498dc928c21381cf45e11745613395ea890923856f0c24b7827746e20fb3e0b0896baa468b0511f21b';
  uint256 public constant MANTLE_FIXED_BLOCK = 79_505_646;

  // Bridges
  address public constant MANTLE_STARGATE_WETH_POOL = 0x4c1d3Fc3fC3c177c3b633427c2F769276c547463;
  address public constant MANTLE_STARGATE_USDC_POOL = 0xAc290Ad4e0c891FDc295ca4F0a6214cf6dC6acDC;
  address public constant MANTLE_STARGATE_USDT_POOL = 0xB715B85682B731dB9D5063187C450095c91C57FC;
}

abstract contract Blast {
  address public constant BLAST_ROLE_MODULE = 0x14bc534044B557bBb5E9A63473e761176bE665f6;
  bytes32 public constant BLAST_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f626c617374000000000000000000;

  // API Inputs
  uint256 public constant BLAST_FEE = 0.006 ether;
  uint256 public constant BLAST_DEADLINE = 1_747_138_533;
  bytes public constant BLAST_SIG =
    hex'22787bcfef8f160a81c38f2cea4ac8200b366dab215909406f993c3d963e12120d4afc2b00a13ead8897e926536dfdf6e67eb52abd4a960cc6e72a49114117ff1b';
  uint256 public constant BLAST_FIXED_BLOCK = 19_164_041;

  // Active Addresses used due to sstore writing issues with deal on fork
  address public constant BLAST_WHALE = 0xC748532C202828969b2Ee68E0F8487E69cC1d800;

  // Bridges
  address public constant BLAST_ACROSS_SPOKE_POOL = 0x2D509190Ed0172ba588407D4c2df918F955Cc6E1;
}

abstract contract Scroll {
  address public constant SCROLL_ROLE_MODULE = 0xfFbA1Fef54b229705Aacf2A8431D7B7d2D2000A0;
  bytes32 public constant SCROLL_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F7363726F6C6C0000000000000000;

  // Api Inputs
  uint256 public constant SCROLL_FEE = 0.000106 ether;
  uint256 public constant SCROLL_DEADLINE = 1_747_139_007;
  bytes public constant SCROLL_SIG =
    hex'44dbf68f2a10df230f0d0dd340621a6b17fd5b415235cb3d3e156c2328f32d805c44bff82374cc0ee526964e940be68c80be58898852eb92ad2fda33ca3a38361c';
  uint256 public constant SCROLL_FIXED_BLOCK = 15_411_273;

  // Bridges
  address public constant SCROLL_ACROSS_SPOKE_POOL = 0x9295ee1d8C5b022Be115A2AD3c30C72E34e7F096;
  address public constant SCROLL_STARGATE_WETH_POOL = 0xC2b638Cb5042c1B3c5d5C969361fB50569840583;
  address public constant SCROLL_STARGATE_USDC_POOL = 0x3Fc69CC4A842838bCDC9499178740226062b14E4;
}

abstract contract Ink {
  address public constant INK_ROLE_MODULE = 0x647Fe289E2D746Ee1eA88d1a3b6a95c5BAde2f17;
  bytes32 public constant INK_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f696e6b0000000000000000000000;

  // Api Inputs
  uint256 public constant INK_FEE = 0.0001 ether;
  uint256 public constant INK_DEADLINE = 1747143461;
  bytes public constant INK_SIG =
    hex'70fd6cac50837d6a3686b10312e428f953e2877ab2de38149b22cacb6161fb5953611fea0136f12cbb09d058253d4a52aeaaf06873e681d9131ab95b8c87af621b';
  uint256 public constant INK_FIXED_BLOCK = 13644402;

  // Bridges
  address public constant INK_ACROSS_SPOKE_POOL = 0xeF684C38F94F48775959ECf2012D7E864ffb9dd4;
  address public constant INK_STARGATE_USDC_POOL = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
}

abstract contract Unichain {
  address public constant UNICHAIN_ROLE_MODULE = 0x715302b659804c40CF83eb5D2e33Bb4b35c8A854;
  bytes32 public constant UNICHAIN_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F756E69636861696E000000000000;

  // Api Inputs
  uint256 public constant UNICHAIN_FEE = 0.0007 ether;
  uint256 public constant UNICHAIN_DEADLINE = 1747144179;
  bytes public constant UNICHAIN_SIG =
    hex'0359d8bbb660e4448ae753d19d850109c52c3add6a7baab32f4a3f8f59bc3a3b77809a80f30af6b4d4f0c85f54846a01df93e634c4133e5c4afd07c770ba6cbe1b';
  uint256 public constant UNICHAIN_FIXED_BLOCK = 16395066;

  // Bridges
  address public constant UNICHAIN_ACROSS_SPOKE_POOL = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
  address public constant UNICHAIN_STARGATE_WETH_POOL = 0xe9aBA835f813ca05E50A6C0ce65D0D74390F7dE7;
}

abstract contract Mode {
  address public constant MODE_ROLE_MODULE = 0x3CACE76d4b1da3a7e7D2643073710aB9F27807E0;
  bytes32 public constant MODE_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f6d6f646500000000000000000000;

  // Api Inputs
  uint256 public constant MODE_FEE = 0.004 ether;
  uint256 public constant MODE_DEADLINE = 1747145892;
  bytes public constant MODE_SIG =
    hex'19638a66549be0110f38c58e3175dbb6890cfd4b0fbecaa8826dfa02c9218edc0394aaaefbafb923841c0e1e53f54f1ad589e4fbe098de0a3020fda36cd455091b';
  uint256 public constant MODE_FIXED_BLOCK = 23488838;

  // Bridges
  address public constant MODE_ACROSS_SPOKE_POOL = 0x3baD7AD0728f9917d1Bf08af5782dCbD516cDd96;
}

// abstract contract Apechain {
//   address public constant APECHAIN_ROLE_MODULE = ;
//   bytes32 public constant APECHAIN_ROLE_KEY = ;

//   // Api Inputs
//     uint256 public constant APECHAIN_FEE = 0 ether;
//   uint256 public constant APECHAIN_DEADLINE = ;
//   bytes public constant APECHAIN_SIG =
//     hex'';
// }

// abstract Ronin {
//   address public constant MODE_ROLE_MODULE = ;
//   bytes32 public constant MODE_ROLE_KEY = ;

//   // Api Inputs
//     uint256 public constant MODE_FEE = 0 ether;
//   uint256 public constant MODE_DEADLINE = ;
//   bytes public constant MODE_SIG =
//     hex'';
// }

// abstract contract Avalanche {
//   address public constant AVALANCHE_ROLE_MODULE = ;
//   bytes32 public constant AVALANCHE_ROLE_KEY = ;

//   // Api Inputs
//     uint256 public constant AVALANCHE_FEE = 0 ether;
//   uint256 public constant AVALANCHE_DEADLINE = ;
//   bytes public constant AVALANCHE_SIG =
//     hex'';
// }

// abstract contract Linea {
//   address public constant LINEA_ROLE_MODULE = ;
//   bytes32 public constant LINEA_ROLE_KEY = ;

//   // Api Inputs
//     uint256 public constant LINEA_FEE = 0 ether;
//   uint256 public constant LINEA_DEADLINE = ;
//   bytes public constant LINEA_SIG =
//     hex'';
// }

// abstract contract Taiko {
//   address public constant TAIKO_ROLE_MODULE = ;
//   bytes32 public constant TAIKO_ROLE_KEY = ;

//   // Api Inputs
//     uint256 public constant TAIKO_FEE = 0 ether;
//   uint256 public constant TAIKO_DEADLINE = ;
//   bytes public constant TAIKO_SIG =
//     hex'';
// }

// abstract contract Zircuit {
//   address public constant ZIRCUIT_ROLE_MODULE = ;
//   bytes32 public constant ZIRCUIT_ROLE_KEY = ;

//   // Api Inputs
//     uint256 public constant ZIRCUIT_FEE = 0 ether;
//   uint256 public constant ZIRCUIT_DEADLINE = ;
//   bytes public constant ZIRCUIT_SIG =
//     hex'';
// }

abstract contract ZodiacHelper is
  Test,
  Arbitrum,
  Blast,
  Optimism,
  Polygon,
  Base,
  Sonic,
  Scroll,
  Berachain,
  Bsc,
  Mantle,
  Ink,
  Unichain,
  Mode
{
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
  address public constant MULTI_SIG_ADDRESS = 0xC55749A006f6B2098dF802b1711522498b83Fae3;
  uint256 public constant EXPECTED_THRESHOLD = 1;
  bytes4 public constant NEW_INTENT_ADDRESS_SELECTOR =
    bytes4(keccak256('newIntent(uint32[],address,address,address,uint256,uint24,uint48,bytes,(uint256,uint256,bytes))'));
  address public constant INVALID_CALLER = address(0x123);
  address public constant INVALID_SPENDER = address(0x456);
  address public constant INVALID_RECEIVER = address(0x789);
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
