// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEverclear} from 'interfaces/common/IEverclear.sol';

library MessageLib {
  /*//////////////////////////////////////////////////////////////
                            ENUMS
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Enum for message types
   * INTENT: Intent message type
   * FILL: Fill message type
   * SETTLEMENT: Settlement message type
   * VAR_UPDATE: Variable update message type
   */
  enum MessageType {
    INTENT,
    FILL,
    SETTLEMENT,
    VAR_UPDATE
  }

  /*//////////////////////////////////////////////////////////////
                      GENERAL PURPOSE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Formats a message with a message type and data
   * @param _messageType The message type
   * @param _data The data to send in the message
   * @return _message The formatted message
   */
  function formatMessage(MessageType _messageType, bytes memory _data) internal pure returns (bytes memory _message) {
    _message = abi.encode(uint8(_messageType), _data);
  }

  /**
   * @dev Parses a message into its message type and data
   * @param _message The message to parse
   * @return _messageType The message type
   * @return _data The data in the message
   */
  function parseMessage(
    bytes memory _message
  ) internal pure returns (MessageType _messageType, bytes memory _data) {
    uint8 _msgTypeNumber;
    (_msgTypeNumber, _data) = abi.decode(_message, (uint8, bytes));
    _messageType = MessageType(_msgTypeNumber);
  }

  /*//////////////////////////////////////////////////////////////
                        MESSAGE FORMATTING
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Formats an intent message
   * @param _intents Array of intents
   * @return _message The formatted intent message
   */
  function formatIntentMessageBatch(
    IEverclear.Intent[] memory _intents
  ) internal pure returns (bytes memory _message) {
    _message = formatMessage(MessageType.INTENT, abi.encode(_intents));
  }

  /**
   * @dev Formats a fill message
   * @param _fillMessages Array of fill messages
   * @return _message The formatted fill message
   */
  function formatFillMessageBatch(
    IEverclear.FillMessage[] memory _fillMessages
  ) internal pure returns (bytes memory _message) {
    _message = formatMessage(MessageType.FILL, abi.encode(_fillMessages));
  }

  /**
   * @dev Formats a settlement message
   * @param _settlementMessages Array of settlement messages
   * @return _message The formatted settlement message
   */
  function formatSettlementBatch(
    IEverclear.Settlement[] memory _settlementMessages
  ) internal pure returns (bytes memory _message) {
    _message = formatMessage(MessageType.SETTLEMENT, abi.encode(_settlementMessages));
  }

  /**
   * @dev Formats a var update message
   * @param _data The data (encoded variable)
   * @return _message The formatted var update message
   */
  function formatVarUpdateMessage(
    bytes memory _data
  ) internal pure returns (bytes memory _message) {
    _message = formatMessage(MessageType.VAR_UPDATE, _data);
  }

  /**
   * @dev Formats an address updating message (Mailbox, SecurityModule, Gateway)
   * @param _updateVariable the name of the variable being updated
   * @param _address The new address
   * @return _message The formatted address update message
   */
  function formatAddressUpdateMessage(
    bytes32 _updateVariable,
    bytes32 _address
  ) internal pure returns (bytes memory _message) {
    _message = formatVarUpdateMessage(abi.encode(_updateVariable, abi.encode(_address)));
  }

  /**
   * @dev Formats a uint updating message (MaxRoutersFee)
   * @param _updateVariable the hashed name of the variable being updated
   * @param _value The new value
   * @return _message The formatted uint update message
   */
  function formatUintUpdateMessage(
    bytes32 _updateVariable,
    uint256 _value
  ) internal pure returns (bytes memory _message) {
    _message = formatVarUpdateMessage(abi.encode(_updateVariable, abi.encode(_value)));
  }

  /*//////////////////////////////////////////////////////////////
                          MESSAGE PARSING
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Parses an intent message
   * @param _data The intent message data
   * @return _intents Array of decoded intents
   */
  function parseIntentMessageBatch(
    bytes memory _data
  ) internal pure returns (IEverclear.Intent[] memory _intents) {
    (_intents) = abi.decode(_data, (IEverclear.Intent[]));
  }

  /**
   * @dev Parses a fill message
   * @param _data The packed fill message data
   * @return _fillMessages Array of fill messages
   */
  function parseFillMessageBatch(
    bytes memory _data
  ) internal pure returns (IEverclear.FillMessage[] memory _fillMessages) {
    (_fillMessages) = abi.decode(_data, (IEverclear.FillMessage[]));
  }

  /**
   * @dev Parses a settlement message
   * @param _data The packed settlement message data
   * @return _settlementMessages Array of settlement messages
   */
  function parseSettlementBatch(
    bytes memory _data
  ) internal pure returns (IEverclear.Settlement[] memory _settlementMessages) {
    (_settlementMessages) = abi.decode(_data, (IEverclear.Settlement[]));
  }

  /**
   * @dev Parses a var update message
   * @param _data The abi encoded variable
   * @return _updateVariable The hashed name of the variable being updated
   * @return _varData The encoded variable data
   */
  function parseVarUpdateMessage(
    bytes memory _data
  ) internal pure returns (bytes32 _updateVariable, bytes memory _varData) {
    (_updateVariable, _varData) = abi.decode(_data, (bytes32, bytes));
  }

  /**
   * @dev Parses an address update message
   * @param _data The abi encoded address
   * @return _address The decoded address
   */
  function parseAddressUpdateMessage(
    bytes memory _data
  ) internal pure returns (bytes32 _address) {
    _address = abi.decode(_data, (bytes32));
  }

  /**
   * @dev Parses a uint update message
   * @param _data The abi encoded uint
   * @return _value The decoded uint
   */
  function parseUintUpdateMessage(
    bytes memory _data
  ) internal pure returns (uint256 _value) {
    _value = abi.decode(_data, (uint256));
  }
}
