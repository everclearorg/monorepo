// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';

import {Script} from 'forge-std/Script.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';

contract ProcessIntentQueue is Script, ScriptUtils {
  function run(string memory _account, address _spoke, uint256 _value, bytes memory _encodedIntents) public {
    IEverclear.Intent[] memory _decodedIntents = abi.decode(_encodedIntents, (IEverclear.Intent[]));
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearSpoke(_spoke).processIntentQueue{value: _value}(_decodedIntents);

    vm.stopBroadcast();
  }
}
