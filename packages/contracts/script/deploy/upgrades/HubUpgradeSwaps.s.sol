// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {EverclearHubV2} from 'contracts/hub/EverclearHubV2.sol';
import {HandlerV2} from 'contracts/hub/modules/HandlerV2.sol';
import {HubMessageReceiverV2} from 'contracts/hub/modules/HubMessageReceiverV2.sol';

import {ManagerV2} from 'contracts/hub/modules/ManagerV2.sol';
import {SettlerV2} from 'contracts/hub/modules/SettlerV2.sol';
import {AssetManagerV2} from 'contracts/hub/modules/managers/AssetManagerV2.sol';

import {MainnetProductionEnvironment} from '../../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../../MainnetStaging.sol';
import {ICREATE3} from './ICREATE3.sol';

contract DeployHubSwapsUpgrade is Script, ScriptUtils {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  struct DeploymentParams {
    address owner;
    address hub;
    address hubImpl;
  }

  error EmptyConfig();
  error InvalidConfig();

  bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  function run() external {
    DeploymentParams memory _params = _deploymentParams[block.chainid];
    if (_params.hub == address(0)) revert EmptyConfig();

    // Deploying delegation contracts
    vm.startBroadcast();

    // 1 - HubMessageReceiverV2
    address hubMessageReceiverV2 = address(new HubMessageReceiverV2());
    // 2 - HandlerV2
    address handlerV2 = address(new HandlerV2());
    // 3 - SettlerV2
    address settlerV2 = address(new SettlerV2());
    // 4 - Manager
    address managerV2 = address(new ManagerV2());
    // 5 - EverclearHubV2
    address everclearHubV2 = address(new EverclearHubV2());

    // asserting expectations for the upgrade
    address oldImplementation = (vm.load(_params.hub, IMPLEMENTATION_SLOT)).toAddress();
    if (oldImplementation != _params.hubImpl) revert InvalidConfig();

    // logging
    console.log('HubMessageReceiverV2 deployed at:', hubMessageReceiverV2);
    console.log('HandlerV2 deployed at:', handlerV2);
    console.log('SettlerV2 deployed at:', settlerV2);
    console.log('ManagerV2 deployed at:', managerV2);
    console.log('EverclearHubV2 deployed at:', everclearHubV2);

    // NOTE: The upgrade would call
    bytes memory initializeCalldata =
      abi.encodeWithSelector(EverclearHubV2.initialize.selector, settlerV2, managerV2, handlerV2, hubMessageReceiverV2);
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, everclearHubV2, initializeCalldata);
    console.log('---- Upgrade data for multi-sig ----');
    console.logBytes(upgradeCalldata);
    console.log('---- End of upgrade data ----');
  }
}

contract MainnetStaging is DeployHubSwapsUpgrade, MainnetStagingEnvironment {
  function setUp() public {
    //// Hub - staging config
    _deploymentParams[EVERCLEAR_DOMAIN] = DeploymentParams({owner: OWNER, hub: address(HUB), hubImpl: HUB_IMPL}); // set domain id as mapping key
  }
}

contract MainnetProduction is DeployHubSwapsUpgrade, MainnetProductionEnvironment {
  function setUp() public {
    //// Hub - staging config
    _deploymentParams[EVERCLEAR_DOMAIN] = DeploymentParams({owner: OWNER, hub: address(HUB), hubImpl: HUB_IMPL}); // set domain id as mapping key
  }
}
