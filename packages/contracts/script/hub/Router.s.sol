// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ScriptUtils} from '../utils/Utils.sol';
import {Script} from 'forge-std/Script.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';

import {TestnetStagingEnvironment} from '../TestnetStaging.sol';

contract SetSolverBase is Script, ScriptUtils {
  IEverclearHub internal _hub;
  address internal _solver;
  uint256 internal _solverPk;
  uint32[] _domains;
  bool _finished;

  error InvalidAmountOfDomains();

  function _getInputs() internal {
    _solverPk = vm.parseUint(vm.promptSecret('Solver OWNER private key'));
    _solver = vm.parseAddress(vm.prompt('Solver address'));

    while (!_finished) {
      uint32 _domain;
      try vm.parseUint(vm.prompt('Domain ID to support (press [Enter] to finish)')) returns (uint256 _res) {
        _domain = uint32(_res);
      } catch (bytes memory) {
        _domain = 0;
      }

      if (_domain == 0) {
        _finished = true;
      } else {
        _domains.push(_domain);
      }
    }

    if (_domains.length == 0) {
      revert InvalidAmountOfDomains();
    }
  }

  function run() public {
    vm.startBroadcast(_solverPk);

    _hub.setUserSupportedDomains(_domains);

    vm.stopBroadcast();
  }
}

contract TestnetStaging is SetSolverBase, TestnetStagingEnvironment {
  function setUp() public {
    // vm.createSelectFork(HUB_RPC);
    _checkValidDomain(EVERCLEAR_DOMAIN);
    _hub = HUB;
    _getInputs();
  }
}
