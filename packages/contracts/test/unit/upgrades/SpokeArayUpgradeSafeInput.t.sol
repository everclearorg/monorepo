// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {ISpecifiesInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {EverclearSpoke, IEverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';
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

contract SpokeArrayUpgradeProdSafeInput is MainnetProductionEnvironment, UpgradeHelper {
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
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      owner: ARBITRUM_SPOKE_OWNER,
      spokeProxy: address(ARBITRUM_ONE_SPOKE),
      spokeImpl: ARBITRUM_SPOKE_IMPL
    });

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({ // set domain id as mapping key
      owner: OPTIMISM_SPOKE_OWNER,
      spokeProxy: address(OPTIMISM_SPOKE),
      spokeImpl: OPTIMISM_SPOKE_IMPL
    });

    //// Base
    _deploymentParams[BASE] = DeploymentParams({ // set domain id as mapping key
      owner: BASE_SPOKE_OWNER,
      spokeProxy: address(BASE_SPOKE),
      spokeImpl: BASE_SPOKE_IMPL
    });

    //// Bnb
    _deploymentParams[BNB] = DeploymentParams({ // set domain id as mapping key
      owner: BNB_SPOKE_OWNER,
      spokeProxy: address(BNB_SPOKE),
      spokeImpl: BNB_SPOKE_IMPL
    });

    //// Ethereum
    _deploymentParams[ETHEREUM] = DeploymentParams({ // set domain id as mapping key
      owner: ETHEREUM_SPOKE_OWNER,
      spokeProxy: address(ETHEREUM_SPOKE),
      spokeImpl: ETHEREUM_SPOKE_IMPL
    });

    //// Zircuit
    _deploymentParams[ZIRCUIT] = DeploymentParams({ // set domain id as mapping key
      owner: ZIRCUIT_SPOKE_OWNER,
      spokeProxy: address(ZIRCUIT_SPOKE_DEPRECATED),
      spokeImpl: ZIRCUIT_SPOKE_IMPL_DEPRECATED
    });
  }

  // ============ Upgrade ============ //
  function test_spokeArrayUpgradeSafe_upgradeMainnetProd() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'));
    vm.rollFork(21_421_710);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ETHEREUM_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '1';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-ethereumMainnetProd.json',
      'Spoke Upgrade Ethereum Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeArrayUpgradeSafe_upgradeArbitrumProd() public {
    vm.createSelectFork(vm.envString('ARBITRUM_RPC'));
    vm.rollFork(285_669_290);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ARB_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '42161';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-arbitrumMainnetProd.json',
      'Spoke Upgrade Arbitrum Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeArrayUpgradeSafe_upgradeOptimismProd() public {
    vm.createSelectFork(vm.envString('OPTIMISM_RPC'));
    vm.rollFork(129_415_940);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = OP_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '10';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-optimismMainnetProd.json',
      'Spoke Upgrade Optimism Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeArrayUpgradeSafe_upgradeBaseProd() public {
    vm.createSelectFork(vm.envString('BASE_RPC'));
    vm.rollFork(23_820_790);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = BASE_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '8453';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-baseMainnetProd.json',
      'Spoke Upgrade Base Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeArrayUpgradeSafe_upgradeBNBProd() public {
    vm.createSelectFork(vm.envString('BNB_RPC'));
    vm.rollFork(44_950_057);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = BNB_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '56';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-bnbMainnetProd.json',
      'Spoke Upgrade BNB Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeArrayUpgradeSafe_upgradeZircuitProd() public {
    vm.createSelectFork(vm.envString('ZIRCUIT_RPC'));
    vm.rollFork(7_309_025);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ZIRCUIT_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '48900';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-zircuitMainnetProd.json',
      'Spoke Upgrade Zircuit Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  // ============ Helpers ============ //
  function _cacheSpokeState() internal view returns (CachedSpokeState memory state) {
    state.permit = address(spokeProxy.PERMIT2());
    state.EVERCLEAR = spokeProxy.EVERCLEAR();
    state.DOMAIN = spokeProxy.DOMAIN();
    state.lighthouse = spokeProxy.lighthouse();
    state.watchtower = spokeProxy.watchtower();
    state.messageReceiver = spokeProxy.messageReceiver();
    state.gateway = address(spokeProxy.gateway());
    state.callExecutor = address(spokeProxy.callExecutor());
    state.paused = spokeProxy.paused();
    state.nonce = spokeProxy.nonce();
    state.messageGasLimit = spokeProxy.messageGasLimit();
  }
}

contract SpokeArrayUpgradeMainnetStagingSafeInput is MainnetStagingEnvironment, UpgradeHelper {
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
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      owner: ARBITRUM_SPOKE_OWNER,
      spokeProxy: address(ARBITRUM_ONE_SPOKE),
      spokeImpl: ARBITRUM_SPOKE_IMPL
    });

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({ // set domain id as mapping key
      owner: OPTIMISM_SPOKE_OWNER,
      spokeProxy: address(OPTIMISM_SPOKE),
      spokeImpl: OPTIMISM_SPOKE_IMPL
    });

    //// Ethereum
    _deploymentParams[ETHEREUM] = DeploymentParams({ // set domain id as mapping key
      owner: ETHEREUM_SPOKE_OWNER,
      spokeProxy: address(ETHEREUM_SPOKE),
      spokeImpl: ETHEREUM_SPOKE_IMPL
    });
  }

  // ============ Upgrade ============ //
  function test_spokeArrayUpgradeSafe_upgradeMainnetStaging() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'));
    vm.rollFork(21_409_813);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ETHEREUM_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '1';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-ethereumMainnetStaging.json',
      'Spoke Upgrade Ethereum Mainnet Staging',
      safeTransactions,
      chainId
    );
  }

  function test_spokeArrayUpgradeSafe_upgradeArbitrumStaging() public {
    vm.createSelectFork(vm.envString('ARBITRUM_RPC'));
    vm.rollFork(285_592_581);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ARB_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '42161';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-arbitrumMainnetStaging.json',
      'Spoke Upgrade Arbitrum Mainnet Staging',
      safeTransactions,
      chainId
    );
  }

  function test_spokeArrayUpgradeSafe_upgradeOptimismStaging() public {
    vm.createSelectFork(vm.envString('OPTIMISM_RPC'));
    vm.rollFork(129_406_283);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = OP_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '10';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-optimismMainnetStaging.json',
      'Spoke Upgrade Optimism Mainnet Staging',
      safeTransactions,
      chainId
    );
  }

  // ============ Helpers ============ //
  function _cacheSpokeState() internal view returns (CachedSpokeState memory state) {
    state.permit = address(spokeProxy.PERMIT2());
    state.EVERCLEAR = spokeProxy.EVERCLEAR();
    state.DOMAIN = spokeProxy.DOMAIN();
    state.lighthouse = spokeProxy.lighthouse();
    state.watchtower = spokeProxy.watchtower();
    state.messageReceiver = spokeProxy.messageReceiver();
    state.gateway = address(spokeProxy.gateway());
    state.callExecutor = address(spokeProxy.callExecutor());
    state.paused = spokeProxy.paused();
    state.nonce = spokeProxy.nonce();
    state.messageGasLimit = spokeProxy.messageGasLimit();
  }
}

contract SpokeArrayUpgradeTestnetStagingSafeInput is TestnetStagingEnvironment, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  // ============ Constants ============ //
  // Current Owner //
  address public constant ETHEREUM_SPOKE_OWNER = 0xbb8012544f64AdAC48357eE474e6B8e641151dad;
  address public constant ARB_SPOKE_OWNER = 0xbb8012544f64AdAC48357eE474e6B8e641151dad;
  address public constant OP_SPOKE_OWNER = 0xbb8012544f64AdAC48357eE474e6B8e641151dad;
  address public constant BSC_SPOKE_OWNER = 0xbb8012544f64AdAC48357eE474e6B8e641151dad;

  address public constant ETHEREUM_SEPOLIA_SPOKE_IMPL = 0xDfcC61b2cbE946Bf6cd7c261d1cfb19A7ef47E55;
  address public constant ARB_SEPOLIA_SPOKE_IMPL = 0xDfcC61b2cbE946Bf6cd7c261d1cfb19A7ef47E55;
  address public constant OP_SEPOLIA_SPOKE_IMPL = 0xDfcC61b2cbE946Bf6cd7c261d1cfb19A7ef47E55;
  address public constant BSC_TESTNET_SPOKE_IMPL = 0xDfcC61b2cbE946Bf6cd7c261d1cfb19A7ef47E55;

  address public constant ETHEREUM_SEPOLIA_SPOKE_UPGRADE_IMPL = address(0);
  address public constant ARB_SEPOLIA_SPOKE_UPGRADE_IMPL = 0xD385Af1A209890AEE184BDf75f328aC396d52fB6;
  address public constant OP_SEPOLIA_SPOKE_UPGRADE_IMPL = 0xD385Af1A209890AEE184BDf75f328aC396d52fB6;
  address public constant BSC_TESTNET_SPOKE_UPGRADE_IMPL = 0xD385Af1A209890AEE184BDf75f328aC396d52fB6;

  function setUp() public {
    // Ethereum Sepolia
    _deploymentParams[ETHEREUM_SEPOLIA] = DeploymentParams({
      owner: ETHEREUM_SPOKE_OWNER,
      spokeProxy: address(ETHEREUM_SEPOLIA_SPOKE),
      spokeImpl: ETHEREUM_SEPOLIA_SPOKE_IMPL
    });

    // BSC Testnet
    _deploymentParams[BSC_TESTNET] =
      DeploymentParams({owner: BSC_SPOKE_OWNER, spokeProxy: address(BSC_SPOKE), spokeImpl: BSC_TESTNET_SPOKE_IMPL});

    // Op Sepolia
    _deploymentParams[OP_SEPOLIA] =
      DeploymentParams({owner: OP_SPOKE_OWNER, spokeProxy: address(OP_SEPOLIA_SPOKE), spokeImpl: OP_SEPOLIA_SPOKE_IMPL});

    // Arb Sepolia
    _deploymentParams[ARB_SEPOLIA] = DeploymentParams({
      owner: ARB_SPOKE_OWNER,
      spokeProxy: address(ARB_SEPOLIA_SPOKE),
      spokeImpl: ARB_SEPOLIA_SPOKE_IMPL
    });
  }

  // ============ Upgrade ============ //
  function test_spokeArrayUpgradeSafe_upgradeEthereumSepolia() private {
    vm.createSelectFork(vm.envString('ETHEREUM_SEPOLIA_RPC'));
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ETHEREUM_SEPOLIA_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '11155111';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-ethereumSepolia.json',
      'Spoke Upgrade Ethereum Sepolia',
      safeTransactions,
      chainId
    );
  }

  function test_spokeArrayUpgradeSafe_upgradeArbitrumSepolia() public {
    vm.createSelectFork(vm.envString('ARB_SEPOLIA_RPC'));
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = ARB_SEPOLIA_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '421614';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-arbitrumSepolia.json',
      'Spoke Upgrade Arbitrum Sepolia',
      safeTransactions,
      chainId
    );
  }

  function test_spokeArrayUpgradeSafe_upgradeOptimismSepolia() public {
    vm.createSelectFork(vm.envString('OP_SEPOLIA_RPC'));
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = OP_SEPOLIA_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '11155420';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-optimismSepolia.json',
      'Spoke Upgrade Optimism Sepolia',
      safeTransactions,
      chainId
    );
  }

  function test_spokeArrayUpgradeSafe_upgradeBNBTestnet() public {
    vm.createSelectFork(vm.envString('BNB_TESTNET_RPC'));
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = BSC_TESTNET_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_params.owner);
    (success,) = _params.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
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
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '97';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-bnbTestnet.json', 'Spoke Upgrade BNB Testnet', safeTransactions, chainId
    );
  }

  // ============ Helpers ============ //
  function _cacheSpokeState() internal view returns (CachedSpokeState memory state) {
    state.permit = address(spokeProxy.PERMIT2());
    state.EVERCLEAR = spokeProxy.EVERCLEAR();
    state.DOMAIN = spokeProxy.DOMAIN();
    state.lighthouse = spokeProxy.lighthouse();
    state.watchtower = spokeProxy.watchtower();
    state.messageReceiver = spokeProxy.messageReceiver();
    state.gateway = address(spokeProxy.gateway());
    state.callExecutor = address(spokeProxy.callExecutor());
    state.paused = spokeProxy.paused();
    state.nonce = spokeProxy.nonce();
    state.messageGasLimit = spokeProxy.messageGasLimit();
  }
}
