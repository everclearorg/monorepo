// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';
import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

import {IHubStorageV2} from 'interfaces/hub/IHubStorageV2.sol';

/**
 * @title IHubMessageReceiverV2
 * @notice Interface for the hub message receiver
 */
interface IHubMessageReceiverV2 is IHubStorageV2, IMessageReceiver, IEverclearV2 {
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
