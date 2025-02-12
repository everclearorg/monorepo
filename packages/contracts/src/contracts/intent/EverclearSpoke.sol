// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/*

Coded for Everclear with ♥ by

░██╗░░░░░░░██╗░█████╗░███╗░░██╗██████╗░███████╗██████╗░██╗░░░░░░█████╗░███╗░░██╗██████╗░
░██║░░██╗░░██║██╔══██╗████╗░██║██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗
░╚██╗████╗██╔╝██║░░██║██╔██╗██║██║░░██║█████╗░░██████╔╝██║░░░░░███████║██╔██╗██║██║░░██║
░░████╔═████║░██║░░██║██║╚████║██║░░██║██╔══╝░░██╔══██╗██║░░░░░██╔══██║██║╚████║██║░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝██║░╚███║██████╔╝███████╗██║░░██║███████╗██║░░██║██║░╚███║██████╔╝
░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚══╝╚═════╝░╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░

https://defi.sucks

*/

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {NoncesUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol';

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';

import {AssetUtils} from 'contracts/common/AssetUtils.sol';
import {Constants as Common} from 'contracts/common/Constants.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {QueueLib} from 'contracts/common/QueueLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {Constants} from 'contracts/intent/lib/Constants.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';
import {IPermit2} from 'interfaces/common/IPermit2.sol';
import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';

import {SpokeStorage} from 'contracts/intent/SpokeStorage.sol';
/**
 * @title EverclearSpoke
 * @notice Spoke contract for Everclear
 */

contract EverclearSpoke is
  SpokeStorage,
  UUPSUpgradeable,
  OwnableUpgradeable,
  NoncesUpgradeable,
  IEverclearSpoke,
  IMessageReceiver
{
  using QueueLib for QueueLib.IntentQueue;
  using QueueLib for QueueLib.FillQueue;
  using SafeERC20 for IERC20;
  using TypeCasts for address;
  using TypeCasts for bytes32;

  constructor() {
    _disableInitializers();
  }

  /*///////////////////////////////////////////////////////////////
                       EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEverclearSpoke
  function pause() external hasPauseAccess {
    paused = true;
    emit Paused();
  }

  /// @inheritdoc IEverclearSpoke
  function unpause() external hasPauseAccess {
    paused = false;
    emit Unpaused();
  }

  /// @inheritdoc IEverclearSpoke
  function setStrategyForAsset(address _asset, IEverclear.Strategy _strategy) external onlyOwner {
    strategies[_asset] = _strategy;
    emit StrategySetForAsset(_asset, _strategy);
  }

  /// @inheritdoc IEverclearSpoke
  function setModuleForStrategy(IEverclear.Strategy _strategy, ISettlementModule _module) external onlyOwner {
    modules[_strategy] = _module;
    emit ModuleSetForStrategy(_strategy, _module);
  }

  /// @inheritdoc IEverclearSpoke
  function updateSecurityModule(
    address _newSecurityModule
  ) external onlyOwner {
    gateway.updateSecurityModule(_newSecurityModule);
  }

  /// @inheritdoc IMessageReceiver
  function receiveMessage(
    bytes calldata
  ) external {
    _delegate(messageReceiver);
  }

  /// @inheritdoc IEverclearSpoke
  function newIntent(
    uint32[] memory _destinations,
    address _receiver,
    address _inputAsset,
    address _outputAsset,
    uint256 _amount,
    uint24 _maxFee,
    uint48 _ttl,
    bytes calldata _data
  ) external whenNotPaused returns (bytes32 _intentId, Intent memory _intent) {
    if (_destinations.length > 10) revert EverclearSpoke_NewIntent_InvalidIntent();
    (_intentId, _intent) = _newIntent({
      _destinations: _destinations,
      _receiver: _receiver,
      _inputAsset: _inputAsset,
      _outputAsset: _outputAsset,
      _amount: _amount,
      _maxFee: _maxFee,
      _ttl: _ttl,
      _data: _data,
      _usesPermit2: false
    });
  }

  /// @inheritdoc IEverclearSpoke
  function newIntent(
    uint32[] memory _destinations,
    address _receiver,
    address _inputAsset,
    address _outputAsset,
    uint256 _amount,
    uint24 _maxFee,
    uint48 _ttl,
    bytes calldata _data,
    Permit2Params calldata _permit2Params
  ) external whenNotPaused returns (bytes32 _intentId, Intent memory _intent) {
    if (_destinations.length > 10) revert EverclearSpoke_NewIntent_InvalidIntent();
    PERMIT2.permitTransferFrom(
      IPermit2.PermitTransferFrom({
        permitted: IPermit2.TokenPermissions({token: IERC20(_inputAsset), amount: _amount}),
        nonce: _permit2Params.nonce,
        deadline: _permit2Params.deadline
      }),
      IPermit2.SignatureTransferDetails({to: address(this), requestedAmount: _amount}),
      msg.sender,
      _permit2Params.signature
    );

    (_intentId, _intent) = _newIntent({
      _destinations: _destinations,
      _receiver: _receiver,
      _inputAsset: _inputAsset,
      _outputAsset: _outputAsset,
      _amount: _amount,
      _maxFee: _maxFee,
      _ttl: _ttl,
      _data: _data,
      _usesPermit2: true
    });
  }

  /// @inheritdoc IEverclearSpoke
  function fillIntent(
    Intent calldata _intent,
    uint24 _fee
  ) external whenNotPaused returns (FillMessage memory _fillMessage) {
    _fillMessage = _fillIntent(_intent, msg.sender, _fee);
  }

  /// @inheritdoc IEverclearSpoke
  function fillIntentForSolver(
    address _solver,
    Intent calldata _intent,
    uint256 _nonce,
    uint24 _fee,
    bytes calldata _signature
  ) external whenNotPaused returns (FillMessage memory _fillMessage) {
    bytes memory _data = abi.encode(FILL_INTENT_FOR_SOLVER_TYPEHASH, _intent, _nonce, _fee);
    _verifySignature(_solver, _data, _nonce, _signature);

    _fillMessage = _fillIntent(_intent, _solver, _fee);
  }

  /// @inheritdoc IEverclearSpoke
  function processIntentQueue(
    Intent[] calldata _intents
  ) external payable whenNotPaused {
    (bytes memory _batchIntentmessage, uint256 _firstIdx) = _processIntentQueue(_intents);

    (bytes32 _messageId, uint256 _feeSpent) =
      gateway.sendMessage{value: msg.value}(EVERCLEAR, _batchIntentmessage, messageGasLimit);

    emit IntentQueueProcessed(_messageId, _firstIdx, _firstIdx + _intents.length, _feeSpent);
  }

  /// @inheritdoc IEverclearSpoke
  function processFillQueue(
    uint32 _amount
  ) external payable whenNotPaused {
    (bytes memory _batchFillMessage, uint256 _firstIdx) = _processFillQueue(_amount);

    (bytes32 _messageId, uint256 _feeSpent) =
      gateway.sendMessage{value: msg.value}(EVERCLEAR, _batchFillMessage, messageGasLimit);

    emit FillQueueProcessed(_messageId, _firstIdx, _firstIdx + _amount, _feeSpent);
  }

  /// @inheritdoc IEverclearSpoke
  function processIntentQueueViaRelayer(
    uint32 _domain,
    Intent[] calldata _intents,
    address _relayer,
    uint256 _ttl,
    uint256 _nonce,
    uint256 _bufferDBPS,
    bytes calldata _signature
  ) external whenNotPaused {
    uint32 _amount = uint32(_intents.length);
    bytes memory _data =
      abi.encode(PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH, _domain, _amount, _relayer, _ttl, _nonce, _bufferDBPS);
    _verifySignature(lighthouse, _data, _nonce, _signature);
    _processQueueChecks(_domain, _relayer, _ttl);

    (bytes memory _batchIntentmessage, uint256 _firstIdx) = _processIntentQueue(_intents);

    uint256 _fee = gateway.quoteMessage(EVERCLEAR, _batchIntentmessage, messageGasLimit);

    (bytes32 _messageId, uint256 _feeSpent) = gateway.sendMessage(
      EVERCLEAR, _batchIntentmessage, _fee + ((_fee * _bufferDBPS) / Common.DBPS_DENOMINATOR), messageGasLimit
    );

    emit IntentQueueProcessed(_messageId, _firstIdx, _firstIdx + _amount, _feeSpent);
  }

  /// @inheritdoc IEverclearSpoke
  function processFillQueueViaRelayer(
    uint32 _domain,
    uint32 _amount,
    address _relayer,
    uint256 _ttl,
    uint256 _nonce,
    uint256 _bufferDBPS,
    bytes calldata _signature
  ) external whenNotPaused {
    bytes memory _data =
      abi.encode(PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH, _domain, _amount, _relayer, _ttl, _nonce, _bufferDBPS);
    _verifySignature(lighthouse, _data, _nonce, _signature);
    _processQueueChecks(_domain, _relayer, _ttl);

    (bytes memory _batchFillMessage, uint256 _firstIdx) = _processFillQueue(_amount);

    uint256 _fee = gateway.quoteMessage(EVERCLEAR, _batchFillMessage, messageGasLimit);

    (bytes32 _messageId, uint256 _feeSpent) = gateway.sendMessage(
      EVERCLEAR, _batchFillMessage, _fee + ((_fee * _bufferDBPS) / Common.DBPS_DENOMINATOR), messageGasLimit
    );

    emit FillQueueProcessed(_messageId, _firstIdx, _firstIdx + _amount, _feeSpent);
  }

  /// @inheritdoc IEverclearSpoke
  function deposit(address _asset, uint256 _amount) external whenNotPaused {
    _pullTokens(msg.sender, _asset, _amount);
    balances[_asset.toBytes32()][msg.sender.toBytes32()] += _amount;

    emit Deposited(msg.sender, _asset, _amount);
  }

  /// @inheritdoc IEverclearSpoke
  function withdraw(address _asset, uint256 _amount) external whenNotPaused {
    balances[_asset.toBytes32()][msg.sender.toBytes32()] -= _amount;

    _pushTokens(msg.sender, _asset, _amount);
    emit Withdrawn(msg.sender, _asset, _amount);
  }

  /// @inheritdoc IEverclearSpoke
  function updateGateway(
    address _newGateway
  ) external onlyOwner {
    address _oldGateway = address(gateway);
    gateway = ISpokeGateway(_newGateway);

    emit GatewayUpdated(_oldGateway, _newGateway);
  }

  /// @inheritdoc IEverclearSpoke
  function updateMessageReceiver(
    address _newMessageReceiver
  ) external onlyOwner {
    address _oldMessageReceiver = messageReceiver;
    messageReceiver = _newMessageReceiver;
    emit MessageReceiverUpdated(_oldMessageReceiver, _newMessageReceiver);
  }

  /// @inheritdoc IEverclearSpoke
  function updateMessageGasLimit(
    uint256 _newGasLimit
  ) external onlyOwner {
    uint256 _oldGasLimit = messageGasLimit;
    messageGasLimit = _newGasLimit;
    emit MessageGasLimitUpdated(_oldGasLimit, _newGasLimit);
  }

  /// @inheritdoc IEverclearSpoke
  function executeIntentCalldata(
    Intent calldata _intent
  ) external whenNotPaused validDestination(_intent) {
    bytes32 _intentId = keccak256(abi.encode(_intent));

    if (status[_intentId] != IntentStatus.SETTLED) {
      revert EverclearSpoke_ExecuteIntentCalldata_InvalidStatus(_intentId);
    }

    // internal method will revert if it fails
    _executeCalldata(_intentId, _intent.data);

    status[_intentId] = IntentStatus.SETTLED_AND_MANUALLY_EXECUTED;
  }

  /*///////////////////////////////////////////////////////////////
                           INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEverclearSpoke
  function initialize(
    SpokeInitializationParams calldata _init
  ) public initializer {
    DOMAIN = uint32(block.chainid);
    gateway = _init.gateway;
    messageReceiver = _init.messageReceiver;
    lighthouse = _init.lighthouse;
    watchtower = _init.watchtower;
    callExecutor = _init.callExecutor;
    EVERCLEAR = _init.hubDomain;
    messageGasLimit = 20_000_000;

    __Ownable_init(_init.owner);

    // Intialize the queues
    intentQueue.first = 1;
    fillQueue.first = 1;
  }

  /*///////////////////////////////////////////////////////////////
                       INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Creates a new intent
   * @param _destinations The destination chains of the intent
   * @param _receiver The destinantion address of the intent
   * @param _inputAsset The asset address on origin
   * @param _outputAsset The asset address on destination
   * @param _amount The amount of the asset
   * @param _maxFee The maximum fee that can be taken by solvers
   * @param _ttl The time to live of the intent
   * @param _data The data of the intent
   * @param _usesPermit2 If the intent uses permit2
   * @return _intentId The ID of the intent
   * @return _intent The intent structure
   */
  function _newIntent(
    uint32[] memory _destinations,
    address _receiver,
    address _inputAsset,
    address _outputAsset,
    uint256 _amount,
    uint24 _maxFee,
    uint48 _ttl,
    bytes calldata _data,
    bool _usesPermit2
  ) internal returns (bytes32 _intentId, Intent memory _intent) {
    if (_destinations.length == 1) {
      // output asset should not be null if the intent has a single destination and ttl != 0
      if (_ttl != 0 && _outputAsset == address(0)) revert EverclearSpoke_NewIntent_InvalidIntent();
    } else {
      // output asset should be null if the intent has multiple destinations
      // ttl should be 0 if the intent has multiple destinations
      if (_ttl != 0 || _outputAsset != address(0)) revert EverclearSpoke_NewIntent_InvalidIntent();
    }

    if (_maxFee > Common.DBPS_DENOMINATOR) {
      revert EverclearSpoke_NewIntent_MaxFeeExceeded(_maxFee, Common.DBPS_DENOMINATOR);
    }

    if (_data.length > Common.MAX_CALLDATA_SIZE) {
      revert EverclearSpoke_NewIntent_CalldataExceedsLimit();
    }

    uint256 _normalizedAmount =
      AssetUtils.normalizeDecimals(ERC20(_inputAsset).decimals(), Common.DEFAULT_NORMALIZED_DECIMALS, _amount);

    // check normalized amount before pulling tokens
    if (_normalizedAmount == 0) {
      revert EverclearSpoke_NewIntent_ZeroAmount();
    }

    if (!_usesPermit2) {
      Strategy _strategy = strategies[_inputAsset];
      if (_strategy == Strategy.DEFAULT) {
        _pullTokens(msg.sender, _inputAsset, _amount);
      } else {
        ISettlementModule _module = modules[_strategy];
        _module.handleBurnStrategy(_inputAsset, msg.sender, _amount, '');
      }
    }

    _intent = Intent({
      initiator: msg.sender.toBytes32(),
      receiver: _receiver.toBytes32(),
      inputAsset: _inputAsset.toBytes32(),
      outputAsset: _outputAsset.toBytes32(),
      maxFee: _maxFee,
      origin: DOMAIN,
      nonce: ++nonce,
      timestamp: uint48(block.timestamp),
      ttl: _ttl,
      amount: _normalizedAmount,
      destinations: _destinations,
      data: _data
    });

    _intentId = keccak256(abi.encode(_intent));

    intentQueue.enqueueIntent(_intentId);

    status[_intentId] = IntentStatus.ADDED;

    emit IntentAdded(_intentId, intentQueue.last, _intent);
  }

  /**
   * @notice Fills an intent
   * @param _intent The intent structure
   * @param _solver The solver address
   * @param _fee The total fee, expressed in dbps, represents the solver fee plus the sum of protocol fees for the token
   * @return _fillMessage The fill message
   */
  function _fillIntent(
    Intent calldata _intent,
    address _solver,
    uint24 _fee
  ) internal validDestination(_intent) returns (FillMessage memory _fillMessage) {
    bytes32 _intentId = keccak256(abi.encode(_intent));
    if (block.timestamp >= _intent.timestamp + _intent.ttl) {
      revert EverclearSpoke_FillIntent_IntentExpired(_intentId);
    }

    if (_fee > _intent.maxFee) {
      revert EverclearSpoke_FillIntent_MaxFeeExceeded(_fee, _intent.maxFee);
    }

    if (status[_intentId] != IntentStatus.NONE) {
      revert EverclearSpoke_FillIntent_InvalidStatus(_intentId);
    }

    uint256 _amount = AssetUtils.normalizeDecimals(
      Common.DEFAULT_NORMALIZED_DECIMALS, ERC20(_intent.outputAsset.toAddress()).decimals(), _intent.amount
    );

    uint256 _feeDeduction = _amount * _fee / Common.DBPS_DENOMINATOR;
    uint256 _finalAmount = _amount - _feeDeduction;

    if (balances[_intent.outputAsset][_solver.toBytes32()] < _finalAmount) {
      revert EverclearSpoke_FillIntent_InsufficientFunds(
        _finalAmount, balances[_intent.outputAsset][_solver.toBytes32()]
      );
    }

    balances[_intent.outputAsset][_solver.toBytes32()] -= _finalAmount;
    status[_intentId] = IntentStatus.FILLED;

    if (_intent.receiver != 0 && _intent.outputAsset != 0 && _amount != 0) {
      _pushTokens(_intent.receiver.toAddress(), _intent.outputAsset.toAddress(), _finalAmount);
    }

    if (keccak256(_intent.data) != Constants.EMPTY_HASH) {
      _executeCalldata(_intentId, _intent.data);
    }

    _fillMessage = FillMessage({
      intentId: _intentId,
      initiator: _intent.initiator,
      solver: _solver.toBytes32(),
      executionTimestamp: uint48(block.timestamp),
      fee: _fee
    });

    fillQueue.enqueueFill(_fillMessage);

    emit IntentFilled(_intentId, _solver, _fee, fillQueue.last, _intent);
  }

  /**
   * @notice Verifies a signature
   * @param _signer The signer of the message
   * @param _data The data of the message
   * @param _nonce The nonce of the message
   * @param _signature The signature of the message
   */
  function _verifySignature(address _signer, bytes memory _data, uint256 _nonce, bytes calldata _signature) internal {
    bytes32 _hash = keccak256(_data);
    address _recoveredSigner = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(_hash), _signature);
    if (_recoveredSigner != _signer) {
      revert EverclearSpoke_InvalidSignature();
    }

    _useCheckedNonce(_recoveredSigner, _nonce);
  }

  /**
   * @notice Process the intent queue messages to send a batching message to the transport layer
   * @param _intents The intents to process, the order of the intents must match the order in the queue
   * @return _batchIntentmessage The batched intent message
   * @return _firstIdx The first index of the intents processed
   */
  function _processIntentQueue(
    Intent[] calldata _intents
  )
    internal
    validQueueAmount(intentQueue.first, intentQueue.last, _intents.length)
    returns (bytes memory _batchIntentmessage, uint256 _firstIdx)
  {
    _firstIdx = intentQueue.first;

    for (uint32 _i; _i < _intents.length; _i++) {
      bytes32 _queueIntentId = intentQueue.dequeueIntent();
      bytes32 _intentHash = keccak256(abi.encode(_intents[_i]));
      // verify the intent and its position in the queue
      if (_queueIntentId != _intentHash) {
        revert EverclearSpoke_ProcessIntentQueue_NotFound(_intentHash, _i);
      }
    }

    _batchIntentmessage = MessageLib.formatIntentMessageBatch(_intents);
  }

  /**
   * @notice Process the fill queue messages to send a batching message to the transport layer
   * @param _amount The amount of messages to process
   * @return _batchFillMessage The batched fill message
   * @return _firstIdx The first index of the fills processed
   */
  function _processFillQueue(
    uint32 _amount
  )
    internal
    validQueueAmount(fillQueue.first, fillQueue.last, _amount)
    returns (bytes memory _batchFillMessage, uint256 _firstIdx)
  {
    _firstIdx = fillQueue.first;

    FillMessage[] memory _fillMessages = new FillMessage[](_amount);
    for (uint32 _i; _i < _amount; _i++) {
      _fillMessages[_i] = fillQueue.dequeueFill();
    }

    _batchFillMessage = MessageLib.formatFillMessageBatch(_fillMessages);
  }

  /**
   * @notice Executes the calldata of an intent
   * @param _intentId The intent ID
   * @param _data The calldata of the intent
   */
  function _executeCalldata(bytes32 _intentId, bytes memory _data) internal {
    (address _target, bytes memory _calldata) = abi.decode(_data, (address, bytes));

    (bool _success, bytes memory _returnData) = callExecutor.excessivelySafeCall(
      _target, gasleft() - Constants.EXECUTE_CALLDATA_RESERVE_GAS, 0, Constants.DEFAULT_COPY_BYTES, _calldata
    );

    if (_success) {
      emit ExternalCalldataExecuted(_intentId, _returnData);
    } else {
      revert EverclearSpoke_ExecuteIntentCalldata_ExternalCallFailed();
    }
  }

  /**
   * @notice Pull tokens from the sender to the spoke contract
   * @param _sender The address of the sender
   * @param _asset The address of the asset
   * @param _amount The amount of the asset
   */
  function _pullTokens(address _sender, address _asset, uint256 _amount) internal {
    IERC20(_asset).safeTransferFrom(_sender, address(this), _amount);
  }

  /**
   * @notice Push tokens from the spoke contract to the recipient
   * @param _recipient The address of the recipient
   * @param _asset The address of the asset
   * @param _amount The amount of the asset
   */
  function _pushTokens(address _recipient, address _asset, uint256 _amount) internal {
    IERC20(_asset).safeTransfer(_recipient, _amount);
  }

  /**
   * @notice Perform a `delegatcall`
   * @param _delegatee The address of the delegatee
   */
  function _delegate(
    address _delegatee
  ) internal {
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize())

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas(), _delegatee, 0, calldatasize(), 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())

      switch result
      // delegatecall returns 0 on error.
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }

  /**
   * @notice Checks that the upgrade function is called by the owner
   */
  function _authorizeUpgrade(
    address
  ) internal override onlyOwner {}

  /**
   * @notice Process queue checks (applied when a relayer tries to process a queue)
   * @param _domain The domain of the queue
   * @param _relayer The relayer address
   * @param _ttl The time to live of the message
   */
  function _processQueueChecks(uint32 _domain, address _relayer, uint256 _ttl) internal view {
    if (_domain != DOMAIN) {
      revert EverclearSpoke_ProcessFillViaRelayer_WrongDomain();
    }

    if (_relayer != msg.sender) {
      revert EverclearSpoke_ProcessFillViaRelayer_NotRelayer();
    }

    if (block.timestamp > _ttl) {
      revert EverclearSpoke_ProcessFillViaRelayer_TTLExpired();
    }
  }
}
