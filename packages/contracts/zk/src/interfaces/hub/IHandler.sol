// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IEverclear} from 'interfaces/common/IEverclear.sol';

/**
 * @title IHandler
 * @notice Interface for the handler contract
 */
interface IHandler {
  /*//////////////////////////////////////////////////////////////
                                EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice emitted when a set of expired intents is handled
   * @param _intentIds The array of intent ids
   */
  event ExpiredIntentsHandled(bytes32[] _intentIds);

  /**
   * @notice emitted when an unsupported intent is sent back to its origin
   * @param _domain The origin domain for the unsupported intent
   * @param _messageId The message id for the interchain message
   * @param _intentId The id of the intent
   */
  event ReturnUnsupportedIntent(uint32 indexed _domain, bytes32 _messageId, bytes32 _intentId);

  /**
   * @notice Emitted when fees are withdrawn
   * @param _withdrawer The address of the withdrawer
   * @param _feeRecipient The address of the fee recipient
   * @param _tickerHash The hash of the ticker symbol
   * @param _amount The amount withdrawn
   * @param _paymentId The ID of the payment
   */
  event FeesWithdrawn(
    address _withdrawer, bytes32 _feeRecipient, bytes32 _tickerHash, uint256 _amount, bytes32 _paymentId
  );

  /*//////////////////////////////////////////////////////////////
                                ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the intent being handled is not added on the Hub
   * @param _intentId The id of the intent
   * @param _status The status of the intent
   */
  error Handler_HandleExpiredIntents_InvalidStatus(bytes32 _intentId, IEverclear.IntentStatus _status);

  /**
   * @notice Thrown when the intent being handled is not expired yet
   * @param _intentId The id of the intent
   * @param _blockTimestamp The current block timestamp
   * @param _expirationTimestamp The expiration timestamp of the intent
   */
  error Handler_HandleExpiredIntents_NotExpired(
    bytes32 _intentId, uint256 _blockTimestamp, uint256 _expirationTimestamp
  );

  /**
   * @notice Thrown when the intent being handled is not added on the Hub
   */
  error Handler_ReturnUnsupportedIntent_InvalidStatus();

  /**
   * @notice Thrown when the intent being handled has a zero TTL which is a slow path
   * @param _intentId The id of the intent
   */
  error Handler_HandleExpiredIntents_ZeroTTL(bytes32 _intentId);

  /**
   * @notice Thrown when the caller does not have enough fees in the fee vault
   */
  error Handler_WithdrawFees_InsufficientFunds();

  /**
   * @notice Thrown when the caller tries to withdraw zero fees
   */
  error Handler_WithdrawFees_ZeroAmount();

  /**
   * @notice Thrown when the caller tries to withdraw fees to an unsupported domain
   * @param _domain The domain to withdraw fees to
   */
  error Handler_WithdrawFees_UnsupportedDomain(uint32 _domain);

  /*//////////////////////////////////////////////////////////////
                                LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Handle expired _intents by settling them to their original destination
   * @param _expiredIntentIds The array of expired intent ids to handle
   */
  function handleExpiredIntents(
    bytes32[] calldata _expiredIntentIds
  ) external payable;

  /**
   * @notice Handle unsupported _intents by sending them back to their origin domain
   * @param _intentId The id of the unsupported intent to return
   */
  function returnUnsupportedIntent(
    bytes32 _intentId
  ) external payable;

  /**
   * @notice Withdraw fees from the fee vault
   * @param _feeRecipient The bytes32 cast address of the fee recipient
   * @param _tickerHash The hash of the ticker symbol
   * @param _amount The amount to withdraw
   * @param _destinations The array of destinations
   */
  function withdrawFees(
    bytes32 _feeRecipient,
    bytes32 _tickerHash,
    uint256 _amount,
    uint32[] calldata _destinations
  ) external;
}
