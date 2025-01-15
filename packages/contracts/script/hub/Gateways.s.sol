// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';

import {TestnetStagingEnv} from '../utils/Environment.sol';

contract RegisterGatewaysBase is Script, ScriptUtils {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  IEverclearHub internal _hub;
  GatewayParams[] internal _gatewayParams;

  struct GatewayParams {
    uint32 domain;
    string domainName;
    bytes32 gateway;
  }

  function run() public {
    uint256 _ownerPk = vm.envUint('DEPLOYER_PK');
    vm.startBroadcast(_ownerPk);

    for (uint256 _i = 0; _i < _gatewayParams.length; ++_i) {
      uint32 _domain = _gatewayParams[_i].domain;
      bytes32 _gateway = _gatewayParams[_i].gateway;
      string memory _name = _gatewayParams[_i].domainName;

      _hub.updateChainGateway(_domain, _gateway);
      console.log('Chain:', _name, ' | Gateway:', _gateway.toAddress());
    }

    vm.stopBroadcast();
  }
}

contract TestnetStaging is RegisterGatewaysBase, TestnetStagingEnv {
  using TypeCasts for address;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl(HUB_RPC));
    _checkValidDomain(EVERCLEAR_DOMAIN);
    _hub = HUB;

    // declare which gateways to link to each domain
    _gatewayParams.push(
      GatewayParams({domain: SEPOLIA, domainName: 'ETH Sepolia', gateway: address(SEPOLIA_SPOKE_GATEWAY).toBytes32()})
    );

    _gatewayParams.push(
      GatewayParams({domain: BSC_TESTNET, domainName: 'BSC Testnet', gateway: address(BSC_SPOKE_GATEWAY).toBytes32()})
    );
  }
}
