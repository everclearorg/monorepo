// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20, IFeeAdapter, IRoleModule, ZodiacHelper, ZodiacProductionEnvironment} from './ZodiacHelper.sol';
import {EverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {MainnetProductionEnvironment} from 'script/MainnetProduction.sol';

contract ZodiacProdActions is MainnetProductionEnvironment, ZodiacHelper, ZodiacProductionEnvironment {
  function setUp() public {
    // Ethereum
    _zodiacConfig[ETHEREUM] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: ETHEREUM_PROD_ROLE_MODULE,
      feeAdapter: ETHEREUM_FEE_ADAPTER,
      roleKey: ETHEREUM_ROLE_KEY,
      validFee: ETHEREUM_FEE,
      validDeadline: ETHEREUM_DEADLINE,
      validSignature: ETHEREUM_SIG,
      weth: ETHEREUM_WETH,
      usdc: ETHEREUM_USDC,
      usdt: ETHEREUM_USDT,
      fixedBlock: ETHEREUM_FIXED_BLOCK
    });
    _addressConfig[ETHEREUM] = ExternalAddresses({
      across: ETHEREUM_ACROSS_SPOKE_POOL,
      stargateWeth: ETHEREUM_STARGATE_WETH_POOL,
      stargateUsdc: ETHEREUM_STARGATE_USDC_POOL,
      stargateUsdt: ETHEREUM_STARGATE_USDT_POOL,
      cbBTC: ETHEREUM_CBBTC
    });

    // Arbitrum
    _zodiacConfig[ARBITRUM_ONE] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: ARBITRUM_PROD_ROLE_MODULE,
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
    _addressConfig[ARBITRUM_ONE] = ExternalAddresses({
      across: ARBITRUM_ACROSS_SPOKE_POOL,
      stargateWeth: ARBITRUM_STARGATE_WETH_POOL,
      stargateUsdc: ARBITRUM_STARGATE_USDC_POOL,
      stargateUsdt: ARBITRUM_STARGATE_USDT_POOL,
      cbBTC: address(0)
    });

    // Optimism
    _zodiacConfig[OPTIMISM] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: OPTIMISM_PROD_ROLE_MODULE,
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
    _addressConfig[OPTIMISM] = ExternalAddresses({
      across: OPTIMISM_ACROSS_SPOKE_POOL,
      stargateWeth: OPTIMISM_STARGATE_WETH_POOL,
      stargateUsdc: OPTIMISM_STARGATE_USDC_POOL,
      stargateUsdt: OPTIMISM_STARGATE_USDT_POOL,
      cbBTC: address(0)
    });

    // Polygon
    _zodiacConfig[POLYGON] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: POLYGON_PROD_ROLE_MODULE,
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
    _addressConfig[POLYGON] = ExternalAddresses({
      across: POLYGON_ACROSS_SPOKE_POOL,
      stargateWeth: address(0),
      stargateUsdc: POLYGON_STARGATE_USDC_POOL,
      stargateUsdt: POLYGON_STARGATE_USDT_POOL,
      cbBTC: address(0)
    });

    // Base
    _zodiacConfig[BASE] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: BASE_PROD_ROLE_MODULE,
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
    _addressConfig[BASE] = ExternalAddresses({
      across: BASE_ACROSS_SPOKE_POOL,
      stargateWeth: BASE_STARGATE_WETH_POOL,
      stargateUsdc: BASE_STARGATE_USDC_POOL,
      stargateUsdt: address(0),
      cbBTC: BASE_CBBTC
    });

    // BNB
    _zodiacConfig[BNB] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: BSC_PROD_ROLE_MODULE,
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
    _addressConfig[BNB] = ExternalAddresses({
      across: address(0),
      stargateWeth: address(0),
      stargateUsdc: BSC_STARGATE_USDC_POOL,
      stargateUsdt: BSC_STARGATE_USDT_POOL,
      cbBTC: address(0)
    });

    // Blast
    _zodiacConfig[BLAST] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: BLAST_PROD_ROLE_MODULE,
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
    _addressConfig[BLAST] = ExternalAddresses({
      across: BLAST_ACROSS_SPOKE_POOL,
      stargateWeth: address(0),
      stargateUsdc: address(0),
      stargateUsdt: address(0),
      cbBTC: address(0)
    });

    // Sonic
    _zodiacConfig[SONIC] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: SONIC_PROD_ROLE_MODULE,
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
    _addressConfig[SONIC] = ExternalAddresses({
      across: address(0),
      stargateWeth: address(0),
      stargateUsdc: SONIC_STARGATE_USDC_POOL,
      stargateUsdt: address(0),
      cbBTC: address(0)
    });

    // Mantle
    _zodiacConfig[MANTLE] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: MANTLE_PROD_ROLE_MODULE,
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
    _addressConfig[MANTLE] = ExternalAddresses({
      across: address(0),
      stargateWeth: MANTLE_STARGATE_WETH_POOL,
      stargateUsdc: MANTLE_STARGATE_USDC_POOL,
      stargateUsdt: MANTLE_STARGATE_USDT_POOL,
      cbBTC: address(0)
    });

    // Ink
    _zodiacConfig[INK] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: INK_PROD_ROLE_MODULE,
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
    _addressConfig[INK] = ExternalAddresses({
      across: INK_ACROSS_SPOKE_POOL,
      stargateWeth: address(0),
      stargateUsdc: INK_STARGATE_USDC_POOL,
      stargateUsdt: address(0),
      cbBTC: address(0)
    });

    // Scroll
    _zodiacConfig[SCROLL] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: SCROLL_PROD_ROLE_MODULE,
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
    _addressConfig[SCROLL] = ExternalAddresses({
      across: SCROLL_ACROSS_SPOKE_POOL,
      stargateWeth: SCROLL_STARGATE_WETH_POOL,
      stargateUsdc: SCROLL_STARGATE_USDC_POOL,
      stargateUsdt: address(0),
      cbBTC: address(0)
    });

    // Berachain
    _zodiacConfig[BERACHAIN] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: BERACHAIN_PROD_ROLE_MODULE,
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
    _addressConfig[BERACHAIN] = ExternalAddresses({
      across: address(0),
      stargateWeth: BERACHAIN_STARGATE_WETH_POOL,
      stargateUsdc: BERACHAIN_STARGATE_USDC_POOL,
      stargateUsdt: address(0),
      cbBTC: address(0)
    });

    // Unichain
    _zodiacConfig[UNICHAIN] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: UNICHAIN_PROD_ROLE_MODULE,
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
    _addressConfig[UNICHAIN] = ExternalAddresses({
      across: UNICHAIN_ACROSS_SPOKE_POOL,
      stargateWeth: UNICHAIN_STARGATE_WETH_POOL,
      stargateUsdc: address(0),
      stargateUsdt: address(0),
      cbBTC: address(0)
    });

    // Mode
    _zodiacConfig[MODE] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: MODE_PROD_ROLE_MODULE,
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
    _addressConfig[MODE] = ExternalAddresses({
      across: MODE_ACROSS_SPOKE_POOL,
      stargateWeth: address(0),
      stargateUsdc: address(0),
      stargateUsdt: address(0),
      cbBTC: address(0)
    });

    // Ronin
    _zodiacConfig[RONIN] = ZodiacConfiguration({
      safeAddress: PROD_RONIN_SAFE_ADDRESS,
      roleModule: RONIN_PROD_ROLE_MODULE,
      feeAdapter: RONIN_FEE_ADAPTER,
      roleKey: RONIN_ROLE_KEY,
      validFee: RONIN_FEE,
      validDeadline: RONIN_DEADLINE,
      validSignature: RONIN_SIG,
      weth: RONIN_WETH,
      usdc: RONIN_USDC,
      usdt: address(0),
      fixedBlock: RONIN_FIXED_BLOCK
    });

    // Avalanche
    _zodiacConfig[AVALANCHE] = ZodiacConfiguration({
      safeAddress: PROD_MULTI_SIG_ADDRESS,
      roleModule: AVALANCHE_PROD_ROLE_MODULE,
      feeAdapter: AVALANCHE_FEE_ADAPTER,
      roleKey: AVALANCHE_ROLE_KEY,
      validFee: AVALANCHE_FEE,
      validDeadline: AVALANCHE_DEADLINE,
      validSignature: AVALANCHE_SIG,
      weth: AVALANCHE_WETH,
      usdc: AVALANCHE_USDC,
      usdt: AVALANCHE_USDT,
      fixedBlock: AVALANCHE_FIXED_BLOCK
    });
    _addressConfig[AVALANCHE] = ExternalAddresses({
      across: address(0),
      stargateWeth: address(0),
      stargateUsdc: AVALANCHE_STARGATE_USDC_POOL,
      stargateUsdt: AVALANCHE_STARGATE_USDT_POOL,
      cbBTC: address(0)
    });
  }

  function test_zodiacProdConfiguration_ethereum() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing fee adapter can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(addressConfig.cbBTC, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Across: testing across spoke pool can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.stargateUsdt, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdc, config.safeAddress, 100_000e6);
    _transferAsset(config.usdc, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    deal(config.usdt, config.safeAddress, 100_000e6);
    _transferAsset(config.usdt, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    deal(config.weth, config.safeAddress, 1 ether);
    _transferAsset(config.weth, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1 ether, false);

    // WETH: approving weth to burn WETH then unwrapping
    _approveAsset(config.weth, APPROVED_CALLER, config.weth, config, 100 ether, false);
    deal(config.weth, config.safeAddress, 10 ether);
    _unwrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // WETH: wrapping weth
    vm.deal(config.safeAddress, 100 ether);
    _wrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // ETH: transferring to Binance
    _transferEth(APPROVED_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.destination = 10;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.inputAmount = _amounts[0]; // 1 ether
    _params.outputAmount = _amounts[0] * 90_000 / 100_000;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;

    // Across: sending an order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, false);

    // Stargate: sending an order
    _params.inputAmount = 100e6;
    _params.outputAmount = 90e6;
    _params.nativeFee = 0.01 ether;
    _params.destination = 30_110;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    // Stargate: sending an order in native
    _params.inputAmount = 1 ether;
    _params.outputAmount = 0.9 ether;
    _sendStargateWeth(_params, config, config.safeAddress, addressConfig.stargateWeth, false);

    // //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: transferring to invalid receiver
    _transferAsset(config.usdt, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);
    _transferAsset(config.usdc, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);

    // invalidCaller: transferring ETH to Binance
    _transferEth(INVALID_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: transferring to invalid receiver
    _transferAsset(config.usdt, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);
    _transferAsset(config.usdc, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);

    // invalidReceiver: transferring ETH to invalid receiver
    _transferEth(APPROVED_CALLER, INVALID_RECEIVER, 1 ether, config.roleKey, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _dealFunds(config.usdt, _amounts, config.validFee, config.safeAddress);

    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }

  function test_zodiacProdConfiguration_arbitrum() public {
    vm.createSelectFork(vm.envString('ARBITRUM_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing fee adapter can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Across: testing across spoke pool can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.stargateUsdt, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdc, config.safeAddress, 100_000e6);
    _transferAsset(config.usdc, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    deal(config.usdt, config.safeAddress, 100_000e6);
    _transferAsset(config.usdt, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    // ETH: transferring to Binance
    vm.deal(config.safeAddress, 100 ether);
    _transferEth(APPROVED_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, false);

    // WETH: approving weth to burn WETH then unwrapping
    _approveAsset(config.weth, APPROVED_CALLER, config.weth, config, 100 ether, false);
    deal(config.weth, config.safeAddress, 10 ether);
    _unwrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // WETH: wrapping weth
    vm.deal(config.safeAddress, 100 ether);
    _wrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.destination = 10;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.inputAmount = _amounts[0]; // 1 ether
    _params.outputAmount = _amounts[0] * 90_000 / 100_000;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;

    // Across: sending an order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, false);

    // Stargate: sending an order
    _params.inputAmount = 200e6;
    _params.outputAmount = 180e6;
    _params.nativeFee = 0.01 ether;
    _params.destination = 30_101;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    // Stargate: sending an order in native
    _params.inputAmount = 1 ether;
    _params.outputAmount = 0.9 ether;
    _sendStargateWeth(_params, config, config.safeAddress, addressConfig.stargateWeth, false);

    // //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: transferring with invalid caller
    _transferAsset(config.usdt, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);
    _transferAsset(config.usdc, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);

    // invalidCaller: transferring to Binance with invalid caller
    _transferEth(INVALID_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: transferring to invalid receiver
    _transferAsset(config.usdt, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);
    _transferAsset(config.usdc, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);

    // invalidReceiver: transferring to invalid receiver
    _transferEth(APPROVED_CALLER, INVALID_RECEIVER, 1 ether, config.roleKey, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _dealFunds(config.usdt, _amounts, config.validFee, config.safeAddress);

    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }

  function test_zodiacProdConfiguration_optimism() public {
    vm.createSelectFork(vm.envString('OPTIMISM_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Across: testing across spoke pool can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.stargateUsdt, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdc, config.safeAddress, 100_000e6);
    _transferAsset(config.usdc, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    deal(config.usdt, config.safeAddress, 100_000e6);
    _transferAsset(config.usdt, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    // ETH: transferring to Binance
    vm.deal(config.safeAddress, 100 ether);
    _transferEth(APPROVED_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, false);

    // WETH: approving weth to burn WETH then unwrapping
    _approveAsset(config.weth, APPROVED_CALLER, config.weth, config, 100 ether, false);
    deal(config.weth, config.safeAddress, 10 ether);
    _unwrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // WETH: wrapping weth
    vm.deal(config.safeAddress, 100 ether);
    _wrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.destination = 1;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.inputAmount = _amounts[0]; // 1 ether
    _params.outputAmount = _amounts[0] * 90_000 / 100_000;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;

    // Across: sending an order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, false);

    // Stargate: sending an order
    _params.inputAmount = 100e6;
    _params.outputAmount = 90e6;
    _params.nativeFee = 0.01 ether;
    _params.destination = 30_101;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    // Stargate: sending an order in native
    _params.inputAmount = 1 ether;
    _params.outputAmount = 0.9 ether;
    _sendStargateWeth(_params, config, config.safeAddress, addressConfig.stargateWeth, false);

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: transferring to invalid receiver
    _transferAsset(config.usdt, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);
    _transferAsset(config.usdc, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);

    // invalidCaller: transferring to Binance
    _transferEth(INVALID_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: transferring to invalid receiver
    _transferAsset(config.usdt, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);
    _transferAsset(config.usdc, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);

    // invalidReceiver: transferring to invalid receiver
    _transferEth(APPROVED_CALLER, INVALID_RECEIVER, 1 ether, config.roleKey, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _dealFunds(config.usdt, _amounts, config.validFee, config.safeAddress);

    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }

  function test_zodiacProdConfiguration_polygon() public {
    vm.createSelectFork(vm.envString('POLYGON_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Across: testing across spoke pool can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.stargateUsdt, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdc, config.safeAddress, 100_000e6);
    _transferAsset(config.usdc, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    deal(config.usdt, config.safeAddress, 100_000e6);
    _transferAsset(config.usdt, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    // POL: transferring to Binance
    vm.deal(config.safeAddress, 100 ether);
    _transferEth(APPROVED_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.destination = 10;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.inputAmount = _amounts[0]; // 1 ether
    _params.outputAmount = _amounts[0] * 90_000 / 100_000;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;

    // Across: sending an order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, false);

    // Stargate: sending an order
    _params.inputAmount = 100e6;
    _params.outputAmount = 90e6;
    _params.nativeFee = 100 ether;
    _params.destination = 30_101;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: transferring to invalid receiver
    _transferAsset(config.usdt, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);
    _transferAsset(config.usdc, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);

    // invalidCaller: transferring to Binance
    _transferEth(INVALID_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: transferring to invalid receiver
    _transferAsset(config.usdt, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);
    _transferAsset(config.usdc, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);

    // invalidReceiver: transferring to invalid receiver
    _transferEth(APPROVED_CALLER, INVALID_RECEIVER, 1 ether, config.roleKey, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _dealFunds(config.usdt, _amounts, config.validFee, config.safeAddress);

    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }

  function test_zodiacProdConfiguration_base() public {
    vm.createSelectFork(vm.envString('BASE_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(addressConfig.cbBTC, APPROVED_CALLER, config.feeAdapter, config, 1 ether, false);

    // Across: testing across spoke pool can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdc, config.safeAddress, 100_000e6);
    _transferAsset(config.usdc, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    // ETH: transferring to Binance
    vm.deal(config.safeAddress, 100 ether);
    _transferEth(APPROVED_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, false);

    // WETH: approving weth to burn WETH then unwrapping
    _approveAsset(config.weth, APPROVED_CALLER, config.weth, config, 100 ether, false);
    deal(config.weth, config.safeAddress, 10 ether);
    _unwrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // WETH: wrapping weth
    vm.deal(config.safeAddress, 100 ether);
    _wrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: Sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.destination = 10;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.inputAmount = _amounts[0]; // 1 ether
    _params.outputAmount = _amounts[0] * 90_000 / 100_000;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;

    // Across: sending an order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, false);

    // Stargate: sending an order
    _params.inputAmount = 100e6;
    _params.outputAmount = 90e6;
    _params.nativeFee = 0.01 ether;
    _params.destination = 30_101;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    // Stargate: sending an order in native
    _params.inputAmount = 1 ether;
    _params.outputAmount = 0.9 ether;
    _sendStargateWeth(_params, config, config.safeAddress, addressConfig.stargateWeth, false);

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(addressConfig.cbBTC, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: transferring to invalid receiver
    _transferAsset(config.usdt, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);
    _transferAsset(config.usdc, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);

    // invalidCaller: transferring to Binance
    _transferEth(INVALID_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(addressConfig.cbBTC, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: transferring to invalid receiver
    _transferAsset(config.usdt, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);
    _transferAsset(config.usdc, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);

    // invalidReceiver: transferring to Binance
    _transferEth(APPROVED_CALLER, INVALID_RECEIVER, 1 ether, config.roleKey, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _dealFunds(config.usdt, _amounts, config.validFee, config.safeAddress);

    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }

  function test_zodiacProdConfiguration_bsc() public {
    vm.createSelectFork(vm.envString('BNB_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.stargateUsdt, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdc, config.safeAddress, 100_000e18);
    _transferAsset(config.usdc, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    deal(config.usdt, config.safeAddress, 100_000e18);
    _transferAsset(config.usdt, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    // BNB: transferring to Binance
    vm.deal(config.safeAddress, 100 ether);
    _transferEth(APPROVED_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.message = '';
    _params.inputAmount = 100e18;
    _params.outputAmount = 99e18;
    _params.nativeFee = 0.01 ether;
    _params.destination = 30_101;

    vm.deal(config.safeAddress, 100 ether);
    deal(config.usdt, config.safeAddress, 100_000e18);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: transferring to invalid receiver
    _transferAsset(config.usdt, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);
    _transferAsset(config.usdc, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);

    // invalidCaller: transferring to Binance
    _transferEth(INVALID_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: transferring to invalid receiver
    _transferAsset(config.usdt, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);
    _transferAsset(config.usdc, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);

    // BNB: transferring to invalid receiver
    _transferEth(APPROVED_CALLER, INVALID_RECEIVER, 1 ether, config.roleKey, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _dealFunds(config.usdt, _amounts, config.validFee, config.safeAddress);

    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }

  function test_zodiacProdConfiguration_blast() public {
    vm.createSelectFork(vm.envString('BLAST_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Across: testing across spoke pool can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);

    // WETH: approving weth to burn WETH then unwrapping
    _approveAsset(config.weth, APPROVED_CALLER, config.weth, config, 100 ether, false);
    _dealFundsFromActive(config.weth, 100 ether, BLAST_WHALE, config.safeAddress);
    _unwrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // WETH: wrapping weth
    vm.deal(config.safeAddress, 100 ether);
    _wrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.destination = 1;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.inputAmount = _amounts[0]; // 1 ether
    _params.outputAmount = _amounts[0] * 90_000 / 100_000;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;

    // Across: sending an order
    _sendDepositV3(_params, config, false);

    // //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';
  }

  function test_zodiacProdConfiguration_scroll() public {
    vm.createSelectFork(vm.envString('SCROLL_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Across: testing across spoke pool can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdt, config.safeAddress, 100_000e6);
    _transferAsset(config.usdt, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    // ETH: transferring to Binance
    vm.deal(config.safeAddress, 100 ether);
    _transferEth(APPROVED_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, false);

    // WETH: approving weth to burn WETH then unwrapping
    _approveAsset(config.weth, APPROVED_CALLER, config.weth, config, 100 ether, false);
    deal(config.weth, config.safeAddress, 10 ether);
    _unwrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // WETH: wrapping weth
    vm.deal(config.safeAddress, 100 ether);
    _wrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.destination = 10;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.inputAmount = _amounts[0]; // 1 ether
    _params.outputAmount = _amounts[0] * 90_000 / 100_000;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;

    // Across: sending an order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, false);

    // Stargate: sending an order
    _params.inputAmount = 100e6;
    _params.outputAmount = 90e6;
    _params.nativeFee = 0.01 ether;
    _params.destination = 30_101;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    // Stargate: sending an order in native
    _params.inputAmount = 1 ether;
    _params.outputAmount = 0.9 ether;
    _sendStargateWeth(_params, config, config.safeAddress, addressConfig.stargateWeth, false);

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: transferring to invalid receiver
    _transferAsset(config.usdt, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);

    // ETH: transferring to Binance
    _transferEth(INVALID_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: transferring to invalid receiver
    _transferAsset(config.usdt, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);

    // invalidReceiver: transferring to Binance
    _transferEth(APPROVED_CALLER, INVALID_RECEIVER, 1 ether, config.roleKey, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';
  }

  function test_zodiacProdConfiguration_sonic() public {
    vm.createSelectFork(vm.envString('SONIC_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdc, config.safeAddress, 100_000e6);
    _transferAsset(config.usdc, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.usdc;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.inputAmount = 100e6;
    _params.outputAmount = 90e6;
    _params.nativeFee = 10 ether;
    _params.destination = 30_101;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: transferring to invalid receiver
    _transferAsset(config.usdc, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: transferring to invalid receiver
    _transferAsset(config.usdc, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';
  }

  function test_zodiacProdConfiguration_berachain() public {
    vm.createSelectFork(vm.envString('BERACHAIN_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Stargate: configuring the bridge inputs
    BridgeParams memory _params;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.inputAmount = 100e6;
    _params.outputAmount = 90e6;
    _params.nativeFee = 10 ether;
    _params.destination = 30_101;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);

    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }

  function test_zodiacProdConfiguration_mantle() public {
    vm.createSelectFork(vm.envString('MANTLE_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.stargateUsdt, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdc, config.safeAddress, 100_000e6);
    _transferAsset(config.usdc, APPROVED_CALLER, BYBIT_EVM_ADDRESS, config, 1000e6, false);

    // ETH: transferring to Binance
    vm.deal(config.safeAddress, 100 ether);
    _transferEth(APPROVED_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, false);
    _transferEth(APPROVED_CALLER, BYBIT_EVM_ADDRESS, 1 ether, config.roleKey, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Stargate: configuring the bridge inputs
    BridgeParams memory _params;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.usdc;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.inputAmount = 100e6;
    _params.outputAmount = 90e6;
    _params.nativeFee = 40 ether;
    _params.destination = 30_101;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    // //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: transferring to invalid receiver
    _transferAsset(config.usdt, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);

    // invalidCaller: transferring to Binance
    _transferEth(INVALID_CALLER, BINANCE_EVM_ADDRESS, 1 ether, config.roleKey, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: transferring to invalid receiver
    _transferAsset(config.usdc, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);

    // invalidReceiver: transferring to an invalid receiver
    _transferEth(APPROVED_CALLER, INVALID_RECEIVER, 1 ether, config.roleKey, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _dealFunds(config.usdt, _amounts, config.validFee, config.safeAddress);

    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }

  function test_zodiacProdConfiguration_ink() public {
    vm.createSelectFork(vm.envString('INK_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Across: testing across spoke pool can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);

    // WETH: approving weth to burn WETH then unwrapping
    _approveAsset(config.weth, APPROVED_CALLER, config.weth, config, 100 ether, false);
    deal(config.weth, config.safeAddress, 10 ether);
    _unwrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // WETH: wrapping weth
    vm.deal(config.safeAddress, 100 ether);
    _wrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.destination = 10;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.inputAmount = _amounts[0]; // 1 ether
    _params.outputAmount = _amounts[0] * 90_000 / 100_000;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;

    // Across: sending an order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, false);

    // Stargate: sending an order
    _params.inputAmount = 100e6;
    _params.outputAmount = 90e6;
    _params.nativeFee = 0.01 ether;
    _params.destination = 30_101;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    // //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);

    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }

  function test_zodiacProdConfiguration_unichain() public {
    vm.createSelectFork(vm.envString('UNI_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Across: testing across spoke pool can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);

    // WETH: approving weth to burn WETH then unwrapping
    _approveAsset(config.weth, APPROVED_CALLER, config.weth, config, 100 ether, false);
    deal(config.weth, config.safeAddress, 10 ether);
    _unwrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // WETH: wrapping weth
    vm.deal(config.safeAddress, 100 ether);
    _wrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.destination = 10;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.inputAmount = _amounts[0]; // 1 ether
    _params.outputAmount = _amounts[0] * 90_000 / 100_000;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;

    // Across: sending an order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, false);

    // Stargate: sending an order in native
    _params.inputAmount = 1 ether;
    _params.outputAmount = 0.9 ether;
    _params.nativeFee = 0.01 ether;
    _params.destination = 30_101;
    vm.deal(config.safeAddress, 100 ether);
    _sendStargateWeth(_params, config, config.safeAddress, addressConfig.stargateWeth, false);

    _params.inputAmount = 1 ether;
    _params.outputAmount = 0.9 ether;
    _sendStargateWeth(_params, config, config.safeAddress, addressConfig.stargateWeth, false);

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }

  function test_zodiacProdConfiguration_mode() public {
    vm.createSelectFork(vm.envString('MODE_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // // Across: testing across spoke pool can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.across, config, 100 ether, false);

    // WETH: approving weth to burn WETH then unwrapping
    _approveAsset(config.weth, APPROVED_CALLER, config.weth, config, 100 ether, false);
    deal(config.weth, config.safeAddress, 10 ether);
    _unwrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // WETH: wrapping weth
    vm.deal(config.safeAddress, 100 ether);
    _wrapWETH(config.weth, 10 ether, config.roleKey, APPROVED_CALLER, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: ending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Bridges: configuring the bridge inputs
    BridgeParams memory _params;
    _params.destination = 10;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.inputAmount = _amounts[0]; // 1 ether
    _params.outputAmount = _amounts[0] * 90_000 / 100_000;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;

    // Across: sending an order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, false);

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidDepositor: checking random address cannot receive funds with Across
    _params.depositor = INVALID_RECEIVER;
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendDepositV3(_params, config, true);
    _params.depositor = config.safeAddress;

    // invalidReceiver: checking random address cannot receive funds with Across
    _params.receiver = INVALID_RECEIVER;
    _sendDepositV3(_params, config, true);
    _params.receiver = config.safeAddress;

    // invalidRelayer: checking relayer must be address(0)
    _params.exclusiveRelayer = address(0x123);
    _sendDepositV3(_params, config, true);
    _params.exclusiveRelayer = address(0);

    // invalidDeadline: checking exclusivity deadline must be zero
    _params.exclusivityDeadline = uint32(NONZERO_TTL);
    _sendDepositV3(_params, config, true);
    _params.exclusivityDeadline = 0;

    // invalidMessage: checking message must be empty
    _params.message = '0x1234';
    _sendDepositV3(_params, config, true);
    _params.message = '';
  }

  function test_zodiacProdConfiguration_ronin() public {
    vm.createSelectFork(vm.envString('RONIN_RPC'));
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

    // FeeAdapter: testing the test address can set approvals for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdc, config.safeAddress, 100_000e6);
    _transferAsset(config.usdc, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    deal(config.weth, config.safeAddress, 10 ether);
    _transferAsset(config.weth, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 10 ether, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: ending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, PROD_MULTI_SIG_ADDRESS, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, PROD_MULTI_SIG_ADDRESS, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, PROD_MULTI_SIG_ADDRESS, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, PROD_MULTI_SIG_ADDRESS, false, ZERO_TTL, ZERO_FEE
    );

    //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );
  }

  function test_zodiacProdConfiguration_avalanche() public {
    vm.createSelectFork(vm.envString('AVALANCHE_RPC'));
    ZodiacConfiguration memory config = _zodiacConfig[block.chainid];
    ExternalAddresses memory addressConfig = _addressConfig[block.chainid];
    vm.rollFork(config.fixedBlock);

    // Setting up the environment
    feeAdapter = IFeeAdapter(config.feeAdapter);
    roleModule = IRoleModule(config.roleModule);

    //////////////////////////// Supported Actions ////////////////////////////
    // checking module is configured as expected
    _checkRolesConfiguration(config);

    // checking safe is configured as expected
    _checkSafeConfiguration(config);

    // FeeAdapter: testing fee adapter can be set as spender for each asset
    _approveAsset(config.weth, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdc, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, config.feeAdapter, config, 100 ether, false);

    // Stargate: testing stargate can be approved for each asset
    _approveAsset(config.usdc, APPROVED_CALLER, addressConfig.stargateUsdc, config, 100 ether, false);
    _approveAsset(config.usdt, APPROVED_CALLER, addressConfig.stargateUsdt, config, 100 ether, false);

    // Binance: testing can transfer to Binance
    deal(config.usdc, config.safeAddress, 100_000e6);
    _transferAsset(config.usdc, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    deal(config.usdt, config.safeAddress, 100_000e6);
    _transferAsset(config.usdt, APPROVED_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, false);

    // Everclear: sending an order via newOrder - payload pulled related to WETH and already approved via test above
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 1;
    _destinations[1] = 10;

    uint256[] memory _amounts = new uint256[](2);
    _amounts[0] = 1 ether;
    _amounts[1] = 0.001 ether;

    // Everclear: sending new intent
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Everclear: sending new order
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false);
    _dealFunds(config.weth, _amounts, config.validFee, config.safeAddress);
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, false, ZERO_TTL, ZERO_FEE
    );

    // Stargate: sending an order
    BridgeParams memory _params;
    _params.caller = APPROVED_CALLER;
    _params.receiver = config.safeAddress;
    _params.depositor = config.safeAddress;
    _params.inputToken = config.weth;
    _params.quoteTimestamp = uint32(block.timestamp);
    _params.fillDeadline = uint32(block.timestamp + 30 minutes);
    _params.message = '';
    _params.across = addressConfig.across;
    _params.inputAmount = 100e6;
    _params.outputAmount = 90e6;
    _params.nativeFee = 1 ether;
    _params.destination = 30_110;

    vm.deal(config.safeAddress, 100 ether);
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, false);

    // //////////////////////////// Reverting Actions ////////////////////////////
    // invalidCaller: checking an invalid address cannot set approvals for each asset
    _approveAsset(config.weth, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdc, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);
    _approveAsset(config.usdt, INVALID_CALLER, config.feeAdapter, config, 100 ether, true);

    // invalidCaller: transferring to invalid receiver
    _transferAsset(config.usdt, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);
    _transferAsset(config.usdc, INVALID_CALLER, BINANCE_EVM_ADDRESS, config, 1000e6, true);

    // invalidCaller: checking a random address cannot send a new intent
    _sendNewIntent(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, INVALID_CALLER, config.safeAddress, true);

    // invalidSpender: checking an invalid spender cannot be used in approval spender field
    _approveAsset(config.weth, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdc, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);
    _approveAsset(config.usdt, APPROVED_CALLER, INVALID_SPENDER, config, 100 ether, true);

    // invalidReceiver: transferring to invalid receiver
    _transferAsset(config.usdt, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);
    _transferAsset(config.usdc, APPROVED_CALLER, INVALID_RECEIVER, config, 1000e6, true);

    // invalidReceiver: checking a random address cannot receive funds
    _sendNewIntent(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);
    _sendNewOrder(_destinations, _amounts, config, config.weth, APPROVED_CALLER, INVALID_RECEIVER, true);

    // invalidReceiver: checking the receiver invalidity in different arrays
    _sendNewOrderInvalidFirstArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidSecondArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);
    _sendNewOrderInvalidFifthArrayReceiver(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidTTl: checking the order cannot be sent with a non-zero ttl
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, NONZERO_TTL, ZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayTtl(_destinations, _amounts, config, config.weth, APPROVED_CALLER);

    // invalidMaxFee: checking the order cannot be sent with a non-zero max fee
    _sendNewIntent(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrder(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress, true, ZERO_TTL, NONZERO_FEE
    );
    _sendNewOrderInvalidFifthArrayMaxFee(
      _destinations, _amounts, config, config.weth, APPROVED_CALLER, config.safeAddress
    );

    // invalidReceiver: checking random address cannot receive funds wih Stargate
    _params.receiver = INVALID_RECEIVER;
    _dealFunds(config.usdc, _amounts, config.validFee, config.safeAddress);
    _dealFunds(config.usdt, _amounts, config.validFee, config.safeAddress);

    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true);
    _params.receiver = config.safeAddress;

    // invalidRefundReceiver: checking refund address must be safe address
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdc, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateUsdt, true);
    _sendStargate(_params, config, INVALID_RECEIVER, addressConfig.stargateWeth, true);

    // invalidExtraOptions and composeMsg: checking extra options must be empty
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '0x123', '');
    _sendStargate(_params, config, config.safeAddress, addressConfig.stargateWeth, true, '', '0x123');
  }
}
