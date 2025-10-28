// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';
import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';

import {ISpokeStorageV5} from './ISpokeStorageV5.sol';

/**
 * @title IEverclearSpoke
 * @notice Interface for the EverclearSpoke contract
 */
interface IEverclearSpokeV5 is ISpokeStorageV5 {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters needed to execute a permit2
   * @param nonce The nonce of the permit
   * @param deadline The deadline of the permit
   * @param signature The signature of the permit
   */
  struct Permit2Params {
    uint256 nonce;
    uint256 deadline;
    bytes signature;
  }
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice emitted when a new intent is added on origin
   * @param _intentId The ID of the intent
   * @param _queueIdx The index of the intent in the IntentQueue
   * @param _intent The intent object
   */
  event IntentAdded(bytes32 indexed _intentId, uint256 _queueIdx, Intent _intent);

  /**
   * @notice emitted when an intent is filled on destination
   * @param _intentId The ID of the intent
   * @param _solver The address of the intent solver
   * @param _receiver The address of the intent receiver
   * @param _amountOut The total amount the user has been transferred
   * @param _queueIdx The index of the FillMessage in the FillQueue
   * @param _intent The full intent object
   */
  event IntentFilled(
    bytes32 indexed _intentId,
    address indexed _solver,
    bytes32 indexed _receiver,
    uint256 _amountOut,
    uint256 _queueIdx,
    Intent _intent
  );

  /**
   * @notice emitted when solver (or anyone) deposits an asset in the EverclearSpoke
   * @param _depositant The address of the depositant
   * @param _asset The address of the deposited asset
   * @param _amount The amount of the deposited asset
   */
  event Deposited(address indexed _depositant, address indexed _asset, uint256 _amount);

  /**
   * @notice emitted when solver (or anyone) withdraws an asset from the EverclearSpoke
   * @param _withdrawer The address of the withdrawer
   * @param _asset The address of the withdrawn asset
   * @param _amount The amount of the withdrawn asset
   */
  event Withdrawn(address indexed _withdrawer, address indexed _asset, uint256 _amount);

  /**
   * @notice Emitted when the intent queue is processed
   * @param _messageId The ID of the message
   * @param _firstIdx The first index of the queue to be processed
   * @param _lastIdx The last index of the queue to be processed
   * @param _quote The quote amount
   */
  event IntentQueueProcessed(bytes32 indexed _messageId, uint256 _firstIdx, uint256 _lastIdx, uint256 _quote);

  /**
   * @notice Emitted when the fill queue is processed
   * @param _messageId The ID of the message
   * @param _firstIdx The first index of the queue to be processed
   * @param _lastIdx The last index of the queue to be processed
   * @param _quote The quote amount
   */
  event FillQueueProcessed(bytes32 indexed _messageId, uint256 _firstIdx, uint256 _lastIdx, uint256 _quote);

  /**
   * @notice Emitted when an external call is executed
   * @param _intentId The ID of the intent
   * @param _returnData The return data of the call
   */
  event ExternalCalldataExecuted(bytes32 indexed _intentId, bytes _returnData);

  /**
   * @notice Emitted when feeAdapter is updated
   * @param _newFeeAdapter The new fee adapter
   */
  event FeeAdapterUpdated(address _newFeeAdapter);

  /**
   * @notice Emitted when fill signer is updated
   * @param _oldFillSigner The old fill signer
   * @param _newFillSigner The new fill signer
   */
  event FillSignerUpdated(address _oldFillSigner, address _newFillSigner);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the intent is already filled
   * @param _intentId The id of the intent which is being tried to fill
   */
  error EverclearSpoke_FillIntent_InvalidStatus(bytes32 _intentId);

  /**
   * @notice Thrown when trying to fill an expired intent
   * @param _intentId The id of the intent which is being tried to fill
   */
  error EverclearSpoke_FillIntent_IntentExpired(bytes32 _intentId);

  /**
   * @notice Thrown when calling newIntent with invalid intent parameters
   */
  error EverclearSpoke_NewIntent_InvalidIntent();

  /**
   * @notice Thrown when the ttl is non-zero and outputAsset is null
   */
  error EverclearSpoke_NewIntent_OutputAssetNull();

  /**
   * @notice Thrown when the destination array > 1 and outputAsset is not null
   */
  error EverclearSpoke_NewIntent_OutputAssetNotNull();

  /**
   * @notice Thrown when the maxFee is exceeded
   * @param _amountOut The amount sent by the solver
   * @param _amountOutMin The min amount out
   */
  error EverclearSpoke_FillIntent_AmountOutInvalid(uint256 _amountOut, uint256 _amountOutMin);

  /**
   * @notice Thrown when the intent amount is zero
   */
  error EverclearSpoke_NewIntent_ZeroAmount();

  /**
   * @notice Thrown when the solver doesnt have sufficient funds to fill an intent
   * @param _requested The amount of tokens needed to fill the intent
   * @param _available The amount of tokens the solver has deposited in the `EverclearSpoke`
   */
  error EverclearSpoke_FillIntent_InsufficientFunds(uint256 _requested, uint256 _available);

  /**
   * @notice Thrown when the destination array is empty
   */
  error EverclearSpoke_FillIntent_InvalidDestinationArray();

  /**
   * @notice Thrown when the intent calldata exceeds the limit
   */
  error EverclearSpoke_NewIntent_CalldataExceedsLimit();

  /**
   * @notice Thrown when a signature signer does not match the expected address
   */
  error EverclearSpoke_InvalidSignature();

  /**
   * @notice Thrown when the domain does not match the expected domain
   */
  error EverclearSpoke_ProcessFillViaRelayer_WrongDomain();

  /**
   * @notice Thrown when the relayer address does not match the msg.sender
   */
  error EverclearSpoke_ProcessFillViaRelayer_NotRelayer();

  /**
   * @notice Thrown when the TTL of the message has expired
   */
  error EverclearSpoke_ProcessFillViaRelayer_TTLExpired();

  /**
   * @notice Thrown when processing the intent queue and the intent is not found in the position specified in the parameter
   * @param _intentId The id of the intent being processed
   * @param _position The position specified by the queue processor
   */
  error EverclearSpoke_ProcessIntentQueue_NotFound(bytes32 _intentId, uint256 _position);

  /**
   * @notice Thrown when trying to execute the calldata of an intent with invalid status
   * @param _intentId The id of the intent whose calldata is trying to be executed
   */
  error EverclearSpoke_ExecuteIntentCalldata_InvalidStatus(bytes32 _intentId);

  /**
   * @notice Thrown when the external call failed on executeIntentCalldata
   */
  error EverclearSpoke_ExecuteIntentCalldata_ExternalCallFailed();

  /**
   * @notice Thrown when the queues are non-empty
   */
  error EverclearSpoke_Initialize_IntentQueueNotEmpty();

  /**
   * @notice Thrown when the queues are non-empty
   */
  error EverclearSpoke_Initialize_FillQueueNotEmpty();

  /**
   * @notice Thrown when the array length invalid in a batch fill
   */
  error EverclearSpoke_FillIntent_InvalidArrayLengths();

  /**
   * @notice Thrown when the fill signature is invalid
   */
  error EverclearSpoke_InvalidFillSignature();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Pauses the contract
   * @dev only the lighthouse and watchtower can pause the contract
   */
  function pause() external;

  /**
   * @notice Unpauses the contract
   * @dev only the lighthouse and watchtower can unpause the contract
   */
  function unpause() external;

  /**
   * @notice Sets a minting / burning strategy for an asset
   * @param _asset The asset address
   * @param _strategy The strategy id (see `enum Strategy`)
   */
  function setStrategyForAsset(
    address _asset,
    IEverclearV2.Strategy _strategy
  ) external;

  /**
   * @notice Sets a module for a strategy
   * @param _strategy The strategy id (see `enum Strategy`)
   * @param _module The module contract
   */
  function setModuleForStrategy(
    IEverclearV2.Strategy _strategy,
    ISettlementModule _module
  ) external;

  /**
   * @notice Updates the security module
   * @param _newSecurityModule The address of the new security module
   */
  function updateSecurityModule(
    address _newSecurityModule
  ) external;

  /**
   * @notice Update the fee adapter
   * @param _newFeeAdapter The address of the new fee adapter
   */
  function updateFeeAdapter(
    address _newFeeAdapter
  ) external;

  /**
   * @notice Initialize the EverclearSpoke contract
   */
  function initialize(
    address _feeAdapter,
    address _messageReceiver,
    address _fillSigner
  ) external;

  /**
   * @notice Creates a new intent
   * @param _destinations The possible destination chains of the intent
   * @param _receiver The destination address of the intent
   * @param _inputAsset The asset address on origin
   * @param _outputAsset The asset address on destination
   * @param _amount The amount of the asset
   * @param _amountOutMin The minimum amount out the solver should return
   * @param _ttl The time to live of the intent
   * @param _data The data of the intent
   * @return _intentId The ID of the intent
   * @return _intent The intent object
   */
  function newIntent(
    uint32[] memory _destinations,
    bytes32 _receiver,
    address _inputAsset,
    bytes32 _outputAsset,
    uint256 _amount,
    uint256 _amountOutMin,
    uint48 _ttl,
    bytes calldata _data
  ) external returns (bytes32 _intentId, Intent memory _intent);

  /**
   * @notice Creates a new intent
   * @param _destinations The possible destination chains of the intent
   * @param _receiver The destination address of the intent
   * @param _inputAsset The asset address on origin
   * @param _outputAsset The asset address on destination
   * @param _amount The amount of the asset
   * @param _amountOutMin The minimum amount out the solver should return
   * @param _ttl The time to live of the intent
   * @param _data The data of the intent
   * @return _intentId The ID of the intent
   * @return _intent The intent object
   */
  function newIntent(
    uint32[] memory _destinations,
    address _receiver,
    address _inputAsset,
    address _outputAsset,
    uint256 _amount,
    uint256 _amountOutMin,
    uint48 _ttl,
    bytes calldata _data
  ) external returns (bytes32 _intentId, Intent memory _intent);

  /**
   * @notice Fills a batch of intents
   * @param _intents The intents to fill
   * @param _amountOut The amounts of the assets the solver is sending to the users
   * @param _destinations The destinations for the repayment
   */
  function batchFillIntent(
    Intent[] calldata _intents,
    uint256[] calldata _amountOut,
    uint32[][] calldata _destinations,
    bytes calldata _signature
  ) external returns (FillMessage[] memory _fillMessages);

  /**
   * @notice Fills a batch of intents
   * @param _intents The intents to fill
   * @param _amountOut The amounts of the assets the solver is sending to the users
   * @param _destinations The destinations for the repayment
   */
  function batchFillIntentWithPull(
    Intent[] calldata _intents,
    uint256[] calldata _amountOut,
    uint32[][] calldata _destinations,
    bytes calldata _signature
  ) external returns (FillMessage[] memory _fillMessages);

  /**
   * @notice fills an intent
   * @param _intent The intent structure
   * @param _amountOut The amount of the asset the solver is sending to the user
   * @return _fillMessage The enqueued fill message
   */
  function fillIntent(
    Intent calldata _intent,
    uint256 _amountOut,
    uint32[] memory _destinations,
    bytes calldata _signature
  ) external returns (FillMessage memory _fillMessage);

  /**
   * @notice fills an intent pulling funds from callers wallet
   * @param _intent The intent structure
   * @param _amountOut The amount of the asset the solver is sending to the user
   * @return _fillMessage The enqueued fill message
   */
  function fillIntentWithPull(
    Intent calldata _intent,
    uint256 _amountOut,
    uint32[] memory _destinations,
    bytes calldata _signature
  ) external returns (FillMessage memory _fillMessage);

  /**
   * @notice Allows a relayer to fill an intent for a solver
   * @param _solver The address of the solver
   * @param _intent The intent structure
   * @param _nonce The nonce of the signature
   * @param _amountOut The amount of the asset the solver is sending to the user
   * @param _signature The solver signature
   * @return _fillMessage The enqueued fill message
   */
  function fillIntentForSolver(
    address _solver,
    Intent calldata _intent,
    uint256 _nonce,
    uint256 _amountOut,
    bytes32 _receiver,
    uint32[] memory _destinations,
    bytes calldata _signature,
    bool _pullFunds
  ) external returns (FillMessage memory _fillMessage);

  /**
   * @notice Process the intent queue messages to send a batched message to the transport layer
   * @param _intents The intents to process, must respect the intent queue order
   */
  function processIntentQueue(
    Intent[] calldata _intents
  ) external payable;

  /**
   * @notice Process the fill queue messages to send a batched message to the transport layer
   * @param _amount The amount of messages to process and batch
   */
  function processFillQueue(
    uint32 _amount
  ) external payable;

  /**
   * @notice Process the intent queue messages to send a batched message to the transport layer (via relayer)
   * @param _domain The domain of the message
   * @param _intents The intents to process, must respect the intent queue order
   * @param _relayer The address of the relayer
   * @param _ttl The time to live of the message
   * @param _nonce The nonce of the signature
   * @param _bufferDBPS The buffer in DBPS to add to the fee
   * @param _signature The signature of the data
   */
  function processIntentQueueViaRelayer(
    uint32 _domain,
    Intent[] calldata _intents,
    address _relayer,
    uint256 _ttl,
    uint256 _nonce,
    uint256 _bufferDBPS,
    bytes calldata _signature
  ) external;

  /**
   * @notice Process the fill queue messages to send a batched message to the transport layer (via relayer)
   * @param _domain The domain of the message
   * @param _amount The amount of messages to process and batch
   * @param _relayer The address of the relayer
   * @param _ttl The time to live of the message
   * @param _nonce The nonce of the signature
   * @param _bufferDBPS The buffer in DBPS to add to the fee
   * @param _signature The signature of the data
   */
  function processFillQueueViaRelayer(
    uint32 _domain,
    uint32 _amount,
    address _relayer,
    uint256 _ttl,
    uint256 _nonce,
    uint256 _bufferDBPS,
    bytes calldata _signature
  ) external;

  /**
   * @notice deposits an asset into the EverclearSpoke
   * @dev should be only called by solvers but it is permissionless, the funds will be used by the solvers to execute intents
   * @param _asset The address of the asset
   * @param _amount The amount of the asset
   */
  function deposit(
    address _asset,
    uint256 _amount
  ) external;

  /**
   * @notice withdraws an asset from the EverclearSpoke
   * @dev can be called by solvers or users
   * @param _asset The address of the asset
   * @param _amount The amount of the asset
   */
  function withdraw(
    address _asset,
    uint256 _amount
  ) external;

  /**
   * @notice Updates the gateway
   * @param _newGateway The address of the new gateway
   */
  function updateGateway(
    address _newGateway
  ) external;

  /**
   * @notice Updates the message receiver
   * @param _newMessageReceiver The address of the new message receiver
   */
  function updateMessageReceiver(
    address _newMessageReceiver
  ) external;

  /**
   * @notice Updates the max gas limit used for outgoing messages
   * @param _newGasLimit The new gas limit
   */
  function updateMessageGasLimit(
    uint256 _newGasLimit
  ) external;

  /**
   * @notice Updates the fill signer
   * @param _fillSigner The address of the new fill signer
   */
  function updateFillSigner(
    address _fillSigner
  ) external;

  /**
   * @notice Executes the calldata of an intent
   * @param _intent The intent object
   */
  function executeIntentCalldata(
    Intent calldata _intent
  ) external;
}
