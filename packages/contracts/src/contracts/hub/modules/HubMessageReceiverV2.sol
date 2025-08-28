// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AssetUtils} from 'contracts/common/AssetUtils.sol';
import {Constants as Common} from 'contracts/common/Constants.sol';
import {MessageLibV2} from 'contracts/common/MessageLibV2.sol';

import {HubQueueLibV2} from 'contracts/hub/lib/HubQueueLibV2.sol';
import {InvoiceListLibV2} from 'contracts/hub/lib/InvoiceListLibV2.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';
import {IHubMessageReceiverV2, IMessageReceiver} from 'interfaces/hub/IHubMessageReceiverV2.sol';

import {SettlerLogicV2} from 'contracts/hub/modules/SettlerLogicV2.sol';
import 'forge-std/console2.sol';

/**
 * @title HubMessageReceiverV2
 * @notice Contract for processing incoming cross-chain messages
 */
contract HubMessageReceiverV2 is SettlerLogicV2, IHubMessageReceiverV2 {
  using InvoiceListLibV2 for InvoiceListLibV2.InvoiceList;
  using HubQueueLibV2 for HubQueueLibV2.DepositQueue;
  using HubQueueLibV2 for HubQueueLibV2.SettlementQueue;
  using Uint32Set for Uint32Set.Set;

  /// @inheritdoc IMessageReceiver
  function receiveMessage(
    bytes calldata _message
  ) external override onlyAuthorized {
    (MessageLibV2.MessageType _messageType, bytes memory _data) = MessageLibV2.parseMessage(_message);

    if (_messageType == MessageLibV2.MessageType.INTENT) {
      _processIntents(MessageLibV2.parseIntentMessageBatch(_data));
    } else if (_messageType == MessageLibV2.MessageType.FILL) {
      _processFillMessages(MessageLibV2.parseFillMessageBatch(_data));
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

      (bool _supported, bytes32 _tickerHash, bytes32 _inputAssetHash, IEverclearV2.Strategy _strategy) =
        _checkSupportedIntent(_intent);

      // Check if the intent is supported and if the input and output assets are correct
      if (!_supported) {
        _intentContext.status = IntentStatus.UNSUPPORTED;
        emit IntentProcessed(_intentId, IntentStatus.UNSUPPORTED);
        continue;
      }

      if (_strategy == IEverclearV2.Strategy.DEFAULT) {
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

      console2.log('Filling solver');
      console2.logBytes32(_fillMessage.solver);
      _intentContext.solver = _fillMessage.solver;
      _intentContext.amountOut = _fillMessage.amountOut;
      _intentContext.fillTimestamp = _fillMessage.executionTimestamp;

      // checking destinations for the repayment asset - setting to provided array if valid or origin if invalid
      bool supportedDestinations =
        _checkSupportedDestinations(_fillMessage.intentInputAsset, _fillMessage.intentOrigin, _fillMessage.destinations);
      if (supportedDestinations) {
        _intentContext.solverDestinations = _fillMessage.destinations;
      } else {
        _intentContext.solverDestinations = new uint32[](1);
        _intentContext.solverDestinations[0] = _fillMessage.intentOrigin;
      }

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
    returns (bool _supported, bytes32 _tickerHash, bytes32 _inputAssetHash, IEverclearV2.Strategy _strategy)
  {
    _inputAssetHash = AssetUtils.getAssetHash(_intent.inputAsset, _intent.origin);
    _tickerHash = _adoptedForAssets[_inputAssetHash].tickerHash;

    if (!_adoptedForAssets[_inputAssetHash].approval) {
      return (false, _tickerHash, _inputAssetHash, IEverclearV2.Strategy.DEFAULT);
    }

    for (uint256 _i; _i < _intent.destinations.length; _i++) {
      if (!_supportedDomains.contains(_intent.destinations[_i])) {
        return (false, _tickerHash, _inputAssetHash, IEverclearV2.Strategy.DEFAULT);
      }
    }

    if (_intent.destinations.length == 1 && _intent.outputAsset != 0) {
      // Output asset must be validated
      uint32 _destination = _intent.destinations[0];
      bytes32 _outputAssetHash = AssetUtils.getAssetHash(_intent.outputAsset, _destination);

      // Checking the output asset when netting
      if (_intent.ttl == 0) {
        bytes32 _expectedOutputHash = _tokenConfigs[_tickerHash].assetHashes[_destination];
        if (!_adoptedForAssets[_outputAssetHash].approval || _outputAssetHash != _expectedOutputHash) {
          return (false, _tickerHash, _inputAssetHash, IEverclearV2.Strategy.DEFAULT);
        }
      } else {
        if (!_adoptedForAssets[_outputAssetHash].approval) {
          return (false, _tickerHash, _inputAssetHash, IEverclearV2.Strategy.DEFAULT);
        }
      }
    }

    return (true, _tickerHash, _inputAssetHash, _adoptedForAssets[_inputAssetHash].strategy);
  }

  function _checkSupportedDestinations(
    bytes32 _intentInputAsset,
    uint32 _origin,
    uint32[] memory _destinations
  ) internal view returns (bool) {
    // checking the provided domain is supported
    for (uint256 i; i < _destinations.length; i++) {
      if (!_supportedDomains.contains(_destinations[i])) {
        return false;
      }
    }

    // checking input asset is approved on provided destinations to enable repayment on a diff chain
    bytes32 _inputAssetHash = AssetUtils.getAssetHash(_intentInputAsset, _origin);
    bytes32 _tickerHash = _adoptedForAssets[_inputAssetHash].tickerHash;
    for (uint256 i; i < _destinations.length; i++) {
      bytes32 _outputAssetHash = _tokenConfigs[_tickerHash].assetHashes[_destinations[i]];
      if (!_adoptedForAssets[_outputAssetHash].approval) {
        return false;
      }
    }
    return true;
  }
}
