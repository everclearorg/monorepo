// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ScriptUtils} from '../utils/Utils.sol';

import {NoopIsm} from '@hyperlane/isms/NoopIsm.sol';
import {Script} from 'forge-std/Script.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';

import {TestnetProductionEnvironment} from '../TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../TestnetStaging.sol';

contract UpdateIsmBase is Script, ScriptUtils {
  mapping(uint32 _domain => IEverclearSpoke _spoke) internal _spokes;
  uint256 _userPk;
  bool _isHub;
  IEverclearHub _hub;

  function _getInputs() internal {
    _userPk = vm.parseUint(vm.promptSecret('User private key'));
  }

  function run() public {
    vm.startBroadcast(_userPk);

    // Deploy noop ISM
    NoopIsm _ism = new NoopIsm();

    // Set on everclear contract
    if (_isHub) {
      // Set on hub
      _hub.updateSecurityModule(address(_ism));
    } else {
      // Set on spoke contract
      IEverclearSpoke _spoke = _spokes[uint32(block.chainid)];
      _spoke.updateSecurityModule(address(_ism));
    }

    vm.stopBroadcast();
  }
}

contract TestnetProduction is UpdateIsmBase, TestnetProductionEnvironment {
  function setUp() public {
    _spokes[ETHEREUM_SEPOLIA] = ETHEREUM_SEPOLIA_SPOKE;
    _spokes[BSC_TESTNET] = BSC_SPOKE;
    _hub = HUB;
    _isHub = block.chainid == EVERCLEAR_DOMAIN;

    _getInputs();
  }
}

contract TestnetStaging is UpdateIsmBase, TestnetStagingEnvironment {
  function setUp() public {
    _spokes[ETHEREUM_SEPOLIA] = ETHEREUM_SEPOLIA_SPOKE;
    _spokes[BSC_TESTNET] = BSC_SPOKE;
    _hub = HUB;
    _isHub = block.chainid == EVERCLEAR_DOMAIN;

    _getInputs();
  }
}
