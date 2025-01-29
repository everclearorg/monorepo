// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IMessageReceiver
 * @notice Interface for the transport layer communication with the message receiver
 */
interface IMessageReceiver {
  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Receive a message from the transport layer
   * @param _message The message to receive encoded as bytes
   * @dev This function should be called by the the gateway contract
   */
  function receiveMessage(
    bytes calldata _message
  ) external;
}
