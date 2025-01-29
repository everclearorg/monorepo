// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

/**
 * @title HubQueueLib
 * @notice Library for managing hub queues
 * @dev first element is initialized to 1 the first enqueue, empty checks also checks the case where first is 0
 */
library HubQueueLib {
  /**
   * @notice Structure for the DepositQueue
   * @param first The first position in the queue
   * @param last The last position in the queue
   * @param firstDepositWithPurchasePower The first deposit in the queue with purchase power remaining
   * @param queue The queue of deposits
   */
  struct DepositQueue {
    uint256 first;
    uint256 last;
    uint256 firstDepositWithPurchasePower;
    mapping(uint256 _position => IHubStorage.Deposit _deposit) queue;
  }

  /**
   * @notice Structure for the SettlementQueue
   * @param first The first position in the queue
   * @param last The last position in the queue
   * @param queue The queue of settlements
   */
  struct SettlementQueue {
    uint256 first;
    uint256 last;
    mapping(uint256 _position => IEverclear.Settlement _settlement) queue;
  }

  /**
   * @notice Thrown when the queue is empty
   */
  error Queue_EmptyQueue();

  /**
   * @notice Enqueue an deposit to the DepositQueue
   * @param _queue The DepositQueue
   * @param _deposit The deposit to enqueue
   */
  function enqueueDeposit(DepositQueue storage _queue, IHubStorage.Deposit memory _deposit) internal {
    if (_queue.first == 0) {
      _queue.first = 1;
      _queue.firstDepositWithPurchasePower = 1;
    }
    _queue.last += 1;
    _queue.queue[_queue.last] = _deposit;
  }

  /**
   * @notice Enqueue a settlement to the SettlementQueue
   * @param _queue The SettlementQueue
   * @param _settlement The settlement to enqueue
   */
  function enqueueSettlement(SettlementQueue storage _queue, IEverclear.Settlement memory _settlement) internal {
    if (_queue.first == 0) {
      _queue.first = 1;
    }
    _queue.last += 1;
    _queue.queue[_queue.last] = _settlement;
  }

  /**
   * @notice Dequeue a deposit from the DepositQueue
   * @param _queue The DepositQueue
   * @return _deposit The dequeued deposit
   */
  function dequeueDeposit(
    DepositQueue storage _queue
  ) internal returns (IHubStorage.Deposit memory _deposit) {
    // non-empty queue check
    if (_queue.last < _queue.first || _queue.first == 0) revert Queue_EmptyQueue();

    _deposit = _queue.queue[_queue.first];

    delete _queue.queue[_queue.first];
    _queue.first += 1;
  }

  /**
   * @notice Dequeue a settlement from the SettlementQueue
   * @param _queue The SettlementQueue
   * @return _settlement The dequeued _settlement
   */
  function dequeueSettlement(
    SettlementQueue storage _queue
  ) internal returns (IEverclear.Settlement memory _settlement) {
    // non-empty queue
    if (_queue.last < _queue.first || _queue.first == 0) revert Queue_EmptyQueue();

    _settlement = _queue.queue[_queue.first];

    delete _queue.queue[_queue.first];
    _queue.first += 1;
  }

  /**
   * @notice Update the deposit head
   * @param _queue The DepositQueue
   * @param _position The position in the queue
   * @param _decreaseAmount The amount to decrease the purchase power by
   */
  function updateAt(DepositQueue storage _queue, uint256 _position, uint256 _decreaseAmount) internal {
    IHubStorage.Deposit storage _deposit = _queue.queue[_position];
    _deposit.purchasePower -= _decreaseAmount;
    if (_deposit.purchasePower == 0) {
      _queue.firstDepositWithPurchasePower += 1;
    }
  }

  /**
   * @notice Get the deposit at a given position in the DepositQueue
   * @param _queue The DepositQueue
   * @return _deposit The deposit head element in the queue
   */
  function head(
    DepositQueue storage _queue
  ) internal view returns (IHubStorage.Deposit memory) {
    return _queue.queue[_queue.first];
  }

  /**
   * @notice Get the deposit at a given position in the DepositQueue
   * @param _queue The DepositQueue
   * @param _position The position in the queue
   * @return _deposit The deposit at the given position
   */
  function at(DepositQueue storage _queue, uint256 _position) internal view returns (IHubStorage.Deposit memory) {
    return _queue.queue[_position];
  }

  function isEmpty(
    DepositQueue storage _queue
  ) internal view returns (bool _isEmpty) {
    return _queue.last < _queue.first || _queue.first == 0;
  }
}
