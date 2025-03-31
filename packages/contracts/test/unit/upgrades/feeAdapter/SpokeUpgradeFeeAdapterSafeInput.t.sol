// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {EverclearSpokeV3} from 'contracts/intent/EverclearSpokeV3.sol';

import {ISpokeStorageV3} from 'contracts/intent/SpokeStorageV3.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {MainnetProductionEnvironment} from 'script/MainnetProduction.sol';
import {MainnetStagingEnvironment} from 'script/MainnetStaging.sol';
import {UpgradeHelper} from 'test//utils/UpgradeHelper.sol';

contract SpokeUpgradeFeeAdapterProdSafeInput is MainnetProductionEnvironment, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  // Deprecated contracts from upgrades //
  address public constant ZIRCUIT_SPOKE_DEPRECATED = 0xa05A3380889115bf313f1Db9d5f335157Be4D816;
  address public constant ZIRCUIT_SPOKE_IMPL_DEPRECATED = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  // Owner //
  address public constant L1_MULTI_SIG = 0xa02a88F0bbD47045001Bd460Ad186C30F9a974d6;
  address public constant L2_MULTI_SIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;

  address public constant BLAST_SPOKE_OWNER = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant L2_MULTI_SIG_2 = 0xBc8988C7a4b77c1d6df7546bd876Ea4D42DF0837;

  // Deployed upgrade contracts //
  address public constant ETHEREUM_SPOKE_UPGRADE_IMPL = address(0);
  address public constant ARB_SPOKE_UPGRADE_IMPL = address(0);
  address public constant OP_SPOKE_UPGRADE_IMPL = address(0);
  address public constant BNB_SPOKE_UPGRADE_IMPL = address(0);
  address public constant BASE_SPOKE_UPGRADE_IMPL = address(0);
  address public constant ZIRCUIT_SPOKE_UPGRADE_IMPL = address(0);
  address public constant BLAST_SPOKE_UPGRADE_IMPL = address(0);
  address public constant LINEA_SPOKE_UPGRADE_IMPL = address(0);
  address public constant POLYGON_SPOKE_UPGRADE_IMPL = address(0);
  address public constant AVALANCHE_SPOKE_UPGRADE_IMPL = address(0);
  address public constant SCROLL_SPOKE_UPGRADE_IMPL = address(0);
  address public constant APECHAIN_SPOKE_UPGRADE_IMPL = address(0);
  address public constant TAIKO_SPOKE_UPGRADE_IMPL = address(0);
  address public constant MODE_SPOKE_UPGRADE_IMPL = address(0);
  address public constant UNICHAIN_SPOKE_UPGRADE_IMPL = address(0);
  address public constant RONIN_SPOKE_UPGRADE_IMPL = address(0);

  function setUp() public {
    //// Arbitrum One
    _deploymentParamsV3[ARBITRUM_ONE] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(ARBITRUM_ONE_SPOKE),
      spokeImpl: ARBITRUM_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    //// Optimism
    _deploymentParamsV3[OPTIMISM] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(OPTIMISM_SPOKE),
      spokeImpl: OPTIMISM_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    //// Base
    _deploymentParamsV3[BASE] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(BASE_SPOKE),
      spokeImpl: BASE_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    //// Bnb
    _deploymentParamsV3[BNB] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(BNB_SPOKE),
      spokeImpl: BNB_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    //// Ethereum
    _deploymentParamsV3[ETHEREUM] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L1_MULTI_SIG,
      spokeProxy: address(ETHEREUM_SPOKE),
      spokeImpl: ETHEREUM_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    //// Zircuit
    _deploymentParamsV3[ZIRCUIT] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(ZIRCUIT_SPOKE),
      spokeImpl: ZIRCUIT_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    // Blast
    _deploymentParamsV3[BLAST] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(BLAST_SPOKE),
      spokeImpl: BLAST_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    // Linea
    _deploymentParamsV3[LINEA] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(LINEA_SPOKE),
      spokeImpl: LINEA_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    // Polygon
    _deploymentParamsV3[POLYGON] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(POLYGON_SPOKE),
      spokeImpl: POLYGON_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    // Avalanche
    _deploymentParamsV3[AVALANCHE] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(AVALANCHE_SPOKE),
      spokeImpl: AVALANCHE_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    // Scroll
    _deploymentParamsV3[SCROLL] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(SCROLL_SPOKE),
      spokeImpl: SCROLL_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    // Ape
    _deploymentParamsV3[APECHAIN] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG_2,
      spokeProxy: address(APECHAIN_SPOKE),
      spokeImpl: APECHAIN_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    // Taiko
    _deploymentParamsV3[TAIKO] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG_2,
      spokeProxy: address(TAIKO_SPOKE),
      spokeImpl: TAIKO_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    // Mode
    _deploymentParamsV3[MODE] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG_2,
      spokeProxy: address(MODE_SPOKE),
      spokeImpl: MODE_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    // Uni
    _deploymentParamsV3[UNICHAIN] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG_2,
      spokeProxy: address(UNICHAIN_SPOKE),
      spokeImpl: UNICHAIN_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    // Ronin
    _deploymentParamsV3[RONIN] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG_2,
      spokeProxy: address(RONIN_SPOKE),
      spokeImpl: RONIN_SPOKE_IMPL,
      feeAdapter: address(0)
    });
  }

  // ============ Upgrade ============ //
  function test_spokeUpgradeFeeAdapterSafe_upgradeMainnetProd() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'));
    vm.rollFork(22_146_318);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ETHEREUM_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '1';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-ethereumMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Ethereum | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeArbitrumProd() public {
    vm.createSelectFork(vm.envString('ARBITRUM_RPC'));
    vm.rollFork(320_483_553);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ARB_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '42161';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-arbitrumMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Arbitrum | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeOptimismProd() public {
    vm.createSelectFork(vm.envString('OPTIMISM_RPC'));
    vm.rollFork(133_790_742);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = OP_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '10';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-optimismMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Optimism | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeBaseProd() public {
    vm.createSelectFork(vm.envString('BASE_RPC'));
    vm.rollFork(28_195_511);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = BASE_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '8453';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-baseMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Base | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeBNBProd() public {
    vm.createSelectFork(vm.envString('BNB_RPC'));
    vm.rollFork(47_866_210);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = BNB_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '56';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-bnbMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | BNB | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeZircuitProd() public {
    vm.createSelectFork(vm.envString('ZIRCUIT_RPC'));
    vm.rollFork(11_622_098);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ZIRCUIT_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '48900';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-zircuitMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Zircuit | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeBlastProd() public {
    vm.createSelectFork(vm.envString('BLAST_RPC'));
    vm.rollFork(17_303_775);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = BLAST_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '81457';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-blastMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Blast | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeLineaProd() public {
    vm.createSelectFork(vm.envString('LINEA_RPC'));
    vm.rollFork(17_564_832);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = LINEA_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '59144';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-lineaMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Linea | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradePolygonProd() public {
    vm.createSelectFork(vm.envString('POLYGON_RPC'));
    vm.rollFork(69_723_951);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = POLYGON_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '137';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-lineaMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Polygon | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeAvalancheProd() public {
    vm.createSelectFork(vm.envString('AVALANCHE_RPC'));
    vm.rollFork(21_053_270);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = AVALANCHE_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '43114';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-avalancheMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Avalanche | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeScrollProd() public {
    vm.createSelectFork(vm.envString('SCROLL_RPC'));
    vm.rollFork(14_331_080);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = SCROLL_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '534352';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-scrollMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Scroll | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeApeProd() public {
    vm.createSelectFork(vm.envString('APE_RPC'));
    vm.rollFork(12_543_894);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = APECHAIN_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '33139';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-apechainMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Apechain | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeTaikoProd() public {
    vm.createSelectFork(vm.envString('TAIKO_RPC'));
    vm.rollFork(1_028_472);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = TAIKO_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '167000';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-taikoMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Taiko | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeModeProd() public {
    vm.createSelectFork(vm.envString('MODE_RPC'));
    vm.rollFork(21_628_204);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = MODE_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '34443';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-modeMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Mode | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeUniProd() public {
    vm.createSelectFork(vm.envString('UNI_RPC'));
    vm.rollFork(12_675_697);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = UNICHAIN_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '130';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-unichainMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Unichain | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeRoninProd() public {
    vm.createSelectFork(vm.envString('RONIN_RPC'));
    vm.rollFork(43_857_109);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = RONIN_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '2020';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-roninMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Ronin | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  // TODO: May need to deploy + upgrade via the zk project
  function test_spokeUpgradeFeeAdapterSafe_upgradeZKSyncProd() public {}
}

contract SpokeUpgradeFeeAdapterMainnetStagingSafeInput is MainnetStagingEnvironment, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  // Owner //
  address public constant L1_MULTI_SIG = 0xa02a88F0bbD47045001Bd460Ad186C30F9a974d6;
  address public constant L2_MULTI_SIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;

  // Deployed upgrade contracts //
  address public constant ETHEREUM_SPOKE_UPGRADE_IMPL = address(0);
  address public constant ARB_SPOKE_UPGRADE_IMPL = address(0);
  address public constant OP_SPOKE_UPGRADE_IMPL = address(0);

  function setUp() public {
    //// Arbitrum One
    _deploymentParamsV3[ARBITRUM_ONE] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(ARBITRUM_ONE_SPOKE),
      spokeImpl: ARBITRUM_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    //// Optimism
    _deploymentParamsV3[OPTIMISM] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(OPTIMISM_SPOKE),
      spokeImpl: OPTIMISM_SPOKE_IMPL,
      feeAdapter: address(0)
    });

    //// Ethereum
    _deploymentParamsV3[ETHEREUM] = DeploymentParamsV3({ // set domain id as mapping key
      owner: L1_MULTI_SIG,
      spokeProxy: address(ETHEREUM_SPOKE),
      spokeImpl: ETHEREUM_SPOKE_IMPL,
      feeAdapter: address(0)
    });
  }

  // ============ Upgrade ============ //
  function test_spokeUpgradeFeeAdapterSafe_upgradeMainnetStaging() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'));
    vm.rollFork(22_146_318);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ETHEREUM_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '1';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-ethereumMainnetStaging.json',
      'Spoke Upgrade Ethereum Mainnet Staging',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeArbitrumStaging() public {
    vm.createSelectFork(vm.envString('ARBITRUM_RPC'));
    vm.rollFork(320_483_553);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ARB_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '42161';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-arbitrumMainnetStaging.json',
      'Spoke Upgrade - Fee Adapter | Arbitrum | Mainnet Staging',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeOptimismStaging() public {
    vm.createSelectFork(vm.envString('OPTIMISM_RPC'));
    vm.rollFork(133_790_742);
    _paramsV3 = _deploymentParamsV3[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = OP_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, _paramsV3.feeAdapter);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function reverts
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV3.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '10';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeFeeAdapter-optimismMainnetStaging.json',
      'Spoke Upgrade - Fee Adapter | Optimism | Mainnet Staging',
      safeTransactions,
      chainId
    );
  }
}
