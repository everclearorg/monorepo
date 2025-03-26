// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {AssetUtils} from 'contracts/common/AssetUtils.sol';
import {Constants as Common} from 'contracts/common/Constants.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';
import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';

import {SpokeStorage} from 'contracts/intent/SpokeStorage.sol';

contract SpokeMessageReceiver is SpokeStorage, OwnableUpgradeable, IMessageReceiver {
  using TypeCasts for bytes32;

  /**
   * @notice Checks that the function is called by the gateway
   */
  modifier onlyAuthorized() {
    if (msg.sender != owner() && (msg.sender != address(gateway) || paused)) {
      revert EverclearSpoke_Unauthorized();
    }
    _;
  }

  /// @inheritdoc IMessageReceiver
  function receiveMessage(
    bytes memory _message
  ) external onlyAuthorized {
    (MessageLib.MessageType _messageType, bytes memory _data) = MessageLib.parseMessage(_message);

    if (_messageType == MessageLib.MessageType.SETTLEMENT) {
      _handleBatchSettlement(_data);
    } else if (_messageType == MessageLib.MessageType.VAR_UPDATE) {
      (bytes32 _updateVariable, bytes memory _updateData) = MessageLib.parseVarUpdateMessage(_data);
      _handleVarUpdate(_updateVariable, _updateData);
    } else {
      revert EverclearSpoke_InvalidMessageType();
    }
  }

  /**
   * @notice handle a variable update message
   * @param _updateVariable The hash of the variable being updated
   * @param _updateData The data of the update
   */
  function _handleVarUpdate(bytes32 _updateVariable, bytes memory _updateData) internal {
    if (_updateVariable == Common.GATEWAY_HASH) {
      address _newGateway = MessageLib.parseAddressUpdateMessage(_updateData).toAddress();
      _updateGateway(_newGateway);
    } else if (_updateVariable == Common.MAILBOX_HASH) {
      address _newMailbox = MessageLib.parseAddressUpdateMessage(_updateData).toAddress();
      _updateMailbox(_newMailbox);
    } else if (_updateVariable == Common.LIGHTHOUSE_HASH) {
      address _newLighthouse = MessageLib.parseAddressUpdateMessage(_updateData).toAddress();
      _updateLighthouse(_newLighthouse);
    } else if (_updateVariable == Common.WATCHTOWER_HASH) {
      address _newWatchtower = MessageLib.parseAddressUpdateMessage(_updateData).toAddress();
      _updateWatchtower(_newWatchtower);
    } else {
      revert EverclearSpoke_InvalidVarUpdate();
    }
  }

  /**
   * @notice Handles a batch of settlement messages
   * @param _data The batch of settlement messages
   */
  function _handleBatchSettlement(
    bytes memory _data
  ) internal {
    Settlement[] memory _settlementMessage = MessageLib.parseSettlementBatch(_data);
    for (uint256 _i; _i < _settlementMessage.length; _i++) {
      Settlement memory _message = _settlementMessage[_i];
      _handleSettlement(_message);
    }
  }

  /**
   * @notice Handles a settlement message
   * @param _message The settlement message
   */
  function _handleSettlement(
    Settlement memory _message
  ) internal {
    address _asset = _message.asset.toAddress();
    address _recipient = _message.recipient.toAddress();

    IntentStatus _intentStatus = status[_message.intentId];
    // if already settled, ignore (shouldn't happen)
    if (_intentStatus == IntentStatus.SETTLED || _intentStatus == IntentStatus.SETTLED_AND_MANUALLY_EXECUTED) {
      return;
    }
    status[_message.intentId] = IntentStatus.SETTLED;

    uint256 _amount =
      AssetUtils.normalizeDecimals(Common.DEFAULT_NORMALIZED_DECIMALS, ERC20(_asset).decimals(), _message.amount);

    // after decimals normalization, the _amount can be 0 as result of loss of precision, check if it's > 0
    if (_amount > 0) {
      // if amount is > 0 proceed with the settlement according to the strategy
      // fetch strategy for asset
      Strategy _strategy = strategies[_asset];

      if (_strategy == Strategy.DEFAULT) {
        // default strategy
        if (_message.updateVirtualBalance) {
          balances[_message.asset][_message.recipient] += _amount;
        } else {
          // if transfer fails (eg. blacklisted recipient), increase virtual balance instead
          bytes memory _transferData = abi.encodeWithSignature('transfer(address,uint256)', _recipient, _amount);
          (bool _success, bytes memory _res) = _asset.call(_transferData);

          // doing the transfer as a low-level call to avoid reverting the whole batch if the transfer calls revert
          // applying the same checks as `SafeERC20` for the `transfer` as it can't be wrapped in a `try/catch` block
          if (!_success || (_res.length != 0 && !abi.decode(_res, (bool)))) {
            balances[_message.asset][_message.recipient] += _amount;
            emit AssetTransferFailed(_asset, _recipient, _amount);
          }
        }
      } else {
        // dedicated strategy
        ISettlementModule _module = modules[_strategy];
        address _mintRecipient = _message.updateVirtualBalance ? address(this) : _recipient;
        bool _success = _module.handleMintStrategy(_asset, _mintRecipient, _recipient, _amount, '');

        if (_success && _message.updateVirtualBalance) {
          balances[_message.asset][_message.recipient] += _amount;
        } else if (!_success) {
          emit AssetMintFailed(_asset, _recipient, _amount, _strategy);
        }
      }
    }
    emit Settled(_message.intentId, _recipient, _asset, _amount);
  }

  /**
   * @notice Update the gateway
   * @param _newGateway The new gateway address
   */
  function _updateGateway(
    address _newGateway
  ) internal validAddress(_newGateway) {
    address _oldGateway = address(gateway);
    gateway = ISpokeGateway(_newGateway);
    emit GatewayUpdated(_oldGateway, _newGateway);
  }

  /**
   * @notice Update the local mailbox address
   * @param _newMailbox The new mailbox address
   */
  function _updateMailbox(
    address _newMailbox
  ) internal {
    gateway.updateMailbox(_newMailbox);
  }

  /**
   * @notice Update the interchain security module address
   * @param _newSecurityModule The new security module address
   */
  function _updateSecurityModule(
    address _newSecurityModule
  ) internal {
    gateway.updateSecurityModule(_newSecurityModule);
  }

  /**
   * @notice Update the lighthouse address
   * @param _newLighthouse The new lighthouse address
   */
  function _updateLighthouse(
    address _newLighthouse
  ) internal validAddress(_newLighthouse) {
    address _oldLighthouse = lighthouse;
    lighthouse = _newLighthouse;
    emit LighthouseUpdated(_oldLighthouse, _newLighthouse);
  }

  /**
   * @notice Update the watchtower address
   * @param _newWatchtower The new watchtower address
   */
  function _updateWatchtower(
    address _newWatchtower
  ) internal validAddress(_newWatchtower) {
    address _oldWatchtower = watchtower;
    watchtower = _newWatchtower;

    emit WatchtowerUpdated(_oldWatchtower, _newWatchtower);
  }
}
