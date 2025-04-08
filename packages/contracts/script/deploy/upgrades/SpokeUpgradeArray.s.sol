// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {EverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';

import {MainnetProductionEnvironment} from '../../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../../MainnetStaging.sol';
import {TestnetStagingEnvironment} from '../../TestnetStaging.sol';
import {ICREATE3} from './ICREATE3.sol';

contract DeploySpokeArrayUpgrade is Script, ScriptUtils {
  using TypeCasts for bytes32;

  error Create3DeploymentFailed();

  bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  address public constant CREATE_3 = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;

  struct DeploymentParams {
    address owner;
    address spokeProxy;
  }

  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  error EmptyProxy();

  function run() public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];
    if (_params.spokeProxy == address(0)) revert EmptyProxy();

    vm.startBroadcast();
    bool testnet = _isTestnet(block.chainid);
    address newEverclearSpoke;

    if (!testnet) {
      // Generating the inputs for CREATE3
      uint8 version = 3;
      bytes32 _salt = keccak256(abi.encodePacked(_params.spokeProxy, version));
      bytes32 _implementationSalt = keccak256(abi.encodePacked(_salt, 'implementation'));
      bytes memory _creation = type(EverclearSpoke).creationCode;

      // Deploying the new implementation via CREATE3
      bytes memory create3Calldata = abi.encodeWithSelector(ICREATE3.deploy.selector, _implementationSalt, _creation);
      (bool success, bytes memory returnData) = CREATE_3.call(create3Calldata);
      if (!success) revert Create3DeploymentFailed();
      newEverclearSpoke = abi.decode(returnData, (address));
    } else {
      // Deploying the new implemenation on testnet (unsupported by CREATE3)
      newEverclearSpoke = address(new EverclearSpoke());
    }

    vm.stopBroadcast();

    console.log('------------------------------------------------');
    console.log('Deployed spoke impl to:', newEverclearSpoke, ' for chainId:', block.chainid);
    console.log('Chain ID:', block.chainid);
    console.log('------------------------------------------------');
  }

  function _isTestnet(
    uint256 chainId
  ) internal pure returns (bool) {
    return chainId == 97 || chainId == 421_614 || chainId == 11_155_420 || chainId == 11_155_111;
  }

  function _upgradeProxy(
    address _spokeProxy,
    address _newEverclearSpoke
  ) internal returns (address storedImplementation) {
    // Upgrading the spoke
    EverclearSpoke(_spokeProxy).upgradeToAndCall(_newEverclearSpoke, '');
    storedImplementation = vm.load(_spokeProxy, IMPLEMENTATION_SLOT).toAddress();
    console.log('Spoke upgraded, new implementation stored:', storedImplementation);
  }
}

contract TestnetStaging is DeploySpokeArrayUpgrade, TestnetStagingEnvironment {
  function setUp() public {
    _deploymentParams[ETHEREUM_SEPOLIA] = DeploymentParams({owner: OWNER, spokeProxy: address(ETHEREUM_SEPOLIA_SPOKE)});

    _deploymentParams[BSC_TESTNET] = DeploymentParams({owner: OWNER, spokeProxy: address(BSC_SPOKE)});

    _deploymentParams[OP_SEPOLIA] = DeploymentParams({owner: OWNER, spokeProxy: address(OP_SEPOLIA_SPOKE)});

    _deploymentParams[ARB_SEPOLIA] = DeploymentParams({owner: OWNER, spokeProxy: address(ARB_SEPOLIA_SPOKE)});
  }
}

contract MainnetStaging is DeploySpokeArrayUpgrade, MainnetStagingEnvironment {
  function setUp() public {
    //// Arbitrum One
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      owner: OWNER,
      spokeProxy: address(0)
    });

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({ // set domain id as mapping key
      owner: OWNER,
      spokeProxy: address(0)
    });
  }
}

contract MainnetProduction is DeploySpokeArrayUpgrade, MainnetProductionEnvironment {
  function setUp() public {
    //// Arbitrum One
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      owner: OWNER,
      spokeProxy: address(ARBITRUM_ONE_SPOKE)
    });

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({ // set domain id as mapping key
      owner: OWNER,
      spokeProxy: address(OPTIMISM_SPOKE)
    });

    //// Base
    _deploymentParams[BASE] = DeploymentParams({ // set domain id as mapping key
      owner: OWNER,
      spokeProxy: address(BASE_SPOKE)
    });

    //// Bnb
    _deploymentParams[BNB] = DeploymentParams({ // set domain id as mapping key
      owner: OWNER,
      spokeProxy: address(BNB_SPOKE)
    });

    //// Ethereum
    _deploymentParams[ETHEREUM] = DeploymentParams({ // set domain id as mapping key
      owner: OWNER,
      spokeProxy: address(ETHEREUM_SPOKE)
    });
  }
}
