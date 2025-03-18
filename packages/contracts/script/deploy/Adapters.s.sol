// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ScriptUtils } from '../utils/Utils.sol';

import { Script } from 'forge-std/Script.sol';
import { console } from 'forge-std/console.sol';

import { FeeAdapter } from 'contracts/intent/FeeAdapter.sol';

import {MainnetProductionEnvironment} from '../MainnetProduction.sol';

contract DeployAdapterBase is Script, ScriptUtils {
  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  struct DeploymentParams {
    address spoke;
    address xerc20Module;
    address feeRecipient;
    address owner;
  }

  FeeAdapter internal _feeAdapter;

  error WrongChainId();
  error FeeAdapterMismatch();

  function run(string memory _account) public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];
    if (
      _params.spoke == address(0) ||
      _params.xerc20Module == address(0) ||
      _params.feeRecipient == address(0) ||
      _params.owner == address(0)
    ) {
      revert WrongChainId();
    }

    uint256 _deployerPk = vm.envUint(_account);
    address _deployer = vm.addr(_deployerPk);
    uint64 _nonce = vm.getNonce(_deployer);

    vm.startBroadcast(_deployerPk);

    address _expectedFeeAdapter = _addressFrom(_deployer, _nonce);

    // deploy feeAdapter
    _feeAdapter = new FeeAdapter(_params.spoke, _params.feeRecipient, _params.xerc20Module, _params.owner);
    if (address(_feeAdapter) != _expectedFeeAdapter) revert FeeAdapterMismatch();

    vm.stopBroadcast();

    console.log('------------------------------------------------');
    console.log('FeeAdapter:', address(_feeAdapter));
    console.log('Chain ID:', block.chainid);
    console.log('------------------------------------------------');
  }
}

contract MainnetProduction is DeployAdapterBase, MainnetProductionEnvironment {
  function setUp() public {
    //// Arbitrum One
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ARBITRUM_ONE_SPOKE),
      xerc20Module: address(ARBITRUM_ONE_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({ // set domain id as mapping key
      spoke: address(OPTIMISM_SPOKE),
      xerc20Module: address(OPTIMISM_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    //// Base
    _deploymentParams[BASE] = DeploymentParams({ // set domain id as mapping key
      spoke: address(BASE_SPOKE),
      xerc20Module: address(BASE_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    //// Bnb
    _deploymentParams[BNB] = DeploymentParams({ // set domain id as mapping key
      spoke: address(BNB_SPOKE),
      xerc20Module: address(BNB_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    //// Ethereum
    _deploymentParams[ETHEREUM] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ETHEREUM_SPOKE),
      xerc20Module: address(ETHEREUM_XERC20_MODULE),
      feeRecipient: L1_FEE_RECIPIENT,
      owner: L1_FEE_RECIPIENT
    });

    //// Zircuit
    _deploymentParams[ZIRCUIT] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ZIRCUIT_SPOKE),
      xerc20Module: address(ZIRCUIT_XERC20_MODULE),
      feeRecipient: address(0),
      owner: address(0)
    });

    //// Blast
    _deploymentParams[BLAST] = DeploymentParams({ // set domain id as mapping key
      spoke: address(BLAST_SPOKE),
      xerc20Module: address(BLAST_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    /// Linea
    _deploymentParams[LINEA] = DeploymentParams({ // set domain id as mapping key
      spoke: address(LINEA_SPOKE),
      xerc20Module: address(LINEA_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    /// Polygon
    _deploymentParams[POLYGON] = DeploymentParams({ // set domain id as mapping key
      spoke: address(POLYGON_SPOKE),
      xerc20Module: address(POLYGON_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    /// Avalanche
    _deploymentParams[AVALANCHE] = DeploymentParams({ // set domain id as mapping key
      spoke: address(AVALANCHE_SPOKE),
      xerc20Module: address(AVALANCHE_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    /// zkSync
    _deploymentParams[ZKSYNC] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ZKSYNC_SPOKE),
      xerc20Module: address(ZKSYNC_XERC20_MODULE),
      feeRecipient: address(0),
      owner: address(0)
    });

    // scroll
    _deploymentParams[SCROLL] = DeploymentParams({ // set domain id as mapping key
      spoke: address(SCROLL_SPOKE),
      xerc20Module: address(SCROLL_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    // taiko
    _deploymentParams[TAIKO] = DeploymentParams({ // set domain id as mapping key
      spoke: address(TAIKO_SPOKE),
      xerc20Module: address(TAIKO_XERC20_MODULE),
      feeRecipient: address(0),
      owner: address(0)
    });

    // apechain
    _deploymentParams[APECHAIN] = DeploymentParams({ // set domain id as mapping key
      spoke: address(APECHAIN_SPOKE),
      xerc20Module: address(APECHAIN_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    // unichain
    _deploymentParams[UNICHAIN] = DeploymentParams({ // set domain id as mapping key
      spoke: address(UNICHAIN_SPOKE),
      xerc20Module: address(UNICHAIN_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });

    // ronin
    _deploymentParams[RONIN] = DeploymentParams({
      spoke: address(RONIN_SPOKE),
      xerc20Module: address(RONIN_XERC20_MODULE),
      feeRecipient: address(0),
      owner: address(0)
    });

    // mode
    _deploymentParams[MODE] = DeploymentParams({
      spoke: address(MODE_SPOKE),
      xerc20Module: address(MODE_XERC20_MODULE),
      feeRecipient: L2_FEE_RECIPIENT,
      owner: L2_FEE_RECIPIENT
    });
  }
}
