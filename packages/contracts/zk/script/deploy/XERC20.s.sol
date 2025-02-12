// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from "../utils/Utils.sol";

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {XERC20Module} from "contracts/intent/modules/XERC20Module.sol";

contract DeployXERC20 is Script, ScriptUtils {
    mapping(uint256 _chainId => address _spoke) internal _spokes;

    XERC20Module internal _module;

    error SpokeNotDeployed();
    error SpokeMismatch();

    function run() public {
        address _spoke = 0x7F5e085981C93C579c865554B9b723B058AaE4D3;
        if (_spoke.code.length == 0) {
            revert SpokeNotDeployed();
        }

        vm.startBroadcast();

        _module = new XERC20Module(_spoke);
        if (_module.spoke() != _spoke) {
            revert SpokeMismatch();
        }

        vm.stopBroadcast();

        console.log("------------------------------------------------");
        console.log("XERC20 Module:", address(_module));
        console.log("Everclear Spoke:", _spoke);
        console.log("Chain ID:", block.chainid);
        console.log("------------------------------------------------");
    }
}
