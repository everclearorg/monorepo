// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

import {ScriptUtils} from '../utils/Utils.sol';

import {EverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';
import {Script} from 'forge-std/Script.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';

contract TransferOwnership is Script, ScriptUtils {
  error FailedToTransferOwnership();

  function run(string memory _account, address _spoke, address _newOwner) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    OwnableUpgradeable(_spoke).transferOwnership(_newOwner);

    if (OwnableUpgradeable(_spoke).owner() != _newOwner) {
      revert FailedToTransferOwnership();
    }

    vm.stopBroadcast();
  }
}

contract TransferGatewayOwnership is Script, ScriptUtils {
  error FailedToTransferOwnership();

  function run(string memory _account, address _spoke, address _newOwner) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    address _gateway = address(EverclearSpoke(_spoke).gateway());

    OwnableUpgradeable(_gateway).transferOwnership(_newOwner);

    if (OwnableUpgradeable(_gateway).owner() != _newOwner) {
      revert FailedToTransferOwnership();
    }

    vm.stopBroadcast();
  }
}

contract Pause is Script, ScriptUtils {
  function run(string memory _account, address _spoke) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearSpoke(_spoke).pause();

    vm.stopBroadcast();
  }
}

contract Unpause is Script, ScriptUtils {
  function run(string memory _account, address _spoke) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearSpoke(_spoke).unpause();

    vm.stopBroadcast();
  }
}
