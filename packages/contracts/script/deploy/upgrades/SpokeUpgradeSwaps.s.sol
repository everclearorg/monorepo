// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {EverclearSpokeV6} from 'contracts/intent/EverclearSpokeV6.sol';
import {FeeAdapterV2} from 'contracts/intent/FeeAdapterV2.sol';
import {SpokeMessageReceiverV2} from 'contracts/intent/modules/SpokeMessageReceiverV2.sol';

import {MainnetProductionEnvironment} from '../../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../../MainnetStaging.sol';

contract DeploySpokeSwapsUpgrade is Script, ScriptUtils {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  struct DeploymentParams {
    address owner;
    address everclearSpoke;
    address fillSigner;
    address xerc20Module;
    address spokeImpl;
  }

  error EmptyConfig();
  error InvalidConfig();
  error UpgradeFailed();

  bool public staging = true;
  address public constant FILL_SIGNER = 0xd148C7f37b346a4bD8e14f8c1f181f5f640481C8;

  bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  function run() external {
    DeploymentParams memory _params = _deploymentParams[block.chainid];
    if (_params.everclearSpoke == address(0)) revert EmptyConfig();
    if (_params.owner == address(0)) revert EmptyConfig();
    if (_params.fillSigner == address(0)) revert EmptyConfig();
    if (_params.xerc20Module == address(0)) revert EmptyConfig();
    if (_params.spokeImpl == address(0)) revert EmptyConfig();

    // Deploying delegation contracts
    vm.startBroadcast();

    // 1 - SpokeMessageReceiverV2
    address spokeMessageReceiver = address(new SpokeMessageReceiverV2());
    // 2 - EverclearSpokeV6
    address everclearSpokeV6 = address(new EverclearSpokeV6());
    // 3 - FeeAdapterV2
    address feeAdapterV2 = address(
      new FeeAdapterV2(_params.everclearSpoke, _params.owner, _params.fillSigner, _params.xerc20Module, _params.owner)
    );

    // asserting expectations for the upgrade
    address oldImplementation = (vm.load(_params.everclearSpoke, IMPLEMENTATION_SLOT)).toAddress();
    if (oldImplementation != _params.spokeImpl) revert InvalidConfig();

    // logging
    console.log('SpokeMessageReceiverV2 deployed at:', spokeMessageReceiver);
    console.log('FeeAdapterV2 deployed at:', feeAdapterV2);
    console.log('EverclearSpokeV6 deployed at:', everclearSpokeV6);

    // NOTE: The upgrade would call
    bytes memory initializeCalldata = abi.encodeWithSelector(
      EverclearSpokeV6.initialize.selector, feeAdapterV2, spokeMessageReceiver, _params.fillSigner
    );
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, everclearSpokeV6, initializeCalldata);
    console.log('---- Upgrade data for multi-sig ----');
    console.logBytes(upgradeCalldata);

    if (staging) {
      console.log('Staging upgrade calldata (for testing):');
      // executing the upgrade directly for staging
      (bool success,) = _params.everclearSpoke.call(upgradeCalldata);
      if (!success) revert UpgradeFailed();
      console.log('Upgrade executed successfully on staging');
    }

    console.log('---- End of upgrade data ----');
  }
}

contract MainnetStaging is DeploySpokeSwapsUpgrade, MainnetStagingEnvironment {
  function setUp() public {
    //// Ethereum - staging config
    _deploymentParams[ETHEREUM] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(ETHEREUM_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(ETHEREUM_XERC20_MODULE),
      spokeImpl: ETHEREUM_SPOKE_IMPL
    }); // set domain id as mapping key

    /// Base - staging config
    _deploymentParams[BASE] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(BASE_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(BASE_XERC20_MODULE),
      spokeImpl: BASE_SPOKE_IMPL
    }); // set domain id as mapping key

    //// Optimism - staging config
    _deploymentParams[OPTIMISM] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(OPTIMISM_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(OPTIMISM_XERC20_MODULE),
      spokeImpl: OPTIMISM_SPOKE_IMPL
    }); // set domain id as mapping key

    /// Arbitrum - staging config
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(ARBITRUM_ONE_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(ARBITRUM_ONE_XERC20_MODULE),
      spokeImpl: ARBITRUM_SPOKE_IMPL
    }); // set domain id as mapping key

    // Tac - staging config
    _deploymentParams[TAC] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(TAC_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(TAC_XERC20_MODULE),
      spokeImpl: TAC_SPOKE_IMPL
    }); // set domain id as mapping key

    // Plasma - staging config
    _deploymentParams[PLASMA] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(PLASMA_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(PLASMA_XERC20_MODULE),
      spokeImpl: PLASMA_SPOKE_IMPL
    }); // set domain id as mapping key
  }
}

contract MainnetProduction is DeploySpokeSwapsUpgrade, MainnetProductionEnvironment {
  function setUp() public {
    //// Ethereum - staging config
    _deploymentParams[ETHEREUM] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(ETHEREUM_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(ETHEREUM_XERC20_MODULE),
      spokeImpl: address(0)
    }); // set domain id as mapping key

    /// Base - staging config
    _deploymentParams[BASE] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(BASE_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(BASE_XERC20_MODULE),
      spokeImpl: address(0)
    }); // set domain id as mapping key

    //// Optimism - staging config
    _deploymentParams[OPTIMISM] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(OPTIMISM_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(OPTIMISM_XERC20_MODULE),
      spokeImpl: address(0)
    }); // set domain id as mapping key

    //// Arbitrum - staging config
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(ARBITRUM_ONE_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(ARBITRUM_ONE_XERC20_MODULE),
      spokeImpl: address(0)
    }); // set domain id as mapping key

    // Tac
    _deploymentParams[TAC] = DeploymentParams({
      owner: OWNER,
      everclearSpoke: address(TAC_SPOKE),
      fillSigner: address(FILL_SIGNER),
      xerc20Module: address(TAC_XERC20_MODULE),
      spokeImpl: TAC_SPOKE_IMPL
    }); // set domain id as mapping key
  }
}
