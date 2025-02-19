// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { console2 as console } from 'forge-std/console2.sol';

import { MessageLib } from 'contracts/common/MessageLib.sol';
import { TypeCasts } from 'contracts/common/TypeCasts.sol';

import { IEverclear } from 'interfaces/common/IEverclear.sol';
import { EverclearHub } from 'contracts/hub/EverclearHub.sol';
import { IHubStorage } from 'interfaces/hub/IHubStorage.sol';
import { EverclearSpoke, IERC20 } from 'contracts/intent/EverclearSpoke.sol';
import { HubGateway } from 'contracts/hub/HubGateway.sol';
import { Settler } from 'contracts/hub/modules/Settler.sol';

import { TestnetProductionEnvironment } from '../../script/TestnetProduction.sol';
import { TestnetStagingEnvironment } from '../../script/TestnetStaging.sol';
import { TestExtended } from '../utils/TestExtended.sol';

/**
 * @notice Designed to help find the correct amount to purchase invoices with.
 */
contract InvoiceHelper is TestExtended {
  struct IntentDetails {
    uint256 originAmount;
    uint256 fees;
    uint256 rewards;
    uint256 invoiceAmount;
    uint256 invoiceEpoch;
    uint256 settlementAmount;
    uint256 settlementEpoch;
  }

  // Set up fee variables
  uint256 DBPS_DENOMINATOR = 100_000;
  uint256 MAX_FEE = 12;
  EverclearHub _hub = EverclearHub(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  HubGateway _hubGateway = HubGateway(payable(0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa));

  function _applyMaxDiscount(uint256 _toDiscount) private returns (uint256 _discounted) {
    _discounted = (_toDiscount * (DBPS_DENOMINATOR - MAX_FEE)) / DBPS_DENOMINATOR;
  }

  function _setupFork(uint256 _l2Block, uint256 _l1Block, bool _etchSettler) private {
    // Create fork at block where deposit for intentB was enqueued - 1
    vm.createSelectFork('https://rpc.everclear.raas.gelato.cloud', _l2Block);

    // Set rpc block to be l1 block
    vm.roll(_l1Block);

    if (!_etchSettler) {
      return;
    }

    Settler _settler = new Settler();
    address _current = _hub.modules(keccak256('settlement_module'));

    vm.etch(_current, address(_settler).code);
  }

  function _applyFees(uint256 _amountAfterFees, bytes32 _tickerHash) private returns (uint256 _amount) {
    IHubStorage.Fee[] memory _fees = _hub.tokenFees(_tickerHash);
    uint24 _totalFeeDbps;
    for (uint256 _i; _i < _fees.length; _i++) {
      IHubStorage.Fee memory _fee = _fees[_i];
      _totalFeeDbps += _fee.fee;
    }
    _amount = (DBPS_DENOMINATOR * _amountAfterFees) / (DBPS_DENOMINATOR - _totalFeeDbps);
    require(_amount > _amountAfterFees, 'Fees reduced amount');
  }

  function _getTotalUnprocessedDeposits(bytes32 _tickerHash, uint32 _domain) private returns (uint256 _deposits) {
    uint48 _lastClosedEpoch = _hub.lastClosedEpochsProcessed(_tickerHash);
    uint48 _current = _hub.getCurrentEpoch();

    while (_lastClosedEpoch < _current) {
      // get the deposit for the ticker
      _deposits += _hub.depositsAvailableInEpoch(_lastClosedEpoch, _domain, _tickerHash);
      // move to the next epoch
      _lastClosedEpoch++;
    }
  }

  function _constructIntentBBatch(
    uint32 _origin,
    uint256 _amountB,
    bytes32 _inputAsset,
    bytes32 _tickerHash
  ) private returns (IEverclear.Intent[] memory _intentBatch, bytes32 _intentIdB) {
    // Format intent batch with updated amount
    uint32[] memory _destinations = new uint32[](9);
    _destinations[0] = uint32(10);
    _destinations[1] = uint32(56);
    _destinations[2] = uint32(8453);
    _destinations[3] = uint32(42161);
    _destinations[4] = uint32(48900);
    _destinations[5] = uint32(59144);
    _destinations[6] = uint32(137);
    _destinations[7] = uint32(43114);
    _destinations[8] = uint32(81457);

    // Assumes the intent is owned by mark
    IEverclear.Intent memory _intentB = IEverclear.Intent({
      initiator: 0x000000000000000000000000cfdfad7450a98654b1b874f89c1f6634a81833bf,
      receiver: 0x000000000000000000000000cfdfad7450a98654b1b874f89c1f6634a81833bf,
      inputAsset: _inputAsset,
      outputAsset: 0x0000000000000000000000000000000000000000000000000000000000000000,
      maxFee: 0,
      origin: _origin,
      nonce: 259,
      timestamp: 1738785671,
      ttl: 0,
      amount: _applyFees(_amountB, _tickerHash),
      destinations: _destinations,
      data: hex''
    });
    _intentIdB = keccak256(abi.encode(_intentB));
    _intentBatch = new IEverclear.Intent[](1);
    _intentBatch[0] = _intentB;
  }

  /**
   * Returns the deposit amount after fees.
   * @dev To get target intent amount, must call `_applyFees` on this value.
   * @dev This is derived from the overall formula:
   *    liquidity == invoice after discount
   *    custodied0 + depositRequired = invoiceAmount - rewards
   *    c0 + d = i - ((d * MAX_FEE) / DBPS))
   *    d + ((d * MAX_FEE) / DBPS)) = i - c0
   * where you are finding the deposit required under the assumptions:
   * - There is only one deposit in the epoch (the one you are getting the amount for)
   * - You are using the exact amount
   * - The deposit amount will be less than the invoice amount
   * - The invoice discount is at the max
   * @param _settlementDomain Domain you want to settle on
   * @param _invoiceAmount Amount of the invoice target you are trying to settle
   * @param _tickerHash Ticker of the invoice
   */
  function _calculateDepositAmount(
    uint32 _settlementDomain,
    uint256 _invoiceAmount,
    bytes32 _tickerHash
  ) private returns (uint256 _deposit) {
    // Get the custodied assets
    uint256 _custodied = _hub.custodiedAssets(_hub.assetHash(_tickerHash, _settlementDomain));

    // Calculate the amount after fees
    _deposit = (DBPS_DENOMINATOR * (_invoiceAmount - _custodied)) / (DBPS_DENOMINATOR + MAX_FEE);
  }

  function test_intentPurchase() public {
    uint256 _l1Block = 21876587;
    _setupFork(784837, _l1Block, false);

    // Define intent constants
    bytes32 _tickerHash = 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0;
    bytes32 _intentA = 0xdca32b8cd9553a81b4548540f141b23432b18ff1a28c0006870032097d313ba8;
    uint256 _amountA = 501810314592980000000;
    uint32 _intentADestination = 8453;

    // Verify intentA exists
    require(_hub.contexts(_intentA).status == IEverclear.IntentStatus.INVOICED, 'intentA not invoiced');

    // Calculate the amount needed for an intent to exactly purchase `A`
    uint256 _amountB = _calculateDepositAmount(_intentADestination, _amountA, _tickerHash);
    // uint256 _amountB = (_amountA * DBPS_DENOMINATOR) / (DBPS_DENOMINATOR + MAX_FEE);
    console.log('amountB    :', _amountB, _applyFees(_amountB, _tickerHash));

    // // Reduce by the custodied assets
    // uint256 _custodied = _hub.custodiedAssets(_hub.assetHash(_tickerHash, _intentADestination));
    // _amountB -= _custodied;
    // console.log('custodied  :', _amountB, _custodied);

    // // Get any deposits in the queue ahead of this one
    // uint256 _unprocessed = _getTotalUnprocessedDeposits(_tickerHash, _intentADestination);
    // _amountB -= _unprocessed;
    // console.log('unprocessed:', _amountB, _unprocessed);

    (IEverclear.Intent[] memory _intentBBatch, bytes32 _intentIdB) = _constructIntentBBatch(
      _intentADestination,
      _amountB,
      0x000000000000000000000000fde4C96c8593536E31F229EA8f37b2ADa2699bb2,
      _tickerHash
    );
    console.log('intentB:');
    console.logBytes32(_intentIdB);

    // Format message to receive with proper amount
    bytes memory _message = MessageLib.formatIntentMessageBatch(_intentBBatch);
    // Receive the message on the hub
    vm.prank(0x7f50C5776722630a0024fAE05fDe8b47571D7B39);
    _hubGateway.handle(_intentADestination, TypeCasts.toBytes32(0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7), _message);
    // NOTE: if intentB is _not_ enqueued (`receiveMessage` is called) in the same epoch that intentA is
    // settled in, it will not get any rewards.

    // Verify the deposit was added
    console.log('status B   :', uint8(_hub.contexts(_intentIdB).status));
    require(_hub.contexts(_intentIdB).status == IEverclear.IntentStatus.ADDED, 'intentB not added');
    require(_hub.contexts(_intentIdB).amountAfterFees == _amountB, 'fees not accounted for');

    // Process queue
    _hub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    // Verify intentA is settled
    console.log('status A   :', uint8(_hub.contexts(_intentA).status));
    require(_hub.contexts(_intentA).status == IEverclear.IntentStatus.SETTLED, 'intentA not settled from B');

    // Verify intentB got rewards
    // TODO: calculate rewards properly
    require(_hub.contexts(_intentIdB).pendingRewards > 0, 'intentB did not get rewards');

    // // Advance to the next epoch
    // uint48 _initialEpoch = _hub.getCurrentEpoch();
    // uint48 _iterations;
    // while (_hub.getCurrentEpoch() == _initialEpoch) {
    //   vm.roll(_l1Block + _iterations);
    //   _iterations++;
    // }
    // require(_initialEpoch + 1 == _hub.getCurrentEpoch(), 'epoch did not advance by 1');

    // // Process queue
    // _hub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    // // Verify intentB is settled
    // require(_hub.contexts(_intentIdB).status == IEverclear.IntentStatus.SETTLED, 'intentB not settled');
  }
}
