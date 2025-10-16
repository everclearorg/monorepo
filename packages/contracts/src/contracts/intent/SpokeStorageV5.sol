// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {QueueLib} from 'contracts/common/QueueLib.sol';
import {QueueLibV2} from 'contracts/common/QueueLibV2.sol';

import {IPermit2} from 'interfaces/common/IPermit2.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';
import {ICallExecutor} from 'interfaces/intent/ICallExecutor.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';
import {ISpokeStorageV5} from 'interfaces/intent/ISpokeStorageV5.sol';

/**
 * @title SpokeStorage
 * @notice Storage layout and modifiers for the `EverclearSpoke`
 */
abstract contract SpokeStorageV5 is ISpokeStorageV5 {
  /// @inheritdoc ISpokeStorageV5
  bytes32 public constant FILL_INTENT_FOR_SOLVER_TYPEHASH = keccak256(
    'function fillIntentForSolver(bytes32 _domain, address _solver, Intent calldata _intent, uint256 _nonce, uint256 _amountOut, uint32[] memory _destinations)'
  );

  /// @inheritdoc ISpokeStorageV5
  bytes32 public constant PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH = keccak256(
    'function processIntentQueueViaRelayer(uint32 _domain, Intent[] memory _intents, address _relayer, uint256 _ttl, uint256 _nonce, uint256 _bufferDBPS)'
  );

  /// @inheritdoc ISpokeStorageV5
  bytes32 public constant PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH = keccak256(
    'function processFillQueueViaRelayer(uint32 _domain, uint32 _amount, address _relayer, uint256 _ttl, uint256 _nonce, uint256 _bufferDBPS)'
  );

  /// @inheritdoc ISpokeStorageV5
  IPermit2 public constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

  /// @inheritdoc ISpokeStorageV5
  bytes32 public constant FILL_INTENT_TYPEHASH = keccak256(
    'function fillIntent(bytes32 _domain, address _sender, Intent calldata _intent, uint256 _amountOut, uint32[] memory _destinations)'
  );

  /// @inheritdoc ISpokeStorageV5
  bytes32 public constant BATCH_FILL_INTENT_TYPEHASH = keccak256(
    'function batchFillIntent(bytes32 _domain, address _sender, Intent[] calldata _intents, uint256[] _amountOut, uint32[][] memory _destinations)'
  );

  /// @inheritdoc ISpokeStorageV5
  uint32 public EVERCLEAR;

  /// @inheritdoc ISpokeStorageV5
  uint32 public DOMAIN;

  /// @inheritdoc ISpokeStorageV5
  address public lighthouse;

  /// @inheritdoc ISpokeStorageV5
  address public watchtower;

  /// @inheritdoc ISpokeStorageV5
  address public messageReceiver;

  /// @inheritdoc ISpokeStorageV5
  ISpokeGateway public gateway;

  /// @inheritdoc ISpokeStorageV5
  ICallExecutor public callExecutor;

  /// @inheritdoc ISpokeStorageV5
  bool public paused;

  /// @inheritdoc ISpokeStorageV5
  uint64 public nonce;

  /// @inheritdoc ISpokeStorageV5
  uint256 public messageGasLimit;

  /// @inheritdoc ISpokeStorageV5
  mapping(bytes32 _asset => mapping(bytes32 _user => uint256 _amount)) public balances;

  /// @inheritdoc ISpokeStorageV5
  mapping(bytes32 _intentId => IntentStatus status) public status;

  /// @inheritdoc ISpokeStorageV5
  mapping(address _asset => Strategy _strategy) public strategies;

  /// @inheritdoc ISpokeStorageV5
  mapping(Strategy _strategy => ISettlementModule _module) public modules;

  /// @notice The deprecated intent queue with previous Intent struct
  QueueLib.IntentQueue public deprecated_intentQueue;

  /// @notice The deprecated fill queue with previous FillMessage struct
  QueueLib.FillQueue public deprecated_fillQueue;

  /**
   * **********************  FeeAdapter Upgrade  **********************
   */
  address public feeAdapter;

  /**
   * **********************  Swap Upgrade  **********************
   */
  /**
   * @notice The intent queue
   */
  QueueLibV2.IntentQueue public intentQueue;
  /**
   * @notice The fill queue
   */
  QueueLibV2.FillQueue public fillQueue;

  /**
   * @notice Checks that the address is valid
   */
  modifier validAddress(
    address _address
  ) {
    if (_address == address(0)) {
      revert EverclearSpoke_ZeroAddress();
    }
    _;
  }

  /**
   * @notice Checks that the local domain is included in the destinations
   * @param _intent The intent to check
   */
  modifier validDestination(
    Intent calldata _intent
  ) {
    // when it's an xcall executable, destinations.length is always 1
    if (_intent.destinations[0] != DOMAIN) {
      revert EverclearSpoke_WrongDestination();
    }
    _;
  }

  /**
   * @notice Checks when processing a queue that the amount is valid for the queue being processed
   * @param _first The first index of the queue
   * @param _last The last index of the queue
   * @param _amount The amount to process
   */
  modifier validQueueAmount(uint256 _first, uint256 _last, uint256 _amount) {
    if (_amount == 0) {
      revert EverclearSpoke_ProcessQueue_ZeroAmount();
    }

    if (_first + _amount - 1 > _last) {
      revert EverclearSpoke_ProcessQueue_InvalidAmount(_first, _last, _amount);
    }

    _;
  }

  /**
   * @notice Checks that the contract is not paused
   */
  modifier whenNotPaused() {
    if (paused) {
      revert EverclearSpoke_Paused();
    }
    _;
  }

  /**
   * @notice Checks that the caller has access to pause the contract
   */
  modifier hasPauseAccess() {
    if (msg.sender != lighthouse && msg.sender != watchtower) {
      revert EverclearSpoke_Pause_NotAuthorized();
    }
    _;
  }

  /**
   * @notice Checks the caller is the fee adapter
   */
  modifier onlyFeeAdapter() {
    if (msg.sender != feeAdapter) {
      revert EverclearSpoke_FeeAdapter_NotAuthorized();
    }
    _;
  }
}
