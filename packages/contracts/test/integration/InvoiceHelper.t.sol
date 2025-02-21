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

  // Setup environment variables (from mainnet prod)
  EverclearHub _hub = EverclearHub(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
  HubGateway _hubGateway = HubGateway(payable(0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa));

  function _applyMaxDiscount(uint256 _toDiscount) private returns (uint256 _discounted) {
    _discounted = (_toDiscount * (DBPS_DENOMINATOR - MAX_FEE)) / DBPS_DENOMINATOR;
  }

  function _applyDiscount(uint256 _toDiscount, uint256 _fee) private returns (uint256 _discounted) {
    _discounted = (_toDiscount * (DBPS_DENOMINATOR - _fee)) / DBPS_DENOMINATOR;
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

  /**
   * @notice Calculates the amount in, given some target amount after fees
   * @param _amountAfterFees The target amount post fees
   * @param _tickerHash The ticker hash for the fee config
   */
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

  /**
   * Calculates all of the deposits that _could_ be applied to invoices that have
   * not yet been tabulated
   * @param _tickerHash The ticker for the deposits to sum
   * @param _domain The domain of the unprocessed deposits
   */
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

  /**
   * Returns a message to be receivedo on the hub with a single intent to be used to purchase
   * some invoice.
   * @param _origin Origin of the intent
   * @param _amount Amount of the intent before fees (i.e. amount to land on hub)
   * @param _inputAsset Asset for the intent
   * @param _tickerHash Ticker for the intent
   * @return _intentBatch The batch (n=1) of intents
   * @return _intentId The identifier of the intent in the batch
   */
  function _constructIntentBatch(
    uint32 _origin,
    uint32 _destination,
    uint256 _amount,
    bytes32 _inputAsset,
    bytes32 _tickerHash
  ) private returns (IEverclear.Intent[] memory _intentBatch, bytes32 _intentId) {
    // Format intent batch with updated amount
    uint32[] memory _destinations;
    if (_destination != 0) {
      _destinations = new uint32[](1);
      _destinations[0] = _destination;
    } else {
      _destinations = new uint32[](9);
      _destinations[0] = uint32(10);
      _destinations[1] = uint32(56);
      _destinations[2] = uint32(8453);
      _destinations[3] = uint32(42161);
      _destinations[4] = uint32(48900);
      _destinations[5] = uint32(59144);
      _destinations[6] = uint32(137);
      _destinations[7] = uint32(43114);
      _destinations[8] = uint32(81457);
    }

    // Assumes the intent is owned by mark
    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0x000000000000000000000000cfdfad7450a98654b1b874f89c1f6634a81833bf,
      receiver: 0x000000000000000000000000cfdfad7450a98654b1b874f89c1f6634a81833bf,
      inputAsset: _inputAsset,
      outputAsset: 0x0000000000000000000000000000000000000000000000000000000000000000,
      maxFee: 0,
      origin: _origin,
      nonce: 259,
      timestamp: 1738785671,
      ttl: 0,
      amount: _amount,
      destinations: _destinations,
      data: hex''
    });
    _intentId = keccak256(abi.encode(_intent));
    _intentBatch = new IEverclear.Intent[](1);
    _intentBatch[0] = _intent;
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
    bytes32 _tickerHash,
    uint256 _fee
  ) private returns (uint256 _deposit) {
    // Get the custodied assets
    uint256 _custodied = _hub.custodiedAssets(_hub.assetHash(_tickerHash, _settlementDomain));

    // console.log('required after fees/rewards', _invoiceAmount - _custodied);

    // Calculate the amount after fees
    _deposit = (DBPS_DENOMINATOR * (_invoiceAmount - _custodied)) / (DBPS_DENOMINATOR + _fee);
    _deposit += 1; // add this to account for Math.floor() of calculated value ^

    // console.log('c0', _custodied);
    uint256 rewards = (_deposit * _fee) / DBPS_DENOMINATOR;
    // console.log('[test] depositsAmount', toBeDiscounted);
    // console.log('[test] invoiceAmount', _invoiceAmount);
    // console.log('[test] liquidity', _custodied + toBeDiscounted);
    // console.log('[test] rewards', rewards);
    // console.log('[test] amount to settle', _invoiceAmount - rewards);
    // console.log('custodied + deposit    ', _custodied + _deposit);
    // console.log('amount to be discounted', toBeDiscounted);
    require(_custodied + _deposit >= _invoiceAmount - rewards, 'custodied + deposit < invoiceAmount');
  }

  function _receiveBatchIntentMessage(uint32 _messageOrigin, IEverclear.Intent[] memory _intentBatch) private {
    // Format message to receive with proper amount
    bytes memory _message = MessageLib.formatIntentMessageBatch(_intentBatch);
    // Receive the message on the hub
    vm.startPrank(address(_hubGateway.mailbox()));
    _hubGateway.handle(_messageOrigin, _hubGateway.chainGateways(_messageOrigin), _message);
    vm.stopPrank();
  }

  function _createADeposit(
    uint32 _originDomain,
    uint32 _settlementDomain,
    address _depositAsset,
    uint256 _depositAmount,
    bytes32 _tickerHash
  ) private returns (bytes32) {
    // Check the invoice queue length
    (, , , uint256 _length) = _hub.invoices(_tickerHash);

    // Create an intent
    (IEverclear.Intent[] memory _targetBatch, bytes32 _target) = _constructIntentBatch(
      _originDomain,
      _settlementDomain,
      _depositAmount,
      TypeCasts.toBytes32(_depositAsset),
      _tickerHash
    );

    // Receive message on hub
    _receiveBatchIntentMessage(_originDomain, _targetBatch);
    // Verify target deposit exists
    IEverclear.IntentStatus _status = _hub.contexts(_target).status;
    if (_length > 0) {
      require(_status == IEverclear.IntentStatus.ADDED, 'did not create deposit properly');
    } else {
      require(
        _status == IEverclear.IntentStatus.INVOICED || _status == IEverclear.IntentStatus.SETTLED,
        'did not create deposit properly'
      );
    }
    return _target;
  }

  function _createAnInvoice(
    uint32 _originDomain,
    uint32 _settlementDomain,
    address _invoiceAsset,
    uint256 _invoiceAmount,
    bytes32 _tickerHash
  ) private returns (bytes32 _invoiceId) {
    _invoiceId = _createADeposit(_originDomain, _settlementDomain, _invoiceAsset, _invoiceAmount, _tickerHash);
    // Process deposits
    _hub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);
    // Verify target invoice exists
    require(_hub.contexts(_invoiceId).status == IEverclear.IntentStatus.INVOICED, 'did not create invoice');
  }

  function _advanceEpochs(uint32 _toAdvance, uint256 _l1Block) private {
    // Advance to the next epoch
    uint48 _initialEpoch = _hub.getCurrentEpoch();
    uint48 _targetEpoch = _initialEpoch + _toAdvance;
    uint48 _iterations;
    while (_hub.getCurrentEpoch() != _targetEpoch) {
      vm.roll(_l1Block + _iterations);
      _iterations++;
    }
    require(_targetEpoch == _hub.getCurrentEpoch(), 'epoch did not advance properly');
  }

  // ================================================
  // ================ Test Cases ====================
  // ================================================

  /**
   * @notice IntentA already exists at the front of the queue, there is one deposit with insufficient
   * balance to settle the intent waiting to be processed (both are in the same epoch).
   *
   * In this case, both deposits should get rewards.
   */
  function test_intentPurchaseTwoDepositsSameEpoch() public {
    // Declare test constants
    // NOTE: at this point, there are no invoices or deposits in USDT
    uint256 _l1Block = 21890255;
    bytes32 _tickerHash = 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0;

    // bytes32 _intentA = 0xcb0bd6c7aaca084e84c9f1153bd801e1378fff99b5fa8f273076fa5195ec5242;
    uint256 _targetInvoiceAmount = 11320000000000000000000; // invoice amount (11320 USDT)
    uint32 _targetOriginDomain = 42161;
    address _targetOriginAsset = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    uint32 _targetSettlementDomain = 10;
    address _targetSettlementAsset = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58; // USDT on OP

    // Create fork
    {
      uint256 _l2Block = 796179;
      _setupFork(_l2Block, _l1Block, true);
    }

    // Verify queue status
    {
      (, , , uint256 _length) = _hub.invoices(_tickerHash);
      require(_length == 0, 'invoice in queue, bad test setup');
    }

    // Create a target invoice
    bytes32 _target = _createAnInvoice(
      _targetOriginDomain,
      _targetSettlementDomain,
      _targetOriginAsset,
      _targetInvoiceAmount,
      _tickerHash
    );

    // Advance multiple epochs to ensure there is max discount
    _advanceEpochs(20, _l1Block);

    // Create an intent with deposit < invoice amount
    uint256 _deposit0Amount = _calculateDepositAmount(
      _targetSettlementDomain,
      _targetInvoiceAmount,
      _tickerHash,
      MAX_FEE
    ) / 3;

    // Create a deposit
    bytes32 _deposit0 = _createADeposit(
      _targetSettlementDomain,
      _targetOriginDomain,
      _targetSettlementAsset,
      _deposit0Amount,
      _tickerHash
    );
    // Verify the deposit is added
    require(_hub.contexts(_deposit0).status == IEverclear.IntentStatus.ADDED, 'deposit0 not added');

    // After test set up, we need to calculate `_deposit1` amount needed to settle `_target`.
    // This calculation should be straightforward -- calculate the invoice amount using the same
    // helper as before. This should already accomodate for the larger custodied balance because
    // deposit0 has arrived on the hub.
    uint256 _deposit1Amount = _calculateDepositAmount(
      _targetSettlementDomain,
      _targetInvoiceAmount,
      _tickerHash,
      MAX_FEE
    );
    // Create a deposit
    bytes32 _deposit1 = _createADeposit(
      _targetSettlementDomain,
      _targetOriginDomain,
      _targetSettlementAsset,
      _deposit1Amount,
      _tickerHash
    );

    // Verify the deposit is added
    require(_hub.contexts(_deposit1).status == IEverclear.IntentStatus.ADDED, 'deposit not added');

    // Process the invoice queue
    _hub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    // Verify target is settled
    require(_hub.contexts(_target).status == IEverclear.IntentStatus.SETTLED, 'target not settled');

    // Verify that both deposits got rewards, and deposit1 rewards > deposit0 rewards
    uint256 _deposit0Rewards = _hub.contexts(_deposit0).pendingRewards;
    require(_deposit0Rewards > 0, 'deposit0 did not get rewards');
    require(_hub.contexts(_deposit1).pendingRewards > _deposit0Rewards, 'deposit1 did not get more rewards than 0');
  }

  /**
   * @notice IntentA already exists at the front of the queue, and there are no deposits to be
   * processed. Will calculate and verify the amountB to purchase a given invoice.
   */
  function test_intentPurchaseFirstInvoiceNoDeposits() public {
    // Declare test constants
    uint256 _l1Block = 21883550;
    uint256 _l2Block = 790616;
    bytes32 _tickerHash = 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0;
    bytes32 _intentA = 0xcb0bd6c7aaca084e84c9f1153bd801e1378fff99b5fa8f273076fa5195ec5242;
    uint256 _amountA = 8999820000000000000; // invoice amount
    uint32 _intentADestination = 324;
    address _intentBInputAsset = 0x493257fD37EDB34451f62EDf8D2a0C418852bA4C;

    // Create fork
    _setupFork(_l2Block, _l1Block, true);

    // Verify intentA exists
    require(_hub.contexts(_intentA).status == IEverclear.IntentStatus.INVOICED, 'intentA not invoiced');

    // Calculate the amount needed for an intent to exactly purchase `A`
    uint256 _amountB = _calculateDepositAmount(_intentADestination, _amountA, _tickerHash, MAX_FEE);
    // uint256 _amountB = (_amountA * DBPS_DENOMINATOR) / (DBPS_DENOMINATOR + MAX_FEE);
    console.log('amountB    :', _amountB, _applyFees(_amountB, _tickerHash));
    console.log('intentB amt:', _applyFees(_amountB, _tickerHash));

    // Create the intent to settle the invoice
    (IEverclear.Intent[] memory _intentBBatch, bytes32 _intentIdB) = _constructIntentBatch(
      _intentADestination,
      uint32(0),
      _amountB,
      TypeCasts.toBytes32(_intentBInputAsset),
      _tickerHash
    );
    console.log('intentB:');
    console.logBytes32(_intentIdB);

    _receiveBatchIntentMessage(_intentADestination, _intentBBatch);
    // NOTE: if intentB is _not_ enqueued (`receiveMessage` is called) in the same epoch that intentA is
    // settled in, it will not get any rewards.

    // Verify the deposit was added
    console.log('status B   :', uint8(_hub.contexts(_intentIdB).status));
    require(_hub.contexts(_intentIdB).status == IEverclear.IntentStatus.ADDED, 'intentB not added');

    // Process queue
    _hub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    // Verify intentA is settled
    console.log('status A   :', uint8(_hub.contexts(_intentA).status));
    require(_hub.contexts(_intentA).status == IEverclear.IntentStatus.SETTLED, 'intentA not settled from B');

    // Verify intentB got rewards
    // TODO: calculate rewards properly
    require(_hub.contexts(_intentIdB).pendingRewards > 0, 'intentB did not get rewards');

    // Verify intentB was settled (not important)
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
