// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';

import {Script} from 'forge-std/Script.sol';

import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';

contract ProcessFillQueue is Script, ScriptUtils {
  function run(string memory _account, address _spoke, uint256 _value, uint32 _amount) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearSpoke(_spoke).processFillQueue{value: _value}(_amount);

    vm.stopBroadcast();
  }
}
