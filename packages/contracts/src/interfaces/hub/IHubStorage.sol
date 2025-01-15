// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';

/**
 * @title IHubStorage
 * @notice Interface for the HubStorage contract
 * @dev once deployed, the storage contract layout should never be changed
 */
interface IHubStorage {
  /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Enum representing the roles of an account
   */
  enum Role {
    NONE,
    ASSET_MANAGER,
    ADMIN
  }

  /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Struct for the asset configuration for a domain.
   *
   * If the decimals are updated in a future token upgrade, the transfers should fail. If that happens, the
   * asset must be removed, and then they can be readded
   *
   * @param tickerHash Hash of the ticker symbol for the token eg. keccak256("DAI")
   * @param adopted Address of adopted asset on this domain
   * @param domain Domain of the asset
   * @param approval Allowed assets for the domain, whitelisted for use in the protocol
   * @param strategy The strategy for the asset
   */
  struct AssetConfig {
    bytes32 tickerHash;
    bytes32 adopted;
    uint32 domain;
    bool approval;
    IEverclear.Strategy strategy;
  }

  /**
   * @notice Struct for protocol fees
   * @dev Configured per-asset, iterated through on settlement
   *        Deducted from the DBPS * xcall amount -> solver should account for this when filling an intent
   * @param recipient The address of the recipient
   * @param fee The fee amount
   */
  struct Fee {
    address recipient;
    uint24 fee;
  }

  /**
   * @notice Struct for token configuration
   * @param maxDiscountDbps The maximum discount in DBPS that can be applied to the asset
   * @param discountPerEpoch The discount per epoch in DBPS
   * @param prioritizedStrategy The prioritized strategy for the token
   * @param fees Array of fees of the token
   * @param domains Set of domains supported by the protocol for the token
   * @param assetHashes Mapping of asset hashes for the token for each domain, to locate the asset for a domain with O(1)
   */
  struct TokenConfig {
    uint24 maxDiscountDbps;
    uint24 discountPerEpoch;
    IEverclear.Strategy prioritizedStrategy;
    Fee[] fees;
    Uint32Set.Set domains;
    mapping(uint32 _domain => bytes32 _assetHashes) assetHashes;
  }

  /**
   * @notice Struct for fees configuration used as read-only parameter to set bulk configuration
   * @param tickerHash Hash of the ticker symbol for the token eg. keccak256("DAI")
   * @param initLastClosedEpochProcessed Flag to indicate if the last closed epoch for the asset should be initialized with block.number / epochLength - 1
   * @param prioritizedStrategy The prioritized strategy for the token
   * @param maxDiscountDbps The maximum discount in DBPS that can be applied to the asset
   * @param discountPerEpoch The discount per epoch in DBPS
   * @param fees Array of fees of the token
   * @param adoptedForAssets Array of asset configurations for the token for each domain
   */
  struct TokenSetup {
    bytes32 tickerHash;
    bool initLastClosedEpochProcessed;
    IEverclear.Strategy prioritizedStrategy;
    uint24 maxDiscountDbps;
    uint24 discountPerEpoch;
    Fee[] fees;
    AssetConfig[] adoptedForAssets;
  }

  /**
   * @notice Struct for domain bulk configuration
   * @param id The id for the domain
   * @param blockGasLimit The block gas limit for the domain
   */
  struct DomainSetup {
    uint32 id;
    uint256 blockGasLimit;
  }

  /**
   * @notice Struct for settlement message gas configuration
   * @param settlementBaseGasUnits The amount of base gas units for a settlement message processing
   * @param averageGasUnitsPerSettlement The average amount of gas units per settlement message processed
   * @param bufferDBPS The gas buffer for relay on destination (in DBPS)
   */
  struct GasConfig {
    uint256 settlementBaseGasUnits;
    uint256 averageGasUnitsPerSettlement;
    uint256 bufferDBPS;
  }

  /**
   * @notice Struct representing a deposit
   * @param intentId The ID of the intent
   * @param purchasePower The purchase power of the deposit
   */
  struct Deposit {
    bytes32 intentId;
    uint256 purchasePower;
  }

  /**
   * @notice The structure of an invoice
   * @param intentId The ID of the intent
   * @param owner The address of the invoice owner
   * @param entryEpoch The epoch when the invoice was created and added to the queue
   * @param amount The amount of tokens the invoice is valid for
   * @dev The entryEpoch is used to determine the discount of the invoice in runtime
   * @dev The discount is calculated as (currentEpoch - entryEpoch) * discountPerEpoch
   * @dev The the invoice must be filled 100% within the same epoch
   */
  struct Invoice {
    bytes32 intentId;
    bytes32 owner;
    uint48 entryEpoch;
    uint256 amount;
  }

  /**
   * @notice Rich intent information
   * @param solver The address of the solver
   * @param fee The fee charged by the solver when filling the intent (solver fee + protocol fee) in DBPS
   * @param totalProtocolFee The total protocol fee of the intent
   * @param fillTimestamp The timestamp of the fill
   * @param amountAfterFees The amount after fees
   * @param pendingRewards The pending rewards
   * @param status The status of the intent
   * @param intent The intent object
   */
  struct IntentContext {
    bytes32 solver;
    uint24 fee;
    uint24 totalProtocolFee;
    uint256 fillTimestamp;
    uint256 amountAfterFees;
    uint256 pendingRewards;
    IEverclear.IntentStatus status;
    IEverclear.Intent intent;
  }

  /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a deposit is created and enqueued
   * @dev not all deposits are created and enqueued, they are created when the invoice queue for the tickerhash is not empty, otherwise is considered processed
   * @param _epoch The epoch of the deposit
   * @param _domain The domain of the deposit
   * @param _tickerHash The hash of the ticker symbol for the asset
   * @param _intentId The ID of the intent
   * @param _amount The amount of the deposit normalized to 18 decimals
   */
  event DepositEnqueued(
    uint48 indexed _epoch, uint32 indexed _domain, bytes32 indexed _tickerHash, bytes32 _intentId, uint256 _amount
  );

  /**
   * @notice Emitted when a deposit is processed
   * @dev when a deposit that arrives to the hub is not created because invoice queue for tickerhash is empty, the event is emitted also
   * @param _epoch The epoch of the deposit
   * @param _domain The domain of the deposit
   * @param _tickerHash The hash of the ticker symbol for the asset
   * @param _intentId The ID of the intent
   * @param _amountAndRewards The amount of the deposit + accumulatedRewards normalized to 18 decimals
   * @dev the rewards will be saved in pending rewards mapping and the final recipient will depend on the final owner of the deposit
   */
  event DepositProcessed(
    uint48 indexed _epoch,
    uint32 indexed _domain,
    bytes32 indexed _tickerHash,
    bytes32 _intentId,
    uint256 _amountAndRewards
  );

  /**
   * @notice Emitted when an invoice is enqueued
   * @param _intentId The ID of the intent
   * @param _tickerHash The hash of the ticker symbol for the asset
   * @param _entryEpoch The epoch when the invoice was created and added to the queue
   * @param _amount The amount of the invoice normalized to 18 decimals
   * @param _owner The address of the invoice owner
   */
  event InvoiceEnqueued(
    bytes32 indexed _intentId, bytes32 indexed _tickerHash, uint48 indexed _entryEpoch, uint256 _amount, bytes32 _owner
  );

  /**
   * @notice Emitted when a settlement is enqueued
   * @param _intentId The ID of the intent
   * @param _domain The domain of the settlement
   * @param _entryEpoch The epoch when the settlement was created and added to the queue
   * @param _asset The asset of the settlement
   * @param _amount The amount of the settlement normalized to 18 decimals
   * @param _updateVirtualBalance The flag to increase the virtual balance when message arrives to the destination
   * @param _owner The address of the settlement owner
   */
  event SettlementEnqueued(
    bytes32 indexed _intentId,
    uint32 indexed _domain,
    uint48 indexed _entryEpoch,
    bytes32 _asset,
    uint256 _amount,
    bool _updateVirtualBalance,
    bytes32 _owner
  );

  /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the contract is paused and the called function is protected
   */
  error HubStorage_Paused();

  /**
   * @notice Thrown when caller is not authorized to call the function
   */
  error HubStorage_Unauthorized();

  /**
   * @notice Thrown when the caller is not authorized to pause
   */
  error HubStorage_Pause_NotAuthorized();

  /**
   * @notice Thrown when caller is not the owner
   */
  error HubStorage_OnlyOwner();

  /**
   * @notice Thrown when the caller is not the lighthouse
   */
  error HubStorage_ProcessQueue_OnlyLighthouse();

  /**
   * @notice Thrown when the address is invalid
   */
  error HubStorage_InvalidAddress();

  /**
   * @notice Thrown when the signature is invalid
   */
  error HubStorage_InvalidSignature();

  /**
   * @notice Thrown when a value set in dbps is invalid or exceeds the DBPS_DENOMINATOR
   */
  error HubStorage_InvalidDbpsValue();

  /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice returns the typehash for `processQueueViaRelayer`
   * @return _typeHash The type hash of `processQueueViaRelayer`
   */
  function PROCESS_QUEUE_VIA_RELAYER_TYPEHASH() external view returns (bytes32 _typeHash);

  /**
   * @notice returns the initialization status
   * @return _initialized The boolean indicating that the contract was initialized
   */
  function initialized() external view returns (bool _initialized);

  /**
   * @notice returns the owner acceptance delay
   * @return _acceptanceDelay The delay required for the proposed owner to accept the contract ownership
   */
  function acceptanceDelay() external view returns (uint256 _acceptanceDelay);

  /**
   * @notice returns the configuration for an asset hash
   * @param _assetHash The address of the user
   * @return _config The configuration for the asset hash
   */
  function adoptedForAssets(
    bytes32 _assetHash
  ) external view returns (AssetConfig memory _config);

  /**
   * @notice returns the discount per epoch for an asset
   * @param _tickerHash The ticker hash
   * @return _discountPerEpoch The discount per epoch for the asset
   */
  function discountPerEpoch(
    bytes32 _tickerHash
  ) external view returns (uint24 _discountPerEpoch);

  /**
   * @notice returns the amount of tokens custodied for an asset and domain
   * @param _assetHash The address of the asset hash (ticker hash & domain)
   * @return _amount The amount of asset (asset + domain) custodied by the system
   */
  function custodiedAssets(
    bytes32 _assetHash
  ) external view returns (uint256 _amount);

  /**
   * @notice returns the deposits queue for an epoch, domain and asset
   * @param _epoch The epoch to get deposits from
   * @param _domain The domain to get deposits from
   * @param _tickerHash The ticker hash for the asset
   * @return _first The first position in the queue
   * @return _last The last position in the queue
   * @return _firstDepositWithPurchasePower The first deposit in the queue with purchase power remaining
   */
  function deposits(
    uint48 _epoch,
    uint32 _domain,
    bytes32 _tickerHash
  ) external view returns (uint256 _first, uint256 _last, uint256 _firstDepositWithPurchasePower);

  /**
   * @notice returns the amount of deposits for an epoch, domain and asset
   * @param _epoch The epoch to get deposits from
   * @param _domain The domain to get deposits from
   * @param _tickerHash The ticker hash for the asset
   * @return _deposited The total amount of deposits
   */
  function depositsAvailableInEpoch(
    uint48 _epoch,
    uint32 _domain,
    bytes32 _tickerHash
  ) external view returns (uint256 _deposited);

  /**
   * @notice returns the gas configuration for the settlement messages
   * @return _settlementBaseGasUnits The amount of base gas units for a settlement message processing
   * @return _averageGasUnitsPerSettlement The average amount of gas units per settlement message processed
   * @return _bufferDBPS The gas buffer for relay on destination (in DBPS)
   */
  function gasConfig()
    external
    view
    returns (uint256 _settlementBaseGasUnits, uint256 _averageGasUnitsPerSettlement, uint256 _bufferDBPS);

  /**
   * @notice returns the epoch length
   * @return _length The epoch length
   */
  function epochLength() external view returns (uint48 _length);

  /**
   * @notice returns the expiry time buffer
   * @return _expiry The expiry time buffer
   * @dev The correct configuration of this variable is crucial to prevent
   * double filling of an intent. If improperly set, this could allow
   * a malicious attacker to take advantage of messaging latency to get an
   * intent both filled by a solver and "slowly" settled by the system,
   * thus getting double the amount of asset and making the solver lose
   * their deposit.
   */
  function expiryTimeBuffer() external view returns (uint48 _expiry);

  /**
   * @notice returns the current payment nonce
   * @return _nonce The current payment nonce
   */
  function paymentNonce() external view returns (uint64 _nonce);

  /**
   * @notice returns the amount of fees accumulated by asset and fee recipient
   * @param _assetHash The asset hash
   * @param _recipient The fee recipient
   * @return _amount The amount of fees accumulated by an account
   */
  function feeVault(bytes32 _assetHash, address _recipient) external view returns (uint256 _amount);

  /**
   * @notice returns the `HubGateway`
   * @return _gateway The `HubGateway`
   */
  function hubGateway() external view returns (IHubGateway _gateway);

  /**
   * @notice returns the full intent context
   * @param _intentId The id of the intent
   * @return _intentContext The context for the intent
   */
  function contexts(
    bytes32 _intentId
  ) external view returns (IntentContext memory _intentContext);

  /**
   * @notice returns the invoice linked list for an assset
   * @param _tickerHash The ticker hash
   * @return _head The head of the linked list
   * @return _tail The tail of the linked list
   * @return _nonce The nonce of the linked list
   * @return _length The length of the linked list
   */
  function invoices(
    bytes32 _tickerHash
  ) external view returns (bytes32 _head, bytes32 _tail, uint256 _nonce, uint256 _length);

  /**
   * @notice returns the lighthouse address
   * @return _lighthouse The address of the Lighthouse agent
   */
  function lighthouse() external view returns (address _lighthouse);

  /**
   * @notice returns the minimum amount of domains a solver must support
   * @return _domainsAmount The mininum amount of domains a solver must support
   */
  function minSolverSupportedDomains() external view returns (uint8 _domainsAmount);

  /**
   * @notice returns the module address for a module type
   * @param _moduleType The hash of the module type
   * @return _module The address of the module
   */
  function modules(
    bytes32 _moduleType
  ) external view returns (address _module);

  /**
   * @notice returns the owner address
   * @return _owner The address of the owner
   */
  function owner() external view returns (address _owner);

  /**
   * @notice returns the pause status
   * @return _paused The boolean indicating if the contract is paused
   */
  function paused() external view returns (bool _paused);

  /**
   * @notice returns the current proposed owner
   * @return _proposedOwner The address of the proposed owner
   */
  function proposedOwner() external view returns (address _proposedOwner);

  /**
   * @notice returns the current proposed ownership timestamp
   * @return _timestamp The timestamp on which a new owner was proposed
   */
  function proposedOwnershipTimestamp() external view returns (uint256 _timestamp);

  /**
   * @notice returns the role for an account
   * @param _account The address of the account
   * @return _role The role the account has
   */
  function roles(
    address _account
  ) external view returns (Role _role);

  /**
   * @notice returns the settlement queue for a domain
   * @param _domain The domain id to get the queue for
   * @return _first The index for the first item of the queue
   * @return _last The index for the last item of the queue
   */
  function settlements(
    uint32 _domain
  ) external view returns (uint256 _first, uint256 _last);

  /**
   * @notice returns the block gas limit for a domain
   * @param _domain The domain id to get the block gas limit for
   * @return _blockGasLimit The block gas limit for the domain
   */
  function domainGasLimit(
    uint32 _domain
  ) external view returns (uint256 _blockGasLimit);

  /**
   * @notice returns the watchtower address
   * @return _watchtower The address of the Watchtower agent
   */
  function watchtower() external view returns (address _watchtower);

  /**
   * @notice returns the token config fields for a ticker hash
   * @param _tickerHash The ticker hash
   * @return _maxDiscountDbps The maximum discount in DBPS that can be applied to the asset
   * @return _discountPerEpoch The discount per epoch in DBPS
   * @return _prioritizedStrategy The prioritized strategy for the token
   */
  function tokenConfigs(
    bytes32 _tickerHash
  ) external view returns (uint24 _maxDiscountDbps, uint24 _discountPerEpoch, IEverclear.Strategy _prioritizedStrategy);

  /**
   * @notice returns the configured fees for an asset
   * @param _tickerHash The ticker hash
   * @return _fees The configured fees for the asset
   */
  function tokenFees(
    bytes32 _tickerHash
  ) external view returns (Fee[] memory _fees);

  /**
   * @notice returns the asset hash for an asset and domain
   * @param _tickerHash The ticker hash
   * @param _domain The domain to get the adopted from
   * @return _assetHash The hash for the domain specific asset
   */
  function assetHash(bytes32 _tickerHash, uint32 _domain) external view returns (bytes32 _assetHash);

  /**
   * @notice returns the current epoch
   * @return _currentEpoch The current epoch
   */
  function getCurrentEpoch() external view returns (uint48 _currentEpoch);
}
