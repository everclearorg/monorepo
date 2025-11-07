// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from "../../utils/Utils.sol";

import {TypeCasts} from "contracts/common/TypeCasts.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {EverclearSpokeV6} from "contracts/intent/EverclearSpokeV6.sol";
import {FeeAdapterV2} from "contracts/intent/FeeAdapterV2.sol";
import {SpokeMessageReceiverV2} from "contracts/intent/modules/SpokeMessageReceiverV2.sol";

import {MainnetProductionEnvironment} from "../../MainnetProduction.sol";

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

    address public constant FILL_SIGNER = address(0x123);
    mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

    function run(string memory _account) external {
        DeploymentParams memory _params = _deploymentParams[block.chainid];
        if (_params.everclearSpoke == address(0)) revert EmptyConfig();
        if (_params.owner == address(0)) revert EmptyConfig();
        if (_params.fillSigner == address(0)) revert EmptyConfig();
        if (_params.xerc20Module == address(0)) revert EmptyConfig();

        

        // Deploying delegation contracts
        uint256 _deployerPk = vm.envUint(_account);
        vm.startBroadcast(_deployerPk);

        // 1 - SpokeMessageReceiverV2
        address spokeMessageReceiver = address(new SpokeMessageReceiverV2());
        // 2 - EverclearSpokeV6
        address everclearSpokeV6 = address(new EverclearSpokeV6());
        // // 3 - FeeAdapterV2
        // address feeAdapterV2 = address(
        //   new FeeAdapterV2(_params.everclearSpoke, _params.owner, _params.fillSigner, _params.xerc20Module, _params.owner)
        // );

        // Logging
        console.log("---- Spoke Swaps Upgrade Data ----");
        console.log("SpokeMessageReceiverV2:", spokeMessageReceiver);
        console.log("EverclearSpokeV6:", everclearSpokeV6);
        console.log("Current Spoke Implementation:", _params.spokeImpl);
        console.log("---- End of upgrade data ----");
        vm.stopBroadcast();
    }
}

contract MainnetProduction is DeploySpokeSwapsUpgrade, MainnetProductionEnvironment {
    function setUp() public {
        //// ZKSYNC
        _deploymentParams[ZKSYNC] = DeploymentParams({ // set domain id as mapping key
            owner: ZKSYNC_ENG_MULTISIG,
            everclearSpoke: address(ZKSYNC_SPOKE),
            fillSigner: FILL_SIGNER,
            xerc20Module: address(ZKSYNC_XERC20_MODULE),
            spokeImpl: address(0)
        });
    }
}
