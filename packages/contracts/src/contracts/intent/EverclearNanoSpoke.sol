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
import {IEverclearNanoSpoke} from 'interfaces/intent/IEverclearNanoSpoke.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';

import {SpokeStorage} from 'contracts/intent/SpokeStorage.sol';
/**
 * @title Everclear NanoSpoke
 * @notice Spoke contract for Everclear
 * @dev Functions removed from this contract include:
 *      - setStrategyForAsset
 *      - setModuleForStrategy
 *      - newIntent (permit2 option)
 *      - fillIntent
 *      - fillIntentForSolver
 *      - processFillQueue
 *      - processFillQueueViaRelayer
 *      - deposit
 *      - executeIntentCalldata
 * @dev Logic that has been added to the contract:
 *      - onlyAuthorized modifier (for receiveMessage)
 *      - receiveMessage implementation (previously delegated)
 *      - _handleVarUpdate
 *      - _handleBatchSettlement
 *      - _handleSettlement
 * @dev Fallback is to update virtual balance on token transfer i.e. withdraw kept
 */

contract EverclearNanoSpoke is
  SpokeStorage,
  UUPSUpgradeable,
  OwnableUpgradeable,
  NoncesUpgradeable,
  IEverclearNanoSpoke,
  IMessageReceiver
{
  using QueueLib for QueueLib.IntentQueue;
  using QueueLib for QueueLib.FillQueue;
  using SafeERC20 for IERC20;
  using TypeCasts for address;
  using TypeCasts for bytes32;

  /**
   * @notice Checks that the function is called by the gateway
   */
  modifier onlyAuthorized() {
    if (msg.sender != owner() && (msg.sender != address(gateway) || paused)) {
      revert EverclearSpoke_Unauthorized();
    }
    _;
  }

  constructor() {
    _disableInitializers();
  }

  /*///////////////////////////////////////////////////////////////
                       EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEverclearNanoSpoke
  function pause() external hasPauseAccess {
    paused = true;
    emit Paused();
  }

  /// @inheritdoc IEverclearNanoSpoke
  function unpause() external hasPauseAccess {
    paused = false;
    emit Unpaused();
  }

  /// @inheritdoc IEverclearNanoSpoke
  function updateSecurityModule(
    address _newSecurityModule
  ) external onlyOwner {
    gateway.updateSecurityModule(_newSecurityModule);
  }

  /// @inheritdoc IMessageReceiver
  function receiveMessage(
    bytes calldata _message
  ) external onlyAuthorized {
    (MessageLib.MessageType _messageType, bytes memory _data) = MessageLib.parseMessage(_message);

    if (_messageType == MessageLib.MessageType.SETTLEMENT) {
      _handleBatchSettlement(_data);
    } else if (_messageType == MessageLib.MessageType.VAR_UPDATE) {
      (bytes32 _updateVariable, bytes memory _updateData) = MessageLib.parseVarUpdateMessage(_data);
      _handleVarUpdate(_updateVariable, _updateData);
    } else {
      revert EverclearSpoke_InvalidMessageType();
    }
  }

  /// @inheritdoc IEverclearNanoSpoke
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
      _data: _data
    });
  }

  /// @inheritdoc IEverclearNanoSpoke
  function processIntentQueue(
    Intent[] calldata _intents
  ) external payable whenNotPaused {
    (bytes memory _batchIntentmessage, uint256 _firstIdx) = _processIntentQueue(_intents);

    (bytes32 _messageId, uint256 _feeSpent) =
      gateway.sendMessage{value: msg.value}(EVERCLEAR, _batchIntentmessage, messageGasLimit);

    emit IntentQueueProcessed(_messageId, _firstIdx, _firstIdx + _intents.length, _feeSpent);
  }

  /// @inheritdoc IEverclearNanoSpoke
  function withdraw(address _asset, uint256 _amount) external whenNotPaused {
    balances[_asset.toBytes32()][msg.sender.toBytes32()] -= _amount;

    _pushTokens(msg.sender, _asset, _amount);
    emit Withdrawn(msg.sender, _asset, _amount);
  }

  /// @inheritdoc IEverclearNanoSpoke
  function updateGateway(
    address _newGateway
  ) external onlyOwner {
    address _oldGateway = address(gateway);
    gateway = ISpokeGateway(_newGateway);

    emit GatewayUpdated(_oldGateway, _newGateway);
  }

  /// @inheritdoc IEverclearNanoSpoke
  function updateMessageReceiver(
    address _newMessageReceiver
  ) external onlyOwner {
    address _oldMessageReceiver = messageReceiver;
    messageReceiver = _newMessageReceiver;
    emit MessageReceiverUpdated(_oldMessageReceiver, _newMessageReceiver);
  }

  /// @inheritdoc IEverclearNanoSpoke
  function updateMessageGasLimit(
    uint256 _newGasLimit
  ) external onlyOwner {
    uint256 _oldGasLimit = messageGasLimit;
    messageGasLimit = _newGasLimit;
    emit MessageGasLimitUpdated(_oldGasLimit, _newGasLimit);
  }

  /*///////////////////////////////////////////////////////////////
                           INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEverclearNanoSpoke
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
    bytes calldata _data
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

    // Minimal implementations only use ERC20 (no xERC20 usage)
    _pullTokens(msg.sender, _inputAsset, _amount);

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
   * @notice Checks that the upgrade function is called by the owner
   */
  function _authorizeUpgrade(
    address
  ) internal override onlyOwner {}

  /**
   * @notice handle a variable update message
   * @param _updateVariable The hash of the variable being updated
   * @param _updateData The data of the update
   */
  function _handleVarUpdate(bytes32 _updateVariable, bytes memory _updateData) internal {
    if (_updateVariable == Common.GATEWAY_HASH) {
      address _newGateway = MessageLib.parseAddressUpdateMessage(_updateData).toAddress();
      _updateGateway(_newGateway);
    } else if (_updateVariable == Common.MAILBOX_HASH) {
      address _newMailbox = MessageLib.parseAddressUpdateMessage(_updateData).toAddress();
      _updateMailbox(_newMailbox);
    } else if (_updateVariable == Common.LIGHTHOUSE_HASH) {
      address _newLighthouse = MessageLib.parseAddressUpdateMessage(_updateData).toAddress();
      _updateLighthouse(_newLighthouse);
    } else if (_updateVariable == Common.WATCHTOWER_HASH) {
      address _newWatchtower = MessageLib.parseAddressUpdateMessage(_updateData).toAddress();
      _updateWatchtower(_newWatchtower);
    } else {
      revert EverclearSpoke_InvalidVarUpdate();
    }
  }

  /**
   * @notice Handles a batch of settlement messages
   * @param _data The batch of settlement messages
   */
  function _handleBatchSettlement(
    bytes memory _data
  ) internal {
    Settlement[] memory _settlementMessage = MessageLib.parseSettlementBatch(_data);
    for (uint256 _i; _i < _settlementMessage.length; _i++) {
      Settlement memory _message = _settlementMessage[_i];
      _handleSettlement(_message);
    }
  }

  /**
   * @notice Handles a settlement message
   * @param _message The settlement message
   */
  function _handleSettlement(
    Settlement memory _message
  ) internal {
    address _asset = _message.asset.toAddress();
    address _recipient = _message.recipient.toAddress();

    IntentStatus _intentStatus = status[_message.intentId];
    // if already settled, ignore (shouldn't happen)
    if (_intentStatus == IntentStatus.SETTLED || _intentStatus == IntentStatus.SETTLED_AND_MANUALLY_EXECUTED) {
      return;
    }
    status[_message.intentId] = IntentStatus.SETTLED;

    uint256 _amount =
      AssetUtils.normalizeDecimals(Common.DEFAULT_NORMALIZED_DECIMALS, ERC20(_asset).decimals(), _message.amount);

    // after decimals normalization, the _amount can be 0 as result of loss of precision, check if it's > 0
    if (_amount > 0) {
      // NOTE: Nanospoke defaults to transfer asset and increase virtual balance on failure
      // if transfer fails (eg. blacklisted recipient), increase virtual balance instead
      bytes memory _transferData = abi.encodeWithSignature('transfer(address,uint256)', _recipient, _amount);
      (bool _success, bytes memory _res) = _asset.call(_transferData);

      // doing the transfer as a low-level call to avoid reverting the whole batch if the transfer calls revert
      // applying the same checks as `SafeERC20` for the `transfer` as it can't be wrapped in a `try/catch` block
      if (!_success || (_res.length != 0 && !abi.decode(_res, (bool)))) {
        balances[_message.asset][_message.recipient] += _amount;
        emit AssetTransferFailed(_asset, _recipient, _amount);
      }
    }
    emit Settled(_message.intentId, _recipient, _asset, _amount);
  }

  /**
   * @notice Update the gateway
   * @param _newGateway The new gateway address
   */
  function _updateGateway(
    address _newGateway
  ) internal validAddress(_newGateway) {
    address _oldGateway = address(gateway);
    gateway = ISpokeGateway(_newGateway);
    emit GatewayUpdated(_oldGateway, _newGateway);
  }

  /**
   * @notice Update the local mailbox address
   * @param _newMailbox The new mailbox address
   */
  function _updateMailbox(
    address _newMailbox
  ) internal {
    gateway.updateMailbox(_newMailbox);
  }

  /**
   * @notice Update the interchain security module address
   * @param _newSecurityModule The new security module address
   */
  function _updateSecurityModule(
    address _newSecurityModule
  ) internal {
    gateway.updateSecurityModule(_newSecurityModule);
  }

  /**
   * @notice Update the lighthouse address
   * @param _newLighthouse The new lighthouse address
   */
  function _updateLighthouse(
    address _newLighthouse
  ) internal validAddress(_newLighthouse) {
    address _oldLighthouse = lighthouse;
    lighthouse = _newLighthouse;
    emit LighthouseUpdated(_oldLighthouse, _newLighthouse);
  }

  /**
   * @notice Update the watchtower address
   * @param _newWatchtower The new watchtower address
   */
  function _updateWatchtower(
    address _newWatchtower
  ) internal validAddress(_newWatchtower) {
    address _oldWatchtower = watchtower;
    watchtower = _newWatchtower;

    emit WatchtowerUpdated(_oldWatchtower, _newWatchtower);
  }
}
