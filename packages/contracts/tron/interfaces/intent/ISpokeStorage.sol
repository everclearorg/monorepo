// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IPermit2} from 'interfaces/common/IPermit2.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';
import {ICallExecutor} from 'interfaces/intent/ICallExecutor.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';

/**
 * @title ISpokeStorage
 * @notice Interface for the SpokeStorage contract
 */
interface ISpokeStorage is IEverclear {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Parameters needed to initiliaze `EverclearSpoke`
   * @param gateway The local `SpokeGateway`
   * @param callExecutor The local `CallExecutor`
   * @param messageReceiver The address for the `SpokeMessageReceiver` module
   * @param lighthouse The address for the Lighthouse agent
   * @param watchtower The address for the Watchtower agent
   * @param hubDomain The chain id for the Everclear domain
   * @param owner The initial owner of the contract
   */
  struct SpokeInitializationParams {
    ISpokeGateway gateway;
    ICallExecutor callExecutor;
    address messageReceiver;
    address lighthouse;
    address watchtower;
    uint32 hubDomain;
    address owner;
  }

  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice emitted when the Gateway address is updated
   * @param _oldGateway The address of the old gateway
   * @param _newGateway The address of the new gateway
   */
  event GatewayUpdated(address _oldGateway, address _newGateway);

  /**
   * @notice emitted when the Lighthouse address is updated
   * @param _oldLightHouse The address of the old lighthouse
   * @param _newLightHouse The address of the new lighthouse
   */
  event LighthouseUpdated(address _oldLightHouse, address _newLightHouse);

  /**
   * @notice emitted when the Watchtower address is updated
   * @param _oldWatchtower The address of the old watchtower
   * @param _newWatchtower The address of the new watchtower
   */
  event WatchtowerUpdated(address _oldWatchtower, address _newWatchtower);

  /**
   * @notice emitted when the MessageReceiver address is updated
   * @param _oldMessageReceiver The address of the old message receiver
   * @param _newMessageReceiver The address of the new message receiver
   */
  event MessageReceiverUpdated(address _oldMessageReceiver, address _newMessageReceiver);

  /**
   * @notice emitted when messageGasLimit is updated
   * @param _oldGasLimit The old gas limit
   * @param _newGasLimit The new gas limit
   */
  event MessageGasLimitUpdated(uint256 _oldGasLimit, uint256 _newGasLimit);

  /**
   * @notice emitted when the protocol is paused (domain-level)
   */
  event Paused();

  /**
   * @notice emitted when the protocol is paused (domain-level)
   */
  event Unpaused();

  /**
   * @notice emitted when a strategy is set for an asset
   * @param _asset The address of the asset being configured
   * @param _strategy The id for the strategy (see `enum Strategy`)
   */
  event StrategySetForAsset(address _asset, IEverclear.Strategy _strategy);

  /**
   * @notice emitted when the module is set for a strategy
   * @param _strategy The id for the strategy (see `enum Strategy`)
   * @param _module The settlement module
   */
  event ModuleSetForStrategy(IEverclear.Strategy _strategy, ISettlementModule _module);

  /**
   * @notice emitted when the EverclearSpoke processes a settlement
   * @param _intentId The ID of the intent
   * @param _account The address of the account
   * @param _asset The address of the asset
   * @param _amount The amount of the asset
   */
  event Settled(bytes32 indexed _intentId, address _account, address _asset, uint256 _amount);

  /**
   * @notice emitted when `_handleSettlement` fails to transfer tokens to a user (eg. blacklisted recipient)
   * @param _asset The address of the asset
   * @param _recipient The address of the recipient
   * @param _amount The amount of the asset
   */
  event AssetTransferFailed(address indexed _asset, address indexed _recipient, uint256 _amount);

  /**
   * @notice emitted when `_handleSettlement` fails to mint the non-default stategy asset
   * @param _asset The address of the asset
   * @param _recipient The address of the recipient
   * @param _amount The amount of the asset
   * @param _strategy The strategy used for the asset
   */
  event AssetMintFailed(address indexed _asset, address indexed _recipient, uint256 _amount, Strategy _strategy);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the spoke is receiving a message from an address that is not the authorized gateway, admin or owner
   */
  error EverclearSpoke_Unauthorized();

  /**
   * @notice Thrown when a message is not a valid message type
   */
  error EverclearSpoke_InvalidMessageType();

  /**
   * @notice Thrown when the destination is wrong
   */
  error EverclearSpoke_WrongDestination();

  /**
   * @notice Thrown when a variable update is invalid
   */
  error EverclearSpoke_InvalidVarUpdate();

  /**
   * @notice Thrown when calling to a processQueue method with a zero amount
   */
  error EverclearSpoke_ProcessQueue_ZeroAmount();

  /**
   * @notice Thrown when calling to a processQueue method with an invalid amount
   * @param _first The index of the first element of the queue
   * @param _last The index of the last element of the queue
   * @param _amount The amount of items being tried to process
   */
  error EverclearSpoke_ProcessQueue_InvalidAmount(uint256 _first, uint256 _last, uint256 _amount);

  /**
   * @notice Thrown when calling a function with the zero address
   */
  error EverclearSpoke_ZeroAddress();

  /**
   * @notice Thrown when a function is called when the spoke is paused
   */
  error EverclearSpoke_Paused();

  /**
   * @notice Thrown when the caller is not authorized to pause the spoke
   */
  error EverclearSpoke_Pause_NotAuthorized();

  /*///////////////////////////////////////////////////////////////
                              VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice returns the typehash for `fillIntentForSolver`
   * @return _typeHash The `fillIntentForSolver` type hash
   */
  function FILL_INTENT_FOR_SOLVER_TYPEHASH() external view returns (bytes32 _typeHash);

  /**
   * @notice returns the typehash for `processIntentQueueViaRelayer`
   * @return _typeHash The `processIntentQueueViaRelayer` type hash
   */
  function PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH() external view returns (bytes32 _typeHash);

  /**
   * @notice returns the typehash for `processFillQueueViaRelayer`
   * @return _typeHash The `processFillQueueViaRelayer` type hash
   */
  function PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH() external view returns (bytes32 _typeHash);

  /**
   * @notice returns the permit2 contract
   * @return _permit2 The Permit2 singleton address
   */
  function PERMIT2() external view returns (IPermit2 _permit2);

  /**
   * @notice returns the domain id for the Everclear rollup
   * @return _domain The id of the Everclear domain
   */
  function EVERCLEAR() external view returns (uint32 _domain);

  /**
   * @notice returns the current domain
   * @return _domain The id of the current domain
   */
  function DOMAIN() external view returns (uint32 _domain);

  /**
   * @notice returns the lighthouse address
   * @return _lighthouse The address of the Lighthouse agent
   */
  function lighthouse() external view returns (address _lighthouse);

  /**
   * @notice returns the watchtower address
   * @return _watchtower The address of the Watchtower agent
   */
  function watchtower() external view returns (address _watchtower);

  /**
   * @notice returns the message receiver address
   * @return _messageReceiver The address of the `SpokeMessageReceiver`
   */
  function messageReceiver() external view returns (address _messageReceiver);

  /**
   * @notice returns the gateway
   * @return _gateway The local `SpokeGateway`
   */
  function gateway() external view returns (ISpokeGateway _gateway);

  /**
   * @notice returns the call executor
   * @return _callExecutor The local `CallExecutor`
   */
  function callExecutor() external view returns (ICallExecutor _callExecutor);

  /**
   * @notice returns the paused status of the spoke
   * @return _paused The boolean indicating if the contract is paused
   */
  function paused() external view returns (bool _paused);

  /**
   * @notice returns the current intent nonce
   * @return _nonce The current nonce
   */
  function nonce() external view returns (uint64 _nonce);

  /**
   * @notice returns the gas limit used for outgoing messages
   * @return _messageGasLimit the max gas limit
   */
  function messageGasLimit() external view returns (uint256 _messageGasLimit);

  /**
   * @notice returns the balance of an asset for a user
   * @param _asset The address of the asset
   * @param _user The address of the user
   * @return _amount The amount of assets locked in the contract
   */
  function balances(bytes32 _asset, bytes32 _user) external view returns (uint256 _amount);

  /**
   * @notice returns the status of an intent
   * @param _intentId The ID of the intent
   * @return _status The status of the intent
   */
  function status(
    bytes32 _intentId
  ) external view returns (IntentStatus _status);

  /**
   * @notice returns the configured strategy id for an asset
   * @param _asset The address of the asset
   * @return _strategy The strategy for the asset
   */
  function strategies(
    address _asset
  ) external view returns (IEverclear.Strategy _strategy);

  /**
   * @notice returns the module address for a strategy
   * @param _strategy The strategy id
   * @return _module The strategy module
   */
  function modules(
    IEverclear.Strategy _strategy
  ) external view returns (ISettlementModule _module);
}
