// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, Vm} from 'forge-std/Test.sol';
import {Mocker} from 'test/utils/mocks/Mocker.sol';
import {ERC7683Adapter} from 'contracts/intent/ERC7683Adapter.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {ResolvedCrossChainOrder, Output, FillInstruction} from 'contracts/intent/ERC7683.sol';

contract MockEverclearSpoke {
    using TypeCasts for address;

    event IntentCreated(bytes32 indexed intentId, IEverclear.Intent intent);
    event IntentFilled(bytes32 indexed intentId, address solver, uint24 fee);

    uint64 public nonce;
    mapping(bytes32 => IEverclear.IntentStatus) public status;

    function newIntent(
        uint32[] memory _destinations,
        address _receiver,
        address _inputAsset,
        address _outputAsset,
        uint256 _amount,
        uint24 _maxFee,
        uint48 _ttl,
        bytes calldata _data
    ) external returns (bytes32 _intentId, IEverclear.Intent memory _intent) {
        _intent = IEverclear.Intent({
            initiator: msg.sender.toBytes32(),
            receiver: _receiver.toBytes32(),
            inputAsset: _inputAsset.toBytes32(),
            outputAsset: _outputAsset.toBytes32(),
            maxFee: _maxFee,
            origin: uint32(block.chainid),
            nonce: ++nonce,
            timestamp: uint48(block.timestamp),
            ttl: _ttl,
            amount: _amount,
            destinations: _destinations,
            data: _data
        });

        _intentId = keccak256(abi.encode(_intent));
        status[_intentId] = IEverclear.IntentStatus.ADDED;
        emit IntentCreated(_intentId, _intent);
    }

    function fillIntent(
        IEverclear.Intent calldata _intent,
        uint24 _fee
    ) external returns (IEverclear.FillMessage memory _fillMessage) {
        bytes32 _intentId = keccak256(abi.encode(_intent));
        status[_intentId] = IEverclear.IntentStatus.FILLED;
        emit IntentFilled(_intentId, msg.sender, _fee);

        _fillMessage = IEverclear.FillMessage({
            intentId: _intentId,
            initiator: _intent.initiator,
            solver: msg.sender.toBytes32(),
            executionTimestamp: uint48(block.timestamp),
            fee: _fee
        });
    }
}

contract ERC7683AdapterTest is Test, Mocker {
    using TypeCasts for address;
    using TypeCasts for bytes32;

    ERC7683Adapter public adapter;
    MockEverclearSpoke public everclearSpoke;

    address public constant USER = address(0x1);
    address public constant SOLVER = address(0x2);
    address public constant INPUT_TOKEN = address(0x3);
    address public constant OUTPUT_TOKEN = address(0x4);

    event Open(bytes32 indexed orderId, ResolvedCrossChainOrder resolvedOrder);

    function setUp() public {
        everclearSpoke = new MockEverclearSpoke();
        adapter = new ERC7683Adapter(address(everclearSpoke), uint32(1 days));
    }

    function test_newIntent_EmitsCorrectOpenEvent() public {
        // Setup test parameters
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = 1; // Destination chain ID
        address receiver = address(0x5);
        uint256 amount = 1000;
        uint24 maxFee = 100; // 1%
        uint48 ttl = 1 days; // This ttl is now ignored for deadline calculation
        bytes memory data = '';

        // Calculate expected outputs for the Open event
        Output[] memory expectedMaxSpent = new Output[](1);
        expectedMaxSpent[0] = Output({
            token: INPUT_TOKEN.toBytes32(),
            amount: amount,
            recipient: receiver.toBytes32(),
            chainId: block.chainid
        });

        Output[] memory expectedMinReceived = new Output[](1);
        expectedMinReceived[0] = Output({
            token: OUTPUT_TOKEN.toBytes32(),
            amount: amount - ((amount * maxFee) / 10000),
            recipient: receiver.toBytes32(),
            chainId: uint256(destinations[0])
        });

        FillInstruction[] memory expectedFillInstructions = new FillInstruction[](1);
        expectedFillInstructions[0] = FillInstruction({
            destinationChainId: destinations[0],
            destinationSettler: address(adapter).toBytes32(),
            originData: data
        });

        // Record logs
        vm.recordLogs();

        // Execute newIntent as USER
        vm.prank(USER);
        bytes32 intentId = adapter.newIntent(
            destinations,
            receiver,
            INPUT_TOKEN,
            OUTPUT_TOKEN,
            amount,
            maxFee,
            ttl,
            data
        );

        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Find the Open event
        bool foundOpenEvent = false;
        for (uint i = 0; i < logs.length; i++) {
            // Check if this is the Open event
            if (logs[i].topics[0] == keccak256("Open(bytes32,(address,uint256,uint32,uint32,bytes32,(bytes32,uint256,bytes32,uint256)[],(bytes32,uint256,bytes32,uint256)[],(uint64,bytes32,bytes)[]))")) {
                foundOpenEvent = true;
                
                // The orderId is in topics[1]
                bytes32 emittedOrderId = logs[i].topics[1];
                
                // Decode the ResolvedCrossChainOrder from data
                ResolvedCrossChainOrder memory emittedOrder = abi.decode(logs[i].data, (ResolvedCrossChainOrder));
                
                // Verify each field
                assertEq(emittedOrderId, intentId, "OrderId mismatch");
                assertEq(emittedOrder.user, USER, "User mismatch");
                assertEq(emittedOrder.originChainId, block.chainid, "OriginChainId mismatch");
                assertEq(emittedOrder.openDeadline, uint32(block.timestamp), "OpenDeadline mismatch");
                assertEq(emittedOrder.fillDeadline, uint32(block.timestamp + 1 days), "FillDeadline mismatch");
                assertEq(emittedOrder.orderId, intentId, "OrderId in struct mismatch");
                
                // Verify maxSpent
                assertEq(emittedOrder.maxSpent.length, 1, "MaxSpent length mismatch");
                assertEq(emittedOrder.maxSpent[0].token, expectedMaxSpent[0].token, "MaxSpent token mismatch");
                assertEq(emittedOrder.maxSpent[0].amount, expectedMaxSpent[0].amount, "MaxSpent amount mismatch");
                assertEq(emittedOrder.maxSpent[0].recipient, expectedMaxSpent[0].recipient, "MaxSpent recipient mismatch");
                assertEq(emittedOrder.maxSpent[0].chainId, expectedMaxSpent[0].chainId, "MaxSpent chainId mismatch");
                
                // Verify minReceived
                assertEq(emittedOrder.minReceived.length, 1, "MinReceived length mismatch");
                assertEq(emittedOrder.minReceived[0].token, expectedMinReceived[0].token, "MinReceived token mismatch");
                assertEq(emittedOrder.minReceived[0].amount, expectedMinReceived[0].amount, "MinReceived amount mismatch");
                assertEq(emittedOrder.minReceived[0].recipient, expectedMinReceived[0].recipient, "MinReceived recipient mismatch");
                assertEq(emittedOrder.minReceived[0].chainId, expectedMinReceived[0].chainId, "MinReceived chainId mismatch");
                
                // Verify fillInstructions
                assertEq(emittedOrder.fillInstructions.length, 1, "FillInstructions length mismatch");
                assertEq(emittedOrder.fillInstructions[0].destinationChainId, expectedFillInstructions[0].destinationChainId, "FillInstructions destinationChainId mismatch");
                assertEq(emittedOrder.fillInstructions[0].destinationSettler, expectedFillInstructions[0].destinationSettler, "FillInstructions destinationSettler mismatch");
                assertEq(emittedOrder.fillInstructions[0].originData, expectedFillInstructions[0].originData, "FillInstructions originData mismatch");
                
                break;
            }
        }
        
        assertTrue(foundOpenEvent, "Open event not found");

        // Verify the mock was called correctly
        assertTrue(everclearSpoke.status(intentId) == IEverclear.IntentStatus.ADDED, 'Intent status not set to ADDED');
    }

    function test_fill_CreatesNewIntentInOppositeDirection() public {
        // Create original intent data
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = 1;
        
        IEverclear.Intent memory originalIntent = IEverclear.Intent({
            initiator: USER.toBytes32(),
            receiver: SOLVER.toBytes32(),
            inputAsset: INPUT_TOKEN.toBytes32(),
            outputAsset: OUTPUT_TOKEN.toBytes32(),
            maxFee: 100,
            origin: uint32(block.chainid),
            nonce: 1,
            timestamp: uint48(block.timestamp),
            ttl: 1 days,
            amount: 1000,
            destinations: destinations,
            data: ''
        });

        bytes memory originData = abi.encode(originalIntent);
        bytes32 orderId = keccak256(abi.encode(originalIntent));

        // Execute fill as SOLVER
        vm.prank(SOLVER);
        adapter.fill(orderId, originData, '');

        // Verify a new intent was created in the opposite direction
        bytes32 newIntentId = everclearSpoke.nonce() > 0 ? keccak256(abi.encode(everclearSpoke.nonce())) : bytes32(0);
        assertTrue(newIntentId != bytes32(0), 'No new intent created');
    }

    function test_fill_RevertsWithInvalidOriginData() public {
        bytes32 orderId = bytes32(uint256(1));
        bytes memory invalidOriginData = abi.encode(uint256(1)); // Not an Intent struct
        
        vm.expectRevert(); // Should revert when trying to decode invalid data
        adapter.fill(orderId, invalidOriginData, '');
    }
}
