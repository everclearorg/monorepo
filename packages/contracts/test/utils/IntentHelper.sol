// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IEverclear} from "../../src/interfaces/common/IEverclear.sol";
import {TestExtended} from "./TestExtended.sol";
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {IEverclearSpoke} from "../../src/interfaces/intent/IEverclearSpoke.sol";
import "forge-std/Console.sol";

contract IntentHelper is TestExtended {
    using TypeCasts for address;

    function setUp() public {}

    function testConstructCalldataAndTestProcessQueue() public {
        // Forking to the right chain
        vm.createSelectFork('unichain');

        // Spoke address
        address _spokeAddress = address(0xa05A3380889115bf313f1Db9d5f335157Be4D816);

        // Intent data
        bytes32 _initiator = address(0xade09131C6f43fe22C2CbABb759636C43cFc181e).toBytes32();
        bytes32 _receiver = address(0xade09131C6f43fe22C2CbABb759636C43cFc181e).toBytes32();
        bytes32 _inputAsset = address(0x4200000000000000000000000000000000000006).toBytes32();
        bytes32 _outputAsset = address(0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91).toBytes32();
        uint32 _origin = 130;
        uint64 _nonce = 6;
        uint48 _timestamp = uint48(1739488768);
        uint256 _amount = 60000000000000;
        uint32[] memory _destinations = new uint32[](1);
        _destinations[0] = 324;

        IEverclear.Intent memory intent = IEverclear.Intent({
        initiator: _initiator,
        receiver: _receiver,
        inputAsset: _inputAsset,
        outputAsset: _outputAsset,
        maxFee: 0,
        origin: _origin,
        nonce: _nonce,
        timestamp: _timestamp,
        ttl: 0,
        amount: _amount,
        destinations: _destinations,
        data: bytes("")
        });

        // Calling the spoke
        IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
        _intents[0] = intent;
        console.log("Encoded intents");
        console.logBytes(abi.encode(_intents));

        bytes memory _input = abi.encodeWithSelector(IEverclearSpoke.processIntentQueue.selector, _intents);
        console.log("Selector input");
        console.logBytes(_input);

        // Calling sending raw call to the spoke
        bytes32 _intentId = keccak256(abi.encode(intent));
        console.log("Intent ID");
        console.logBytes32(_intentId);
        // (bool success, ) = _spokeAddress.call{value: 0}(abi.encodeWithSelector(IEverclearSpoke.processIntentQueue.selector, _intents));
        // assertEq(success, true, "Call failed");     
        IEverclearSpoke(_spokeAddress).processIntentQueue{value: 0}(_intents);   
    }
}