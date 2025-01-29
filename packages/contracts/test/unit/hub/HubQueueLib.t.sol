// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {HubQueueLib} from 'contracts/hub/lib/HubQueueLib.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {TestExtended} from 'test/utils/TestExtended.sol';

contract BaseTest is TestExtended {
  HubQueueLib.DepositQueue depositQueue;
  HubQueueLib.SettlementQueue settlementQueue;

  function _mockDepositData(uint256 _index, IHubStorage.Deposit calldata _deposit) internal {
    depositQueue.queue[_index] = _deposit;
  }

  function _mockSettlmentData(uint256 _index, IEverclear.Settlement calldata _settlement) internal {
    settlementQueue.queue[_index] = _settlement;
  }
}

contract Unit_Enqueue is BaseTest {
  using HubQueueLib for HubQueueLib.DepositQueue;
  using HubQueueLib for HubQueueLib.SettlementQueue;

  /**
   * @notice Test enqueueing a deposit
   * @param _first The first position in the queue
   * @param _last The last position in the queue
   * @param _deposit The deposit to enqueue
   */
  function test_EnqueueDeposit(uint256 _first, uint256 _last, IHubStorage.Deposit calldata _deposit) public {
    vm.assume(_first < _last && _first >= 1);
    vm.assume(_last < type(uint256).max);

    depositQueue.first = _first;
    depositQueue.last = _last;

    depositQueue.enqueueDeposit(_deposit);

    IHubStorage.Deposit memory _lastDeposit = depositQueue.queue[depositQueue.last];

    assertEq(depositQueue.last, _last + 1);
    assertEq(depositQueue.first, _first);
    assertEq(_lastDeposit.intentId, _deposit.intentId);
    assertEq(_lastDeposit.purchasePower, _deposit.purchasePower);
  }

  /**
   * @notice Test enqueueing a settlement
   * @param _first The first position in the queue
   * @param _last The last position in the queue
   * @param _settlement The settlement to enqueue
   */
  function test_EnqueueSettlement(uint256 _first, uint256 _last, IEverclear.Settlement calldata _settlement) public {
    vm.assume(_first < _last && _first >= 1);
    vm.assume(_last < type(uint256).max);

    settlementQueue.first = _first;
    settlementQueue.last = _last;

    settlementQueue.enqueueSettlement(_settlement);

    IEverclear.Settlement memory _lastSettlement = settlementQueue.queue[settlementQueue.last];

    assertEq(settlementQueue.last, _last + 1);
    assertEq(settlementQueue.first, _first);
    assertEq(_lastSettlement.intentId, _settlement.intentId);
    assertEq(_lastSettlement.asset, _settlement.asset);
    assertEq(_lastSettlement.amount, _settlement.amount);
    assertEq(_lastSettlement.recipient, _settlement.recipient);
    assertEq(_lastSettlement.updateVirtualBalance, _settlement.updateVirtualBalance);
  }
}

contract Unit_Dequeue is BaseTest {
  using HubQueueLib for HubQueueLib.DepositQueue;
  using HubQueueLib for HubQueueLib.SettlementQueue;

  /**
   * @notice Test dequeueing a deposit
   * @param _first The first position in the queue
   * @param _last The last position in the queue
   * @param _deposit The deposit to dequeue
   */
  function test_DequeueDeposit(uint256 _first, uint256 _last, IHubStorage.Deposit calldata _deposit) public {
    vm.assume(_first < _last && _first >= 1);
    vm.assume(_last < type(uint256).max);

    _mockDepositData(_first, _deposit);

    depositQueue.first = _first;
    depositQueue.last = _last;

    IHubStorage.Deposit memory _returnedDeposit = depositQueue.dequeueDeposit();

    assertEq(depositQueue.first, _first + 1);
    assertEq(depositQueue.last, _last);
    assertEq(_returnedDeposit.intentId, _deposit.intentId);
    assertEq(_returnedDeposit.purchasePower, _deposit.purchasePower);
  }

  /**
   * @notice Test dequeueing a settlement
   * @param _first The first position in the queue
   * @param _last The last position in the queue
   * @param _settlement The settlement to dequeue
   */
  function test_DequeueSettlement(uint256 _first, uint256 _last, IEverclear.Settlement calldata _settlement) public {
    vm.assume(_first < _last && _first >= 1);
    vm.assume(_last < type(uint256).max);

    _mockSettlmentData(_first, _settlement);

    settlementQueue.first = _first;
    settlementQueue.last = _last;

    IEverclear.Settlement memory _returnedSettlement = settlementQueue.dequeueSettlement();

    assertEq(settlementQueue.first, _first + 1);
    assertEq(settlementQueue.last, _last);
    assertEq(_returnedSettlement.intentId, _settlement.intentId);
    assertEq(_returnedSettlement.asset, _settlement.asset);
    assertEq(_returnedSettlement.amount, _settlement.amount);
    assertEq(_returnedSettlement.recipient, _settlement.recipient);
    assertEq(_returnedSettlement.updateVirtualBalance, _settlement.updateVirtualBalance);
  }
}
