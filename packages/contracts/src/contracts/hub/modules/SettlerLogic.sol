// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {HubQueueLib} from 'contracts/hub/lib/HubQueueLib.sol';
import {InvoiceListLib} from 'contracts/hub/lib/InvoiceListLib.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {HubStorage} from 'contracts/hub/HubStorage.sol';

abstract contract SettlerLogic is HubStorage {
  using InvoiceListLib for InvoiceListLib.InvoiceList;
  using HubQueueLib for HubQueueLib.DepositQueue;
  using HubQueueLib for HubQueueLib.SettlementQueue;
  using Uint32Set for Uint32Set.Set;

  /**
   * @notice Create a settlement or an invoice depending on the liquidity in the destination
   * @param _intentId The ID of the intent
   * @param _tickerHash The hash of the ticker symbol
   * @param _recipient The address of the recipient
   * @dev the algorithm will select the destination with the highest liquidity that can cover the amount
   */
  function _createSettlementOrInvoice(bytes32 _intentId, bytes32 _tickerHash, bytes32 _recipient) internal {
    uint32[] memory _destinations = _getDestinations(_tickerHash, _intentId, _recipient);
    IntentContext storage _intentContext = _contexts[_intentId];

    uint256 _amountAndRewards = _intentContext.amountAfterFees + _intentContext.pendingRewards;
    delete _intentContext.pendingRewards;

    uint32 _selectedDestination = _findDestinationWithStrategies(_tickerHash, _amountAndRewards, _destinations);

    if (_selectedDestination != 0) {
      _createSettlement({
        _intentId: _intentId,
        _tickerHash: _tickerHash,
        _amount: _amountAndRewards,
        _destination: _selectedDestination,
        _recipient: _recipient
      });
    } else {
      // Send to invoice queue debt
      _createInvoice({_tickerHash: _tickerHash, _intentId: _intentId, _amount: _amountAndRewards, _owner: _recipient});
    }
  }

  /**
   * @notice Create an invoice
   * @param _tickerHash The hash of the ticker symbol
   * @param _intentId The ID of the intent
   * @param _amount The amount to be settled
   * @param _owner The address of the invoice owner
   */
  function _createInvoice(bytes32 _tickerHash, bytes32 _intentId, uint256 _amount, bytes32 _owner) internal {
    _contexts[_intentId].status = IEverclear.IntentStatus.INVOICED;
    uint48 _currentEpoch = getCurrentEpoch();
    invoices[_tickerHash].append(
      Invoice({intentId: _intentId, owner: _owner, entryEpoch: _currentEpoch, amount: _amount})
    );
    emit InvoiceEnqueued(_intentId, _tickerHash, _currentEpoch, _amount, _owner);
  }

  /**
   * @notice Create a settlement
   * @param _intentId The ID of the intent
   * @param _tickerHash The hash of the ticker symbol
   * @param _amount The amount to be settled
   * @param _destination The destination domain
   * @param _recipient The address of the recipient
   */
  function _createSettlement(
    bytes32 _intentId,
    bytes32 _tickerHash,
    uint256 _amount,
    uint32 _destination,
    bytes32 _recipient
  ) internal {
    // Send to settlement queue ready to be dispatched
    _contexts[_intentId].status = IEverclear.IntentStatus.SETTLED;
    bytes32 _assetHash = _tokenConfigs[_tickerHash].assetHashes[_destination];
    IEverclear.Strategy _strategy = _adoptedForAssets[_assetHash].strategy;
    if (_strategy == IEverclear.Strategy.DEFAULT) {
      custodiedAssets[_assetHash] -= _amount;
    }
    bytes32 _asset = _adoptedForAssets[_assetHash].adopted;
    bool _updateVirtualBalance = updateVirtualBalance[_recipient];
    IEverclear.Settlement memory _settlement = IEverclear.Settlement({
      intentId: _intentId,
      amount: _amount,
      asset: _asset,
      recipient: _recipient,
      updateVirtualBalance: _updateVirtualBalance
    });
    settlements[_destination].enqueueSettlement(_settlement);
    emit SettlementEnqueued(
      _intentId, _destination, getCurrentEpoch(), _asset, _amount, _updateVirtualBalance, _recipient
    );
  }

  /**
   * @notice Get the destinations for a user
   * @param _tickerHash The hash of the ticker symbol
   * @param _intentId The ID of the intent
   * @param _user The user
   * @return _destinations The destinations
   * @dev prioritizes user configured destinations over intent destinations
   */
  function _getDestinations(
    bytes32 _tickerHash,
    bytes32 _intentId,
    bytes32 _user
  ) internal view returns (uint32[] memory _destinations) {
    uint32[] memory _userSupportedDomains = _usersSupportedDomains[_user].memValues();

    // Prioritize creator supported domains over intent destinations
    if (_userSupportedDomains.length == 0) {
      _destinations = _contexts[_intentId].intent.destinations;
      _destinations = _destinations.length == 0 ? _tokenConfigs[_tickerHash].domains.memValues() : _destinations;
    } else {
      _destinations = _userSupportedDomains;
    }
  }

  /**
   * @notice Find the destination evaluating the strategies in order of priority
   * @param _tickerHash The hash of the ticker symbol
   * @param _amountAndRewards The amount after fees + pending rewards
   * @param _destinations The destinations
   * @return _selectedDestination The selected destination
   */
  function _findDestinationWithStrategies(
    bytes32 _tickerHash,
    uint256 _amountAndRewards,
    uint32[] memory _destinations
  ) internal view returns (uint32 _selectedDestination) {
    if (_tokenConfigs[_tickerHash].prioritizedStrategy == IEverclear.Strategy.XERC20) {
      _selectedDestination = _findDestinationXerc20Strategy(_tickerHash, _destinations);
      if (_selectedDestination == 0) {
        _selectedDestination = _findDestinationDefaultStrategy(_tickerHash, _amountAndRewards, _destinations);
      } // else if will be added for other strategies in order of priority
    } else {
      _selectedDestination = _findDestinationDefaultStrategy(_tickerHash, _amountAndRewards, _destinations);
      if (_selectedDestination == 0) {
        _selectedDestination = _findDestinationXerc20Strategy(_tickerHash, _destinations);
      }
    }
  }

  /**
   * @notice Select the destination with the XERC20 strategy
   * @param _tickerHash The hash of the ticker symbol
   * @param _destinations The destinations
   * @return _selectedDestination The first destination that supports xerc20 strategy in order of priority selected by the user
   */
  function _findDestinationXerc20Strategy(
    bytes32 _tickerHash,
    uint32[] memory _destinations
  ) internal view returns (uint32 _selectedDestination) {
    // select the first destination that is an xerc20 strategy that the user prefers
    for (uint256 _i; _i < _destinations.length; _i++) {
      uint32 _destination = _destinations[_i];
      bytes32 _assetHash = _tokenConfigs[_tickerHash].assetHashes[_destination];
      if (_adoptedForAssets[_assetHash].strategy == IEverclear.Strategy.XERC20) {
        _selectedDestination = _destination;
        break;
      }
    }
  }

  /**
   * @notice Select the destination with the default strategy
   * @param _tickerHash The hash of the ticker symbol
   * @param _amountAndRewards The amount after fees + pending rewards
   * @param _destinations The destinations
   * @return _selectedDestination The destination with the highest liquidity that can cover the amount after fees + pending rewards
   */
  function _findDestinationDefaultStrategy(
    bytes32 _tickerHash,
    uint256 _amountAndRewards,
    uint32[] memory _destinations
  ) internal view returns (uint32 _selectedDestination) {
    uint256 _highestLiquidityDestination;
    TokenConfig storage _tokenConfig = _tokenConfigs[_tickerHash];

    // Find the highest liquidity destination that can cover the amount after fees + pending rewards
    for (uint256 _i; _i < _destinations.length; _i++) {
      uint32 _destination = _destinations[_i];
      uint256 _liquidityInDestination = custodiedAssets[_tokenConfig.assetHashes[_destination]];
      if (_liquidityInDestination > _highestLiquidityDestination && _liquidityInDestination >= _amountAndRewards) {
        _selectedDestination = _destination;
        _highestLiquidityDestination = _liquidityInDestination;
      }
    }
  }
}
