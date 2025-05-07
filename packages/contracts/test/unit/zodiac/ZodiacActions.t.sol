// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20, IFeeAdapter, IRoleModule, ZodiacHelper} from './ZodiacHelper.sol';
import {EverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {MainnetProductionEnvironment} from 'script/MainnetProduction.sol';

contract ZodiacActions is MainnetProductionEnvironment, ZodiacHelper {
  function setUp() public {
    _zodiacConfig[ARBITRUM_ONE] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: ARBITRUM_ROLE_MODULE,
      feeAdapter: ARBITRUM_FEE_ADAPTER,
      roleKey: ARBITRUM_ROLE_KEY,
      validFee: ARBITRUM_FEE,
      validDeadline: ARBITRUM_DEADLINE,
      validSignature: ARBITRUM_SIG,
      weth: ARBITRUM_WETH,
      usdc: ARBITRUM_USDC,
      usdt: ARBITRUM_USDT,
      fixedBlock: ARBITRUM_FIXED_BLOCK
    });

    _zodiacConfig[OPTIMISM] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: OPTIMISM_ROLE_MODULE,
      feeAdapter: OPTIMISM_FEE_ADAPTER,
      roleKey: OPTIMISM_ROLE_KEY,
      validFee: OPTIMISM_FEE,
      validDeadline: OPTIMISM_DEADLINE,
      validSignature: OPTIMISM_SIG,
      weth: OPTIMISM_WETH,
      usdc: OPTIMISM_USDC,
      usdt: OPTIMISM_USDT,
      fixedBlock: OPTIMISM_FIXED_BLOCK
    });

    _zodiacConfig[POLYGON] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: POLYGON_ROLE_MODULE,
      feeAdapter: POLYGON_FEE_ADAPTER,
      roleKey: POLYGON_ROLE_KEY,
      validFee: POLYGON_FEE,
      validDeadline: POLYGON_DEADLINE,
      validSignature: POLYGON_SIG,
      weth: POLYGON_WETH,
      usdc: POLYGON_USDC,
      usdt: POLYGON_USDT,
      fixedBlock: POLYGON_FIXED_BLOCK
    });

    _zodiacConfig[BASE] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: BASE_ROLE_MODULE,
      feeAdapter: BASE_FEE_ADAPTER,
      roleKey: BASE_ROLE_KEY,
      validFee: BASE_FEE,
      validDeadline: BASE_DEADLINE,
      validSignature: BASE_SIG,
      weth: BASE_WETH,
      usdc: BASE_USDC,
      usdt: BASE_USDT,
      fixedBlock: BASE_FIXED_BLOCK
    });

    _zodiacConfig[BNB] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: BSC_ROLE_MODULE,
      feeAdapter: BNB_FEE_ADAPTER,
      roleKey: BSC_ROLE_KEY,
      validFee: BSC_FEE,
      validDeadline: BSC_DEADLINE,
      validSignature: BSC_SIG,
      weth: BNB_WETH,
      usdc: BNB_USDC,
      usdt: BNB_USDT,
      fixedBlock: BSC_FIXED_BLOCK
    });

    _zodiacConfig[BLAST] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: BLAST_ROLE_MODULE,
      feeAdapter: BLAST_FEE_ADAPTER,
      roleKey: BLAST_ROLE_KEY,
      validFee: BLAST_FEE,
      validDeadline: BLAST_DEADLINE,
      validSignature: BLAST_SIG,
      weth: BLAST_WETH,
      usdc: address(0),
      usdt: address(0),
      fixedBlock: BLAST_FIXED_BLOCK
    });

    _zodiacConfig[SONIC] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: SONIC_ROLE_MODULE,
      feeAdapter: SONIC_FEE_ADAPTER,
      roleKey: SONIC_ROLE_KEY,
      validFee: SONIC_FEE,
      validDeadline: SONIC_DEADLINE,
      validSignature: SONIC_SIG,
      weth: SONIC_WETH,
      usdc: SONIC_USDC,
      usdt: SONIC_USDT,
      fixedBlock: SONIC_FIXED_BLOCK
    });

    _zodiacConfig[MANTLE] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: MANTLE_ROLE_MODULE,
      feeAdapter: MANTLE_FEE_ADAPTER,
      roleKey: MANTLE_ROLE_KEY,
      validFee: MANTLE_FEE,
      validDeadline: MANTLE_DEADLINE,
      validSignature: MANTLE_SIG,
      weth: MANTLE_WETH,
      usdc: MANTLE_USDC,
      usdt: MANTLE_USDT,
      fixedBlock: MANTLE_FIXED_BLOCK
    });

    _zodiacConfig[INK] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: INK_ROLE_MODULE,
      feeAdapter: INK_FEE_ADAPTER,
      roleKey: INK_ROLE_KEY,
      validFee: INK_FEE,
      validDeadline: INK_DEADLINE,
      validSignature: INK_SIG,
      weth: INK_WETH,
      usdc: INK_USDC,
      usdt: address(0),
      fixedBlock: INK_FIXED_BLOCK
    });

    _zodiacConfig[SCROLL] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: SCROLL_ROLE_MODULE,
      feeAdapter: SCROLL_FEE_ADAPTER,
      roleKey: SCROLL_ROLE_KEY,
      validFee: SCROLL_FEE,
      validDeadline: SCROLL_DEADLINE,
      validSignature: SCROLL_SIG,
      weth: SCROLL_WETH,
      usdc: SCROLL_USDC,
      usdt: SCROLL_USDT,
      fixedBlock: SCROLL_FIXED_BLOCK
    });

    _zodiacConfig[BERACHAIN] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: BERACHAIN_ROLE_MODULE,
      feeAdapter: BERACHAIN_FEE_ADAPTER,
      roleKey: BERACHAIN_ROLE_KEY,
      validFee: BERACHAIN_FEE,
      validDeadline: BERACHAIN_DEADLINE,
      validSignature: BERACHAIN_SIG,
      weth: BERACHAIN_WETH,
      usdc: BERACHAIN_USDC,
      usdt: address(0),
      fixedBlock: BERACHAIN_FIXED_BLOCK
    });

    _zodiacConfig[UNICHAIN] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: UNICHAIN_ROLE_MODULE,
      feeAdapter: UNICHAIN_FEE_ADAPTER,
      roleKey: UNICHAIN_ROLE_KEY,
      validFee: UNICHAIN_FEE,
      validDeadline: UNICHAIN_DEADLINE,
      validSignature: UNICHAIN_SIG,
      weth: UNICHAIN_WETH,
      usdc: UNICHAIN_USDC,
      usdt: UNICHAIN_USDT,
      fixedBlock: UNICHAIN_FIXED_BLOCK
    });

    _zodiacConfig[MODE] = ZodiacConfiguration({
      safeAddress: MULTI_SIG_ADDRESS,
      approvedCaller: SAFE_TEST_ADDRESS,
      roleModule: MODE_ROLE_MODULE,
      feeAdapter: MODE_FEE_ADAPTER,
      roleKey: MODE_ROLE_KEY,
      validFee: MODE_FEE,
      validDeadline: MODE_DEADLINE,
      validSignature: MODE_SIG,
      weth: MODE_WETH,
      usdc: MODE_USDC,
      usdt: MODE_USDT,
      fixedBlock: MODE_FIXED_BLOCK
    });
  }

  function test_zodiacConfiguration_arbitrum() public {
    vm.createSelectFork(vm.envString('ARBITRUM_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_optimism() public {
    vm.createSelectFork(vm.envString('OPTIMISM_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_polygon() public {
    vm.createSelectFork(vm.envString('POLYGON_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_base() public {
    vm.createSelectFork(vm.envString('BASE_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_bsc() public {
    vm.createSelectFork(vm.envString('BNB_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_blast() public {
    vm.createSelectFork(vm.envString('BLAST_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFundsFromActive(config.weth, 100 ether, BLAST_WHALE, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_scroll() public {
    vm.createSelectFork(vm.envString('SCROLL_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_sonic() public {
    vm.createSelectFork(vm.envString('SONIC_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_berachain() public {
    vm.createSelectFork(vm.envString('BERACHAIN_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_mantle() public {
    vm.createSelectFork(vm.envString('MANTLE_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_ink() public {
    vm.createSelectFork(vm.envString('INK_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_unichain() public {
    vm.createSelectFork(vm.envString('UNI_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }

  function test_zodiacConfiguration_mode() public {
    vm.createSelectFork(vm.envString('MODE_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // testing the test address can set approvals for each asset
    _approveAsset(config.weth, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, config.approvedCaller, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, config.approvedCaller, config.feeAdapter, config, 100 ether, false);

    // sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, config.approvedCaller, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, config.approvedCaller, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      NONZERO_TTL,
      ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, config.approvedCaller);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrder(
      _destinations,
      _amounts,
      config,
      config.weth,
      config.approvedCaller,
      config.safeAddress,
      true,
      ZERO_TTL,
      NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, config.approvedCaller, config.safeAddress
    );
  }
}
