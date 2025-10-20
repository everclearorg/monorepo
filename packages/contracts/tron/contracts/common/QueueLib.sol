// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEverclear} from 'interfaces/common/IEverclear.sol';

/**
 * @title QueueLib
 * @notice Library for managing queues
 */
library QueueLib {
  /**
   * @notice Structure for the IntentQueue
   * @dev first should always be initialized to 1
   * @param first The first position in the queue
   * @param last The last position in the queue
   * @param queue The queue of intent ids
   */
  struct IntentQueue {
    uint256 first;
    uint256 last;
    mapping(uint256 _position => bytes32 _intentId) queue;
  }

  /**
   * @notice Structure for the FillQueue
   * @dev Member first should always be initialized to 1
   * @param first The first position in the queue
   * @param last The last position in the queue
   * @param queue The queue of fill messages
   */
  struct FillQueue {
    uint256 first;
    uint256 last;
    mapping(uint256 _position => IEverclear.FillMessage _fillMessage) queue;
  }

  /**
   * @notice Thrown when the queue is empty
   */
  error Queue_EmptyQueue();

  /**
   * @notice Enqueue an intent id to the IntentQueue
   * @param _queue The IntentQueue
   * @param _intentId The intent id to enqueue
   */
  function enqueueIntent(IntentQueue storage _queue, bytes32 _intentId) internal {
    _queue.last += 1;
    _queue.queue[_queue.last] = _intentId;
  }

  /**
   * @notice Enqueue a fill message to the FillQueue
   * @param _queue The FillQueue
   * @param _fillMessage The fill message to enqueue
   */
  function enqueueFill(FillQueue storage _queue, IEverclear.FillMessage memory _fillMessage) internal {
    _queue.last += 1;
    _queue.queue[_queue.last] = _fillMessage;
  }

  /**
   * @notice Dequeue an intent id from the IntentQueue
   * @param _queue The IntentQueue
   * @return _intentId The dequeued intent id
   */
  function dequeueIntent(
    IntentQueue storage _queue
  ) internal returns (bytes32 _intentId) {
    // non-empty queue check
    if (_queue.last < _queue.first) revert Queue_EmptyQueue();

    _intentId = _queue.queue[_queue.first];

    delete _queue.queue[_queue.first];
    _queue.first += 1;
  }

  /**
   * @notice Dequeue a fill message from the FillQueue
   * @param _queue The FillQueue
   * @return _fillMessage The dequeued fill message
   */
  function dequeueFill(
    FillQueue storage _queue
  ) internal returns (IEverclear.FillMessage memory _fillMessage) {
    // non-empty queue
    if (_queue.last < _queue.first) revert Queue_EmptyQueue();

    _fillMessage = _queue.queue[_queue.first];

    delete _queue.queue[_queue.first];
    _queue.first += 1;
  }
}
