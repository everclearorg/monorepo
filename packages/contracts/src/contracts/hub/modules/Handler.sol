// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AssetUtils} from 'contracts/common/AssetUtils.sol';

import {Constants} from 'contracts/common/Constants.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';

import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {SettlerLogic} from 'contracts/hub/modules/SettlerLogic.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHandler} from 'interfaces/hub/IHandler.sol';

/**
 * @title Handler
 * @notice The Handler is the EverclearHub module responsible for handling
 * expired and unsupported intents.
 */
contract Handler is SettlerLogic, IEverclear, IHandler {
  using Uint32Set for Uint32Set.Set;

  /// @inheritdoc IHandler
  function handleExpiredIntents(
    bytes32[] calldata _expiredIntentIds
  ) external payable {
    for (uint256 _i; _i < _expiredIntentIds.length; _i++) {
      IntentContext storage _intentContext = _contexts[_expiredIntentIds[_i]];
      Intent memory _intent = _intentContext.intent;
      bytes32 _intentId = _expiredIntentIds[_i];
      if (_intentContext.status != IntentStatus.DEPOSIT_PROCESSED) {
        revert Handler_HandleExpiredIntents_InvalidStatus(_intentId, _intentContext.status);
      }
      if (_intent.ttl == 0) {
        revert Handler_HandleExpiredIntents_ZeroTTL(_intentId);
      }
      // check if the intent is expired
      if (block.timestamp < _intent.timestamp + _intent.ttl + expiryTimeBuffer) {
        revert Handler_HandleExpiredIntents_NotExpired(
          _intentId, block.timestamp, _intent.timestamp + _intent.ttl + expiryTimeBuffer
        );
      }

      _createSettlementOrInvoice({
        _intentId: _intentId,
        _tickerHash: _adoptedForAssets[AssetUtils.getAssetHash(_intent.inputAsset, _intent.origin)].tickerHash,
        _recipient: _intent.receiver
      });
    }
    emit ExpiredIntentsHandled(_expiredIntentIds);
  }

  /// @inheritdoc IHandler
  function returnUnsupportedIntent(
    bytes32 _intentId
  ) external payable {
    IntentContext storage _intentContext = _contexts[_intentId];
    if (_intentContext.status != IntentStatus.UNSUPPORTED) {
      revert Handler_ReturnUnsupportedIntent_InvalidStatus();
    }
    Intent memory _intent = _intentContext.intent;
    _intentContext.status = IntentStatus.UNSUPPORTED_RETURNED;

    Settlement[] memory _settlementMessageBatch = new Settlement[](1);
    _settlementMessageBatch[0] = Settlement({
      intentId: _intentId,
      amount: _intent.amount,
      asset: _intent.inputAsset,
      recipient: _intent.initiator,
      updateVirtualBalance: true
    });

    bytes memory _settlementMessageData = MessageLib.formatSettlementBatch(_settlementMessageBatch);
    (bytes32 _messageId,) =
      hubGateway.sendMessage{value: msg.value}(_intent.origin, _settlementMessageData, Constants.DEFAULT_GAS_LIMIT);

    emit ReturnUnsupportedIntent(_intent.origin, _messageId, _settlementMessageBatch[0].intentId);
  }

  /// @inheritdoc IHandler
  function withdrawFees(
    bytes32 _feeRecipient,
    bytes32 _tickerHash,
    uint256 _amount,
    uint32[] calldata _destinations
  ) external {
    if (feeVault[_tickerHash][msg.sender] < _amount) {
      revert Handler_WithdrawFees_InsufficientFunds();
    }

    if (_amount == 0) {
      revert Handler_WithdrawFees_ZeroAmount();
    }

    for (uint256 _i; _i < _destinations.length; _i++) {
      if (!_supportedDomains.contains(_destinations[_i])) {
        revert Handler_WithdrawFees_UnsupportedDomain(_destinations[_i]);
      }
    }

    feeVault[_tickerHash][msg.sender] -= _amount;

    bytes32 _paymentId = keccak256(
      abi.encode(_PROTOCOL_PAYMENT, _tickerHash, _amount, msg.sender, _feeRecipient, _destinations, ++paymentNonce)
    );

    uint32 _selectedDestination = _findDestinationWithStrategies(_tickerHash, _amount, _destinations);

    if (_selectedDestination != 0) {
      _createSettlement({
        _intentId: _paymentId,
        _tickerHash: _tickerHash,
        _amount: _amount,
        _destination: _selectedDestination,
        _recipient: _feeRecipient
      });
    } else {
      // Send to invoice queue debt
      _createInvoice({_tickerHash: _tickerHash, _intentId: _paymentId, _amount: _amount, _owner: _feeRecipient});
      _contexts[_paymentId].intent.destinations = _destinations;
    }

    emit FeesWithdrawn(msg.sender, _feeRecipient, _tickerHash, _amount, _paymentId);
  }
}
