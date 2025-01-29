// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {QueueLib} from 'contracts/common/QueueLib.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {TestExtended} from 'test/utils/TestExtended.sol';

contract Unit_TestQueueLib is TestExtended {
  QueueLib.IntentQueue _intentQueue;
  QueueLib.FillQueue _fillQueue;

  function _mockIntentData(uint256 _index, bytes32 _intentId) internal {
    _intentQueue.queue[_index] = _intentId;
  }

  function _mockFillMessage(uint256 _index, IEverclear.FillMessage memory _fillMessage) internal {
    _fillQueue.queue[_index] = _fillMessage;
  }

  /*//////////////////////////////////////////////////////////////
                                ENQUEUE
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Tests the enqueue function for an intent queue
   */
  function test_EnqueueIntent(uint256 _first, uint256 _last, bytes32 _intentId) public {
    vm.assume(_first < _last);
    vm.assume(_last < type(uint256).max);

    _intentQueue.first = _first;
    _intentQueue.last = _last;

    QueueLib.enqueueIntent(_intentQueue, _intentId);

    assertEq(_intentQueue.last, _last + 1);
    assertEq(_intentQueue.first, _first);
    assertEq(_intentQueue.queue[_intentQueue.last], _intentId);
  }

  /**
   * @notice Tests the enqueue function for an fill queue
   */
  function test_EnqueueFill(uint256 _first, uint256 _last, IEverclear.FillMessage memory _fillMessage) public {
    vm.assume(_first < _last);
    vm.assume(_last < type(uint256).max);

    _fillQueue.first = _first;
    _fillQueue.last = _last;

    QueueLib.enqueueFill(_fillQueue, _fillMessage);

    assertEq(_fillQueue.last, _last + 1);
    assertEq(_fillQueue.first, _first);
    assertEq(_fillQueue.queue[_fillQueue.last].intentId, _fillMessage.intentId);
  }

  /*//////////////////////////////////////////////////////////////
                                DEQUEUE
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Tests the dequeue function for an intent queue
   */
  function test_DequeueIntent(uint256 _first, uint256 _last, bytes32 _intentId) public {
    vm.assume(_first < _last);
    vm.assume(_last < type(uint256).max);

    _intentQueue.first = _first;
    _intentQueue.last = _last;

    _mockIntentData(_first, _intentId);

    bytes32 _returnedIntentId = QueueLib.dequeueIntent(_intentQueue);

    assertEq(_intentQueue.first, _first + 1);
    assertEq(_intentQueue.last, _last);
    assertEq(_returnedIntentId, _intentId);
  }

  /**
   * @notice Tests the dequeue function for an fill queue
   */
  function test_DequeuFill(uint256 _first, uint256 _last, IEverclear.FillMessage memory _fillMessage) public {
    vm.assume(_first < _last);
    vm.assume(_last < type(uint256).max);

    _fillQueue.first = _first;
    _fillQueue.last = _last;

    _mockFillMessage(_first, _fillMessage);

    IEverclear.FillMessage memory _returnedMessage = QueueLib.dequeueFill(_fillQueue);

    assertEq(_fillQueue.first, _first + 1);
    assertEq(_fillQueue.last, _last);
    assertEq(_returnedMessage.intentId, _fillMessage.intentId);
  }
}
