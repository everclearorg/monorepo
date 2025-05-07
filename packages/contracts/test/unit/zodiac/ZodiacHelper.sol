// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IRoleModule, ISafe} from './IHelpers.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import 'forge-std/Test.sol';
import {IFeeAdapter} from 'interfaces/intent/IFeeAdapter.sol';

abstract contract Arbitrum {
  address public constant ARBITRUM_ROLE_MODULE = 0xfc62b8FBC8fdDdd1997130923fD44BB785033B12;
  bytes32 public constant ARBITRUM_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f6172620000000000000000000000;

  // API Inputs
  uint256 public constant ARBITRUM_FEE = 0;
  uint256 public constant ARBITRUM_DEADLINE = 1_746_040_172;
  bytes public constant ARBITRUM_SIG =
    hex'aaab94b63255326a48727ec2e36b470afa89f346cd9ac53c7bf1db3d8bd2a7b643c49fbfa826c3ca31dd6134278abe6d5934b4334412df8ab5efe7350df612e71c';
  uint256 public constant ARBITRUM_FIXED_BLOCK = 331_877_505;
}

abstract contract Optimism {
  address public constant OPTIMISM_ROLE_MODULE = 0x14b940d7128237CDA825fD3f2Ab5063B9DFC0613;
  bytes32 public constant OPTIMISM_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6F70000000000000000000000000;

  // API Inputs
  uint256 public constant OPTIMISM_FEE = 0;
  uint256 public constant OPTIMISM_DEADLINE = 1_746_542_001;
  bytes public constant OPTIMISM_SIG =
    hex'635e9ca991fa83c5809fbe0acb3c85a989642ab4f6af79799ee52ec5329a54486e6ea0671ad3b14bc6eb1ec6a30eb0f5d43579057361e5c22172135a6d7984e91b';
  uint256 public constant OPTIMISM_FIXED_BLOCK = 135_471_195;
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
  uint256 public constant POLYGON_FEE = 0.000086 ether;
  uint256 public constant POLYGON_DEADLINE = 1_746_541_265;
  bytes public constant POLYGON_SIG =
    hex'198add1fc5ca646460b61a2c93b02867b37eb500ba12ddd7b87273d9aa2e7c2d4833c9bc4b1a7dd7891c007d36443b4f6c425056dbc438eb6d85097916363b0c1c';
  uint256 public constant POLYGON_FIXED_BLOCK = 71_184_717;
}

abstract contract Bsc {
  address public constant BSC_ROLE_MODULE = 0x5f67084B92abaB83002fE562Be9E761Ba99603E1;
  bytes32 public constant BSC_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6273630000000000000000000000;

  // API Inputs
  uint256 public constant BSC_FEE = 0;
  uint256 public constant BSC_DEADLINE = 1_746_602_760;
  bytes public constant BSC_SIG =
    hex'bc257582e898eb6352b231c6415c5a466f266fadcf1a3773c0df1ee2ab99b4cf349d338011d9748e5705646b56ad2cdce4e82c50077dda9aa802979a8d042c221c';
  uint256 public constant BSC_FIXED_BLOCK = 49239399;
}

abstract contract Base {
  address public constant BASE_ROLE_MODULE = 0x5818a6540c2591BD990B24fA180Ca3217A2f9Cd4;
  bytes32 public constant BASE_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6261736500000000000000000000;

  // API Inputs
  uint256 public constant BASE_FEE = 0;
  uint256 public constant BASE_DEADLINE = 1_746_542_582;
  bytes public constant BASE_SIG =
    hex'4be8d3085373ab8d485948ebe6f4f6b0b8f2a75c4d0fb3eaf2c3744789c248ff5377f884d89ca66c6f679c054bcb1ad6f4b407eacfb6035a84d15edf42b0a6ba1b';
  uint256 public constant BASE_FIXED_BLOCK = 29_876_170;
}

abstract contract Sonic {
  address public constant SONIC_ROLE_MODULE = 0x439DF7B8Fd25a8815Be21b6f4E6039f31F3564E5;
  bytes32 public constant SONIC_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F736F6E6963000000000000000000;

  // API Inputs
  uint256 public constant SONIC_FEE = 0.0005 ether;
  uint256 public constant SONIC_DEADLINE = 1_746_546_087;
  bytes public constant SONIC_SIG =
    hex'812af77f5667ebe3ad7c28960d200e0ded3fb5f8c9ffe1a134e8ca707dccf42309260b89db5e0d404782edeff9ab3e1a248400ee6cd02b5954d7150bf8878ce71b';
  uint256 public constant SONIC_FIXED_BLOCK = 24_788_600;
}

abstract contract Berachain {
  address public constant BERACHAIN_ROLE_MODULE = 0xF8e6e260b83d9665901311063bCF7E6042FcaB70;
  bytes32 public constant BERACHAIN_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6265726100000000000000000000;

  // API Inputs
  uint256 public constant BERACHAIN_FEE = 0.0003 ether;
  uint256 public constant BERACHAIN_DEADLINE = 1_746_547_262;
  bytes public constant BERACHAIN_SIG =
    hex'aaa01289e6f276bbc1f5d7f6d287bd233af08266c2ebeaf408e8d56a2562d9d2454f069d49064d6d884e236833fb0fcf10a99cbc0b7a08230d24723baffb86331c';
  uint256 public constant BERACHAIN_FIXED_BLOCK = 4_655_499;
}

abstract contract Mantle {
  address public constant MANTLE_ROLE_MODULE = 0x0098084D57e6Db1522215BE2776554E42f4a65d7;
  bytes32 public constant MANTLE_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F6D616E746C650000000000000000;

  // Api Inputs
    uint256 public constant MANTLE_FEE = 0.0005 ether;
  uint256 public constant MANTLE_DEADLINE = 1746603551;
  bytes public constant MANTLE_SIG =
    hex'3875e6470c6559751dc5502894d819a5e758c64e21f2425654b0cef7ab939a9b4b91a86a08f1d4e218c19081dc4bbc43f84db51b0af9ac5c13009f84629bf50c1b';
  uint256 public constant MANTLE_FIXED_BLOCK = 79236295;
}

abstract contract Blast {
  address public constant BLAST_ROLE_MODULE = 0x14bc534044B557bBb5E9A63473e761176bE665f6;
  bytes32 public constant BLAST_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f626c617374000000000000000000;

  // API Inputs
  uint256 public constant BLAST_FEE = 0.0015 ether;
  uint256 public constant BLAST_DEADLINE = 1_746_172_456;
  bytes public constant BLAST_SIG =
    hex'58445f383729e230553c787423c80057bda55f9b9434a596ab5e26a941bcd5560601cf121c3a11c6e11b3611b4fdba36ee44cfdfbf0645238497db8dc23044e61b';
  uint256 public constant BLAST_FIXED_BLOCK = 18_681_078;

  // Active Addresses used due to sstore writing issues with deal on fork
  address public constant BLAST_WHALE = 0xC748532C202828969b2Ee68E0F8487E69cC1d800;
}

abstract contract Scroll {
  address public constant SCROLL_ROLE_MODULE = 0xfFbA1Fef54b229705Aacf2A8431D7B7d2D2000A0;
  bytes32 public constant SCROLL_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F7363726F6C6C0000000000000000;

  // Api Inputs
  uint256 public constant SCROLL_FEE = 0.000086 ether;
  uint256 public constant SCROLL_DEADLINE = 1_746_545_024;
  bytes public constant SCROLL_SIG =
    hex'511441d63f86aea28fa3b51e444b12317e6a440eebc8a0985f08a2ccbeab593d0160d493d5a5c44471e2c02105e0d972b3d3a6b244a65cd913166aa8484f5b5e1c';
  uint256 public constant SCROLL_FIXED_BLOCK = 15243096;
}

abstract contract Ink {
  address public constant INK_ROLE_MODULE = 0x647Fe289E2D746Ee1eA88d1a3b6a95c5BAde2f17;
  bytes32 public constant INK_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f696e6b0000000000000000000000;

  // Api Inputs
    uint256 public constant INK_FEE = 0.0001 ether;
  uint256 public constant INK_DEADLINE = 1746604057;
  bytes public constant INK_SIG =
    hex'7e752748cf17ed2b78f1fa2381bd86c69549921e52d777484be06045f3f29c0b589f6c12479201b1e033b4e143297d44d1d260393ecc48035357c8c5d063f6ba1c';
    uint256 public constant INK_FIXED_BLOCK = 13105017;
}

abstract contract Unichain {
  address public constant UNICHAIN_ROLE_MODULE = 0x715302b659804c40CF83eb5D2e33Bb4b35c8A854;
  bytes32 public constant UNICHAIN_ROLE_KEY = 0x6C69717569646974795F6D616E616765725F756E69636861696E000000000000;

  // Api Inputs
  uint256 public constant UNICHAIN_FEE = 0.0001 ether;
  uint256 public constant UNICHAIN_DEADLINE = 1746604542;
  bytes public constant UNICHAIN_SIG =
    hex'accad539f1ed15a5a57783b9fbe13477e76dcc178822a493532142f01066157a3758f8cc33b618ae6d9a7df416c8da103130f677696cdd9c368ec7d5e9a7416e1c';
  uint256 public constant UNICHAIN_FIXED_BLOCK = 15855550;
}

abstract contract Mode {
  address public constant MODE_ROLE_MODULE = 0x3CACE76d4b1da3a7e7D2643073710aB9F27807E0;
  bytes32 public constant MODE_ROLE_KEY = 0x6c69717569646974795f6d616e616765725f6d6f646500000000000000000000;

  // Api Inputs
    uint256 public constant MODE_FEE = 0.00055 ether;
  uint256 public constant MODE_DEADLINE = 1746605147;
  bytes public constant MODE_SIG =
    hex'6762a51d4ac811dc13d1abd7b0b40342db3c8fdcb505c76b88945eb3216c4dc07e1e4dbaa182c9c70d03c0531b53c9c50110d946f55ef2d1c4bb155be16769e01b';
  uint256 public constant MODE_FIXED_BLOCK = 23218418;
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

abstract contract ZodiacHelper is Test, Arbitrum, Blast, Optimism, Polygon, Base, Sonic, Scroll, Berachain, Bsc, Mantle, Ink, Unichain, Mode {
  struct ZodiacConfiguration {
    address safeAddress;
    address approvedCaller;
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

  // Constants
  address public constant SAFE_TEST_ADDRESS = 0x2eEd1440842990Fa61F0c396f981375Fa6004131;
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
