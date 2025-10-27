// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import 'forge-std/Test.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

import {Constants} from '../Constants.sol';

contract Mocker is Test {
  using TypeCasts for address;

  function _mockDispatch(
    address _originGateway,
    address _mailbox,
    bytes memory _message,
    bytes memory _metadata
  ) internal returns (bytes32 _messageId) {
    /* 
      A Message in HL has the following structre:
      VERSION,
      nonce,
      localDomain,
      msg.sender.addressToBytes32(),
      destinationDomain,
      recipientAddress,
      messageBody
     */
    // Mocking a return messageId of the similar structure
    _messageId = keccak256(
      abi.encodePacked(
        Constants.HL_VERSION,
        Constants.MAILBOX_MOCK_NONCE,
        Constants.MOCK_SPOKE_CHAIN_ID,
        _originGateway.toBytes32(),
        Constants.EVERCLEAR_ID,
        Constants.EVERCLEAR_GATEWAY,
        _message
      )
    );

    vm.mockCall(
      address(_mailbox),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)', Constants.EVERCLEAR_ID, Constants.EVERCLEAR_GATEWAY, _message, _metadata
      ),
      abi.encode(_messageId)
    );
  }

  /**
   * @notice Mocks the dispatch of a message to the hub
   * @param _mailbox The origin mailbox contract address
   * @param _originSender The origin sender address
   * @param _chainId The destination chain id
   * @param _destinationGateway The destination gateway address
   * @param _message The message to be dispatched
   */
  function _mockDispatchHub(
    address _mailbox,
    address _originSender,
    uint32 _chainId,
    address _destinationGateway,
    bytes memory _message,
    bytes memory _metadata
  ) internal returns (bytes32 _messageId) {
    /* 
      A Message in HL has the following structre:
      VERSION,
      nonce,
      localDomain,
      msg.sender.addressToBytes32(),
      destinationDomain,
      recipientAddress,
      messageBody
     */
    // Mocking a return messageId of the similar structure
    _messageId = keccak256(
      abi.encodePacked(
        Constants.HL_VERSION,
        Constants.MAILBOX_MOCK_NONCE,
        Constants.EVERCLEAR_ID,
        _originSender.toBytes32(),
        _chainId,
        _destinationGateway.toBytes32(),
        _message
      )
    );

    vm.mockCall(
      address(_mailbox),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)', _chainId, _destinationGateway, _message, _metadata
      ),
      abi.encode(_messageId)
    );
  }

  function _mockReceiveMessage(address _contract, bytes calldata _message) internal {
    vm.mockCall(
      address(_contract), abi.encodeWithSelector(IMessageReceiver.receiveMessage.selector, _message), abi.encode(0)
    );
  }
}
