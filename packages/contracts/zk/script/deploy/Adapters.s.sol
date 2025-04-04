// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {FeeAdapter} from 'contracts/intent/FeeAdapter.sol';

import {MainnetProductionEnvironment} from '../MainnetProduction.sol';

contract DeployAdapterBase is Script, ScriptUtils {
  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  struct DeploymentParams {
    address spoke;
    address xerc20Module;
    address feeRecipient;
    address feeSigner;
    address owner;
  }

  FeeAdapter internal _feeAdapter;

  error WrongChainId();
  error FeeAdapterMismatch();
  error OwnerMismatch();
  error FeeRecipientMismatch();
  error FeeSignerMismatch();
  error SpokeMismatch();

  function run() public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];
    if (
      _params.spoke == address(0) || _params.xerc20Module == address(0) || _params.feeRecipient == address(0)
        || _params.feeSigner == address(0) || _params.owner == address(0)
    ) {
      revert WrongChainId();
    }

    vm.startBroadcast();

    // deploy feeAdapter
    _feeAdapter =
      new FeeAdapter(_params.spoke, _params.feeRecipient, _params.feeSigner, _params.xerc20Module, _params.owner);

    if (_feeAdapter.owner() != _params.owner) {
      revert OwnerMismatch();
    }

    if (_feeAdapter.feeRecipient() != _params.feeRecipient) {
      revert FeeRecipientMismatch();
    }

    if (address(_feeAdapter.spoke()) != _params.spoke) {
      revert SpokeMismatch();
    }

    if (_feeAdapter.feeSigner() != _params.feeSigner) {
      revert FeeSignerMismatch();
    }

    vm.stopBroadcast();

    console.log('------------------------------------------------');
    console.log('FeeAdapter:', address(_feeAdapter));
    console.log('Chain ID:', block.chainid);
    console.log('------------------------------------------------');
  }
}

contract MainnetProduction is DeployAdapterBase, MainnetProductionEnvironment {
  function setUp() public {
    //// ZKSYNC
    _deploymentParams[ZKSYNC] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ZKSYNC_SPOKE),
      xerc20Module: address(ZKSYNC_XERC20_MODULE),
      feeRecipient: ZKSYNC_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: ZKSYNC_ENG_MULTISIG
    });
  }
}
