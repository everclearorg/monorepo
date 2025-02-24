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
   * @dev Not used in intent amount calculations
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
   * Returns the deposit amount.
   * @dev This is derived from the overall formula:
   *    liquidity == invoice after discount
   *    custodied0 + depositRequired = invoiceAmount - rewards
   *    c0 + d = i - ((d * MAX_FEE) / DBPS))
   *    d + ((d * MAX_FEE) / DBPS)) = i - c0
   * where you are finding the deposit required under the assumptions:
   * - Your deposit will be added in the same epoch
   * - You are using the exact amount
   * - Your deposit amount is < invoice amount (i.e. purchasing a single discounted invoice)
   * @param _settlementDomain Domain you want to settle on
   * @param _invoiceAmount Amount of the invoice target you are trying to settle
   * @param _tickerHash Ticker of the invoice
   */
  function _calculateDepositAmount(
    uint32 _settlementDomain,
    uint256 _invoiceAmount,
    bytes32 _tickerHash,
    uint256 _fee,
    uint256 _custodied
  ) private returns (uint256 _deposit) {
    // console.log('');
    // console.log('trying to settle:', _invoiceAmount);

    // Get the existing deposits in the epoch
    uint48 _epoch = _hub.getCurrentEpoch();
    uint256 _deposited = _hub.depositsAvailableInEpoch(_epoch, _settlementDomain, _tickerHash);

    // Calculate the amount needed to close out invoice
    if (_deposited >= _invoiceAmount) {
      // Sufficient deposits already
      _deposit = 0;
      return _deposit;
    }

    uint256 _scaledDelta = DBPS_DENOMINATOR * (_invoiceAmount - _custodied);
    _deposit = (_scaledDelta - _fee * _deposited) / (DBPS_DENOMINATOR + _fee);
    _deposit += 1; // add this to account for Math.floor() of calculated value ^

    // console.log('c0', _custodied);
    uint256 rewards = (_deposit * _fee) / DBPS_DENOMINATOR;
    console.log('[test] invoiceAmount', _invoiceAmount);
    console.log('[test] liquidity', _custodied + _deposit);
    console.log('[test] custodied          ', _custodied);
    console.log('[test] amount to settle   ', _invoiceAmount - rewards);
    console.log('[test] custodied + deposit', _custodied + _deposit);
    // console.log('amount to be discounted', toBeDiscounted);
    require(_custodied + _deposit + _deposited >= _invoiceAmount - rewards, 'custodied + deposit < invoiceAmount');
  }

  // override with default initial custodied value
  function _calculateDepositAmount(
    uint32 _settlementDomain,
    uint256 _invoiceAmount,
    bytes32 _tickerHash,
    uint256 _fee
  ) private returns (uint256 _deposit) {
    // Get the custodied assets
    uint256 _custodied = _hub.custodiedAssets(_hub.assetHash(_tickerHash, _settlementDomain));
    // Call function
    _deposit = _calculateDepositAmount(_settlementDomain, _invoiceAmount, _tickerHash, _fee, _custodied);
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
    console.log('intent amount', _hub.contexts(_target).intent.amount);
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
    bytes32 _tickerHash,
    uint32 _epochsToAdvance,
    uint256 _l1Block
  ) private returns (bytes32 _invoiceId) {
    _invoiceId = _createADeposit(_originDomain, _settlementDomain, _invoiceAsset, _invoiceAmount, _tickerHash);
    if (_epochsToAdvance > 0) {
      _advanceEpochs(_epochsToAdvance, _l1Block);
    }
    // Process deposits
    _hub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);
    // Verify target invoice exists
    require(_hub.contexts(_invoiceId).status == IEverclear.IntentStatus.INVOICED, 'did not create invoice');
  }

  // override ^^
  function _createAnInvoice(
    uint32 _originDomain,
    uint32 _settlementDomain,
    address _invoiceAsset,
    uint256 _invoiceAmount,
    bytes32 _tickerHash
  ) private returns (bytes32 _invoiceId) {
    _invoiceId = _createAnInvoice(_originDomain, _settlementDomain, _invoiceAsset, _invoiceAmount, _tickerHash);
  }

  function _createInvoices(
    uint32 _originDomain,
    uint32 _settlementDomain,
    address _invoiceAsset,
    bytes32 _tickerHash,
    uint256 _l1Block,
    uint256[] memory _invoiceAmounts
  ) private returns (bytes32[] memory _invoiceIds) {
    uint256 _len = _invoiceAmounts.length;
    _invoiceIds = new bytes32[](_len);
    for (uint i; i < _len; i++) {
      _invoiceIds[i] = _createAnInvoice(
        _originDomain,
        _settlementDomain,
        _invoiceAsset,
        _applyFees(_invoiceAmounts[i], _tickerHash),
        _tickerHash,
        1,
        _l1Block
      );
    }
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

  /**
   * @notice Calculate the exact deposit amount needed to settle two invoices
   * @param _settlementDomain The domain to settle on
   * @param _tickerHash The ticker hash of the invoices
   * @return _depositAmount The exact deposit amount needed
   */
  function _calculateExactDepositForMultipleInvoices(
    uint32 _settlementDomain,
    bytes32 _tickerHash,
    uint256[] memory _invoiceAmounts,
    uint256[] memory _fees
  ) public returns (uint256 _depositAmount) {
    // Get initial custodied balance
    uint256 _custodied = _hub.custodiedAssets(_hub.assetHash(_tickerHash, _settlementDomain));

    // Calculate all n-1 settlements
    uint256 _settlementsAmount = 0;
    uint256 _len = _invoiceAmounts.length;
    for (uint i; i < _len - 1; i++) {
      _settlementsAmount += _invoiceAmounts[i] - ((_invoiceAmounts[i] * _fees[i]) / DBPS_DENOMINATOR);
    }

    // Calculate deposit amount required
    // _depositAmount = _totalSettlement + 1 - _custodied; //_custodied > _totalSettlement ? 0 : _totalSettlement - _custodied;
    _depositAmount =
      _settlementsAmount +
      ((DBPS_DENOMINATOR * (_invoiceAmounts[_len - 1] - _custodied)) / (DBPS_DENOMINATOR + _fees[_len - 1]));
    _depositAmount += 1;
    // {
    //   console.log('[t] depositAmount       :', _depositAmount);
    //   console.log('[t] s1                  :', _settlement1);
    //   console.log('[t] intermediary deposit:', _depositAmount - _settlement1);
    //   console.log('[t] s2                  :', _totalSettlement - _settlement1);
    //   console.log('[t] depositInEpoch      :', _depositAmount);
    //   console.log('[t] _custodied          :', _custodied);
    // }
  }

  // ================================================
  // ================ Test Cases ====================
  // ================================================

  /**
   * @notice This tests purchasing multiple intents with a single deposit
   */
  function test_singleDepositMultipleIntentPurchases() public {
    // Declare test constants
    // NOTE: at this point, there are no invoices or deposits in USDT
    uint256 _l1Block = 21890255;
    bytes32 _tickerHash = 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0;

    uint256[] memory _targetInvoiceAmounts = new uint256[](2);
    {
      _targetInvoiceAmounts[0] = 11320000000000000000000; // 11320
      _targetInvoiceAmounts[1] = 12323000000000000000000; // 12323
    }
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

    bytes32[] memory _targets = _createInvoices(
      _targetOriginDomain,
      _targetSettlementDomain,
      _targetOriginAsset,
      _tickerHash,
      _l1Block,
      _targetInvoiceAmounts
    );

    _advanceEpochs(20, _l1Block);

    // Calculate the deposit
    console.log('====== calculating deposit ======');

    uint256[] memory _fees = new uint256[](2);
    _fees[0] = MAX_FEE;
    _fees[1] = MAX_FEE;
    uint256 _depositAmount = _calculateExactDepositForMultipleInvoices(
      _targetSettlementDomain,
      _tickerHash,
      _targetInvoiceAmounts,
      _fees
    );

    // Create a deposit
    bytes32 _deposit = _createADeposit(
      _targetSettlementDomain,
      _targetOriginDomain,
      _targetSettlementAsset,
      _depositAmount,
      _tickerHash
    );

    // Verify the deposit is added
    require(_hub.contexts(_deposit).status == IEverclear.IntentStatus.ADDED, 'deposit not added');

    // Process the invoice queue
    console.log('====== settling invoices ======');
    _hub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);
    _hub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    // Verify targets are settled
    require(_hub.contexts(_targets[0]).status == IEverclear.IntentStatus.SETTLED, 'target[0] not settled');
    require(_hub.contexts(_targets[1]).status == IEverclear.IntentStatus.SETTLED, 'target[1] not settled');

    // Verify that the deposit got rewards to settle invoice
    require(_hub.contexts(_deposit).pendingRewards > 0, 'deposit did not get rewards');
  }

  /**
   * @notice This tests purchasing some intent with a discount < max discount
   */
  function test_intentPurchaseNotAtMax() public {
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
      _applyFees(_targetInvoiceAmount, _tickerHash),
      _tickerHash
    );

    // Advance only a few epochs, expected discount is less than min
    _advanceEpochs(3, _l1Block);

    // Calculate the expected discount
    (, uint24 _discountPerEpoch, ) = _hub.tokenConfigs(_tickerHash);
    uint256 _discount = 3 * _discountPerEpoch;

    // Calculate the deposit
    uint256 _depositAmount = _calculateDepositAmount(
      _targetSettlementDomain,
      _targetInvoiceAmount,
      _tickerHash,
      _discount
    );
    // Create a deposit
    bytes32 _deposit = _createADeposit(
      _targetSettlementDomain,
      _targetOriginDomain,
      _targetSettlementAsset,
      _depositAmount,
      _tickerHash
    );

    // Verify the deposit is added
    require(_hub.contexts(_deposit).status == IEverclear.IntentStatus.ADDED, 'deposit not added');

    // Process the invoice queue
    _hub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    // Verify target is settled
    require(_hub.contexts(_target).status == IEverclear.IntentStatus.SETTLED, 'target not settled');

    // Verify that the deposit got rewards to settle invoice
    require(_hub.contexts(_deposit).pendingRewards > 0, 'deposit did not get rewards');
  }

  /**
   * @notice In this test, we have a pending deposit that is from a previous epoch that has not been
   * processed. This means the previous deposit will _not_ appear in the custodied balance, and will
   * _not_ get rewards because the amount is insufficient to fully settle the invoice.
   *
   * This simulates the deposit calculation if lighthouse has been down
   */
  function test_intentPurchaseUnprocessedEpochs() public {
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
      _applyFees(_targetInvoiceAmount, _tickerHash),
      _tickerHash
    );

    // Create a stale deposit with insufficient funds to settle target
    uint256 _fullSettlement = _calculateDepositAmount(_targetSettlementDomain, _targetInvoiceAmount, _tickerHash, 0);
    bytes32 _deposit0 = _createADeposit(
      _targetSettlementDomain,
      _targetOriginDomain,
      _targetSettlementAsset,
      _fullSettlement / 3,
      _tickerHash
    );

    // Advance multiple epochs to ensure there is max discount on target, dont process deposit0
    _advanceEpochs(20, _l1Block);

    // Verify the deposit is added
    require(_hub.contexts(_deposit0).status == IEverclear.IntentStatus.ADDED, 'deposit not added');

    // Calculate amount to purchase target
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

    // Verify that deposit1 got rewards, and deposit0 did not
    require(_hub.contexts(_deposit0).pendingRewards == 0, 'deposit0 did get rewards');
    require(_hub.contexts(_deposit1).pendingRewards > 0, 'deposit1 did not get rewards');
  }

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
      _applyFees(_targetInvoiceAmount, _tickerHash),
      _tickerHash
    );

    // Advance multiple epochs to ensure there is max discount
    _advanceEpochs(20, _l1Block);

    // Create an intent with deposit < invoice amount
    uint256 _fullSettlement = _calculateDepositAmount(
      _targetSettlementDomain,
      _targetInvoiceAmount,
      _tickerHash,
      MAX_FEE
    );

    // Create a deposit
    bytes32 _deposit0 = _createADeposit(
      _targetSettlementDomain,
      _targetOriginDomain,
      _targetSettlementAsset,
      _fullSettlement / 3,
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

    {
      uint256 _rewards = ((_deposit1Amount + (_fullSettlement / 3)) * MAX_FEE) / DBPS_DENOMINATOR;
      console.log('');
      console.log('[test] rewards            ', _rewards);
      console.log('[test] amount to settle   ', _targetInvoiceAmount - _rewards);
      console.log('[test] depositsAmount     ', _deposit1Amount + (_fullSettlement / 3));
    }
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

    // Calculate the amount needed for an intent3 to exactly purchase `A`
    uint256 _amountB = _calculateDepositAmount(_intentADestination, _amountA, _tickerHash, MAX_FEE);
    // uint256 _amountB = (_amountA * DBPS_DENOMINATOR) / (DBPS_DENOMINATOR + MAX_FEE);
    console.log('amountB    :', _amountB);

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
