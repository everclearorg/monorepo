// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Vm} from 'forge-std/Vm.sol';
import {console} from 'forge-std/console.sol';

import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';

import {ISettler} from 'interfaces/hub/ISettler.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';
import {Constants} from 'test/utils/Constants.sol';

contract FillIntent_TransferSettlement_Integration is IntegrationBase {
  using stdStorage for StdStorage;

  bytes32 internal _intentId;
  IEverclear.Intent internal _intent;
  IEverclear.FillMessage internal _fillMessage;

  function test_FillIntentAndSettleAsTransfer() public {
    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    // Set solver preference to receive transfer on settlement
    vm.prank(_solver);
    hub.setUpdateVirtualBalance(false);

    (_intentId, _intent) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: oUSDT,
      _assetDestination: dUSDT,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: 100 ether,
      _ttl: 1 days
    });

    _fillIntentAndReceiveInHub(_intentId, _intent, dUSDT, BSC_TESTNET_ID, 100 ether * 1e12, _solver2);

    vm.prank(makeAddr('caller'));
    // process deposits and invoices
    hub.processDepositsAndInvoices(keccak256('USDT'), 0, 0, 0);

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{value: 1 ether}(ETHEREUM_SEPOLIA_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    _processSettlementMessage(ETHEREUM_SEPOLIA_ID, _settlementMessageBody);

    uint256 _amountAfterFees = 100 ether - (100 ether * totalProtocolFees / Common.DBPS_DENOMINATOR);

    assertEq(oUSDT.balanceOf(_solver2), _amountAfterFees);
  }
}
