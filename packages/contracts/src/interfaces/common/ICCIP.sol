// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ICCIP {
  /// @dev RMN depends on this struct, if changing, please notify the RMN maintainers.
  struct EVMTokenAmount {
    address token; // token address on the local chain.
    uint256 amount; // Amount of tokens.
  }

  struct Any2EVMMessage {
    bytes32 messageId; // MessageId corresponding to ccipSend on source.
    uint64 sourceChainSelector; // Source chain selector.
    bytes sender; // abi.decode(sender) if coming from an EVM chain.
    bytes data; // payload sent in original message.
    EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
  }

  // If extraArgs is empty bytes, the default is 200k gas limit.
  struct EVM2AnyMessage {
    bytes receiver; // abi.encode(receiver address) for dest EVM chains.
    bytes data; // Data payload.
    EVMTokenAmount[] tokenAmounts; // Token transfers.
    address feeToken; // Address of feeToken. address(0) means you will send msg.value.
    bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2).
  }

  /// @param computeUnits: compute units allowed for claling the ccip_receive instruction on the receiver program on SVM
  /// @param accounts: an array of 32-byte Solana public keys representing additional accounts required for execution
  /// @param accountIsWritableBitmap: a bitmap indicating which accounts in the `accounts` array are writable
  /// @param allowOutOfOrderExecution: must be set to true for SVM as a destination chain
  /// @param tokenReceiver: the Solana account that will initially receive tokens
  struct SVMExtraArgsV1 {
    uint32 computeUnits;
    uint64 accountIsWritableBitmap;
    bool allowOutOfOrderExecution;
    bytes32 tokenReceiver;
    bytes32[] accounts;
  }

  /// @param gasLimit: gas limit for the callback on the destination chain.
  /// @param allowOutOfOrderExecution: if true, it indicates that the message can be executed in any order relative to
  /// other messages from the same sender. This value's default varies by chain. On some chains, a particular value is
  /// enforced, meaning if the expected value is not set, the message request will revert.
  /// @dev Fully compatible with the previously existing EVMExtraArgsV2.
  struct GenericExtraArgsV2 {
    uint256 gasLimit;
    bool allowOutOfOrderExecution;
  }

  /**
   * @notice Sends a CCIP message to a destination chain.
   * @param _destinationChainSelector The selector of the destination chain.
   * @param _message The EVM2AnyMessage struct containing message details.
   * @return messageId The ID of the sent message.
   */
  function ccipSend(
    uint64 _destinationChainSelector,
    EVM2AnyMessage calldata _message
  ) external payable returns (bytes32 messageId);
}
