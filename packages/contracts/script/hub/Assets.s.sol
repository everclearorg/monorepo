// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ScriptUtils} from '../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

contract UpdateMaxDiscountBPS is Script, ScriptUtils {
  function run(string memory _account, address _hub, bytes32 _tickerHash, uint24 _maxDiscountBps) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).setMaxDiscountDbps(_tickerHash, _maxDiscountBps);

    vm.stopBroadcast();
  }
}

contract SetAdopted is Script, ScriptUtils {
  function run(string memory _account, address _hub, IHubStorage.AssetConfig calldata _config) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).setAdoptedForAsset(_config);

    vm.stopBroadcast();
  }
}

contract UpdateDiscountPerEpoch is Script, ScriptUtils {
  function run(string memory _account, address _hub, bytes32 _tickerHash, uint24 _discountPerEpoch) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).setDiscountPerEpoch(_tickerHash, _discountPerEpoch);

    vm.stopBroadcast();
  }
}

contract UpdatePrioritizedStrategy is Script, ScriptUtils {
  function run(string memory _account, address _hub, bytes32 _tickerHash, IEverclear.Strategy _strategy) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).setPrioritizedStrategy(_tickerHash, _strategy);

    vm.stopBroadcast();
  }
}
