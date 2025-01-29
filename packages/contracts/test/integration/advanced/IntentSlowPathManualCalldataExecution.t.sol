// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Vm} from 'forge-std/Vm.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

contract SlowPathIntent_ManualCalldataExecution_Integration is IntegrationBase {
  using stdStorage for StdStorage;

  bytes32 internal _intentId;
  IEverclear.Intent internal _intent;
  IEverclear.FillMessage internal _fillMessage;

  event ExternalCalldataExecuted(bytes32 indexed _intentId, bytes _returnData);

  function test_ManualCalldataExecution() public {
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = ETHEREUM_SEPOLIA_ID;
    _destinations[1] = BSC_TESTNET_ID;

    // Create intent where user settles himself
    (_intentId, _intent) = _createIntentAndReceiveInHubWithTTLAndDestinations({
      _user: _user,
      _assetOrigin: oUSDT,
      _assetDestination: IERC20(address(0)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _intentAmount: 100 ether,
      _ttl: 0,
      _destinations: _destinations
    });

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{value: 1 ether}(ETHEREUM_SEPOLIA_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    _processSettlementMessage(ETHEREUM_SEPOLIA_ID, _settlementMessageBody);

    uint256 _amountAfterFees = 100 ether - (100 ether * totalProtocolFees / Common.DBPS_DENOMINATOR);

    assertEq(oUSDT.balanceOf(_user), _amountAfterFees);

    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    vm.mockCall(makeAddr('target'), abi.encodeWithSignature('doSomething()'), abi.encode(true));
    vm.expectCall(makeAddr('target'), abi.encodeWithSignature('doSomething()'));

    vm.expectEmit(address(sepoliaEverclearSpoke));
    emit ExternalCalldataExecuted(_intentId, abi.encode(true));

    sepoliaEverclearSpoke.executeIntentCalldata(_intent);
  }
}
