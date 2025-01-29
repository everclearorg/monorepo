// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

/**
 * @title IHubMessageReceiver
 * @notice Interface for the hub message receiver
 */
interface IHubMessageReceiver is IHubStorage, IMessageReceiver, IEverclear {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Emitted when an intent is processed
   * @param _intentId The intent ID
   * @param _status The status of the intent
   */
  event IntentProcessed(bytes32 indexed _intentId, IntentStatus indexed _status);

  /**
   * @notice Emitted when a fill message is processed
   * @param _intentId The intent ID
   * @param _status The status of the fill
   */
  event FillProcessed(bytes32 indexed _intentId, IntentStatus _status);

  /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when an invalid message type is received
   */
  error HubMessageReceiver_ReceiveMessage_InvalidMessageType();
}
