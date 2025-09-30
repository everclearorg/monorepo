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

import {IGatewayV3} from 'interfaces/common/IGatewayV3.sol';
import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

/**
 * @title GatewayV3
 * @notice Abstract contract for GatewayV3 functionality.
 * @dev This contract must be inherited from implementations that must override the necessary check functions.
 */
abstract contract GatewayV3 is GasTank, IGatewayV3, IMessageRecipient, ISpecifiesInterchainSecurityModule {
  using TypeCasts for address;

  uint256 public constant POLYMER_ID = 1;
  uint256 public constant HL_ID = 2;
  uint256 public constant CCIP_ID = 3;

  // Tag to indicate a gas limit (or dest chain equivalent processing units) and Out Of Order Execution. This tag is
  // available for multiple chain families. If there is no chain family specific tag, this is the default available
  // for a chain.
  // Note: not available for Solana VM based chains.
  bytes4 public constant GENERIC_EXTRA_ARGS_V2_TAG = 0x181dcf10;

  /// @inheritdoc IGatewayV3
  address public mailbox;

  /// @inheritdoc IGatewayV3
  IMessageReceiver public receiver;

  /// @inheritdoc ISpecifiesInterchainSecurityModule
  IInterchainSecurityModule public interchainSecurityModule;

  /**
   * @notice Checks that the function is called by the local receiver
   */
  modifier onlyReceiver() {
    if (msg.sender != address(receiver)) revert GatewayV3_SendMessage_UnauthorizedCaller();
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
      revert GatewayV3_ZeroAddress();
    }
    _;
  }

  constructor() {
    _disableInitializers();
  }

  /// @inheritdoc IGatewayV3
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
      if (!_success) revert GatewayV3_SendMessage_UnsuccessfulRebate();
    }
  }

  /// @inheritdoc IGatewayV3
  function sendMessage(
    uint32 _chainId,
    bytes calldata _message,
    uint256 _fee,
    uint256 _gasLimit
  ) external onlyReceiver returns (bytes32 _messageId, uint256 _feeSpent) {
    bytes32 _destinationGateway = _getGateway(_chainId);
    IMailbox _mailbox = _activeMailbox(_chainId);

    if (_fee > address(this).balance) {
      revert GatewayV3_SendMessage_InsufficientBalance();
    }

    uint256 _initialBalance = address(this).balance;

    bytes memory _metadata = StandardHookMetadata.formatMetadata(0, _gasLimit, address(this), '');
    _messageId = _mailbox.dispatch{value: _fee}(_chainId, _destinationGateway, _message, _metadata);

    _feeSpent = _initialBalance - address(this).balance;
    emit GasTankSpent(_feeSpent);
  }

  /// @inheritdoc IGatewayV3
  function updateMailbox(
    address
  ) external onlyReceiver {
    revert GatewayV3_Deprecated_SingletonMailbox();
  }

  /// @inheritdoc IGatewayV3
  function updateSecurityModule(
    address _newSecurityModule
  ) external onlyReceiver validAddress(_newSecurityModule.toBytes32()) {
    address _oldSecurityModule = address(interchainSecurityModule);
    interchainSecurityModule = IInterchainSecurityModule(_newSecurityModule);
    emit SecurityModuleUpdated(_oldSecurityModule, _newSecurityModule);
  }

  /// @inheritdoc IGatewayV3
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
   * @notice Handles incoming messages from the mailbox
   * @param _origin The id for the origin domain of the message
   * @param _sender The remote Gateway contract (on the origin domain)
   * @param _message The message payload
   */
  function _handle(uint32 _origin, bytes32 _sender, bytes memory _message) internal virtual;

  function _constructCalldata(
    uint256 _mailboxId,
    uint256 _destDomain,
    bytes32 _recipient,
    bytes memory _message,
    uint256 _gasLimit
  ) internal pure returns (bytes memory) {
    if (_mailboxId == HL_ID) {
      bytes memory _metadata = StandardHookMetadata.formatMetadata(0, _gasLimit, address(0), '');
      return
        abi.encodeWithSignature('dispatch(uint32,bytes32,bytes,bytes)', _destDomain, _recipient, _message, _metadata);
    } else if (_mailboxId == CCIP_ID) {
      EVM2AnyMessage memory _evm2AnyMessage = EVM2AnyMessage({
        receiver: abi.encode(_recipient),
        data: _message,
        tokenAmounts: new EVMTokenAmount[](0),
        feeToken: address(0),
        extraArgs: abi.encodeWithSelector(
          GENERIC_EXTRA_ARGS_V2_TAG, (GenericExtraArgsV2({gasLimit: 200_000, allowOutOfOrderExecution: true}))
        )
      });
      return abi.encodeWithSignature(
        'ccipSend(uint64,(bytes,bytes,(address,uint256)address,bytes))', _destDomain, _recipient, _evm2AnyMessage
      );
    } else {
      revert GatewayV3_SendMessage_UnsupportedMailbox();
    }
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
