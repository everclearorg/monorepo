// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {QueueLib} from 'contracts/common/QueueLib.sol';

import {IPermit2} from 'interfaces/common/IPermit2.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';
import {ICallExecutor} from 'interfaces/intent/ICallExecutor.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';
import {ISpokeStorage} from 'interfaces/intent/ISpokeStorage.sol';

/**
 * @title SpokeStorage
 * @notice Storage layout and modifiers for the `EverclearSpoke`
 */
abstract contract SpokeStorage is ISpokeStorage {
  /// @inheritdoc ISpokeStorage
  bytes32 public constant FILL_INTENT_FOR_SOLVER_TYPEHASH = keccak256(
    'function fillIntentForSolver(address _solver, Intent calldata _intent, uint256 _nonce, uint24 _fee, bytes memory _signature)'
  );

  /// @inheritdoc ISpokeStorage
  bytes32 public constant PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH = keccak256(
    'function processIntentQueueViaRelayer(uint32 _domain, Intent[] memory _intents, address _relayer, uint256 _ttl, uint256 _nonce, uint256 _bufferDBPS, bytes memory _signature)'
  );

  /// @inheritdoc ISpokeStorage
  bytes32 public constant PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH = keccak256(
    'function processFillQueueViaRelayer(uint32 _domain, uint32 _amount, address _relayer, uint256 _ttl, uint256 _nonce, uint256 _bufferDBPS, bytes memory _signature)'
  );

  /// @inheritdoc ISpokeStorage
  IPermit2 public constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

  /// @inheritdoc ISpokeStorage
  uint32 public EVERCLEAR;

  /// @inheritdoc ISpokeStorage
  uint32 public DOMAIN;

  /// @inheritdoc ISpokeStorage
  address public lighthouse;

  /// @inheritdoc ISpokeStorage
  address public watchtower;

  /// @inheritdoc ISpokeStorage
  address public messageReceiver;

  /// @inheritdoc ISpokeStorage
  ISpokeGateway public gateway;

  /// @inheritdoc ISpokeStorage
  ICallExecutor public callExecutor;

  /// @inheritdoc ISpokeStorage
  bool public paused;

  /// @inheritdoc ISpokeStorage
  uint64 public nonce;

  /// @inheritdoc ISpokeStorage
  uint256 public messageGasLimit;

  /// @inheritdoc ISpokeStorage
  mapping(bytes32 _asset => mapping(bytes32 _user => uint256 _amount)) public balances;

  /// @inheritdoc ISpokeStorage
  mapping(bytes32 _intentId => IntentStatus status) public status;

  /// @inheritdoc ISpokeStorage
  mapping(address _asset => Strategy _strategy) public strategies;

  /// @inheritdoc ISpokeStorage
  mapping(Strategy _strategy => ISettlementModule _module) public modules;

  /**
   * @notice The intent queue
   */
  QueueLib.IntentQueue public intentQueue;

  /**
   * @notice The fill queue
   */
  QueueLib.FillQueue public fillQueue;

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
}
