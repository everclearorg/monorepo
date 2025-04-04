// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {EverclearSpokeV4} from 'contracts/intent/EverclearSpokeV4.sol';

import {MainnetProductionEnvironment} from '../../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../../MainnetStaging.sol';
import {ICREATE3} from './ICREATE3.sol';

contract DeployFeeAdapterUpgrade is Script, ScriptUtils {
  using TypeCasts for bytes32;

  struct DeploymentParams {
    address owner;
    address spokeProxy;
  }

  bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  address public constant CREATE_3 = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;

  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  error EmptyProxy();
  error Create3DeploymentFailed();

  function run() public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];
    if (_params.spokeProxy == address(0)) revert EmptyProxy();

    vm.startBroadcast();
    address newEverclearSpoke;

    // Generating the inputs for CREATE3
    uint8 version = 5;
    bytes32 _salt = keccak256(abi.encodePacked(_params.spokeProxy, version));
    bytes32 _implementationSalt = keccak256(abi.encodePacked(_salt, 'implementation'));
    bytes memory _creation = type(EverclearSpokeV4).creationCode;

    // Deploying the new implementation via CREATE3
    bytes memory create3Calldata = abi.encodeWithSelector(ICREATE3.deploy.selector, _implementationSalt, _creation);
    (bool success, bytes memory returnData) = CREATE_3.call(create3Calldata);
    if (!success) revert Create3DeploymentFailed();
    newEverclearSpoke = abi.decode(returnData, (address));

    vm.stopBroadcast();

    console.log('------------------------------------------------');
    console.log('Deployed spoke impl to:', newEverclearSpoke, ' for chainId:', block.chainid);
    console.log('Chain ID:', block.chainid);
    console.log('------------------------------------------------');
  }
}

contract MainnetStaging is DeployFeeAdapterUpgrade, MainnetStagingEnvironment {
  function setUp() public {
    //// Arbitrum One
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({owner: OWNER, spokeProxy: address(ARBITRUM_ONE_SPOKE)}); // set domain id as mapping key

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({owner: OWNER, spokeProxy: address(OPTIMISM_SPOKE)}); // set domain id as mapping key

    // Base
    _deploymentParams[BASE] = DeploymentParams({owner: OWNER, spokeProxy: address(BASE_SPOKE)}); // set domain id as mapping key
  }
}

contract MainnetProduction is DeployFeeAdapterUpgrade, MainnetProductionEnvironment {
  function setUp() public {
    //// Arbitrum One
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({owner: OWNER, spokeProxy: address(ARBITRUM_ONE_SPOKE)}); // set domain id as mapping key

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({owner: OWNER, spokeProxy: address(OPTIMISM_SPOKE)}); // set domain id as mapping key

    //// Base
    _deploymentParams[BASE] = DeploymentParams({owner: OWNER, spokeProxy: address(BASE_SPOKE)}); // set domain id as mapping key

    //// Bnb
    _deploymentParams[BNB] = DeploymentParams({owner: OWNER, spokeProxy: address(BNB_SPOKE)}); // set domain id as mapping key

    //// Ethereum
    _deploymentParams[ETHEREUM] = DeploymentParams({owner: OWNER, spokeProxy: address(ETHEREUM_SPOKE)}); // set domain id as mapping key

    // Zircuit
    _deploymentParams[ZIRCUIT] = DeploymentParams({owner: OWNER, spokeProxy: address(ZIRCUIT_SPOKE)}); // set domain id as mapping key

    // Blast
    _deploymentParams[BLAST] = DeploymentParams({owner: OWNER, spokeProxy: address(BLAST_SPOKE)}); // set domain id as mapping key

    // Linea
    _deploymentParams[LINEA] = DeploymentParams({owner: OWNER, spokeProxy: address(LINEA_SPOKE)}); // set domain id as mapping key

    // Polygon
    _deploymentParams[POLYGON] = DeploymentParams({owner: OWNER, spokeProxy: address(POLYGON_SPOKE)}); // set domain id as mapping key

    // Avalanche
    _deploymentParams[AVALANCHE] = DeploymentParams({owner: OWNER, spokeProxy: address(AVALANCHE_SPOKE)}); // set domain id as mapping key

    // Taiko
    _deploymentParams[TAIKO] = DeploymentParams({owner: OWNER, spokeProxy: address(TAIKO_SPOKE)}); // set domain id as mapping key

    // Scroll
    _deploymentParams[SCROLL] = DeploymentParams({owner: OWNER, spokeProxy: address(SCROLL_SPOKE)}); // set domain id as mapping key

    // Apechain
    _deploymentParams[APECHAIN] = DeploymentParams({owner: OWNER, spokeProxy: address(APECHAIN_SPOKE)}); // set domain id as mapping key

    // Mode
    _deploymentParams[MODE] = DeploymentParams({owner: OWNER, spokeProxy: address(MODE_SPOKE)}); // set domain id as mapping key

    // Unichain
    _deploymentParams[UNICHAIN] = DeploymentParams({owner: OWNER, spokeProxy: address(UNICHAIN_SPOKE)}); // set domain id as mapping key

    // Ronin
    _deploymentParams[RONIN] = DeploymentParams({owner: OWNER, spokeProxy: address(RONIN_SPOKE)}); // set domain id as mapping key
  }
}
