// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { console2 as console } from 'forge-std/console2.sol';
import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';

import { MessageLib } from 'contracts/common/MessageLib.sol';
import { TypeCasts } from 'contracts/common/TypeCasts.sol';

import { IEverclear } from 'interfaces/common/IEverclear.sol';
import { EverclearHub } from 'contracts/hub/EverclearHub.sol';
import { IHubStorage } from 'interfaces/hub/IHubStorage.sol';
import { EverclearSpoke, IERC20 } from 'contracts/intent/EverclearSpoke.sol';
import { HubGateway } from 'contracts/hub/HubGateway.sol';
import { Settler } from 'contracts/hub/modules/Settler.sol';
import { HubMessageReceiver } from 'contracts/hub/modules/HubMessageReceiver.sol';
import { TestnetProductionEnvironment } from '../../script/TestnetProduction.sol';
import { TestnetStagingEnvironment } from '../../script/TestnetStaging.sol';
import { TestExtended } from '../utils/TestExtended.sol';

/**
 * @notice Designed to help find the correct amount to purchase invoices with.
 */
contract InvoiceHelper is TestExtended {
  struct TestConfig {
    uint256 l1Block;
    uint256 l2Block;
    bytes32 tickerHash;
    uint32 targetOriginDomain;
    address targetOriginAsset;
    uint32 targetSettlementDomain;
    address targetSettlementAsset;
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
    address _settlerAddr = _hub.modules(keccak256('settlement_module'));
    vm.etch(_settlerAddr, address(_settler).code);

    HubMessageReceiver _receiver = new HubMessageReceiver();
    address _receiverAddr = _hub.modules(keccak256('message_receiver_module'));
    vm.etch(_receiverAddr, address(_receiver).code);
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
    console.log('[test] liquidity (custodied + deposit)', _custodied + _deposit);
    console.log('[test] rewards', rewards);
    console.log('[test] amount to settle (invoice - rewards)   ', _invoiceAmount - rewards);
    console.log('[test] custodied          ', _custodied);
    console.log('[test] deposit           ', _deposit);
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
  ) private returns (bytes32 depositId) {
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
    console.log("    Intent status after receiving on hub:", uint8(_hub.contexts(_target).status));
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
    console.log("    Intent status after processing:", uint8(_hub.contexts(_invoiceId).status));
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
   * @notice Calculate the exact deposit amount needed to settle multiple invoices
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
    // Initialize values
    uint256 _len = _invoiceAmounts.length;
    
    // Calculate total amount needed to settle all invoices
    uint256 _totalNeededAmount = 0;
    
    // Add up all invoice amounts
    for (uint i = 0; i < _len; i++) {
      _totalNeededAmount += _invoiceAmounts[i];
      console.log('  [test] invoice', i, 'amount', _invoiceAmounts[i]);
    }
    
    console.log('  [test] total invoice amount', _totalNeededAmount);
    
    // Get the custodied amount
    uint256 _custodied = _hub.custodiedAssets(_hub.assetHash(_tickerHash, _settlementDomain));
    console.log('  [test] custodied amount', _custodied);
    
    // Simplifying, assume all fees are the same (usually MAX in our tests)
    uint256 _fee = _fees[_len - 1];
    
    _depositAmount = _calculateDepositAmount(
      _settlementDomain,
      _totalNeededAmount,
      _tickerHash,
      _fee,
      _custodied
    );
    
    console.log('  [test] calculated deposit amount', _depositAmount);
    
    return _depositAmount;
  }

  /**
   * Helper function to create invoices
   * @param _originDomain The origin domain of the invoices
   * @param _destinationDomain The destination domain of the invoices
   * @param _originAsset The asset address at the origin
   * @param _tickerHash The ticker hash for the invoices
   * @param _l1Block The L1 block number for epoch advancement
   * @param _amounts The amounts for each invoice
   * @param _advanceEpochsPerInvoice Number of epochs to advance after each invoice creation
   * @return _invoiceIds Array of created invoice IDs
   */
  function _createInvoices(
    uint32 _originDomain,
    uint32 _destinationDomain,
    address _originAsset,
    bytes32 _tickerHash,
    uint256 _l1Block,
    uint256[] memory _amounts,
    uint32 _advanceEpochsPerInvoice
  ) private returns (bytes32[] memory _invoiceIds) {
    _invoiceIds = new bytes32[](_amounts.length);
    for (uint i = 0; i < _amounts.length; i++) {
      _invoiceIds[i] = _createAnInvoice(
        _originDomain,
        _destinationDomain,
        _originAsset,
        _applyFees(_amounts[i], _tickerHash),
        _tickerHash,
        _advanceEpochsPerInvoice,
        _l1Block
      );
    }
  }

  /**
   * Helper function to verify settlement of invoices
   * @param _tickerHash The ticker hash
   * @param _invoiceIds Array of invoice IDs to verify settlement status
   * @param _expectedStatuses Array of expected statuses for each invoice ID
   * @param _depositId The ID of the deposit to verify rewards for
   */
  function _verifySettlement(
    bytes32 _tickerHash,
    bytes32[] memory _invoiceIds,
    IEverclear.IntentStatus[] memory _expectedStatuses,
    bytes32 _depositId
  ) private {
    // Process the invoice queue
    console.log('====== settling invoices ======');
    _hub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    // Verify invoice statuses
    for (uint i = 0; i < _invoiceIds.length; i++) {
      console.log("Intent status at verification:", uint8(_hub.contexts(_invoiceIds[i]).status));
      require(
        _hub.contexts(_invoiceIds[i]).status == _expectedStatuses[i],
        string.concat('invoice status mismatch at index ', Strings.toString(i))
      );
    }
    
    // Verify that the deposit got rewards to settle invoice
    require(_hub.contexts(_depositId).pendingRewards > 0, 'deposit did not get rewards');
  }

  /**
   * @notice This tests purchasing a target invoice where non-targeted preceding invoices must
   * be part of the total purchase amount due to the FIFO ordering.
   * @dev Queue state should be:
   *      A
   *      B
   *      C
   *      D
   * where A, C <= D, and B > D. and you only want to purchase D
   * but due to the ordering B also must be purchased.
   */
  function test_purchaseNonHeadInvoiceMustPurchaseAllPreceding() public {
    // NOTE: at this point, there are no invoices or deposits in USDT
    TestConfig memory cfg = TestConfig({
      l1Block: 21890255,
      l2Block: 796179,
      tickerHash: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0,
      targetOriginDomain: 42161, // Arb
      targetOriginAsset: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, // USDT on Arb
      targetSettlementDomain: 10, // OP
      targetSettlementAsset: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58 // USDT on OP
    });

    {
      _setupFork(cfg.l2Block, cfg.l1Block, true);

      // Verify initial queue status
      (, , , uint256 _length) = _hub.invoices(cfg.tickerHash);
      console.log('_length', _length);
      require(_length == 0, 'invoice in queue, bad test setup');
    }
    
    uint256 _initialCustodied = _hub.custodiedAssets(_hub.assetHash(cfg.tickerHash, cfg.targetSettlementDomain));
    console.log('[test] initial custodied', _initialCustodied);

    // Create all invoices
    uint256[] memory _invoiceQueueAmounts = new uint256[](4);
    {
      _invoiceQueueAmounts[0] = 5000000000000000000000;   // A: 5000
      _invoiceQueueAmounts[1] = 9500000000000000000000;   // B: 9500
      _invoiceQueueAmounts[2] = 5500000000000000000000;   // C: 5500
      _invoiceQueueAmounts[3] = 9000000000000000000000;   // D: 9000
    }
    bytes32[] memory _invoiceQueue = _createInvoices(
      cfg.targetOriginDomain,
      cfg.targetSettlementDomain,
      cfg.targetOriginAsset,
      cfg.tickerHash,
      cfg.l1Block,
      _invoiceQueueAmounts
    );

    // Define the target invoice(s)
    // Note: we need to add all ABC in order to purchase D
    bytes32[] memory _targetInvoices = new bytes32[](4);
    _targetInvoices[0] = _invoiceQueue[0]; // Target invoice A
    _targetInvoices[1] = _invoiceQueue[1]; // Target invoice B
    _targetInvoices[2] = _invoiceQueue[2]; // Target invoice C
    _targetInvoices[3] = _invoiceQueue[3]; // Target invoice D
    uint256[] memory _targetInvoiceAmounts = new uint256[](4);
    {
      _targetInvoiceAmounts[0] = 5000000000000000000000; // A
      _targetInvoiceAmounts[1] = 9500000000000000000000; // B
      _targetInvoiceAmounts[2] = 5500000000000000000000; // C
      _targetInvoiceAmounts[3] = 9000000000000000000000; // D
    }

    // Take to max discount
    _advanceEpochs(20, cfg.l1Block);

    // Calculate deposit amount and create deposit
    bytes32 _depositId;
    {
      uint256[] memory _fees = new uint256[](4);
      _fees[0] = MAX_FEE;
      _fees[1] = MAX_FEE;
      _fees[2] = MAX_FEE;
      _fees[3] = MAX_FEE;

      uint256 _depositAmount = _calculateExactDepositForMultipleInvoices(
        cfg.targetSettlementDomain,
        cfg.tickerHash,
        _targetInvoiceAmounts,
        _fees
      );
      console.log('calculated purchase amount:', _depositAmount);

      _depositId = _createADeposit(
        cfg.targetSettlementDomain,
        cfg.targetOriginDomain,
        cfg.targetSettlementAsset,
        _depositAmount,
        cfg.tickerHash
      );
    }

    // Verify settlement
    IEverclear.IntentStatus[] memory _expectedStatuses = new IEverclear.IntentStatus[](4);
    _expectedStatuses[0] = IEverclear.IntentStatus.SETTLED;
    _expectedStatuses[1] = IEverclear.IntentStatus.SETTLED;
    _expectedStatuses[2] = IEverclear.IntentStatus.SETTLED;
    _expectedStatuses[3] = IEverclear.IntentStatus.SETTLED;

    _verifySettlement(
      cfg.tickerHash,
      _invoiceQueue,
      _expectedStatuses,
      _depositId
    );
  }

  /**
   * @notice This tests purchasing a target invoice where non-targeted preceding invoices must
   * be part of the total purchase amount where preceding <= target.
   * @dev Queue state should be:
   *      A
   *      B
   *      C
   *      D
   * where A,B <= D and C > D and you only want to purchase D.
   */
  function test_purchaseNonHeadInvoiceMustPurchasePreceding() public {
    // NOTE: at this point, there are no invoices or deposits in USDT
    TestConfig memory cfg = TestConfig({
      l1Block: 21890255,
      l2Block: 796179,
      tickerHash: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0,
      targetOriginDomain: 42161, // Arb
      targetOriginAsset: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, // USDT on Arb
      targetSettlementDomain: 10, // OP
      targetSettlementAsset: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58 // USDT on OP
    });

    {
      _setupFork(cfg.l2Block, cfg.l1Block, true);

      // Verify initial queue status
      (, , , uint256 _length) = _hub.invoices(cfg.tickerHash);
      console.log('_length', _length);
      require(_length == 0, 'invoice in queue, bad test setup');
    }
    
    uint256 _initialCustodied = _hub.custodiedAssets(_hub.assetHash(cfg.tickerHash, cfg.targetSettlementDomain));
    console.log('[test] initial custodied', _initialCustodied);

    // Create all invoices
    uint256[] memory _invoiceQueueAmounts = new uint256[](4);
    {
      _invoiceQueueAmounts[0] = 4000000000000000000000; // A: 4000
      _invoiceQueueAmounts[1] = 8000000000000000000000; // B: 8000
      _invoiceQueueAmounts[2] = 9500000000000000000000; // C: 9500
      _invoiceQueueAmounts[3] = 9000000000000000000000; // D: 9000
    }
    bytes32[] memory _invoiceQueue = _createInvoices(
      cfg.targetOriginDomain,
      cfg.targetSettlementDomain,
      cfg.targetOriginAsset,
      cfg.tickerHash,
      cfg.l1Block,
      _invoiceQueueAmounts
    );

    // Define the target invoice(s)
    // Note: we need to add A and B because they need to be purchased first
    bytes32[] memory _targetInvoices = new bytes32[](3);
    _targetInvoices[0] = _invoiceQueue[0]; // Target invoice A
    _targetInvoices[1] = _invoiceQueue[1]; // Target invoice B
    _targetInvoices[2] = _invoiceQueue[3]; // Target invoice D
    uint256[] memory _targetInvoiceAmounts = new uint256[](3);
    {
      _targetInvoiceAmounts[0] = 4000000000000000000000; // A
      _targetInvoiceAmounts[1] = 8000000000000000000000; // B
      _targetInvoiceAmounts[2] = 9000000000000000000000; // D
    }

    // Take to max discount
    _advanceEpochs(20, cfg.l1Block);

    // Calculate deposit amount and create deposit
    bytes32 _depositId;
    {
      uint256[] memory _fees = new uint256[](3);
      _fees[0] = MAX_FEE;
      _fees[1] = MAX_FEE;
      _fees[2] = MAX_FEE;
      
      uint256 _depositAmount = _calculateExactDepositForMultipleInvoices(
        cfg.targetSettlementDomain,
        cfg.tickerHash,
        _targetInvoiceAmounts,
        _fees
      );
      console.log('calculated purchase amount:', _depositAmount);

      _depositId = _createADeposit(
        cfg.targetSettlementDomain,
        cfg.targetOriginDomain,
        cfg.targetSettlementAsset,
        _depositAmount,
        cfg.tickerHash
      );
    }

    // Verify settlement
    IEverclear.IntentStatus[] memory _expectedStatuses = new IEverclear.IntentStatus[](4);
    _expectedStatuses[0] = IEverclear.IntentStatus.SETTLED;
    _expectedStatuses[1] = IEverclear.IntentStatus.SETTLED;
    _expectedStatuses[2] = IEverclear.IntentStatus.INVOICED;
    _expectedStatuses[3] = IEverclear.IntentStatus.SETTLED;

    _verifySettlement(
      cfg.tickerHash,
      _invoiceQueue,
      _expectedStatuses,
      _depositId
    );
  }

  /**
   * @notice This tests an observed mark purchase that undershot the invoice target:
   * invoiceA: https://explorer.everclear.org/intents/0x4813e4fb49399aee1253c83682b6a2e7b863ef15eb9c63d06f48e40caad5ce4a
   * invoiceB (target): https://explorer.everclear.org/intents/0x846935f8559d1487cf595d02540d762d74e6b19171a989505412c89b7b1192e6
   * attempted purchase: https://explorer.everclear.org/intents/0xabc7d25f17de8fb9ea50ee4eb35d75cf6d01c3043b972802b3a5780e247a4d65
   * @dev Runs test at block with max discount on fee to compare to API
   */
  function test_expectedAmount() public {
    TestConfig memory cfg = TestConfig({
      l1Block: 21918628,
      l2Block: 819570,
      tickerHash: 0xd6aca1be9729c13d677335161321649cccae6a591554772516700f986f942eaa,
      targetOriginDomain: 59144, // Linea
      targetOriginAsset: 0x176211869cA2b568f2A7D4EE941E073a821EE1ff, // USDC on Linea
      targetSettlementDomain: 534352, // Scroll
      targetSettlementAsset: 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4 // USDC on Scroll
    });

    // Create fork
    {
      _setupFork(cfg.l2Block, cfg.l1Block, true);

      // Verify queue status
      (, , , uint256 _length) = _hub.invoices(cfg.tickerHash);
      console.log('_length', _length);
      require(_length >= 2, 'invoices not in queue, bad test setup');
    }

    uint256[] memory _invoiceQueueAmounts = new uint256[](2);
    _invoiceQueueAmounts[0] = 9999935289356868044962;
    _invoiceQueueAmounts[1] = 204995900000000000000;

    bytes32[] memory _invoiceQueue = new bytes32[](2);
    _invoiceQueue[0] = 0x4813e4fb49399aee1253c83682b6a2e7b863ef15eb9c63d06f48e40caad5ce4a;
    _invoiceQueue[1] = 0x846935f8559d1487cf595d02540d762d74e6b19171a989505412c89b7b1192e6;

    uint256[] memory _fees = new uint256[](1);
    _fees[0] = MAX_FEE; // update this if blocks are updated

    uint256[] memory _targetInvoiceAmounts = new uint256[](1);
    _targetInvoiceAmounts[0] = _invoiceQueueAmounts[1];
    uint256 _depositAmount = _calculateExactDepositForMultipleInvoices(
      cfg.targetSettlementDomain,
      cfg.tickerHash,
      _targetInvoiceAmounts,
      _fees
    );
    console.log('calculated purchase amount:', _depositAmount); // 2047404059810832

    // Create deposit
    bytes32 _depositId = _createADeposit(
      cfg.targetSettlementDomain,
      cfg.targetOriginDomain,
      cfg.targetSettlementAsset,
      _depositAmount,
      cfg.tickerHash
    );

    IEverclear.IntentStatus[] memory _expectedStatuses = new IEverclear.IntentStatus[](2);
    _expectedStatuses[0] = IEverclear.IntentStatus.INVOICED;
    _expectedStatuses[1] = IEverclear.IntentStatus.SETTLED;

    // Verify settlement
    _verifySettlement(
      cfg.tickerHash,
      _invoiceQueue,
      _expectedStatuses,
      _depositId
    );
  }

  /**
   * @notice This tests purchasing an invoice that is not at the front of the queue.
   * @dev Queue state should be:
   *      A
   *      B
   *      C
   * where (amountB + amountC) < amountA, and you only want to purchase B, C.
   */
  function test_purchaseNonHeadInvoices() public {
    // Declare test constants
    // NOTE: at this point, there are no invoices or deposits in USDT
    TestConfig memory cfg = TestConfig({
      l1Block: 21890255,
      l2Block: 796179,
      tickerHash: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0,
      targetOriginDomain: 42161, // Arb 
      targetOriginAsset: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, // USDT on Arb
      targetSettlementDomain: 10, // OP
      targetSettlementAsset: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58 // USDT on OP
    });

    uint256[] memory _targetInvoiceAmounts = new uint256[](3);
    {
      _targetInvoiceAmounts[0] = 12323000000000000000000; // 12323
      _targetInvoiceAmounts[1] = 11320000000000000000000; // 11320 -> target
      _targetInvoiceAmounts[2] = 320000000000000000000; // 320 -> target
    }

    // Create fork
    {
      _setupFork(cfg.l2Block, cfg.l1Block, true);

      // Verify queue status
      (, , , uint256 _length) = _hub.invoices(cfg.tickerHash);
      require(_length == 0, 'invoice in queue, bad test setup');
    }

    // Create invoices
    bytes32[] memory _targets = _createInvoices(
      cfg.targetOriginDomain,
      cfg.targetSettlementDomain,
      cfg.targetOriginAsset,
      cfg.tickerHash,
      cfg.l1Block,
      _targetInvoiceAmounts
    );

    // Take to max discount
    _advanceEpochs(20, cfg.l1Block);

    bytes32 _deposit;
    {
      uint256[] memory _fees = new uint256[](2);
      _fees[0] = MAX_FEE;
      _fees[1] = MAX_FEE;
      uint256[] memory _targetAmounts = new uint256[](2);
      _targetAmounts[0] = _targetInvoiceAmounts[1];
      _targetAmounts[1] = _targetInvoiceAmounts[2];
      uint256 _depositAmount = _calculateExactDepositForMultipleInvoices(
        cfg.targetSettlementDomain,
        cfg.tickerHash,
        _targetAmounts,
        _fees
      );

      // Create a deposit
      _deposit = _createADeposit(
        cfg.targetSettlementDomain,
        cfg.targetOriginDomain,
        cfg.targetSettlementAsset,
        _depositAmount,
        cfg.tickerHash
      );
    }

    bytes32[] memory _invoicesToVerify = new bytes32[](2);
    _invoicesToVerify[0] = _targets[0];
    _invoicesToVerify[1] = _targets[1];
    
    IEverclear.IntentStatus[] memory _expectedStatuses = new IEverclear.IntentStatus[](2);
    _expectedStatuses[0] = IEverclear.IntentStatus.INVOICED;
    _expectedStatuses[1] = IEverclear.IntentStatus.SETTLED;

    // Verify settlement
    _verifySettlement(
      cfg.tickerHash,
      _invoicesToVerify,
      _expectedStatuses,
      _deposit
    );
  }

  /**
   * @notice This tests purchasing multiple intents with a single deposit
   */
  function test_singleDepositMultipleIntentPurchases() public {
    // Declare test constants
    // NOTE: at this point, there are no invoices or deposits in USDT
    TestConfig memory cfg = TestConfig({
      l1Block: 21890255,
      l2Block: 796179,
      tickerHash: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0,
      targetOriginDomain: 42161,
      targetOriginAsset: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9,
      targetSettlementDomain: 10,
      targetSettlementAsset: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58 // USDT on OP
    });

    uint256[] memory _targetInvoiceAmounts = new uint256[](3);
    {
      _targetInvoiceAmounts[0] = 11320000000000000000000; // 11320
      _targetInvoiceAmounts[1] = 12323000000000000000000; // 12323
      _targetInvoiceAmounts[2] = 12321000000000000000000; // 12321
    }

    // Create fork
    {
      _setupFork(cfg.l2Block, cfg.l1Block, true);

      // Verify queue status
      (, , , uint256 _length) = _hub.invoices(cfg.tickerHash);
      require(_length == 0, 'invoice in queue, bad test setup');
    }

    // Create invoices
    bytes32[] memory _targets = _createInvoices(
      cfg.targetOriginDomain,
      cfg.targetSettlementDomain,
      cfg.targetOriginAsset,
      cfg.tickerHash,
      cfg.l1Block,
      _targetInvoiceAmounts
    );

    _advanceEpochs(20, cfg.l1Block);

    // Calculate the deposit
    console.log('====== calculating deposit ======');

    uint256[] memory _fees = new uint256[](3);
    _fees[0] = MAX_FEE;
    _fees[1] = MAX_FEE;
    _fees[2] = MAX_FEE;
    uint256 _depositAmount = _calculateExactDepositForMultipleInvoices(
      cfg.targetSettlementDomain,
      cfg.tickerHash,
      _targetInvoiceAmounts,
      _fees
    );

    // Set up expected statuses for verification
    IEverclear.IntentStatus[] memory _expectedStatuses = new IEverclear.IntentStatus[](3);
    _expectedStatuses[0] = IEverclear.IntentStatus.SETTLED;
    _expectedStatuses[1] = IEverclear.IntentStatus.SETTLED;
    _expectedStatuses[2] = IEverclear.IntentStatus.SETTLED;

    // Create deposit
    bytes32 _deposit = _createADeposit(
      cfg.targetSettlementDomain,
      cfg.targetOriginDomain,
      cfg.targetSettlementAsset,
      _depositAmount,
      cfg.tickerHash
    );

    // Verify settlement
    _verifySettlement(
      cfg.tickerHash,
      _targets,
      _expectedStatuses,
      _deposit
    );
  }

  // /**
  //  * @notice This tests purchasing some intent with a discount < max discount
  //  */
  function test_intentPurchaseNotAtMax() public {
    // Declare test constants
    // NOTE: at this point, there are no invoices or deposits in USDT
    TestConfig memory cfg = TestConfig({
      l1Block: 21890255,
      l2Block: 796179,
      tickerHash: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0,
      targetOriginDomain: 42161, // Arb
      targetOriginAsset: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, // USDT on Arb
      targetSettlementDomain: 10, // OP
      targetSettlementAsset: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58 // USDT on OP
    });

    // bytes32 _intentA = 0xcb0bd6c7aaca084e84c9f1153bd801e1378fff99b5fa8f273076fa5195ec5242;
    uint256[] memory _invoiceAmounts = new uint256[](1);
    {
      _invoiceAmounts[0] = 11320000000000000000000; // 11320
    }
  
    // Create fork
    {
      _setupFork(cfg.l2Block, cfg.l1Block, true);

      // Verify queue status
      (, , , uint256 _length) = _hub.invoices(cfg.tickerHash);
      require(_length == 0, 'invoice in queue, bad test setup');
    }

    bytes32[] memory _invoiceQueue = _createInvoices(
      cfg.targetOriginDomain,
      cfg.targetSettlementDomain,
      cfg.targetOriginAsset,
      cfg.tickerHash,
      cfg.l1Block,
      _invoiceAmounts
    );

    // Advance only a few epochs, expected discount is less than min
    _advanceEpochs(3, cfg.l1Block);

    // Calculate the expected discount
    (, uint24 _discountPerEpoch, ) = _hub.tokenConfigs(cfg.tickerHash);
    uint256 _discount = 3 * _discountPerEpoch;

    // Calculate the deposit
    uint256 _depositAmount = _calculateDepositAmount(
      cfg.targetSettlementDomain,
      _invoiceAmounts[0],
      cfg.tickerHash,
      _discount
    );
    
    // Create deposit and verify settlement
    IEverclear.IntentStatus[] memory _expectedStatuses = new IEverclear.IntentStatus[](1);
    _expectedStatuses[0] = IEverclear.IntentStatus.SETTLED;

    bytes32 _deposit = _createADeposit(
      cfg.targetSettlementDomain,
      cfg.targetOriginDomain,
      cfg.targetSettlementAsset,
      _depositAmount,
      cfg.tickerHash
    );

    // Verify settlement
    _verifySettlement(
      cfg.tickerHash,
      _invoiceQueue,
      _expectedStatuses,
      _deposit
    );
  }

  // /**
  //  * @notice In this test, we have a pending deposit that is from a previous epoch that has not been
  //  * processed. This means the previous deposit will _not_ appear in the custodied balance, and will
  //  * _not_ get rewards because the amount is insufficient to fully settle the invoice.
  //  *
  //  * This simulates the deposit calculation if lighthouse has been down
  //  */
  function test_intentPurchaseUnprocessedEpochs() public {
    // Declare test constants
    // NOTE: at this point, there are no invoices or deposits in USDT
    TestConfig memory cfg = TestConfig({
      l1Block: 21890255,
      l2Block: 796179,
      tickerHash: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0,
      targetOriginDomain: 42161, // Arb
      targetOriginAsset: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, // USDT on Arb
      targetSettlementDomain: 10, // OP
      targetSettlementAsset: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58 // USDT on OP
    });

    // bytes32 _intentA = 0xcb0bd6c7aaca084e84c9f1153bd801e1378fff99b5fa8f273076fa5195ec5242;
    uint256[] memory _targetInvoiceAmounts = new uint256[](1);
    {
      _targetInvoiceAmounts[0] = 11320000000000000000000; // 11320
    }

    // Create fork
    {
      _setupFork(cfg.l2Block, cfg.l1Block, true);

      // Verify queue status
      (, , , uint256 _length) = _hub.invoices(cfg.tickerHash);
      require(_length == 0, 'invoice in queue, bad test setup');
    }

    // Create a target invoice
    bytes32[] memory _targets = _createInvoices(
      cfg.targetOriginDomain,
      cfg.targetSettlementDomain,
      cfg.targetOriginAsset,
      cfg.tickerHash,
      cfg.l1Block,
      _targetInvoiceAmounts
    );

    // Create a stale deposit with insufficient funds to settle target
    uint256 _fullSettlement = _calculateDepositAmount(
      cfg.targetSettlementDomain,
      _targetInvoiceAmounts[0],
      cfg.tickerHash,
      0
    );
    bytes32 _deposit0 = _createADeposit(
      cfg.targetSettlementDomain,
      cfg.targetOriginDomain,
      cfg.targetSettlementAsset,
      _fullSettlement / 3,
      cfg.tickerHash
    );

    // Advance multiple epochs to ensure there is max discount on target, dont process deposit0
    _advanceEpochs(20, cfg.l1Block);

    // Verify the deposit is added
    require(_hub.contexts(_deposit0).status == IEverclear.IntentStatus.ADDED, 'deposit not added');

    // Calculate amount to purchase target
    uint256 _deposit1Amount = _calculateDepositAmount(
      cfg.targetSettlementDomain,
      _targetInvoiceAmounts[0],
      cfg.tickerHash,
      MAX_FEE
    );

    // Create a deposit
    bytes32 _deposit1 = _createADeposit(
      cfg.targetSettlementDomain,
      cfg.targetOriginDomain,
      cfg.targetSettlementAsset,
      _deposit1Amount,
      cfg.tickerHash
    );

    // Verify the deposit is added
    require(_hub.contexts(_deposit1).status == IEverclear.IntentStatus.ADDED, 'deposit not added');

    // Process the invoice queue
    _hub.processDepositsAndInvoices(cfg.tickerHash, 0, 0, 0);

    // Verify target is settled
    require(_hub.contexts(_targets[0]).status == IEverclear.IntentStatus.SETTLED, 'target not settled');

    // Verify that deposit1 got rewards, and deposit0 did not
    require(_hub.contexts(_deposit0).pendingRewards == 0, 'deposit0 did get rewards');
    require(_hub.contexts(_deposit1).pendingRewards > 0, 'deposit1 did not get rewards');
  }

  // /**
  //  * @notice IntentA already exists at the front of the queue, there is one deposit with insufficient
  //  * balance to settle the intent waiting to be processed (both are in the same epoch).
  //  *
  //  * In this case, both deposits should get rewards.
  //  */
  function test_intentPurchaseTwoDepositsSameEpoch() public {
    // Declare test constants
    // NOTE: at this point, there are no invoices or deposits in USDT
    TestConfig memory cfg = TestConfig({
      l1Block: 21890255,
      l2Block: 796179,
      tickerHash: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0,
      targetOriginDomain: 42161, // Arb
      targetOriginAsset: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, // USDT on Arb
      targetSettlementDomain: 10, // OP
      targetSettlementAsset: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58 // USDT on OP
    });

    // bytes32 _intentA = 0xcb0bd6c7aaca084e84c9f1153bd801e1378fff99b5fa8f273076fa5195ec5242;
    uint256[] memory _targetInvoiceAmounts = new uint256[](1);
    {
      _targetInvoiceAmounts[0] = 11320000000000000000000; // invoice amount (11320 USDT)
    }

    // Create fork
    {
      _setupFork(cfg.l2Block, cfg.l1Block, true);

      // Verify queue status
      (, , , uint256 _length) = _hub.invoices(cfg.tickerHash);
      require(_length == 0, 'invoice in queue, bad test setup');
    }

    // Create a target invoice
    bytes32[] memory _targets = _createInvoices(
      cfg.targetOriginDomain,
      cfg.targetSettlementDomain,
      cfg.targetOriginAsset,
      cfg.tickerHash,
      cfg.l1Block,
      _targetInvoiceAmounts
    );

    // Advance multiple epochs to ensure there is max discount
    _advanceEpochs(20, cfg.l1Block);

    // Create an intent with deposit < invoice amount
    uint256 _fullSettlement = _calculateDepositAmount(
      cfg.targetSettlementDomain,
      _targetInvoiceAmounts[0],
      cfg.tickerHash,
      MAX_FEE
    );

    // Create a deposit
    bytes32 _deposit0 = _createADeposit(
      cfg.targetSettlementDomain,
      cfg.targetOriginDomain,
      cfg.targetSettlementAsset,
      _fullSettlement / 3,
      cfg.tickerHash
    );
    // Verify the deposit is added
    require(_hub.contexts(_deposit0).status == IEverclear.IntentStatus.ADDED, 'deposit0 not added');

    // After test set up, we need to calculate `_deposit1` amount needed to settle `_target`.
    // This calculation should be straightforward -- calculate the invoice amount using the same
    // helper as before. This should already accomodate for the larger custodied balance because
    // deposit0 has arrived on the hub.
    uint256 _deposit1Amount = _calculateDepositAmount(
      cfg.targetSettlementDomain,
      _targetInvoiceAmounts[0],
      cfg.tickerHash,
      MAX_FEE
    );

    {
      uint256 _rewards = ((_deposit1Amount + (_fullSettlement / 3)) * MAX_FEE) / DBPS_DENOMINATOR;
      console.log('');
      console.log('[test] rewards            ', _rewards);
      console.log('[test] amount to settle   ', _targetInvoiceAmounts[0] - _rewards);
      console.log('[test] depositsAmount     ', _deposit1Amount + (_fullSettlement / 3));
    }
    // Create a deposit
    bytes32 _deposit1 = _createADeposit(
      cfg.targetSettlementDomain,
      cfg.targetOriginDomain,
      cfg.targetSettlementAsset,
      _deposit1Amount,
      cfg.tickerHash
    );

    // Verify the deposit is added
    require(_hub.contexts(_deposit1).status == IEverclear.IntentStatus.ADDED, 'deposit not added');

    // Process the invoice queue
    _hub.processDepositsAndInvoices(cfg.tickerHash, 0, 0, 0);

    // Verify target is settled
    require(_hub.contexts(_targets[0]).status == IEverclear.IntentStatus.SETTLED, 'target not settled');

    // Verify that both deposits got rewards, and deposit1 rewards > deposit0 rewards
    uint256 _deposit0Rewards = _hub.contexts(_deposit0).pendingRewards;
    require(_deposit0Rewards > 0, 'deposit0 did not get rewards');
    require(_hub.contexts(_deposit1).pendingRewards > _deposit0Rewards, 'deposit1 did not get more rewards than 0');
  }

  // /**
  //  * @notice IntentA already exists at the front of the queue, and there are no deposits to be
  //  * processed. Will calculate and verify the amountB to purchase a given invoice.
  //  */
  function test_intentPurchaseFirstInvoiceNoDeposits() public {
    // Declare test constants
    TestConfig memory cfg = TestConfig({
      l1Block: 21883550,
      l2Block: 790616,
      tickerHash: 0x8b1a1d9c2b109e527c9134b25b1a1833b16b6594f92daa9f6d9b7a6024bce9d0,
      targetOriginDomain: 10, // OP
      targetOriginAsset: 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58, // USDT on Arb
      targetSettlementDomain: 324, // zkSync
      targetSettlementAsset: 0x493257fD37EDB34451f62EDf8D2a0C418852bA4C // USDT on zkSync
    });
    
    bytes32 _intentA = 0xcb0bd6c7aaca084e84c9f1153bd801e1378fff99b5fa8f273076fa5195ec5242;
    uint256[] memory _targetInvoiceAmounts = new uint256[](1);
    {
      _targetInvoiceAmounts[0] = 8999820000000000000; // invoice amount
    }

    // Create fork
    _setupFork(cfg.l2Block, cfg.l1Block, true);

    // Verify intentA exists
    require(_hub.contexts(_intentA).status == IEverclear.IntentStatus.INVOICED, 'intentA not invoiced');

    // Calculate the amount needed for an intent3 to exactly purchase `A`
    uint256 _amountB = _calculateDepositAmount(
      cfg.targetSettlementDomain, 
      _targetInvoiceAmounts[0], 
      cfg.tickerHash, 
      MAX_FEE
    );
    // uint256 _amountB = (_amountA * DBPS_DENOMINATOR) / (DBPS_DENOMINATOR + MAX_FEE);
    console.log('amountB    :', _amountB);

    // Create the intent to settle the invoice
    (IEverclear.Intent[] memory _intentBBatch, bytes32 _intentIdB) = _constructIntentBatch(
      cfg.targetSettlementDomain,
      uint32(0),
      _amountB,
      TypeCasts.toBytes32(cfg.targetSettlementAsset),
      cfg.tickerHash
    );
    console.log('intentB:');
    console.logBytes32(_intentIdB);

    _receiveBatchIntentMessage(cfg.targetSettlementDomain, _intentBBatch);
    // NOTE: if intentB is _not_ enqueued (`receiveMessage` is called) in the same epoch that intentA is
    // settled in, it will not get any rewards.

    // Verify the deposit was added
    console.log('status B   :', uint8(_hub.contexts(_intentIdB).status));
    require(_hub.contexts(_intentIdB).status == IEverclear.IntentStatus.ADDED, 'intentB not added');

    // Process queue
    _hub.processDepositsAndInvoices(cfg.tickerHash, 0, 0, 0);

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
