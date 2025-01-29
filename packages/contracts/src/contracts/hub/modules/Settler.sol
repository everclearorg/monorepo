// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';

import {Constants} from 'contracts/common/Constants.sol';
import {Constants as Common} from 'contracts/common/Constants.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';

import {HubQueueLib} from 'contracts/hub/lib/HubQueueLib.sol';
import {InvoiceListLib} from 'contracts/hub/lib/InvoiceListLib.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {ISettler} from 'interfaces/hub/ISettler.sol';

import {SettlerLogic} from 'contracts/hub/modules/SettlerLogic.sol';

/**
 * @title Settler
 * @notice Contract for processing settlements
 */
contract Settler is SettlerLogic, ISettler, IEverclear {
  using InvoiceListLib for InvoiceListLib.InvoiceList;
  using HubQueueLib for HubQueueLib.DepositQueue;
  using HubQueueLib for HubQueueLib.SettlementQueue;
  using Uint32Set for Uint32Set.Set;

  // @inheritdoc ISettler
  function processDepositsAndInvoices(
    bytes32 _tickerHash,
    uint32 _maxEpochs,
    uint32 _maxDeposits,
    uint32 _maxInvoices
  ) external {
    uint48 _epoch = getCurrentEpoch();
    uint48 _previousLastClosedEpochProcessed = lastClosedEpochsProcessed[_tickerHash];

    // Process invoices phase
    _processInvoices({_tickerHash: _tickerHash, _epoch: _epoch, _maxInvoices: _maxInvoices});

    // Clean up phase
    _cleanUpClosedEpochsDeposits({
      _tickerHash: _tickerHash,
      _currentEpoch: _epoch,
      _maxEpochs: _maxEpochs,
      _maxDeposits: _maxDeposits
    });

    uint48 _lastClosedEpochProcessed = lastClosedEpochsProcessed[_tickerHash];

    // only emitting event for last closed epoch processed state change since for every invoice and deposit processed an individual event is emitted in the internal functions
    if (_lastClosedEpochProcessed > _previousLastClosedEpochProcessed) {
      emit ClosedEpochsProcessed(_tickerHash, _lastClosedEpochProcessed);
    }
  }

  /// @inheritdoc ISettler
  function processSettlementQueue(uint32 _domain, uint32 _amount) external payable {
    (bytes memory _message, uint256 _gasLimit) = _processSettlementQueue(_domain, _amount);

    (bytes32 _messageId, uint256 _feeSpent) = hubGateway.sendMessage{value: msg.value}(_domain, _message, _gasLimit);

    emit SettlementQueueProcessed(_messageId, _domain, _amount, _feeSpent);
  }

  /// @inheritdoc ISettler
  function processSettlementQueueViaRelayer(
    uint32 _domain,
    uint32 _amount,
    address _relayer,
    uint256 _ttl,
    uint256 _nonce,
    uint256 _bufferDBPS,
    bytes calldata _signature
  ) external {
    bytes memory _data =
      abi.encode(PROCESS_QUEUE_VIA_RELAYER_TYPEHASH, _domain, _amount, _relayer, _ttl, _nonce, _bufferDBPS);
    _verifySignature(lighthouse, _data, _nonce, _signature);

    (bytes memory _message, uint256 _gasLimit) = _processSettlementQueue(_domain, _amount);

    uint256 _fee = hubGateway.quoteMessage(_domain, _message, _gasLimit);

    (bytes32 _messageId, uint256 _feeSpent) =
      hubGateway.sendMessage(_domain, _message, _fee + ((_fee * _bufferDBPS) / Common.DBPS_DENOMINATOR), _gasLimit);

    emit SettlementQueueProcessed(_messageId, _domain, _amount, _feeSpent);
  }

  /**
   * @notice Process an invoice
   * @param _epoch The epoch of the invoice
   * @param _tickerHash The hash of the ticker
   * @param _invoice The invoice to be processed
   * @return _settled Whether the invoice was settled
   */
  function _processInvoice(
    uint48 _epoch,
    bytes32 _tickerHash,
    Invoice memory _invoice
  ) internal returns (bool _settled) {
    FindDomainResult memory _domainResult = _findDestinationWithStrategiesForInvoice(_epoch, _tickerHash, _invoice);

    if (_domainResult.selectedDomain == 0) {
      // Cannot apply xerc20 strategy and no domains have enough liquidity to cover the invoice
      // Invoice cannot be settled
      return false;
    }

    // Invoice can be settled
    _settled = true;
    if (_domainResult.strategy == IEverclear.Strategy.XERC20) {
      // xerc20 strategy, no discount is applied
      _createSettlement({
        _intentId: _invoice.intentId,
        _tickerHash: _tickerHash,
        _amount: _invoice.amount,
        _destination: _domainResult.selectedDomain,
        _recipient: _invoice.owner
      });
    } else {
      // Default strategy
      // Found liquidity in a domain - Invoice can be settled, iterate deposits queue
      // _selectedAmountAfterDiscount will be progressively decreased with deposits amounts until is 100% covered or no more deposits are available
      uint256 _remainingAmount = _domainResult.selectedAmountAfterDiscount;

      HubQueueLib.DepositQueue storage _depositQueue = deposits[_epoch][_domainResult.selectedDomain][_tickerHash];
      uint256 _index = _depositQueue.firstDepositWithPurchasePower;
      Deposit memory _deposit = _depositQueue.at(_index);
      while (_remainingAmount > 0 && _deposit.intentId != 0) {
        uint256 _nominator = _deposit.purchasePower > _remainingAmount ? _remainingAmount : _deposit.purchasePower;
        uint256 _depositRewards =
          _nominator * _domainResult.selectedRewardsForDepositors / _domainResult.selectedAmountAfterDiscount;

        _contexts[_deposit.intentId].pendingRewards += _depositRewards;

        if (_deposit.purchasePower > _remainingAmount) {
          _depositQueue.updateAt({_position: _index, _decreaseAmount: _remainingAmount});
          _remainingAmount = 0;
        } else {
          _depositQueue.updateAt({_position: _index, _decreaseAmount: _deposit.purchasePower});
          _remainingAmount -= _deposit.purchasePower;
          _index += 1;
          _deposit = _depositQueue.at(_index);
        }
      }

      uint256 _depositsAmount = depositsAvailableInEpoch[_epoch][_domainResult.selectedDomain][_tickerHash];
      depositsAvailableInEpoch[_epoch][_domainResult.selectedDomain][_tickerHash] = _depositsAmount
        > _domainResult.selectedAmountAfterDiscount ? _depositsAmount - _domainResult.selectedAmountAfterDiscount : 0;

      _createSettlement({
        _intentId: _invoice.intentId,
        _tickerHash: _tickerHash,
        _amount: _domainResult.selectedAmountAfterDiscount,
        _destination: _domainResult.selectedDomain,
        _recipient: _invoice.owner
      });
    }
  }

  /**
   * @notice Process and removes a deposit
   * @param _epoch The epoch of the deposit
   * @param _domain The domain of the deposit
   * @param _tickerHash The hash of the ticker
   */
  function _processDeposit(uint48 _epoch, uint32 _domain, bytes32 _tickerHash) internal {
    // deposit is removed
    Deposit memory _deposit = deposits[_epoch][_domain][_tickerHash].dequeueDeposit();

    IntentContext storage _intentContext = _contexts[_deposit.intentId];

    // check if deposit was an xcall
    Intent memory _intent = _intentContext.intent;

    // Emit edeposit processed before invoice or settlement enqueued events
    emit DepositProcessed(
      _epoch, _domain, _tickerHash, _deposit.intentId, _intentContext.amountAfterFees + _intentContext.pendingRewards
    );

    if (_intent.ttl == 0) {
      // slow path intent rewards are for the depositor
      _createSettlementOrInvoice({_intentId: _deposit.intentId, _tickerHash: _tickerHash, _recipient: _intent.receiver});
    } else {
      // xcall intent
      bytes32 _solver = _intentContext.solver;
      // check if intent was filled
      if (_solver == 0) {
        // intent not filled yet
        bool _expired = block.timestamp > _intent.timestamp + _intent.ttl + expiryTimeBuffer;
        if (_expired) {
          // expired, goes slow path and settle and rewards are for depositor
          _createSettlementOrInvoice({
            _intentId: _deposit.intentId,
            _tickerHash: _tickerHash,
            _recipient: _intent.receiver
          });
        } else {
          // not expired, settle and rewards might be for the solver if filled or for depositor if not filled and goes slow path
          _intentContext.status = IntentStatus.DEPOSIT_PROCESSED;
        }
      } else {
        // intent filled, settle and rewards goes to solver
        // settle solver
        _createSettlementOrInvoice({_intentId: _deposit.intentId, _tickerHash: _tickerHash, _recipient: _solver});
      }
    }
  }

  /**
   * @notice Process the settlement queue and dispatch the settlements using the transport layer
   * @param _domain The domain of the settlement
   * @param _amount The amount of the settlement
   * @return _message The message to be sent
   * @return _gasLimit The gas limit for the message
   */
  function _processSettlementQueue(
    uint32 _domain,
    uint32 _amount
  ) internal returns (bytes memory _message, uint256 _gasLimit) {
    if (!_supportedDomains.contains(_domain)) {
      revert Settler_DomainNotSupported();
    }
    if (_amount > settlements[_domain].last - settlements[_domain].first + 1) {
      revert Settler_InsufficientSettlements();
    }

    IEverclear.Settlement[] memory _settlementMessages = new IEverclear.Settlement[](_amount);

    uint256 _baseGasLimit = gasConfig.settlementBaseGasUnits + (gasConfig.averageGasUnitsPerSettlement * _amount);
    _gasLimit = _baseGasLimit + ((_baseGasLimit * gasConfig.bufferDBPS) / Common.DBPS_DENOMINATOR);

    if (_gasLimit > domainGasLimit[_domain]) {
      revert Settler_DomainBlockGasLimitReached(domainGasLimit[_domain], _gasLimit);
    }

    for (uint32 _i; _i < _amount; _i++) {
      _settlementMessages[_i] = HubQueueLib.dequeueSettlement(settlements[_domain]);
    }

    _message = MessageLib.formatSettlementBatch(_settlementMessages);
  }

  /**
   * @notice Process invoices for a ticker hash
   * @param _tickerHash The hash of the ticker
   * @param _epoch The epoch of the invoices
   * @param _maxInvoices The maximum number of invoices to be iterated to avoid out of gas error
   */
  function _processInvoices(bytes32 _tickerHash, uint48 _epoch, uint32 _maxInvoices) internal {
    if (_tokenConfigs[_tickerHash].domains.length() == 0) {
      revert Settler_ProcessDepositsAndInvoices_InvalidTickerHash();
    }
    // Process invoices and deposits for the current epoch phase
    InvoiceListLib.InvoiceList storage _invoiceList = invoices[_tickerHash];

    bytes32 _invoiceId = _invoiceList.head;
    bytes32 _previousInvoiceId;
    uint32 _invoicesProcessed;
    while (_invoiceId != 0) {
      Invoice memory _invoice = _invoiceList.at(_invoiceId).invoice;
      bytes32 _nextId;
      _nextId = _invoiceList.at(_invoiceId).next;
      if (_processInvoice(_epoch, _tickerHash, _invoice)) {
        // remove the invoice from the list if it was settled
        _invoiceList.remove(_invoiceId, _previousInvoiceId);
      } else {
        // update the previous invoice id if the invoice was not settled
        _previousInvoiceId = _invoiceId;
      }
      if (_maxInvoices > 0 && ++_invoicesProcessed >= _maxInvoices) {
        break;
      }
      _invoiceId = _nextId;
    }
  }

  /**
   * @notice Clean up deposits for closed epochs
   * @param _tickerHash The hash of the ticker
   * @param _currentEpoch The current epoch
   * @param _maxEpochs The maximum number of epochs to be processed
   * @param _maxDeposits The maximum number of deposits across domains to be processed
   */
  function _cleanUpClosedEpochsDeposits(
    bytes32 _tickerHash,
    uint48 _currentEpoch,
    uint32 _maxEpochs,
    uint32 _maxDeposits
  ) internal {
    uint48 _lastClosedEpoch = _currentEpoch - 1;
    uint48 _lastClosedEpochProcessed = lastClosedEpochsProcessed[_tickerHash];
    uint32 _depositsProcessed;
    if (_lastClosedEpoch > _lastClosedEpochProcessed || _lastClosedEpoch == 0) {
      uint48 _i;
      for (_i = _lastClosedEpochProcessed; _i <= _lastClosedEpoch; _i++) {
        uint32[] memory _assetDomains = _tokenConfigs[_tickerHash].domains.memValues();
        for (uint256 _j; _j < _assetDomains.length; _j++) {
          uint32 _domain = _assetDomains[_j];
          HubQueueLib.DepositQueue storage _depositQueue = deposits[_i][_domain][_tickerHash];
          while (!_depositQueue.isEmpty()) {
            _processDeposit(_i, _domain, _tickerHash);
            if (_maxDeposits > 0 && ++_depositsProcessed >= _maxDeposits) {
              // _i - 1 to continue processing from the current closed epoch being processed since it was not fully processed
              lastClosedEpochsProcessed[_tickerHash] = _i > 0 ? _i - 1 : 0;
              // since maxDeposits is across domains of tickerHash the method returns and stops processing
              return;
            }
          }
        }

        if (_maxEpochs > 0 && _i - _lastClosedEpochProcessed >= _maxEpochs) {
          // store the last closed epoch processed
          lastClosedEpochsProcessed[_tickerHash] = _i;
          return;
        }
      }

      // all the epochs were processed _i has an extra increment so it needs to be decremented
      lastClosedEpochsProcessed[_tickerHash] = _i - 1;
    }
  }

  /**
   * @notice Verifies a signature
   * @param _signer The signer of the message
   * @param _data The data of the message
   * @param _signature The signature of the message
   */
  function _verifySignature(address _signer, bytes memory _data, uint256 _nonce, bytes calldata _signature) internal {
    bytes32 _hash = keccak256(_data);
    address _recoveredSigner = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(_hash), _signature);
    if (_recoveredSigner != _signer) {
      revert HubStorage_InvalidSignature();
    }

    _useCheckedNonce(_recoveredSigner, _nonce);
  }

  /**
   * @notice Find the destination for an invoice with strategies in order of priority
   * @param _epoch The epoch of the invoice
   * @param _tickerHash The hash of the ticker
   * @param _invoice The invoice to be processed
   * @return _domainResult The result of the domain search
   */
  function _findDestinationWithStrategiesForInvoice(
    uint48 _epoch,
    bytes32 _tickerHash,
    Invoice memory _invoice
  ) internal view returns (FindDomainResult memory _domainResult) {
    uint32[] memory _destinations = _getDestinations(_tickerHash, _invoice.intentId, _invoice.owner);

    if (_tokenConfigs[_tickerHash].prioritizedStrategy == IEverclear.Strategy.XERC20) {
      // xerc20 strategy discount will be zero
      _domainResult.selectedDomain = _findDestinationXerc20Strategy(_tickerHash, _destinations);
      if (_domainResult.selectedDomain == 0) {
        // Default strategy with lowest discount and highest liquidity
        _domainResult = _findLowestDiscountAndHighestLiquidity(
          FindDomainParams({tickerHash: _tickerHash, invoice: _invoice, epoch: _epoch, domains: _destinations})
        );
      } else {
        _domainResult.strategy = IEverclear.Strategy.XERC20;
      } // else if will be added for other strategies in order of priority
    } else {
      // Default strategy with lowest discount and highest liquidity
      _domainResult = _findLowestDiscountAndHighestLiquidity(
        FindDomainParams({tickerHash: _tickerHash, invoice: _invoice, epoch: _epoch, domains: _destinations})
      );

      if (_domainResult.selectedDomain == 0) {
        // xerc20 strategy discount will be zero
        _domainResult.selectedDomain = _findDestinationXerc20Strategy(_tickerHash, _destinations);
        if (_domainResult.selectedDomain != 0) {
          _domainResult.strategy = IEverclear.Strategy.XERC20;
        } // else if will be added for other strategies in order of priority
      }
    }
  }

  /**
   * @notice Finds the domain with the lowest discount and the highest liquidity
   * @param _params The parameters for the domain search
   * @return _result The result of the domain search
   */
  function _findLowestDiscountAndHighestLiquidity(
    FindDomainParams memory _params
  ) internal view returns (FindDomainResult memory _result) {
    uint256 _selectedLiquidity;
    TokenConfig storage tokenConfig = _tokenConfigs[_params.tickerHash];
    _result.discountDbps = _getDiscountDbps(_params.tickerHash, _params.epoch, _params.invoice.entryEpoch);

    for (uint256 _i; _i < _params.domains.length; _i++) {
      uint32 _domain = _params.domains[_i];
      uint256 _liquidity = custodiedAssets[tokenConfig.assetHashes[_domain]];
      (uint256 _amountAfterDiscount, uint256 _amountToBeDiscounted, uint256 _rewardsForDepositors) =
        _getDiscountedAmount(_params.tickerHash, _result.discountDbps, _domain, _params.epoch, _params.invoice.amount);

      if (_liquidity >= _amountAfterDiscount) {
        if (
          (_amountAfterDiscount > _result.selectedAmountAfterDiscount)
            || (_amountAfterDiscount == _result.selectedAmountAfterDiscount && _liquidity > _selectedLiquidity)
        ) {
          _result.selectedDomain = _domain;
          _result.selectedAmountAfterDiscount = _amountAfterDiscount;
          _result.selectedAmountToBeDiscounted = _amountToBeDiscounted;
          _result.selectedRewardsForDepositors = _rewardsForDepositors;
          _selectedLiquidity = _liquidity;
        }
      }
    }
  }

  /**
   * @notice Get the discount Dbps for an invoice
   * @param _tickerHash The hash of the ticker
   * @param _epoch The epoch for discount calculation
   * @param _entryEpoch The epoch when the invoice was created
   * @return _discountDbps The discount in DBPS
   */
  function _getDiscountDbps(
    bytes32 _tickerHash,
    uint48 _epoch,
    uint48 _entryEpoch
  ) internal view returns (uint24 _discountDbps) {
    if (_epoch <= _entryEpoch) {
      return 0;
    }
    uint24 _interval = uint24(_epoch - _entryEpoch);
    TokenConfig storage _tokenConfig = _tokenConfigs[_tickerHash];
    uint24 _maxDiscountDbps = _tokenConfig.maxDiscountDbps;
    uint24 discountPerEpoch = _tokenConfig.discountPerEpoch;
    if (discountPerEpoch > 0 && type(uint24).max / discountPerEpoch < _interval) {
      return _maxDiscountDbps;
    }
    _discountDbps = _interval * discountPerEpoch;
    if (_discountDbps > _maxDiscountDbps) {
      _discountDbps = _maxDiscountDbps;
    }
  }

  /**
   * @notice Get the discounted amount of an invoice
   * @param _tickerHash The hash of the ticker
   * @param _discountDbps The discount in DBPS
   * @param _domain The domain of the invoice
   * @param _epoch The epoch for discount calculation
   * @param _invoiceAmount The invoice amount to cover
   * @return _amountAfterDiscount The discounted amount for the invoice owner
   * @return _amountToBeDiscounted The amount to be discounted
   * @return _rewardsForDepositors The rewards to be distributed for depositors that cover the invoice
   */
  function _getDiscountedAmount(
    bytes32 _tickerHash,
    uint24 _discountDbps,
    uint32 _domain,
    uint48 _epoch,
    uint256 _invoiceAmount
  ) internal view returns (uint256 _amountAfterDiscount, uint256 _amountToBeDiscounted, uint256 _rewardsForDepositors) {
    uint256 depositsAmount = depositsAvailableInEpoch[_epoch][_domain][_tickerHash];
    _amountToBeDiscounted = depositsAmount < _invoiceAmount ? depositsAmount : _invoiceAmount;
    _rewardsForDepositors = (_amountToBeDiscounted * _discountDbps) / Constants.DBPS_DENOMINATOR;
    _amountAfterDiscount = _invoiceAmount - _rewardsForDepositors;
  }
}
