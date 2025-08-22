// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {NoncesUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol';

import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';

import {HubQueueLibV2} from 'contracts/hub/lib/HubQueueLibV2.sol';
import {InvoiceListLibV2} from 'contracts/hub/lib/InvoiceListLibV2.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {console2} from 'forge-std/console2.sol';
import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {IHubStorageV2} from 'interfaces/hub/IHubStorageV2.sol';

abstract contract HubStorageV2 is NoncesUpgradeable, IHubStorageV2 {
  using InvoiceListLibV2 for InvoiceListLibV2.InvoiceList;
  using HubQueueLibV2 for HubQueueLibV2.DepositQueue;
  using HubQueueLibV2 for HubQueueLibV2.SettlementQueue;
  using Uint32Set for Uint32Set.Set;

  /**
   * @notice The module type hash for the settlement module
   */
  bytes32 internal constant _SETTLEMENT_MODULE = keccak256('settlement_module');

  /**
   * @notice The module type hash for the handler module
   */
  bytes32 internal constant _HANDLER_MODULE = keccak256('handler_module');

  /**
   * @notice The module type hash for the message receiver module
   */
  bytes32 internal constant _MESSAGE_RECEIVER_MODULE = keccak256('message_receiver_module');

  /**
   * @notice The module type hash for the manager module
   */
  bytes32 internal constant _MANAGER_MODULE = keccak256('manager_module');

  /**
   * @notice The type hash for protocol payment
   */
  bytes32 internal constant _PROTOCOL_PAYMENT = keccak256('protocol_payment');

  /// @inheritdoc IHubStorageV2
  bytes32 public constant PROCESS_QUEUE_VIA_RELAYER_TYPEHASH = keccak256(
    'function processQueueViaRelayer(uint32 _domain, uint32 _amount, address _relayer, uint256 _ttl, uint256 _nonce, uint256 _bufferDBPS, bytes calldata _signature)'
  );

  /// @inheritdoc IHubStorageV2
  address public owner;

  /// @inheritdoc IHubStorageV2
  address public proposedOwner;

  /// @inheritdoc IHubStorageV2
  address public lighthouse;

  /// @inheritdoc IHubStorageV2
  address public watchtower;

  /// @inheritdoc IHubStorageV2
  IHubGateway public hubGateway;

  /// @inheritdoc IHubStorageV2
  bool public initialized;

  /// @inheritdoc IHubStorageV2
  bool public paused;

  /// @inheritdoc IHubStorageV2
  uint8 public minSolverSupportedDomains;

  /// @inheritdoc IHubStorageV2
  uint48 public epochLength;

  /// @inheritdoc IHubStorageV2
  uint48 public expiryTimeBuffer;

  /**
   * @notice The _carryEpoch will be used to store the carry-over epoch, preventing the repetition of previous epochs when the epoch length is updated to a smaller value. It will also store the elapsed epochs from the old configuration. This ensures that the current epoch will always increase and progress in a unidirectional manner, independent of the epoch length
   */
  uint48 internal _carryEpoch;

  /// @inheritdoc IHubStorageV2
  uint64 public paymentNonce;

  /**
   * @notice The last block number when the carry epoch was updated
   */
  uint256 internal _lastBlockNumberCarryEpochUpdated;

  /// @inheritdoc IHubStorageV2
  uint256 public acceptanceDelay;

  /// @inheritdoc IHubStorageV2
  uint256 public proposedOwnershipTimestamp;

  /// @inheritdoc IHubStorageV2
  mapping(address _account => Role _role) public roles;

  /**
   * @notice The supported domains for a users and solvers
   */
  mapping(bytes32 _user => Uint32Set.Set _supportedDomains) internal _usersSupportedDomains;

  /**
   * @notice If set to true, the settlement will not be transferred to the recipient in spoke domain and the virtual balance will be increased
   */
  mapping(bytes32 _user => bool _updateVirtualBalance) public updateVirtualBalance;

  /// @inheritdoc IHubStorageV2
  mapping(bytes32 _tickerHash => mapping(address _recipient => uint256 _amount)) public feeVault;

  /**
   * @notice The configuration for an adpoted asset
   */
  mapping(bytes32 _assetHash => AssetConfig _config) internal _adoptedForAssets;

  /**
   * @notice The configuration for an asset
   */
  mapping(bytes32 _tickerHash => TokenConfig _tokenConfig) internal _tokenConfigs;

  /**
   * @notice The last processed epoch for a ticker used to clean up and close deposits for previous epochs
   */
  mapping(bytes32 _tickerHash => uint48 _lastClosedEpochProcessed) public lastClosedEpochsProcessed;

  /// @inheritdoc IHubStorageV2
  mapping(bytes32 _assetHash => uint256 _amount) public custodiedAssets;

  /**
   * @notice The context for an intent
   */
  mapping(bytes32 _intentId => DeprecatedIntentContext _intentContext) internal _deprecatedContexts;

  /// @inheritdoc IHubStorageV2
  mapping(bytes32 _tickerHash => InvoiceListLibV2.InvoiceList _invoiceList) public invoices;

  /// @inheritdoc IHubStorageV2
  mapping(uint32 _domain => HubQueueLibV2.SettlementQueue _settlementQueue) public settlements;

  /// @inheritdoc IHubStorageV2
  mapping(uint32 _domain => uint256 _blockGasLimit) public domainGasLimit;

  /// @inheritdoc IHubStorageV2
  mapping(uint48 _epoch => mapping(uint32 _domain => mapping(bytes32 _tickerHash => uint256 _available))) public
    depositsAvailableInEpoch;

  /// @inheritdoc IHubStorageV2
  mapping(
    uint48 _epoch => mapping(uint32 _domain => mapping(bytes32 _tickerHash => HubQueueLibV2.DepositQueue _depositQueue))
  ) public deposits;

  /**
   * @notice The set of domains supported by Everclear
   */
  Uint32Set.Set internal _supportedDomains;

  /// @inheritdoc IHubStorageV2
  GasConfig public gasConfig;

  /// @inheritdoc IHubStorageV2
  mapping(bytes32 _moduleType => address _module) public modules;

  /**
   * **********************  Swap Upgrade  **********************
   */
  /**
   * @notice The context for an intent
   */
  mapping(bytes32 _intentId => IntentContext _intentContext) internal _contexts;

  /**
   * @notice Check that the caller has a specific role
   * @param _role The role to check
   */
  modifier hasRole(
    Role _role
  ) {
    if (roles[msg.sender] != _role && msg.sender != owner) {
      revert HubStorage_Unauthorized();
    }
    _;
  }

  /**
   * @notice Check that the caller is the owner
   */
  modifier onlyOwner() {
    if (msg.sender != owner) {
      revert HubStorage_OnlyOwner();
    }
    _;
  }

  /**
   * @notice Check that the caller is the gateway, the owner or an admin
   */
  modifier onlyAuthorized() {
    if (msg.sender != owner && roles[msg.sender] != Role.ADMIN && (msg.sender != address(hubGateway) || paused)) {
      revert HubStorage_Unauthorized();
    }
    _;
  }

  /**
   * @notice Check that the function is called by the lighthouse
   */
  modifier onlyLighthouse() {
    if (msg.sender != lighthouse) {
      revert HubStorage_ProcessQueue_OnlyLighthouse();
    }
    _;
  }

  /**
   * @notice Check that the caller is authorized to pause the contract
   */
  modifier pauseAuthorized() {
    if (msg.sender != owner && msg.sender != watchtower) {
      revert HubStorage_Pause_NotAuthorized();
    }
    _;
  }

  /**
   * @notice Check that the address is valid
   * @param _address The address to check
   */
  modifier validAddress(
    address _address
  ) {
    if (_address == address(0)) {
      revert HubStorage_InvalidAddress();
    }
    _;
  }

  /**
   * @notice Check that the contract is not paused
   */
  modifier whenNotPaused() {
    if (paused) {
      revert HubStorage_Paused();
    }
    _;
  }

  /// @inheritdoc IHubStorageV2
  function contexts(
    bytes32 _intentId
  ) external view returns (IntentContext memory _intentContext) {
    _intentContext = _contexts[_intentId];
  }

  /// @inheritdoc IHubStorageV2
  function adoptedForAssets(
    bytes32 _assetHash
  ) external view returns (AssetConfig memory _config) {
    _config = _adoptedForAssets[_assetHash];
  }

  /// @inheritdoc IHubStorageV2
  function tokenFees(
    bytes32 _tickerHash
  ) external view returns (Fee[] memory _fees) {
    return _tokenConfigs[_tickerHash].fees;
  }

  /// @inheritdoc IHubStorageV2
  function assetHash(bytes32 _tickerHash, uint32 _domain) external view returns (bytes32 _assetHash) {
    return _tokenConfigs[_tickerHash].assetHashes[_domain];
  }

  /// @inheritdoc IHubStorageV2
  function discountPerEpoch(
    bytes32 _tickerHash
  ) external view returns (uint24 _discountPerEpoch) {
    return _tokenConfigs[_tickerHash].discountPerEpoch;
  }

  /// @inheritdoc IHubStorageV2
  function tokenConfigs(
    bytes32 _tickerHash
  )
    external
    view
    returns (uint24 _maxDiscountDbps, uint24 _discountPerEpoch, IEverclearV2.Strategy _prioritizedStrategy)
  {
    TokenConfig storage _tokenConfig = _tokenConfigs[_tickerHash];
    return (_tokenConfig.maxDiscountDbps, _tokenConfig.discountPerEpoch, _tokenConfig.prioritizedStrategy);
  }

  /// @inheritdoc IHubStorageV2
  function getCurrentEpoch() public view returns (uint48 _currentEpoch) {
    console2.log('Logs');
    console2.log(_carryEpoch);
    console2.log(block.number);
    console2.log(_lastBlockNumberCarryEpochUpdated);
    console2.log(epochLength);

    _currentEpoch = _carryEpoch + uint48((block.number - _lastBlockNumberCarryEpochUpdated) / epochLength);
  }
}
