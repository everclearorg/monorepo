// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Vm} from 'forge-std/Vm.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

contract FastPathIntent_Expired_ManualCalldataExecution is IntegrationBase {
  using stdStorage for StdStorage;

  bytes32 internal _intentId;
  IEverclear.Intent internal _intent;
  IEverclear.FillMessage internal _fillMessage;

  uint256 intentAmountEth = 100 ether;
  uint256 intentAmountBsc = 100 ether * 1e12;

  event ExternalCalldataExecuted(bytes32 indexed _intentId, bytes _returnData);

  function test_ExpiredIntent_ManualCalldataExecution() public {
    // Create intent
    (_intentId, _intent) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: oUSDT,
      _assetDestination: dUSDT,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: intentAmountEth,
      _ttl: 1 days
    });

    // 3 hour buffer
    vm.warp(_intent.timestamp + 1 days + 3 hours + 1);

    bytes32[] memory _expiredIntentIds = new bytes32[](1);
    _expiredIntentIds[0] = _intentId;

    hub.handleExpiredIntents(_expiredIntentIds);

    // New Intent to create liquidity
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: dUSDT,
      _assetDestination: oUSDT,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: intentAmountBsc
    });

    _processDepositsAndInvoices(keccak256('USDT'));

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{value: 1 ether}(BSC_TESTNET_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    _processSettlementMessage(BSC_TESTNET_ID, _settlementMessageBody);

    uint256 _amountAfterFees = intentAmountBsc - (intentAmountBsc * totalProtocolFees / Common.DBPS_DENOMINATOR);

    assertEq(dUSDT.balanceOf(_user), _amountAfterFees);

    vm.selectFork(BSC_TESTNET_FORK);

    vm.mockCall(makeAddr('target'), abi.encodeWithSignature('doSomething()'), abi.encode(true));
    vm.expectCall(makeAddr('target'), abi.encodeWithSignature('doSomething()'));

    vm.expectEmit(address(bscEverclearSpoke));
    emit ExternalCalldataExecuted(_intentId, abi.encode(true));

    bscEverclearSpoke.executeIntentCalldata(_intent);
  }
}
