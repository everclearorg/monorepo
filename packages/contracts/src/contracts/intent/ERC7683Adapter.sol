// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC7683, IDestinationSettler, ResolvedCrossChainOrder, Output, FillInstruction} from 'contracts/intent/ERC7683.sol';
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

    // ERC-7683 interface ID
    // TODO what is this?
    bytes4 private constant INTENT_INTERFACE_ID = 0x6b6b2482;

    constructor(address _everclearSpoke) {
        everclearSpoke = IEverclearSpoke(_everclearSpoke);
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
        // Call EverclearSpoke's newIntent
        (intentId, IEverclear.Intent memory intent) = everclearSpoke.newIntent(
            destinations,
            receiver,
            inputAsset,
            outputAsset,
            amount,
            maxFee,
            ttl,
            data
        );

        // Create and emit the ERC-7683 Open event
        Output[] memory maxSpent = new Output[](1);
        maxSpent[0] = Output({
            token: inputAsset.toBytes32(),
            amount: amount,
            recipient: address(this).toBytes32(), // Tokens are held by this adapter
            chainId: block.chainid
        });

        Output[] memory minReceived = new Output[](1);
        minReceived[0] = Output({
            token: outputAsset.toBytes32(),
            amount: amount - ((amount * maxFee) / 10000), // Amount after max fee
            recipient: receiver.toBytes32(),
            chainId: uint256(destinations[0]) // First destination chain
        });

        FillInstruction[] memory fillInstructions = new FillInstruction[](1);
        fillInstructions[0] = FillInstruction({
            destinationChainId: destinations[0],
            destinationSettler: address(this).toBytes32(), // This adapter acts as settler
            originData: data
        });

        emit Open(
            intentId,
            ResolvedCrossChainOrder({
                user: msg.sender,
                originChainId: block.chainid,
                openDeadline: uint32(block.timestamp), // Already opened
                fillDeadline: ttl > 0 ? uint32(block.timestamp + ttl) : 0, // TODO fix this
                orderId: intentId,
                maxSpent: maxSpent,
                minReceived: minReceived,
                fillInstructions: fillInstructions
            })
        );
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

    /**
     * @notice Calculate the execution amount after fees
     * @param intent The intent structure
     * @param fee The fee in basis points
     * @return intentId The ID of the intent
     * @return executionAmount The amount after fees
     */
    function _calculateExecutionAmount(
        IEverclear.Intent calldata intent,
        uint24 fee
    ) internal pure returns (bytes32 intentId, uint256 executionAmount) {
        intentId = keccak256(abi.encode(intent));
        executionAmount = intent.amount - ((intent.amount * fee) / 10000);
    }

    /**
     * @notice Implementation of IERC165 interface detection
     * @param interfaceId The interface identifier to check
     * @return bool True if the contract implements the interface
     */
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == INTENT_INTERFACE_ID || interfaceId == type(IERC165).interfaceId;
    }
} 