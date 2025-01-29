// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MessageLib} from 'contracts/common/MessageLib.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {TestExtended} from 'test/utils/TestExtended.sol';

contract Unit_TestMessaging is TestExtended {
  /*//////////////////////////////////////////////////////////////
                       GENERAL PURPOSE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Tests the format and parse functions for a message
   * @param _messageIndex Used to select the message type
   * @param _data The data to be formatted and parsed
   */
  function test_FormatAndParseMessage(uint256 _messageIndex, bytes memory _data) public pure {
    // Bound to available message types
    _messageIndex = bound(_messageIndex, 0, 3);
    MessageLib.MessageType _messageType = MessageLib.MessageType(_messageIndex);
    bytes memory _message = MessageLib.formatMessage(_messageType, _data);

    (MessageLib.MessageType _parsedMessageType, bytes memory _parsedData) = MessageLib.parseMessage(_message);

    assertEq(uint8(_messageType), uint8(_parsedMessageType));
    assertEq(_data, _parsedData);
  }

  /*//////////////////////////////////////////////////////////////
                                 INTENT
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Tests the format and parse functions for an intent message
   * @param _intents The intents to be formatted and parsed
   */
  function test_IntentMessage(
    IEverclear.Intent[] memory _intents
  ) public pure {
    bytes memory _message = MessageLib.formatIntentMessageBatch(_intents);
    (MessageLib.MessageType _parsedMessageType, bytes memory _data) = MessageLib.parseMessage(_message);

    IEverclear.Intent[] memory _parsedIntents = MessageLib.parseIntentMessageBatch(_data);

    assertEq(uint8(MessageLib.MessageType.INTENT), uint8(_parsedMessageType));
    assertEq(_intents.length, _parsedIntents.length);
    // Check correctness of each intent
    for (uint256 _i; _i < _intents.length; _i++) {
      assertEq(keccak256(abi.encode(_intents[_i])), keccak256(abi.encode(_parsedIntents[_i])));
      assertEq(_intents[_i].initiator, _parsedIntents[_i].initiator);
      assertEq(_intents[_i].receiver, _parsedIntents[_i].receiver);
      assertEq(_intents[_i].inputAsset, _parsedIntents[_i].inputAsset);
      assertEq(_intents[_i].outputAsset, _parsedIntents[_i].outputAsset);
      assertEq(_intents[_i].amount, _parsedIntents[_i].amount);
      assertEq(_intents[_i].maxFee, _parsedIntents[_i].maxFee);
      assertEq(_intents[_i].origin, _parsedIntents[_i].origin);
      for (uint256 j; j < _intents[_i].destinations.length; j++) {
        assertEq(_intents[_i].destinations[j], _parsedIntents[_i].destinations[j]);
      }
      assertEq(_intents[_i].nonce, _parsedIntents[_i].nonce);
      assertEq(_intents[_i].timestamp, _parsedIntents[_i].timestamp);
      assertEq(_intents[_i].data, _parsedIntents[_i].data);
    }
  }

  /*//////////////////////////////////////////////////////////////
                                  FILL
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Tests the format and parse functions for a fill message
   * @param _fillMessages The fill messages to be formatted and parsed
   */
  function test_FillMessage(
    IEverclear.FillMessage[] memory _fillMessages
  ) public pure {
    bytes memory _message = MessageLib.formatFillMessageBatch(_fillMessages);
    (MessageLib.MessageType _parsedMessageType, bytes memory _data) = MessageLib.parseMessage(_message);

    IEverclear.FillMessage[] memory _parsedFillMessages = MessageLib.parseFillMessageBatch(_data);

    assertEq(uint8(MessageLib.MessageType.FILL), uint8(_parsedMessageType));
    assertEq(_fillMessages.length, _parsedFillMessages.length);
    for (uint256 _i; _i < _fillMessages.length; _i++) {
      assertEq(_fillMessages[_i].intentId, _parsedFillMessages[_i].intentId);
      assertEq(_fillMessages[_i].solver, _parsedFillMessages[_i].solver);
      assertEq(_fillMessages[_i].executionTimestamp, _parsedFillMessages[_i].executionTimestamp);
      assertEq(_fillMessages[_i].fee, _parsedFillMessages[_i].fee);
    }
  }

  /*//////////////////////////////////////////////////////////////
                               SETTLEMENT
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Tests the format and parse functions for a settlement message
   * @param _settlementMessages The settlement messages to be formatted and parsed
   */
  function test_Settlement(
    IEverclear.Settlement[] memory _settlementMessages
  ) public pure {
    bytes memory _message = MessageLib.formatSettlementBatch(_settlementMessages);
    (MessageLib.MessageType _parsedMessageType, bytes memory _data) = MessageLib.parseMessage(_message);

    IEverclear.Settlement[] memory _parsedSettlements = MessageLib.parseSettlementBatch(_data);

    assertEq(uint8(MessageLib.MessageType.SETTLEMENT), uint8(_parsedMessageType));
    assertEq(_settlementMessages.length, _parsedSettlements.length);
    for (uint256 _i; _i < _settlementMessages.length; _i++) {
      assertEq(_settlementMessages[_i].intentId, _parsedSettlements[_i].intentId);
      assertEq(_settlementMessages[_i].recipient, _parsedSettlements[_i].recipient);
      assertEq(_settlementMessages[_i].asset, _parsedSettlements[_i].asset);
      assertEq(_settlementMessages[_i].amount, _parsedSettlements[_i].amount);
    }
  }

  /*//////////////////////////////////////////////////////////////
                             ADDRESS UPDATE
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Tests the format and parse functions for an address update message
   * @param _newAddress The new address to be formatted and parsed
   * @param _updateVariable The variable to be updated
   */
  function test_AddressUpdateMessage(bytes32 _newAddress, string calldata _updateVariable) public pure {
    bytes32 _updateVariableHash = keccak256(abi.encode(_updateVariable));
    bytes memory _message = MessageLib.formatAddressUpdateMessage(_updateVariableHash, _newAddress);
    (MessageLib.MessageType _parsedMessageType, bytes memory _data) = MessageLib.parseMessage(_message);

    (bytes32 _parsedUpdateVariableHash, bytes memory _parsedData) = MessageLib.parseVarUpdateMessage(_data);

    bytes32 _parsedAddress = MessageLib.parseAddressUpdateMessage(_parsedData);

    assertEq(uint8(MessageLib.MessageType.VAR_UPDATE), uint8(_parsedMessageType));
    assertEq(_updateVariableHash, _parsedUpdateVariableHash);
    assertEq(_newAddress, _parsedAddress);
  }

  /*//////////////////////////////////////////////////////////////
                              UINT UPDATE
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Tests the format and parse functions for a uint update message
   * @param _newUint The new uint to be formatted and parsed
   * @param _updateVariable The variable to be updated
   */
  function test_UintUpdateMessage(uint256 _newUint, string calldata _updateVariable) public pure {
    bytes32 _updateVariableHash = keccak256(abi.encode(_updateVariable));
    bytes memory _message = MessageLib.formatUintUpdateMessage(_updateVariableHash, _newUint);
    (MessageLib.MessageType _parsedMessageType, bytes memory _data) = MessageLib.parseMessage(_message);

    (bytes32 _parsedUpdateVariableHash, bytes memory _parsedData) = MessageLib.parseVarUpdateMessage(_data);

    uint256 _parsedUint = MessageLib.parseUintUpdateMessage(_parsedData);

    assertEq(uint8(MessageLib.MessageType.VAR_UPDATE), uint8(_parsedMessageType));
    assertEq(_updateVariableHash, _parsedUpdateVariableHash);
    assertEq(_newUint, _parsedUint);
  }
}
