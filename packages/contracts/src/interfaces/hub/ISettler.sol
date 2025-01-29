// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

/**
 * @title ISettler
 * @notice Interface for the settler contract
 */
interface ISettler {
  /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Read only struct for the parameters to find a domain that has the lowest discount and the highest liquidity
   * @param tickerHash The hash of the ticker symbol
   * @param invoice The invoice to be settled
   * @param epoch The epoch to be settled
   * @param domains The domains to be settled
   */
  struct FindDomainParams {
    bytes32 tickerHash;
    IHubStorage.Invoice invoice;
    uint48 epoch;
    uint32[] domains;
  }

  /**
   * @notice Read only struct for the result of the domain selection
   * @param strategy The strategy to be used
   * @param discountDbps The discount dbps to be applied
   * @param selectedDomain The domain selected
   * @param selectedAmountAfterDiscount The amount after the discount
   * @param selectedAmountToBeDiscounted The amount to be discounted, can be less or equal than the invoice amount
   * @param selectedRewardsForDepositors The rewards for the depositors
   */
  struct FindDomainResult {
    IEverclear.Strategy strategy;
    uint24 discountDbps;
    uint32 selectedDomain;
    uint256 selectedAmountAfterDiscount;
    uint256 selectedAmountToBeDiscounted;
    uint256 selectedRewardsForDepositors;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a settlement queue is processed
   * @param _messageId The message ID
   * @param _domain The domain which settlements queue is going to be processed
   * @param _amount The amount of settlements to be batched
   * @param _quote The quote for the batch message
   */
  event SettlementQueueProcessed(bytes32 _messageId, uint32 _domain, uint32 _amount, uint256 _quote);

  /**
   * @notice Emitted when a settlement batch is processed for a domain
   * @param _messageId The message ID
   * @param _intentIds The intent ids included in the batch
   * @param _domain The domain where settlements queue is going to be processed
   * @param _quote The quote for the batch message
   */
  event SettlementsProcessed(bytes32 _messageId, bytes32[] _intentIds, uint32 _domain, uint256 _quote);

  /**
   * @notice Emitted when the closed epochs are processed
   * @param _tickerHash The asset for which epochs were processed
   * @param _lastClosedEpochProcessed The last closed epoch processed
   */
  event ClosedEpochsProcessed(bytes32 indexed _tickerHash, uint48 _lastClosedEpochProcessed);

  /*///////////////////////////////////////////////////////////////
                                ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the domain is not supported
   */
  error Settler_DomainNotSupported();

  /**
   * @notice Thrown when the settlement queue doesn't have enough settlements
   */
  error Settler_InsufficientSettlements();

  /**
   * @notice Thrown when the settlement batch requires more gas units than the maximum block gas limit for the domain
   * @param _domainBlockGasLimit The actual block gas limit for the domain
   * @param _settlementBatchGasLimit The gas units needed to process the settlement batch
   */
  error Settler_DomainBlockGasLimitReached(uint256 _domainBlockGasLimit, uint256 _settlementBatchGasLimit);

  /**
   * @notice Thrown when the ticker hash is invalid
   */
  error Settler_ProcessDepositsAndInvoices_InvalidTickerHash();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Process the epochs for a specific asset
   * @param _tickerHash The asset for which epochs are going to be processed
   * @param _maxEpochs The maximum number of epochs to be processed if it's zero it will processed all the closed epochs
   * @param _maxDeposits The maximum number of deposits across supported domains to be processed if it's zero it will process all the deposits
   * @param _maxInvoices The maximum number of invoices to be iterated if it's zero it will iterate all the invoices
   */
  function processDepositsAndInvoices(
    bytes32 _tickerHash,
    uint32 _maxEpochs,
    uint32 _maxDeposits,
    uint32 _maxInvoices
  ) external;

  /**
   * @notice Dispatches batch settlements to the transport layer for a domain and amount
   * @param _domain The domain which settlements queue is going to be processed
   * @param _amount The amount of settlements to be batched
   */
  function processSettlementQueue(uint32 _domain, uint32 _amount) external payable;

  /**
   * @notice Dispatches batch settlements to the transport layer for a domain and amount via a relayer
   * @param _domain The domain which settlements queue is going to be processed
   * @param _amount The amount of settlements to be batched
   * @param _relayer The address of the relayer
   * @param _ttl The time to live of the signature
   * @param _nonce The nonce of the signature
   * @param _bufferDBPS The buffer to be applied to the fee
   * @param _signature The signature of the message
   */
  function processSettlementQueueViaRelayer(
    uint32 _domain,
    uint32 _amount,
    address _relayer,
    uint256 _ttl,
    uint256 _nonce,
    uint256 _bufferDBPS,
    bytes calldata _signature
  ) external;
}
