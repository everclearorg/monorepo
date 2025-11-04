// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';

contract SetModuleForStrategy is Script, ScriptUtils {
  function run(string memory _account, address _spoke, uint8 _strategy, address _module) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearSpoke(_spoke).setModuleForStrategy(IEverclear.Strategy(_strategy), ISettlementModule(_module));

    // assertions
    assert(IEverclearSpoke(_spoke).modules(IEverclear.Strategy(_strategy)) == ISettlementModule(_module));

    console.log('SetModuleForStrategy in spoke contract: ', _spoke);
    console.log('Strategy:                               ', _strategy);
    console.log('Module:                                 ', _module);

    vm.stopBroadcast();
  }
}
