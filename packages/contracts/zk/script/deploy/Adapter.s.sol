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
    /// zkSync
    _deploymentParams[ZKSYNC] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ZKSYNC_SPOKE),
      xerc20Module: address(ZKSYNC_XERC20_MODULE),
      feeRecipient: address(0),
      owner: address(0)
    });
  }
}
