// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

interface IGateway {
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
  event PolymerProverUpdated(address _oldProver, address _newProver);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the message origin is invalid
   */
  error Gateway_Handle_InvalidOriginDomain();

  /**
   * @notice Thrown when the sender is not the appropriate remote Gateway
   */
  error Gateway_Handle_InvalidSender();

  /**
   * @notice Thrown when the caller is not the local mailbox
   */
  error Gateway_Handle_NotCalledByMailbox();

  /**
   * @notice Thrown when the GasTank does not have enough native asset to cover the fee
   */
  error Gateway_SendMessage_InsufficientBalance();

  /**
   * @notice Thrown when the message dispatcher is not the local receiver
   */
  error Gateway_SendMessage_UnauthorizedCaller();

  /**
   * @notice Thrown when the call returning the unused fee fails
   */
  error Gateway_SendMessage_UnsuccessfulRebate();

  /**
   * @notice Thrown when an address equals the address zero
   */
  error Gateway_ZeroAddress();
  error Gateway_PolymerProverNotSet();

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
   * @notice Updates the mailbox
   * @param _mailbox The new mailbox address
   * @dev only called by the `receiver`
   */
  function updateMailbox(
    address _mailbox
  ) external;

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
   * @notice Returns the transport layer message routing smart contract
   * @dev this is independent of the transport layer used, adopting mailbox name because its descriptive enough
   *      using address instead of specific interface to be independent from HL or any other TL
   * @return _mailbox The mailbox contract
   */
  function mailbox() external view returns (IMailbox _mailbox);

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
  function quoteMessage(uint32 _chainId, bytes memory _message, uint256 _gasLimit) external view returns (uint256 _fee);

  /**
   * @notice Handles a Polymer proof for cross-chain event verification
   * @param proof The Polymer proof data
   */
  function handlePolymerProof(bytes calldata proof) external;

  /**
   * @notice Updates the Polymer prover
   * @param _prover The new prover address
   * @dev only called by the `receiver`
   */
  function updatePolymerProver(address _prover) external;
}
