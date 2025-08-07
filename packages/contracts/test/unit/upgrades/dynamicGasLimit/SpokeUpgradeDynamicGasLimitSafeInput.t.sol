// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {EverclearSpokeV5} from 'contracts/intent/EverclearSpokeV5.sol';

import {ISpokeStorageV5} from 'contracts/intent/SpokeStorageV5.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {MainnetProductionEnvironment} from 'script/MainnetProduction.sol';
import {MainnetStagingEnvironment} from 'script/MainnetStaging.sol';
import {UpgradeHelper} from 'test//utils/UpgradeHelper.sol';

contract SpokeUpgradeDynamicGasLimitProdSafeInput is MainnetProductionEnvironment, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  // Deprecated contracts from upgrades //
  address public constant ZIRCUIT_SPOKE_DEPRECATED = 0xa05A3380889115bf313f1Db9d5f335157Be4D816;
  address public constant ZIRCUIT_SPOKE_IMPL_DEPRECATED = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;

  // Owner //
  address public constant L1_MULTI_SIG = 0xa02a88F0bbD47045001Bd460Ad186C30F9a974d6;
  address public constant L2_MULTI_SIG = 0xf20d5277aD2f301E2F18e2948fF3e72Ad0A6dfF9;
  address public constant APECHAIN_MULTI_SIG = 0xAF986F36D0471002ff2A64bAF0653c9F6F3A925B;

  // Deprecated contracts
  address public constant ETHEREUM_SPOKE_DEPRECATED_IMPL = 0xd18C19169e7C87e7d84f27AD412a56C5D743D560;
  address public constant ARBITRUM_SPOKE_DEPRECATED_IMPL = 0xd18C19169e7C87e7d84f27AD412a56C5D743D560;
  address public constant OPTIMISM_SPOKE_DEPRECATED_IMPL = 0xd18C19169e7C87e7d84f27AD412a56C5D743D560;
  address public constant BNB_SPOKE_DEPRECATED_IMPL = 0xd18C19169e7C87e7d84f27AD412a56C5D743D560;
  address public constant BASE_SPOKE_DEPRECATED_IMPL = 0xd18C19169e7C87e7d84f27AD412a56C5D743D560;
  address public constant ZIRCUIT_SPOKE_DEPRECATED_IMPL = 0x81fFF6085F4A77a2e1E6fd31d0F5b972fE869226;
  address public constant BLAST_SPOKE_DEPRECATED_IMPL = 0x15D54e449Ff6Fd32342eE667314a9f46f6eb86e3;
  address public constant LINEA_SPOKE_DEPRECATED_IMPL = 0x9aA2Ecad5C77dfcB4f34893993f313ec4a370460;
  address public constant POLYGON_SPOKE_DEPRECATED_IMPL = 0x15D54e449Ff6Fd32342eE667314a9f46f6eb86e3;
  address public constant AVALANCHE_SPOKE_DEPRECATED_IMPL = 0x15D54e449Ff6Fd32342eE667314a9f46f6eb86e3;
  address public constant SCROLL_SPOKE_DEPRECATED_IMPL = 0x15D54e449Ff6Fd32342eE667314a9f46f6eb86e3;
  address public constant APECHAIN_SPOKE_DEPRECATED_IMPL = 0x15D54e449Ff6Fd32342eE667314a9f46f6eb86e3;
  address public constant TAIKO_SPOKE_DEPRECATED_IMPL = 0xe0F010e465f15dcD42098dF9b99F1038c11B3056;
  address public constant MODE_SPOKE_DEPRECATED_IMPL = 0x15D54e449Ff6Fd32342eE667314a9f46f6eb86e3;
  address public constant UNICHAIN_SPOKE_DEPRECATED_IMPL = 0xd18C19169e7C87e7d84f27AD412a56C5D743D560;
  address public constant RONIN_SPOKE_DEPRECATED_IMPL = 0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa;
  address public constant GNOSIS_SPOKE_DEPRECATED_IMPL = 0x39291a3118Db3644890Ff79fa0D15Dd3cb035927;
  address public constant BERACHAIN_SPOKE_DEPRECATED_IMPL = 0xDD88C7F9474c017E6Af23eb233CA6e3c887648a0;
  address public constant MANTLE_SPOKE_DEPRECATED_IMPL = 0x39291a3118Db3644890Ff79fa0D15Dd3cb035927;
  address public constant SONIC_SPOKE_DEPRECATED_IMPL = 0x15D54e449Ff6Fd32342eE667314a9f46f6eb86e3;
  address public constant INK_SPOKE_DEPRECATED_IMPL = 0xA3534bb14b32579096dfe4352b37FF67CC70B74A;

  // Deployed upgrade contracts //
  address public constant ETHEREUM_SPOKE_UPGRADE_IMPL = 0xb0CE951eF4655C73E42E3c7D85eF166E7c615Af7;
  address public constant ARB_SPOKE_UPGRADE_IMPL = 0xb0CE951eF4655C73E42E3c7D85eF166E7c615Af7;
  address public constant OP_SPOKE_UPGRADE_IMPL = 0xb0CE951eF4655C73E42E3c7D85eF166E7c615Af7;
  address public constant BNB_SPOKE_UPGRADE_IMPL = 0xb0CE951eF4655C73E42E3c7D85eF166E7c615Af7;
  address public constant BASE_SPOKE_UPGRADE_IMPL = 0xb0CE951eF4655C73E42E3c7D85eF166E7c615Af7;
  address public constant ZIRCUIT_SPOKE_UPGRADE_IMPL = address(0);
  address public constant BLAST_SPOKE_UPGRADE_IMPL = 0x52fda30b2d5c391C69faD37322E9e3629d830b0f;
  address public constant LINEA_SPOKE_UPGRADE_IMPL = address(0);
  address public constant POLYGON_SPOKE_UPGRADE_IMPL = 0x18eF4fA0b97FE9D5d3af6c6DB15378B03dC82D30;
  address public constant AVALANCHE_SPOKE_UPGRADE_IMPL = 0x5860eEB5506e8B4dEf8052bC9e3368F947BBafeE;
  address public constant SCROLL_SPOKE_UPGRADE_IMPL = 0x48075FE83aaAc77CcA9A70F2FAa689e3C8b1e3b0;
  address public constant APECHAIN_SPOKE_UPGRADE_IMPL = 0x48075FE83aaAc77CcA9A70F2FAa689e3C8b1e3b0;
  address public constant TAIKO_SPOKE_UPGRADE_IMPL = address(0);
  address public constant MODE_SPOKE_UPGRADE_IMPL = 0x4A181EbD888c5211942eE8d96400e243fF33BfCA;
  address public constant UNICHAIN_SPOKE_UPGRADE_IMPL = 0xb0CE951eF4655C73E42E3c7D85eF166E7c615Af7;
  address public constant RONIN_SPOKE_UPGRADE_IMPL = 0x502d018777158b0a3C818499fC94Cb2041E00201;
  address public constant GNOSIS_SPOKE_UPGRADE_IMPL = 0x6B660e40148Cb05d5d95184e9C02F02b00a45A4E;
  address public constant BERACHAIN_SPOKE_UPGRADE_IMPL = 0x6bfA24Ab64adaCfEC69c5440bf9Ed84C485Eb9ad;
  address public constant MANTLE_SPOKE_UPGRADE_IMPL = 0x27508d1c61Fcc99B4b6e608eF5305AAF5dc1f0a0;
  address public constant SONIC_SPOKE_UPGRADE_IMPL = 0x48075FE83aaAc77CcA9A70F2FAa689e3C8b1e3b0;
  address public constant INK_SPOKE_UPGRADE_IMPL = 0xc715486b1048996fb2F707CE50c0C84Cd1143583;

  function setUp() public {
    //// Arbitrum One
    _deploymentParamsV4[ARBITRUM_ONE] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(ARBITRUM_ONE_SPOKE),
      spokeImpl: ARBITRUM_SPOKE_DEPRECATED_IMPL,
      feeAdapter: ARBITRUM_FEE_ADAPTER
    });

    //// Optimism
    _deploymentParamsV4[OPTIMISM] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(OPTIMISM_SPOKE),
      spokeImpl: OPTIMISM_SPOKE_DEPRECATED_IMPL,
      feeAdapter: OPTIMISM_FEE_ADAPTER
    });

    //// Base
    _deploymentParamsV4[BASE] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(BASE_SPOKE),
      spokeImpl: BASE_SPOKE_DEPRECATED_IMPL,
      feeAdapter: BASE_FEE_ADAPTER
    });

    //// Bnb
    _deploymentParamsV4[BNB] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(BNB_SPOKE),
      spokeImpl: BNB_SPOKE_DEPRECATED_IMPL,
      feeAdapter: BNB_FEE_ADAPTER
    });

    //// Ethereum
    _deploymentParamsV4[ETHEREUM] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L1_MULTI_SIG,
      spokeProxy: address(ETHEREUM_SPOKE),
      spokeImpl: ETHEREUM_SPOKE_DEPRECATED_IMPL,
      feeAdapter: ETHEREUM_FEE_ADAPTER
    });

    //// Zircuit
    _deploymentParamsV4[ZIRCUIT] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(ZIRCUIT_SPOKE),
      spokeImpl: ZIRCUIT_SPOKE_DEPRECATED_IMPL,
      feeAdapter: ZIRCUIT_FEE_ADAPTER
    });

    // Blast
    _deploymentParamsV4[BLAST] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(BLAST_SPOKE),
      spokeImpl: BLAST_SPOKE_DEPRECATED_IMPL,
      feeAdapter: BLAST_FEE_ADAPTER
    });

    // Linea
    _deploymentParamsV4[LINEA] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(LINEA_SPOKE),
      spokeImpl: LINEA_SPOKE_DEPRECATED_IMPL,
      feeAdapter: LINEA_FEE_ADAPTER
    });

    // Polygon
    _deploymentParamsV4[POLYGON] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(POLYGON_SPOKE),
      spokeImpl: POLYGON_SPOKE_DEPRECATED_IMPL,
      feeAdapter: POLYGON_FEE_ADAPTER
    });

    // Avalanche
    _deploymentParamsV4[AVALANCHE] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(AVALANCHE_SPOKE),
      spokeImpl: AVALANCHE_SPOKE_DEPRECATED_IMPL,
      feeAdapter: AVALANCHE_FEE_ADAPTER
    });

    // Scroll
    _deploymentParamsV4[SCROLL] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(SCROLL_SPOKE),
      spokeImpl: SCROLL_SPOKE_DEPRECATED_IMPL,
      feeAdapter: SCROLL_FEE_ADAPTER
    });

    // Ape
    _deploymentParamsV4[APECHAIN] = DeploymentParamsV4({ // set domain id as mapping key
      owner: APECHAIN_MULTI_SIG,
      spokeProxy: address(APECHAIN_SPOKE),
      spokeImpl: APECHAIN_SPOKE_DEPRECATED_IMPL,
      feeAdapter: APECHAIN_FEE_ADAPTER
    });

    // Taiko
    _deploymentParamsV4[TAIKO] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(TAIKO_SPOKE),
      spokeImpl: TAIKO_SPOKE_DEPRECATED_IMPL,
      feeAdapter: TAIKO_FEE_ADAPTER
    });

    // Mode
    _deploymentParamsV4[MODE] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(MODE_SPOKE),
      spokeImpl: MODE_SPOKE_DEPRECATED_IMPL,
      feeAdapter: MODE_FEE_ADAPTER
    });

    // Uni
    _deploymentParamsV4[UNICHAIN] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(UNICHAIN_SPOKE),
      spokeImpl: UNICHAIN_SPOKE_DEPRECATED_IMPL,
      feeAdapter: UNICHAIN_FEE_ADAPTER
    });

    // Ronin
    _deploymentParamsV4[RONIN] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(RONIN_SPOKE),
      spokeImpl: RONIN_SPOKE_DEPRECATED_IMPL,
      feeAdapter: RONIN_FEE_ADAPTER
    });

    // Gnosis
    _deploymentParamsV4[GNOSIS] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(GNOSIS_SPOKE),
      spokeImpl: GNOSIS_SPOKE_DEPRECATED_IMPL,
      feeAdapter: GNOSIS_FEE_ADAPTER
    });

    // Berachain
    _deploymentParamsV4[BERACHAIN] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(BERACHAIN_SPOKE),
      spokeImpl: BERACHAIN_SPOKE_DEPRECATED_IMPL,
      feeAdapter: BERACHAIN_FEE_ADAPTER
    });

    // Mantle
    _deploymentParamsV4[MANTLE] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(MANTLE_SPOKE),
      spokeImpl: MANTLE_SPOKE_DEPRECATED_IMPL,
      feeAdapter: MANTLE_FEE_ADAPTER
    });

    // Ink
    _deploymentParamsV4[INK] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(INK_SPOKE),
      spokeImpl: INK_SPOKE_DEPRECATED_IMPL,
      feeAdapter: INK_FEE_ADAPTER
    });

    // Sonic
    _deploymentParamsV4[SONIC] = DeploymentParamsV4({ // set domain id as mapping key
      owner: L2_MULTI_SIG,
      spokeProxy: address(SONIC_SPOKE),
      spokeImpl: SONIC_SPOKE_DEPRECATED_IMPL,
      feeAdapter: SONIC_FEE_ADAPTER
    });
  }

  // ============ Upgrade ============ //
  function test_spokeUpgradeDynamicGasLimit_upgradeMainnetProd() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'));
    vm.rollFork(23_089_737);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = ETHEREUM_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '1';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-ethereumMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Ethereum | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeArbitrumProd() public {
    vm.createSelectFork(vm.envString('ARBITRUM_RPC'));
    vm.rollFork(365_931_396);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = ARB_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '42161';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-arbitrumMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Arbitrum | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeOptimismProd() public {
    vm.createSelectFork(vm.envString('OPTIMISM_RPC'));
    vm.rollFork(139_488_021);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = OP_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '10';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeArray-optimismMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Optimism | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeBaseProd() public {
    vm.createSelectFork(vm.envString('BASE_RPC'));
    vm.rollFork(33_892_741);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = BASE_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '8453';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-baseMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Base | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeBNBProd() public {
    vm.createSelectFork(vm.envString('BNB_RPC'));
    vm.rollFork(56_769_018);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = BNB_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '56';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-bnbMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | BNB | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeZircuitProd() public {
    vm.createSelectFork(vm.envString('ZIRCUIT_RPC'));
    vm.rollFork(12_170_949);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = ZIRCUIT_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '48900';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-zircuitMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Zircuit | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeBlastProd() public {
    vm.createSelectFork(vm.envString('BLAST_RPC'));
    vm.rollFork(22_882_521);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = BLAST_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '81457';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-blastMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Blast | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeLineaProd() public {
    vm.createSelectFork(vm.envString('LINEA_RPC'));
    vm.rollFork(17_898_766);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = LINEA_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '59144';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-lineaMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Linea | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradePolygonProd() public {
    vm.createSelectFork(vm.envString('POLYGON_RPC'));
    vm.rollFork(74_912_962);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = POLYGON_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '137';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-polygonMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Polygon | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeAvalancheProd() public {
    vm.createSelectFork(vm.envString('AVALANCHE_RPC'));
    vm.rollFork(66_706_583);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = AVALANCHE_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '43114';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-avalancheMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Avalanche | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeScrollProd() public {
    vm.createSelectFork(vm.envString('SCROLL_RPC'));
    vm.rollFork(18_582_961);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = SCROLL_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '534352';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-scrollMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Scroll | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeApeProd() public {
    vm.createSelectFork(vm.envString('APE_RPC'));
    vm.rollFork(20_334_330);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = APECHAIN_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '33139';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-apechainMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Apechain | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeTaikoProd() public {
    vm.createSelectFork(vm.envString('TAIKO_RPC'));
    vm.rollFork(1_061_261);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = TAIKO_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '167000';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-taikoMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Taiko | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeModeProd() public {
    vm.createSelectFork(vm.envString('MODE_RPC'));
    vm.rollFork(27_203_705);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = MODE_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '34443';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-modeMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Mode | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeUniProd() public {
    vm.createSelectFork(vm.envString('UNI_RPC'));
    vm.rollFork(23_826_657);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = UNICHAIN_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '130';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-unichainMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Unichain | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeRoninProd() public {
    vm.createSelectFork(vm.envString('RONIN_RPC'));
    vm.rollFork(44_142_187);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = RONIN_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '2020';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-roninMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Ronin | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeGnosisProd() public {
    vm.createSelectFork(vm.envString('GNOSIS_RPC'));
    vm.rollFork(41_485_405);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = GNOSIS_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '2020';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-gnosisMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Gnosis | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeBerachainProd() public {
    vm.createSelectFork(vm.envString('BERACHAIN_RPC'));
    vm.rollFork(8_794_836);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = BERACHAIN_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '80094';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-berachainMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Berachain | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeMantleProd() public {
    vm.createSelectFork(vm.envString('MANTLE_RPC'));
    vm.rollFork(83_222_422);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = MANTLE_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '5000';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-mantleMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Mantle | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeSonicProd() public {
    vm.createSelectFork(vm.envString('SONIC_RPC'));
    vm.rollFork(42_013_935);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = SONIC_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '146';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-sonicMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Sonic | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }

  function test_spokeUpgradeDynamicGasLimit_upgradeInkProd() public {
    vm.createSelectFork(vm.envString('INK_RPC'));
    vm.rollFork(21_076_874);
    _paramsV3 = _deploymentParamsV4[block.chainid];
    if (_paramsV3.feeAdapter == address(0)) revert NoFeeAdapter();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(_paramsV3.spokeProxy);
    address oldImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, _paramsV3.spokeImpl);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();
    address newEverclearSpoke = INK_SPOKE_UPGRADE_IMPL;

    // Deploying impl and upgrading the contract
    bool success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(_paramsV3.owner);
    (success,) = _paramsV3.spokeProxy.call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(_paramsV3.spokeProxy, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the new contract has dynamicGasLimit input on queues

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(_paramsV3.feeAdapter, spokeProxyV5.feeAdapter());

    // Pushing data to safe tx json //
    safeTransactions.push(_createTransaction(0, _paramsV3.spokeProxy, upgradeCalldata));
    string memory chainId = '57073';
    _writeSafeTransactionInput(
      'safeTransactionInputs/upgradeSpokeDynamicGasLimit-inkMainnetProd.json',
      'Spoke Upgrade - Dynamic Gas Limit | Ink | Mainnet Prod',
      safeTransactions,
      chainId
    );
  }
}
