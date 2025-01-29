// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ScriptUtils} from '../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

contract ProcessSettlementQueue is Script, ScriptUtils {
  function run(string memory _account, address _hub, uint256 _value, uint32 _domain, uint32 _amount) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).processSettlementQueue{value: _value}(_domain, _amount);

    vm.stopBroadcast();
  }
}

contract HandleExpiredIntents is Script, ScriptUtils {
  function run(string memory _account, address _hub, bytes memory _encodedIntentIds) public {
    uint256 _accountPk = vm.envUint(_account);
    bytes32[] memory _intents = abi.decode(_encodedIntentIds, (bytes32[]));
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).handleExpiredIntents(_intents);

    vm.stopBroadcast();
  }
}

contract ReturnUnsupportedIntent is Script, ScriptUtils {
  function run(string memory _account, address _hub, uint256 _value, bytes32 _intentId) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).returnUnsupportedIntent{value: _value}(_intentId);

    vm.stopBroadcast();
  }
}
