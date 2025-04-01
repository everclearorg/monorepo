// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {EverclearSpokeV3} from 'contracts/intent/EverclearSpokeV3.sol';

import {ISpokeStorage} from 'contracts/intent/SpokeStorage.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {MainnetProductionEnvironment} from 'script/MainnetProduction.sol';
import {MainnetStagingEnvironment} from 'script/MainnetStaging.sol';
import {UpgradeHelper} from 'test//utils/UpgradeHelper.sol';

import {TestERC20} from 'test/utils/TestERC20.sol';

contract SpokeUpgradeSolanaCompatibilityProdSafeInput is MainnetProductionEnvironment, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  // Deprecated contracts from upgrades //
  address public constant ZIRCUIT_SPOKE_DEPRECATED = 0xa05A3380889115bf313f1Db9d5f335157Be4D816;
  address public constant ZIRCUIT_SPOKE_IMPL_DEPRECATED = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  // Owner //
  address public constant L1_MULTI_SIG = 0xa02a88F0bbD47045001Bd460Ad186C30F9a974d6;
  address public constant L2_MULTI_SIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant APECHAIN_MULTI_SIG = 0xAF986F36D0471002ff2A64bAF0653c9F6F3A925B;

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
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(ARBITRUM_ONE_SPOKE),
      spokeImpl: ARBITRUM_SPOKE_IMPL
    });

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(OPTIMISM_SPOKE),
      spokeImpl: OPTIMISM_SPOKE_IMPL
    });

    //// Base
    _deploymentParams[BASE] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(BASE_SPOKE),
      spokeImpl: BASE_SPOKE_IMPL
    });

    //// Bnb
    _deploymentParams[BNB] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(BNB_SPOKE),
      spokeImpl: BNB_SPOKE_IMPL
    });

    //// Ethereum
    _deploymentParams[ETHEREUM] = DeploymentParams({ // set domain id as mapping key
      owner: L1_MULTI_SIG,
      spokeProxy: address(ETHEREUM_SPOKE),
      spokeImpl: ETHEREUM_SPOKE_IMPL
    });

    //// Zircuit
    _deploymentParams[ZIRCUIT] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(ZIRCUIT_SPOKE),
      spokeImpl: ZIRCUIT_SPOKE_IMPL
    });

    // Blast
    _deploymentParams[BLAST] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(BLAST_SPOKE),
      spokeImpl: BLAST_SPOKE_IMPL
    });

    // Linea
    _deploymentParams[LINEA] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(LINEA_SPOKE),
      spokeImpl: LINEA_SPOKE_IMPL
    });

    // Polygon
    _deploymentParams[POLYGON] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(POLYGON_SPOKE),
      spokeImpl: POLYGON_SPOKE_IMPL
    });

    // Avalanche
    _deploymentParams[AVALANCHE] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(AVALANCHE_SPOKE),
      spokeImpl: AVALANCHE_SPOKE_IMPL
    });

    // Scroll
    _deploymentParams[SCROLL] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(SCROLL_SPOKE),
      spokeImpl: SCROLL_SPOKE_IMPL
    });

    // Ape
    _deploymentParams[APECHAIN] = DeploymentParams({ // set domain id as mapping key
      owner: APECHAIN_MULTI_SIG,
      spokeProxy: address(APECHAIN_SPOKE),
      spokeImpl: APECHAIN_SPOKE_IMPL
    });

    // Taiko
    _deploymentParams[TAIKO] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(TAIKO_SPOKE),
      spokeImpl: TAIKO_SPOKE_IMPL
    });

    // Mode
    _deploymentParams[MODE] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(MODE_SPOKE),
      spokeImpl: MODE_SPOKE_IMPL
    });

    // Uni
    _deploymentParams[UNICHAIN] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(UNICHAIN_SPOKE),
      spokeImpl: UNICHAIN_SPOKE_IMPL
    });

    // Ronin
    _deploymentParams[RONIN] = DeploymentParams({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(RONIN_SPOKE),
      spokeImpl: RONIN_SPOKE_IMPL
    });
  }

  function _getDestinations(
    uint32 _destination
  ) internal pure returns (uint32[] memory _dests) {
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;
    return _destinations;
  }

  function deployAndDeal(address _receiver, uint256 _amount) public returns (bytes32 _token) {
    address _tokenAddress = address(new TestERC20('Token', 'TKN'));
    deal(_tokenAddress, _receiver, _amount);
    _token = _tokenAddress.toBytes32();
  }

  // ============ Upgrade ============ //
  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeMainnetProd() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'));
    vm.rollFork(22_146_318);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '1';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-ethereumMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Ethereum | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeArbitrumProd() public {
    vm.createSelectFork(vm.envString('ARBITRUM_RPC'));
    vm.rollFork(320_483_553);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '42161';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-arbitrumMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Arbitrum | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeOptimismProd() public {
    vm.createSelectFork(vm.envString('OPTIMISM_RPC'));
    vm.rollFork(133_790_742);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '10';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-optimismMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Optimism | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeBaseProd() public {
    vm.createSelectFork(vm.envString('BASE_RPC'));
    vm.rollFork(28_195_511);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '8453';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-baseMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Base | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeBNBProd() public {
    vm.createSelectFork(vm.envString('BNB_RPC'));
    vm.rollFork(47_866_210);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '56';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-bnbMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | BNB | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeZircuitProd() public {
    vm.createSelectFork(vm.envString('ZIRCUIT_RPC'));
    vm.rollFork(11_622_098);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '48900';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-zircuitMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Zircuit | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeBlastProd() public {
    vm.createSelectFork(vm.envString('BLAST_RPC'));
    vm.rollFork(17_303_775);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = BLAST_SPOKE_UPGRADE_IMPL;

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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '81457';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-blastMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Blast | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeLineaProd() public {
    vm.createSelectFork(vm.envString('LINEA_RPC'));
    vm.rollFork(17_564_832);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = LINEA_SPOKE_UPGRADE_IMPL;

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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '59144';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-lineaMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Linea | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradePolygonProd() public {
    vm.createSelectFork(vm.envString('POLYGON_RPC'));
    vm.rollFork(69_723_951);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = POLYGON_SPOKE_UPGRADE_IMPL;

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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '137';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-lineaMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Polygon | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeAvalancheProd() public {
    vm.createSelectFork(vm.envString('AVALANCHE_RPC'));
    vm.rollFork(21_053_270);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = AVALANCHE_SPOKE_UPGRADE_IMPL;

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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '43114';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-avalancheMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Avalanche | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeScrollProd() public {
    vm.createSelectFork(vm.envString('SCROLL_RPC'));
    vm.rollFork(14_331_080);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = SCROLL_SPOKE_UPGRADE_IMPL;

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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '534352';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-scrollMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Scroll | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeApeProd() public {
    vm.createSelectFork(vm.envString('APE_RPC'));
    vm.rollFork(12_543_894);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = APECHAIN_SPOKE_UPGRADE_IMPL;

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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '33139';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-apechainMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Apechain | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeTaikoProd() public {
    vm.createSelectFork(vm.envString('TAIKO_RPC'));
    vm.rollFork(1_028_472);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = TAIKO_SPOKE_UPGRADE_IMPL;

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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '167000';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-taikoMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Taiko | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeModeProd() public {
    vm.createSelectFork(vm.envString('MODE_RPC'));
    vm.rollFork(21_628_204);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = MODE_SPOKE_UPGRADE_IMPL;

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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '34443';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-modeMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Mode | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeUniProd() public {
    vm.createSelectFork(vm.envString('UNI_RPC'));
    vm.rollFork(12_675_697);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = UNICHAIN_SPOKE_UPGRADE_IMPL;

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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '130';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-unichainMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Unichain | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeRoninProd() public {
    vm.createSelectFork(vm.envString('RONIN_RPC'));
    vm.rollFork(43_857_109);
    _params = _deploymentParams[block.chainid];

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(_params.spokeProxy);
    address oldImplementation = (vm.load(_params.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _params.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();
    address newEverclearSpoke = RONIN_SPOKE_UPGRADE_IMPL;

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

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    // approving the spokeProxy
    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

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

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _params.spokeProxy, upgradeCalldata));
    string memory chainId = '2020';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeSolanaCompatibility-roninMainnetProd.json',
      'Spoke Upgrade - Fee Adapter | Ronin | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  // TODO: May need to deploy + upgrade via the zk project
  function test_spokeUpgradeSolanaCompatibilitySafe_upgradeZKSyncProd() public {}
}