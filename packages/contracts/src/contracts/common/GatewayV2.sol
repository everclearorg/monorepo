// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {
  IInterchainSecurityModule,
  ISpecifiesInterchainSecurityModule
} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';
import {IMessageRecipient} from '@hyperlane/interfaces/IMessageRecipient.sol';

import {GasTank} from 'contracts/common/GasTank.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IGatewayV2} from 'interfaces/common/IGatewayV2.sol';
import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

/**
 * @title GatewayV2
 * @notice Abstract contract for GatewayV2 functionality.
 * @dev This contract must be inherited from implementations that must override the necessary check functions.
 */
abstract contract GatewayV2 is GasTank, IGatewayV2, IMessageRecipient, ISpecifiesInterchainSecurityModule {
  using TypeCasts for address;

  /// @dev DEPRECATED
  IMailbox public mailbox;

  /// @inheritdoc IGatewayV2
  IMessageReceiver public receiver;

  /// @inheritdoc ISpecifiesInterchainSecurityModule
  IInterchainSecurityModule public interchainSecurityModule;

  /**
   * @notice Checks that the function is called by the local receiver
   */
  modifier onlyReceiver() {
    if (msg.sender != address(receiver)) revert Gateway_SendMessage_UnauthorizedCaller();
    _;
  }

  /**
   * @notice Checks that an address is zero
   * @param _address The address to check
   */
  modifier validAddress(
    bytes32 _address
  ) {
    if (_address == 0) {
      revert Gateway_ZeroAddress();
    }
    _;
  }

  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IGatewayV2
  function sendMessage(
    uint32 _chainId,
    bytes calldata _message,
    uint256 _gasLimit
  ) external payable onlyReceiver returns (bytes32 _messageId, uint256 _feeSpent) {
    bytes32 _destinationGateway = _getGateway(_chainId);
    IMailbox _mailbox = _activeMailbox(_chainId);

    uint256 _initialBalance = address(this).balance;

    bytes memory _metadata = StandardHookMetadata.formatMetadata(0, _gasLimit, address(this), '');
    _messageId = _mailbox.dispatch{value: msg.value}(_chainId, _destinationGateway, _message, _metadata);

    _feeSpent = _initialBalance - address(this).balance;

    uint256 _unusedFee = msg.value - _feeSpent;

    if (_unusedFee > 0) {
      (bool _success,) = tx.origin.call{value: _unusedFee}('');
      if (!_success) revert Gateway_SendMessage_UnsuccessfulRebate();
    }
  }

  /// @inheritdoc IGatewayV2
  function sendMessage(
    uint32 _chainId,
    bytes calldata _message,
    uint256 _fee,
    uint256 _gasLimit
  ) external onlyReceiver returns (bytes32 _messageId, uint256 _feeSpent) {
    bytes32 _destinationGateway = _getGateway(_chainId);
    IMailbox _mailbox = _activeMailbox(_chainId);

    if (_fee > address(this).balance) {
      revert Gateway_SendMessage_InsufficientBalance();
    }

    uint256 _initialBalance = address(this).balance;

    bytes memory _metadata = StandardHookMetadata.formatMetadata(0, _gasLimit, address(this), '');
    _messageId = _mailbox.dispatch{value: _fee}(_chainId, _destinationGateway, _message, _metadata);

    _feeSpent = _initialBalance - address(this).balance;
    emit GasTankSpent(_feeSpent);
  }

  /**
   * @notice Handles incoming messages from the mailbox
   * @param _origin The id for the origin domain of the message
   * @param _sender The remote Gateway contract (on the origin domain)
   * @param _message The message payload
   */
  function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
    // only called by mailbox
    IMailbox _mailbox = _activeMailbox(_origin);
    if (msg.sender != address(_mailbox)) {
      revert Gateway_Handle_NotCalledByMailbox();
    }

    _checkValidSender(_origin, _sender);

    receiver.receiveMessage(_message);
  }

  /// @inheritdoc IGatewayV2
  function updateSecurityModule(
    address _newSecurityModule
  ) external onlyReceiver validAddress(_newSecurityModule.toBytes32()) {
    address _oldSecurityModule = address(interchainSecurityModule);
    interchainSecurityModule = IInterchainSecurityModule(_newSecurityModule);
    emit SecurityModuleUpdated(_oldSecurityModule, _newSecurityModule);
  }

  /// @inheritdoc IGatewayV2
  function quoteMessage(
    uint32 _chainId,
    bytes calldata _message,
    uint256 _gasLimit
  ) external view returns (uint256 _fee) {
    IMailbox _mailbox = _activeMailbox(_chainId);
    bytes memory _metadata = StandardHookMetadata.formatMetadata(0, _gasLimit, address(this), '');
    bytes32 _gateway = _getGateway(_chainId);
    _fee = _mailbox.quoteDispatch(_chainId, _gateway, _message, _metadata);
  }

  /**
   * @notice Checks that an incoming message is valid
   * @param _origin The id for the origin domain of the message
   * @param _sender The remote Gateway contract (on the origin domain)
   */
  function _checkValidSender(uint32 _origin, bytes32 _sender) internal view virtual;

  /**
   * @notice Returns the appropriate Gateway address on the destination domain for the message
   * @param _domain The destination domain id
   * @return _gateway The Gateway address
   */
  function _getGateway(
    uint32 _domain
  ) internal view virtual returns (bytes32 _gateway);

  function _activeMailbox(
    uint32 _domain
  ) internal view virtual returns (IMailbox);
}
