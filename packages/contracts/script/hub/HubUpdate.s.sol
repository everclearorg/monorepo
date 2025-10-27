// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

import {ScriptUtils} from '../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

contract UpdateEpochLength is Script, ScriptUtils {
  function run(string memory _account, address _hub, uint48 _epochLength) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).updateEpochLength(_epochLength);

    vm.stopBroadcast();
  }
}

contract UpdateExpiryTimeBuffer is Script, ScriptUtils {
  function run(string memory _account, address _hub, uint48 _expiryTimeBuffer) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).updateExpiryTimeBuffer(_expiryTimeBuffer);

    vm.stopBroadcast();
  }
}

contract UpdateLighthouse is Script, ScriptUtils {
  function run(string memory _account, address _hub, address _lighthouse) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).updateLighthouse(_lighthouse);

    vm.stopBroadcast();
  }
}

contract UpdateWatchtower is Script, ScriptUtils {
  function run(string memory _account, address _hub, address _watchtower) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).updateWatchtower(_watchtower);

    vm.stopBroadcast();
  }
}

contract UpdateMinSupportedDomains is Script, ScriptUtils {
  function run(string memory _account, address _hub, uint8 _minSolverSupportedDomains) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).updateMinSolverSupportedDomains(_minSolverSupportedDomains);

    vm.stopBroadcast();
  }
}

contract UpdateSecurityModule is Script, ScriptUtils {
  function run(string memory _account, address _hub, address _ism) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).updateSecurityModule(_ism);

    vm.stopBroadcast();
  }
}

contract UpdateGasConfig is Script, ScriptUtils {
  function run(string memory _account, address _hub, IHubStorage.GasConfig calldata _gasConfig) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).updateGasConfig(_gasConfig);

    vm.stopBroadcast();
  }
}

contract AddChainGateway is Script, ScriptUtils {
  using TypeCasts for address;

  function run(string memory _account, address _hub, uint32 _chainId, address _gateway) public {
    uint256 _accountPk = vm.envUint(_account);
    bytes32 _padded = _gateway.toBytes32();
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).updateChainGateway(_chainId, _padded);

    vm.stopBroadcast();
  }
}

contract AssignRole is Script, ScriptUtils {
  function run(string memory _account, address _hub, address _user, uint8 _role) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).assignRole(_user, IHubStorage.Role(_role));

    vm.stopBroadcast();
  }
}

contract ProposeNewOwner is Script, ScriptUtils {
  error IncorrectlySetOwner(address _actual, address _intended);

  function run(string memory _account, address _hub, address _owner) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).proposeOwner(_owner);
    address _proposed = IEverclearHub(_hub).proposedOwner();
    if (_proposed != _owner) {
      revert IncorrectlySetOwner(_proposed, _owner);
    }

    vm.stopBroadcast();
  }
}

contract Pause is Script, ScriptUtils {
  function run(string memory _account, address _hub) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).pause();

    vm.stopBroadcast();
  }
}

contract Unpause is Script, ScriptUtils {
  function run(string memory _account, address _hub) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).unpause();

    vm.stopBroadcast();
  }
}

contract TransferOwnership is Script, ScriptUtils {
  function run(string memory _account, address _hub, address _newOwner) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    OwnableUpgradeable(_hub).transferOwnership(_newOwner);

    vm.stopBroadcast();
  }
}

contract TransferGatewayOwnership is Script, ScriptUtils {
  error FailedToTransferOwnership();

  function run(string memory _account, address _hub, address _newOwner) public {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    address _gateway = address(IHubStorage(_hub).hubGateway());

    OwnableUpgradeable(_gateway).transferOwnership(_newOwner);

    if (OwnableUpgradeable(_gateway).owner() != _newOwner) {
      revert FailedToTransferOwnership();
    }

    vm.stopBroadcast();
  }
}
