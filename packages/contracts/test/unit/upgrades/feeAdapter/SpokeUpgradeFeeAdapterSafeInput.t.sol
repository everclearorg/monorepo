// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {ISpecifiesInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {EverclearSpokeV3, IEverclearSpokeV3} from 'contracts/intent/EverclearSpokeV3.sol';

import {ISpokeStorageV3} from 'contracts/intent/SpokeStorageV3.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';

import {Deploy} from 'script/utils/Deploy.sol';
import {BaseTest} from 'test/unit/intent/EverclearSpoke.t.sol';
import {Constants} from 'test/utils/Constants.sol';
import {SafeTxBuilder} from 'test/utils/SafeTxBuilder.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'forge-std/console.sol';

import {MainnetProductionEnvironment} from 'script/MainnetProduction.sol';
import {MainnetStagingEnvironment} from 'script/MainnetStaging.sol';
import {TestnetStagingEnvironment} from 'script/TestnetStaging.sol';
import {ICREATE3, UpgradeHelper} from 'test//utils/UpgradeHelper.sol';

contract SpokeUpgradeFeeAdapterProdSafeInput is MainnetProductionEnvironment, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  // Deprecated contracts from upgrades //
  address public constant ZIRCUIT_SPOKE_DEPRECATED = 0xa05A3380889115bf313f1Db9d5f335157Be4D816;
  address public constant ZIRCUIT_SPOKE_IMPL_DEPRECATED = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  // Owner //
  address public constant ETHEREUM_SPOKE_OWNER = 0xa02a88F0bbD47045001Bd460Ad186C30F9a974d6;
  address public constant ARBITRUM_SPOKE_OWNER = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant OPTIMISM_SPOKE_OWNER = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant BASE_SPOKE_OWNER = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant BNB_SPOKE_OWNER = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant ZIRCUIT_SPOKE_OWNER = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;

  // Deployed upgrade contracts //
  address public constant ETHEREUM_SPOKE_UPGRADE_IMPL = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;
  address public constant ARB_SPOKE_UPGRADE_IMPL = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;
  address public constant OP_SPOKE_UPGRADE_IMPL = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;
  address public constant BNB_SPOKE_UPGRADE_IMPL = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;
  address public constant BASE_SPOKE_UPGRADE_IMPL = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;
  address public constant ZIRCUIT_SPOKE_UPGRADE_IMPL = 0xB8153E02046B8aB4584eA8B85175212A9e7c3E97;

  function setUp() public {
    //// Arbitrum One
    _deploymentParamsV3[ARBITRUM_ONE] = DeploymentParamsV3({ // set domain id as mapping key
      owner: ARBITRUM_SPOKE_OWNER,
      spokeProxy: address(ARBITRUM_ONE_SPOKE),
      spokeImpl: ARBITRUM_SPOKE_IMPL,
      feeAdapter: address(0x123)
    });

    //// Optimism
    _deploymentParamsV3[OPTIMISM] = DeploymentParamsV3({ // set domain id as mapping key
      owner: OPTIMISM_SPOKE_OWNER,
      spokeProxy: address(OPTIMISM_SPOKE),
      spokeImpl: OPTIMISM_SPOKE_IMPL,
      feeAdapter: address(0x123)
    });

    //// Base
    _deploymentParamsV3[BASE] = DeploymentParamsV3({ // set domain id as mapping key
      owner: BASE_SPOKE_OWNER,
      spokeProxy: address(BASE_SPOKE),
      spokeImpl: BASE_SPOKE_IMPL,
      feeAdapter: address(0x123)
    });

    //// Bnb
    _deploymentParamsV3[BNB] = DeploymentParamsV3({ // set domain id as mapping key
      owner: BNB_SPOKE_OWNER,
      spokeProxy: address(BNB_SPOKE),
      spokeImpl: BNB_SPOKE_IMPL,
      feeAdapter: address(0x123)
    });

    //// Ethereum
    _deploymentParamsV3[ETHEREUM] = DeploymentParamsV3({ // set domain id as mapping key
      owner: ETHEREUM_SPOKE_OWNER,
      spokeProxy: address(ETHEREUM_SPOKE),
      spokeImpl: ETHEREUM_SPOKE_IMPL,
      feeAdapter: address(0x123)
    });

    //// Zircuit
    _deploymentParamsV3[ZIRCUIT] = DeploymentParamsV3({ // set domain id as mapping key
      owner: ZIRCUIT_SPOKE_OWNER,
      spokeProxy: address(ZIRCUIT_SPOKE_DEPRECATED),
      spokeImpl: ZIRCUIT_SPOKE_IMPL_DEPRECATED,
      feeAdapter: address(0x123)
    });
  }

  // ============ Upgrade ============ //
  function test_spokeUpgradeFeeAdapterSafe_upgradeMainnetProd() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'));
    vm.rollFork(22_146_318);
    _paramsV3 = _deploymentParamsV3[block.chainid];

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
    _intent.destinations = new uint32[](11);

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
      'safeTransactionInputs/upgradeSpokeArray-ethereumMainnetProd.json',
      'Spoke Upgrade Ethereum Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeArbitrumProd() public {
    vm.createSelectFork(vm.envString('ARBITRUM_RPC'));
    vm.rollFork(320_483_553);
    _paramsV3 = _deploymentParamsV3[block.chainid];

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
    _intent.destinations = new uint32[](11);

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
      'safeTransactionInputs/upgradeSpokeArray-arbitrumMainnetProd.json',
      'Spoke Upgrade Arbitrum Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeOptimismProd() public {
    vm.createSelectFork(vm.envString('OPTIMISM_RPC'));
    vm.rollFork(133_790_742);
    _paramsV3 = _deploymentParamsV3[block.chainid];

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
    _intent.destinations = new uint32[](11);

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
      'Spoke Upgrade Optimism Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeBaseProd() public {
    vm.createSelectFork(vm.envString('BASE_RPC'));
    vm.rollFork(28_195_511);
    _paramsV3 = _deploymentParamsV3[block.chainid];

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
    _intent.destinations = new uint32[](11);

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
      'safeTransactionInputs/upgradeSpokeArray-baseMainnetProd.json',
      'Spoke Upgrade Base Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeBNBProd() public {
    vm.createSelectFork(vm.envString('BNB_RPC'));
    vm.rollFork(47_866_210);
    _paramsV3 = _deploymentParamsV3[block.chainid];

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
    _intent.destinations = new uint32[](11);

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
      'safeTransactionInputs/upgradeSpokeArray-bnbMainnetProd.json',
      'Spoke Upgrade BNB Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeZircuitProd() public {
    vm.createSelectFork(vm.envString('ZIRCUIT_RPC'));
    vm.rollFork(11_622_098);
    _paramsV3 = _deploymentParamsV3[block.chainid];

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
    _intent.destinations = new uint32[](11);

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
      'safeTransactionInputs/upgradeSpokeArray-zircuitMainnetProd.json',
      'Spoke Upgrade Zircuit Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeBlastProd() public {}

  function test_spokeUpgradeFeeAdapterSafe_upgradeLineaProd() public {}

  function test_spokeUpgradeFeeAdapterSafe_upgradePolygonProd() public {}

  function test_spokeUpgradeFeeAdapterSafe_upgradeAvalancheProd() public {}

  function test_spokeUpgradeFeeAdapterSafe_upgradeScrollProd() public {}

  function test_spokeUpgradeFeeAdapterSafe_upgradeApeProd() public {}

  function test_spokeUpgradeFeeAdapterSafe_upgradeTaikoProd() public {}

  function test_spokeUpgradeFeeAdapterSafe_upgradeModeProd() public {}

  function test_spokeUpgradeFeeAdapterSafe_upgradeUniProd() public {}

  function test_spokeUpgradeFeeAdapterSafe_upgradeRoninProd() public {}

  // TODO: May need to deploy + upgrade via the zk project
  function test_spokeUpgradeFeeAdapterSafe_upgradeZKSyncProd() public {}
}

contract SpokeUpgradeFeeAdapterMainnetStagingSafeInput is MainnetStagingEnvironment, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  // Owner //
  address public constant ETHEREUM_SPOKE_OWNER = 0xa02a88F0bbD47045001Bd460Ad186C30F9a974d6;
  address public constant ARBITRUM_SPOKE_OWNER = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant OPTIMISM_SPOKE_OWNER = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;

  // Deployed upgrade contracts //
  address public constant ETHEREUM_SPOKE_UPGRADE_IMPL = 0x259F03D45eA8dE916a935E388024cF86D893244A;
  address public constant ARB_SPOKE_UPGRADE_IMPL = 0x259F03D45eA8dE916a935E388024cF86D893244A;
  address public constant OP_SPOKE_UPGRADE_IMPL = 0x259F03D45eA8dE916a935E388024cF86D893244A;

  function setUp() public {
    //// Arbitrum One
    _deploymentParamsV3[ARBITRUM_ONE] = DeploymentParamsV3({ // set domain id as mapping key
      owner: ARBITRUM_SPOKE_OWNER,
      spokeProxy: address(ARBITRUM_ONE_SPOKE),
      spokeImpl: ARBITRUM_SPOKE_IMPL,
      feeAdapter: address(0x123)
    });

    //// Optimism
    _deploymentParamsV3[OPTIMISM] = DeploymentParamsV3({ // set domain id as mapping key
      owner: OPTIMISM_SPOKE_OWNER,
      spokeProxy: address(OPTIMISM_SPOKE),
      spokeImpl: OPTIMISM_SPOKE_IMPL,
      feeAdapter: address(0x123)
    });

    //// Ethereum
    _deploymentParamsV3[ETHEREUM] = DeploymentParamsV3({ // set domain id as mapping key
      owner: ETHEREUM_SPOKE_OWNER,
      spokeProxy: address(ETHEREUM_SPOKE),
      spokeImpl: ETHEREUM_SPOKE_IMPL,
      feeAdapter: address(0x123)
    });
  }

  // ============ Upgrade ============ //
  function test_spokeUpgradeFeeAdapterSafe_upgradeMainnetStaging() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'));
    vm.rollFork(22_146_318);
    _paramsV3 = _deploymentParamsV3[block.chainid];

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
    _intent.destinations = new uint32[](11);

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
      'safeTransactionInputs/upgradeSpokeArray-ethereumMainnetStaging.json',
      'Spoke Upgrade Ethereum Mainnet Staging',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeArbitrumStaging() public {
    vm.createSelectFork(vm.envString('ARBITRUM_RPC'));
    vm.rollFork(320_483_553);
    _paramsV3 = _deploymentParamsV3[block.chainid];

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
    _intent.destinations = new uint32[](11);

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
      'safeTransactionInputs/upgradeSpokeArray-arbitrumMainnetStaging.json',
      'Spoke Upgrade Arbitrum Mainnet Staging',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeFeeAdapterSafe_upgradeOptimismStaging() public {
    vm.createSelectFork(vm.envString('OPTIMISM_RPC'));
    vm.rollFork(133_790_742);
    _paramsV3 = _deploymentParamsV3[block.chainid];

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
    _intent.destinations = new uint32[](11);

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
      'safeTransactionInputs/upgradeSpokeArray-optimismMainnetStaging.json',
      'Spoke Upgrade Optimism Mainnet Staging',
      safeTransactions,
      chainId
    );
  }
}
