// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

interface IGatewayV3 {
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

  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the mailbox is updated
   * @param _oldMailbox The old mailbox address
   * @param _newMailbox The new mailbox address
   */
  event MailboxUpdated(address _oldMailbox, address _newMailbox);

  /**
   * @notice Emitted when the security module is updated
   * @param _oldSecurityModule The old security module address
   * @param _newSecurityModule The new security module address
   */
  event SecurityModuleUpdated(address _oldSecurityModule, address _newSecurityModule);

  /**
   * @notice Emitted when a message is dispatched to the transport layer
   * @param destinationDomain The destination domain of the message
   * @param recipient The recipient of the message
   * @param message The message payload
   */
  event Dispatch(uint32 indexed destinationDomain, bytes32 indexed recipient, bytes message);

  /**
   * @notice Emitted when the Hyperlane mailbox is updated
   * @param _oldMailbox The old Hyperlane mailbox address
   * @param _newMailbox The new Hyperlane mailbox address
   */
  event HyperlaneMailboxUpdated(address _oldMailbox, address _newMailbox);

  /**
   * @notice Emitted when the CCIP mailbox is updated
   * @param _oldMailbox The old CCIP mailbox address
   * @param _newMailbox The new CCIP mailbox address
   */
  event CCIPMailboxUpdated(address _oldMailbox, address _newMailbox);

  /**
   * @notice Emitted when the Polymer mailbox is updated
   * @param _oldMailbox The old Polymer mailbox address
   * @param _newMailbox The new Polymer mailbox address
   */
  event PolymerMailboxUpdated(address _oldMailbox, address _newMailbox);

  /**
   * @notice Emitted when the Polymer prover is updated
   * @param _oldProver The old Polymer prover address
   * @param _newProver The new Polymer prover address
   */
  event PolymerProverUpdated(address _oldProver, address _newProver);

  /**
   * @notice Emitted when the CCIP mappings are updated
   * @param _everclearId The Everclear chain ids
   * @param _ccipChainId The CCIP chain ids
   */
  event CCIPMappingsUpdated(uint256[] _everclearId, uint256[] _ccipChainId);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the sender is not the appropriate remote Gateway
   */
  error GatewayV3_Handle_InvalidSender();

  /**
   * @notice Thrown when the caller is not the local mailbox
   */
  error GatewayV3_Handle_NotCalledByMailbox();

  /**
   * @notice Thrown when the GasTank does not have enough native asset to cover the fee
   */
  error GatewayV3_SendMessage_InsufficientBalance();

  /**
   * @notice Thrown when the message dispatcher is not the local receiver
   */
  error GatewayV3_SendMessage_UnauthorizedCaller();

  /**
   * @notice Thrown when the call returning the unused fee fails
   */
  error GatewayV3_SendMessage_UnsuccessfulRebate();

  /**
   * @notice Thrown when an address equals the address zero
   */
  error GatewayV3_ZeroAddress();

  /**
   * @notice Thrown when the domain from message is not the same as the local domain
   */
  error GatewayV3_Handle_InvalidEventSelector();

  /**
   * @notice Thrown when array mismatch occurs
   */
  error GatewayV3_Domain_ArrayLengthMismatch();

  /**
   * @notice Thrown when the caller is not the active mailbox
   */
  error GatewayV3_Handle_NotCalledByActiveMailbox();

  error GatewayV3_Handle_InvalidDestinationDomain();
  error GatewayV3_Handle_InvalidRecipient();
  error GatewayV3_SendMessage_CallFailure();
  error GatewayV3_Domain_NotFound();
  error GatewayV3_SendMessage_UnsupportedMailbox();
  error GatewayV3_Handle_InvalidTopicsLength();
  error GatewayV3_Handle_ProofAlreadyUsed();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Send a message to the transport layer using the gas tank
   * @param _chainId The id of the destination chain
   * @param _message The message to send
   * @param _fee The fee to send the message
   * @param _gasLimit The gas limit to use on destination
   * @return _messageId The id message of the transport layer
   * @return _feeSpent The fee spent to send the message
   * @dev only called by the spoke contract
   */
  function sendMessage(
    uint32 _chainId,
    bytes memory _message,
    uint256 _fee,
    uint256 _gasLimit
  ) external returns (bytes32 _messageId, uint256 _feeSpent);

  /**
   * @notice Send a message to the transport layer
   * @param _chainId The id of the destination chain
   * @param _message The message to send
   * @param _gasLimit The gas limit to use on destination
   * @return _messageId The id message of the transport layer
   * @return _feeSpent The fee spent to send the message
   * @dev only called by the spoke contract
   */
  function sendMessage(
    uint32 _chainId,
    bytes memory _message,
    uint256 _gasLimit
  ) external payable returns (bytes32 _messageId, uint256 _feeSpent);

  /**
   * @notice Updates the gateway security module
   * @param _securityModule The address of the new security module
   * @dev only called by the `receiver`
   */
  function updateSecurityModule(
    address _securityModule
  ) external;

  /*///////////////////////////////////////////////////////////////
                              VIEWS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Returns the message receiver for this Gateway (EverclearHub / EverclearSpoke)
   * @return _receiver The message receiver
   */
  function receiver() external view returns (IMessageReceiver _receiver);

  /**
   * @notice Quotes cost of sending a message to the transport layer
   * @param _chainId The id of the destination chain
   * @param _message The message to send
   * @param _gasLimit The gas limit for delivering the message
   * @return _fee The fee to send the message
   */
  function quoteMessage(
    uint32 _chainId,
    bytes memory _message,
    uint256 _gasLimit
  ) external view returns (uint256 _fee);
}
