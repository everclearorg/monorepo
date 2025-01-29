// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

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

contract FillIntent_ReceiveRewardsOnSettlement is IntegrationBase {
  using stdStorage for StdStorage;
  using TypeCasts for address;

  bytes32 internal _intentId;
  IEverclear.Intent internal _intent;
  IEverclear.FillMessage internal _fillMessage;

  uint256 internal _intentAmountEthereum = 100 ether;
  uint256 internal _intentAmountBSC = 100 ether * 1e12;

  function test_FillIntentAndSettleWithRewards() public {
    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    // Set solver preference to receive settlement as virtual balance update
    vm.prank(_solver2);
    hub.setUpdateVirtualBalance(true);

    // Create initial intent - slow path
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: oUSDT,
      _assetDestination: dUSDT,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmountEthereum
    });

    // 3 epochs worth of rewards for the solver
    _rollEpochs(3);

    // Create intent to fill invoice
    (_intentId, _intent) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: dUSDT,
      _assetDestination: oUSDT,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _intentAmountBSC,
      _ttl: 1 days
    });

    vm.prank(makeAddr('caller'));
    // process deposits and invoices
    hub.processDepositsAndInvoices(keccak256('USDT'), 0, 0, 0);

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, _intentAmountEthereum);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{value: 1 ether}(BSC_TESTNET_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    _processSettlementMessage(BSC_TESTNET_ID, _settlementMessageBody);

    // Solver should receive rewards of the above intent
    _fillIntentAndReceiveInHub(_intentId, _intent, oUSDT, ETHEREUM_SEPOLIA_ID, _intentAmountEthereum, _solver2);

    // Create another intent so theres liquidity to settle the solver
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: dUSDT,
      _assetDestination: oUSDT,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _intentAmountBSC * 10
    });

    _closeEpochAndProcessDepositsAndInvoices(keccak256('USDT'));

    vm.recordLogs();

    // process settlement queue
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{value: 1 ether}(BSC_TESTNET_ID, 1);

    entries = vm.getRecordedLogs();

    _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    _processSettlementMessage(BSC_TESTNET_ID, _settlementMessageBody);

    uint256 _amountAfterFees = _intentAmountBSC - (_intentAmountBSC * totalProtocolFees / Common.DBPS_DENOMINATOR);
    uint256 _rewards = _amountAfterFees * defaultDiscountPerEpoch * 3 / Common.DBPS_DENOMINATOR;
    uint256 _settlementAmount = _amountAfterFees + _rewards;

    assertEq(dUSDT.balanceOf(_solver2), 0);
    assertEq(bscEverclearSpoke.balances(address(dUSDT).toBytes32(), _solver2.toBytes32()), _settlementAmount);
  }
}
