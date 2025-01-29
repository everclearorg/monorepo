// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AssetUtils} from 'contracts/common/AssetUtils.sol';
import {Constants as Common} from 'contracts/common/Constants.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';

import {HubQueueLib} from 'contracts/hub/lib/HubQueueLib.sol';
import {InvoiceListLib} from 'contracts/hub/lib/InvoiceListLib.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubMessageReceiver, IMessageReceiver} from 'interfaces/hub/IHubMessageReceiver.sol';

import {SettlerLogic} from 'contracts/hub/modules/SettlerLogic.sol';

/**
 * @title HubMessageReceiver
 * @notice Contract for processing incoming cross-chain messages
 */
contract HubMessageReceiver is SettlerLogic, IHubMessageReceiver {
  using InvoiceListLib for InvoiceListLib.InvoiceList;
  using HubQueueLib for HubQueueLib.DepositQueue;
  using HubQueueLib for HubQueueLib.SettlementQueue;
  using Uint32Set for Uint32Set.Set;

  /// @inheritdoc IMessageReceiver
  function receiveMessage(
    bytes calldata _message
  ) external override onlyAuthorized {
    (MessageLib.MessageType _messageType, bytes memory _data) = MessageLib.parseMessage(_message);

    if (_messageType == MessageLib.MessageType.INTENT) {
      _processIntents(MessageLib.parseIntentMessageBatch(_data));
    } else if (_messageType == MessageLib.MessageType.FILL) {
      _processFillMessages(MessageLib.parseFillMessageBatch(_data));
    } else {
      revert HubMessageReceiver_ReceiveMessage_InvalidMessageType();
    }
  }

  /**
   * @notice Process an array of intent messages
   * @param __intents The array of intent messages
   */
  function _processIntents(
    Intent[] memory __intents
  ) internal {
    for (uint256 _i; _i < __intents.length; _i++) {
      Intent memory _intent = __intents[_i];
      bytes32 _intentId = keccak256(abi.encode(_intent));
      IntentContext storage _intentContext = _contexts[_intentId];
      IntentStatus _previousStatus = _intentContext.status;
      uint48 _currentEpoch = getCurrentEpoch();

      if (_previousStatus != IntentStatus.NONE && _previousStatus != IntentStatus.FILLED) {
        continue;
      }

      // store intent
      _intentContext.intent = _intent;

      (bool _supported, bytes32 _tickerHash, bytes32 _inputAssetHash, IEverclear.Strategy _strategy) =
        _checkSupportedIntent(_intent);

      // Check if the intent is supported and if the input and output assets are correct
      if (!_supported) {
        _intentContext.status = IntentStatus.UNSUPPORTED;
        emit IntentProcessed(_intentId, IntentStatus.UNSUPPORTED);
        continue;
      }

      if (_strategy == IEverclear.Strategy.DEFAULT) {
        // update the custodied assets balance
        custodiedAssets[_inputAssetHash] += _intent.amount;
      }

      // deduct protocol fees
      (_intentContext.totalProtocolFee, _intentContext.amountAfterFees) =
        _deductProtocolFees(_tickerHash, _intent.amount);

      if (invoices[_tickerHash].length == 0) {
        emit DepositProcessed(_currentEpoch, _intent.origin, _tickerHash, _intentId, _intent.amount);

        if (_intent.ttl == 0) {
          // slow path, no solvers
          _createSettlementOrInvoice({_intentId: _intentId, _tickerHash: _tickerHash, _recipient: _intent.receiver});
        } else {
          bytes32 _solver = _intentContext.solver;
          // xcall
          if (_solver == 0) {
            // intent not filled yet
            // when deposit is not created is considered processed
            _intentContext.status = IntentStatus.DEPOSIT_PROCESSED;
          } else {
            // fast path, intent filled, settle solver
            _createSettlementOrInvoice(_intentId, _tickerHash, _solver);
          }
        }
      } else {
        // store deposit
        deposits[_currentEpoch][_intent.origin][_tickerHash].enqueueDeposit(
          Deposit({intentId: _intentId, purchasePower: _intent.amount})
        );
        _intentContext.status =
          _previousStatus == IntentStatus.FILLED ? IntentStatus.ADDED_AND_FILLED : IntentStatus.ADDED;
        depositsAvailableInEpoch[_currentEpoch][_intent.origin][_tickerHash] += _intent.amount;

        emit DepositEnqueued(_currentEpoch, _intent.origin, _tickerHash, _intentId, _intent.amount);
      }

      emit IntentProcessed(_intentId, _intentContext.status);
    }
  }

  /**
   * @notice Process an array of fill messages
   * @param _fillMessages The fill messages
   */
  function _processFillMessages(
    FillMessage[] memory _fillMessages
  ) internal {
    for (uint256 _i; _i < _fillMessages.length; _i++) {
      FillMessage memory _fillMessage = _fillMessages[_i];
      bytes32 _intentId = _fillMessage.intentId;
      IntentContext storage _intentContext = _contexts[_intentId];
      IntentStatus _previousStatus = _intentContext.status;

      if (
        _previousStatus != IntentStatus.NONE && _previousStatus != IntentStatus.ADDED
          && _previousStatus != IntentStatus.DEPOSIT_PROCESSED
      ) {
        continue;
      }

      _intentContext.solver = _fillMessage.solver;
      _intentContext.fee = _fillMessage.fee;
      _intentContext.fillTimestamp = _fillMessage.executionTimestamp;

      if (_previousStatus == IntentStatus.DEPOSIT_PROCESSED) {
        Intent memory _intent = _contexts[_intentId].intent;
        bytes32 _tickerHash = _adoptedForAssets[AssetUtils.getAssetHash(_intent.inputAsset, _intent.origin)].tickerHash;
        // settle solver
        _createSettlementOrInvoice({_intentId: _intentId, _tickerHash: _tickerHash, _recipient: _fillMessage.solver});
      } else {
        _intentContext.status =
          _previousStatus == IntentStatus.ADDED ? IntentStatus.ADDED_AND_FILLED : IntentStatus.FILLED;
      }

      emit FillProcessed(_intentId, _intentContext.status);
    }
  }

  /**
   * @notice Deduct protocol fees from the amount of the intent and distribute it to the recipients
   * @param _tickerHash The hash of the ticker symbol
   * @param _amount The amount to be settled
   * @return _totalFeeDbps The total protocol fees in DBPS
   * @return _amountAfterFees The amount after protocol fees deduction
   */
  function _deductProtocolFees(
    bytes32 _tickerHash,
    uint256 _amount
  ) internal returns (uint24 _totalFeeDbps, uint256 _amountAfterFees) {
    _amountAfterFees = _amount;
    Fee[] memory _fees = _tokenConfigs[_tickerHash].fees;
    for (uint256 _i; _i < _fees.length; _i++) {
      Fee memory _fee = _fees[_i];
      _totalFeeDbps += _fee.fee;
      uint256 _feeAmount = (_amount * _fee.fee) / Common.DBPS_DENOMINATOR;
      feeVault[_tickerHash][_fee.recipient] += _feeAmount;
      _amountAfterFees -= _feeAmount;
    }
  }

  /**
   * @notice Check if an intent is supported
   * @param _intent The intent object
   * @return _supported Whether the intent is supported
   * @return _tickerHash The hash of the ticker symbol
   * @return _inputAssetHash The hash of the input asset
   * @return _strategy The strategy to be used
   */
  function _checkSupportedIntent(
    Intent memory _intent
  )
    internal
    view
    returns (bool _supported, bytes32 _tickerHash, bytes32 _inputAssetHash, IEverclear.Strategy _strategy)
  {
    _inputAssetHash = AssetUtils.getAssetHash(_intent.inputAsset, _intent.origin);
    _tickerHash = _adoptedForAssets[_inputAssetHash].tickerHash;

    if (!_adoptedForAssets[_inputAssetHash].approval) {
      return (false, _tickerHash, _inputAssetHash, IEverclear.Strategy.DEFAULT);
    }

    for (uint256 _i; _i < _intent.destinations.length; _i++) {
      if (!_supportedDomains.contains(_intent.destinations[_i])) {
        return (false, _tickerHash, _inputAssetHash, IEverclear.Strategy.DEFAULT);
      }
    }

    if (_intent.destinations.length == 1 && _intent.outputAsset != 0) {
      // Output asset must be validated
      uint32 _destination = _intent.destinations[0];
      bytes32 _outputAssetHash = AssetUtils.getAssetHash(_intent.outputAsset, _destination);
      bytes32 _expectedOutputHash = _tokenConfigs[_tickerHash].assetHashes[_destination];

      if (!_adoptedForAssets[_outputAssetHash].approval || _outputAssetHash != _expectedOutputHash) {
        return (false, _tickerHash, _inputAssetHash, IEverclear.Strategy.DEFAULT);
      }
    }

    return (true, _tickerHash, _inputAssetHash, _adoptedForAssets[_inputAssetHash].strategy);
  }
}
