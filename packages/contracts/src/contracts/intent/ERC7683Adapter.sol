// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IDestinationSettler, ResolvedCrossChainOrder, Output, FillInstruction} from 'contracts/intent/ERC7683.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

/**
 * @title ERC7683Adapter
 * @notice Adapter contract that implements ERC-7683 and adapts it to EverclearSpoke
 */
contract ERC7683Adapter is IDestinationSettler {
    using TypeCasts for address;
    using TypeCasts for bytes32;

    // Event from IOriginSettler that we need to emit
    event Open(bytes32 indexed orderId, ResolvedCrossChainOrder resolvedOrder);

    // The EverclearSpoke contract this adapter wraps
    IEverclearSpoke public immutable everclearSpoke;

    // Fixed period for fill deadline
    uint32 public immutable FILL_DEADLINE_PERIOD;

    // Group related parameters to reduce stack variables
    struct IntentParams {
        uint32[] destinations;
        address receiver;
        address inputAsset;
        address outputAsset;
        uint256 amount;
        uint24 maxFee;
        uint48 ttl;
        bytes data;
    }

    struct OrderParams {
        address user;
        uint32 destinationChainId;
        uint48 ttl;
        bytes32 orderId;
        uint32 timestamp;
    }

    constructor(address _everclearSpoke, uint32 _fillDeadlinePeriod) {
        everclearSpoke = IEverclearSpoke(_everclearSpoke);
        FILL_DEADLINE_PERIOD = _fillDeadlinePeriod;
    }

    /**
     * @notice Creates a new intent and emits ERC-7683 compatible events
     * @param destinations The possible destination chains of the intent
     * @param receiver The destination address of the intent
     * @param inputAsset The asset address on origin
     * @param outputAsset The asset address on destination
     * @param amount The amount of the asset
     * @param maxFee The maximum fee that can be taken by solvers
     * @param ttl The time to live of the intent
     * @param data The data of the intent
     * @return intentId The ID of the intent
     */
    function newIntent(
        uint32[] memory destinations,
        address receiver,
        address inputAsset,
        address outputAsset,
        uint256 amount,
        uint24 maxFee,
        uint48 ttl,
        bytes calldata data
    ) external returns (bytes32 intentId) {
        IntentParams memory params = IntentParams({
            destinations: destinations,
            receiver: receiver,
            inputAsset: inputAsset,
            outputAsset: outputAsset,
            amount: amount,
            maxFee: maxFee,
            ttl: ttl,
            data: data
        });

        (intentId,) = everclearSpoke.newIntent(
            params.destinations,
            params.receiver,
            params.inputAsset,
            params.outputAsset,
            params.amount,
            params.maxFee,
            params.ttl,
            params.data
        );

        OrderParams memory orderParams = OrderParams({
            user: msg.sender,
            destinationChainId: destinations[0],
            ttl: ttl,
            orderId: intentId,
            timestamp: uint32(block.timestamp)
        });

        emit Open(intentId, _createResolvedOrder(orderParams, params));
    }

    /**
     * @notice Implements the IDestinationSettler fill function
     * @param orderId The unique order identifier
     * @param originData Data emitted on the origin to parameterize the fill
     * @param fillerData Data provided by the filler (unused in this implementation)
     */
    function fill(
        bytes32 orderId,
        bytes calldata originData, // TODO wtf is this data?
        bytes calldata fillerData
    ) external override {
        // Decode the original intent from originData
        IEverclear.Intent memory originalIntent = abi.decode(originData, (IEverclear.Intent));
        
        // Create a new intent in the opposite direction
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = originalIntent.origin;

        // Calculate execution amount after fees
        uint256 executionAmount = originalIntent.amount - ((originalIntent.amount * originalIntent.maxFee) / 10000);

        everclearSpoke.newIntent(
            destinations,
            originalIntent.initiator.toAddress(), // Original initiator becomes receiver
            originalIntent.outputAsset.toAddress(), // Original output asset becomes input
            originalIntent.inputAsset.toAddress(), // Original input asset becomes output
            executionAmount,
            originalIntent.maxFee,
            0, // TTL is 0 for fills
            '' // No additional data needed for fills
        );
    }

    function _createOutput(
        bytes32 token,
        uint256 amount,
        bytes32 recipient,
        uint256 chainId
    ) internal pure returns (Output memory) {
        return Output({
            token: token,
            amount: amount,
            recipient: recipient,
            chainId: chainId
        });
    }

    function _createMaxSpent(
        IntentParams memory params
    ) internal view returns (Output[] memory) {
        Output[] memory maxSpent = new Output[](1);
        maxSpent[0] = _createOutput(
            params.inputAsset.toBytes32(),
            params.amount,
            params.receiver.toBytes32(),
            block.chainid
        );
        return maxSpent;
    }

    function _createMinReceived(
        IntentParams memory params,
        uint256 destinationChainId
    ) internal pure returns (Output[] memory) {
        Output[] memory minReceived = new Output[](1);
        uint256 amountAfterFees = params.amount - ((params.amount * params.maxFee) / 10000);
        minReceived[0] = _createOutput(
            params.outputAsset.toBytes32(),
            amountAfterFees,
            params.receiver.toBytes32(),
            destinationChainId
        );
        return minReceived;
    }

    function _createFillInstructions(
        uint32 destinationChainId,
        bytes memory data
    ) internal view returns (FillInstruction[] memory) {
        FillInstruction[] memory instructions = new FillInstruction[](1);
        instructions[0] = FillInstruction({
            destinationChainId: destinationChainId,
            destinationSettler: address(this).toBytes32(),
            originData: data
        });
        return instructions;
    }

    function _createResolvedOrder(
        OrderParams memory orderParams,
        IntentParams memory intentParams
    ) internal view returns (ResolvedCrossChainOrder memory) {
        return ResolvedCrossChainOrder({
            user: orderParams.user,
            originChainId: block.chainid,
            openDeadline: orderParams.timestamp,
            fillDeadline: uint32(orderParams.timestamp + FILL_DEADLINE_PERIOD),
            orderId: orderParams.orderId,
            maxSpent: _createMaxSpent(intentParams),
            minReceived: _createMinReceived(intentParams, orderParams.destinationChainId),
            fillInstructions: _createFillInstructions(orderParams.destinationChainId, intentParams.data)
        });
    }
} 