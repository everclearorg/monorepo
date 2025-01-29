// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

/**
 * @title IProtocolManager
 * @notice Interface for the ProtocolManager contract
 */
interface IProtocolManager {
  /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a new owner is proposed
   * @param _proposedOwner The address of the proposed owner
   * @param _timestamp The timestamp of the proposal
   */
  event OwnershipProposed(address indexed _proposedOwner, uint256 _timestamp);

  /**
   * @notice Emitted when the proposed owner accepts the ownership
   * @param _oldOwner The address of the old owner
   * @param _newOwner The address of the new owner
   */
  event OwnershipTransferred(address indexed _oldOwner, address indexed _newOwner);

  /**
   * @notice Emitted when the contract is paused
   */
  event Paused();

  /**
   * @notice Emitted when the contract is unpaused
   */
  event Unpaused();

  /**
   * @notice Emitted when a role is assigned to an account
   * @param _account The address being assigned the role
   * @param _role The role
   */
  event RoleAssigned(address indexed _account, IHubStorage.Role _role);

  /**
   * @notice Emitted when the lighthouse address is updated
   * @param _oldLighthouse The old lighthouse address
   * @param _newLighthouse The new lighthouse address
   * @param _messageIds The message IDs of the update messages
   */
  event LighthouseUpdated(address _oldLighthouse, address _newLighthouse, bytes32[] _messageIds);

  /**
   * @notice Emitted when the watchtower address is updated
   * @param _oldWatchtower The old watchtower address
   * @param _newWatchtower The new watchtower address
   * @param _messageIds The message IDs of the update messages
   */
  event WatchtowerUpdated(address _oldWatchtower, address _newWatchtower, bytes32[] _messageIds);

  /**
   * @notice Emitted when the acceptance delay is updated
   * @param _oldAcceptanceDelay The old acceptance delay
   * @param _newAcceptanceDelay The new acceptance delay
   */
  event AcceptanceDelayUpdated(uint256 _oldAcceptanceDelay, uint256 _newAcceptanceDelay);

  /**
   * @notice Emitted when new supported domains are added
   * @param _domains The domains added
   */
  event SupportedDomainsAdded(IHubStorage.DomainSetup[] _domains);

  /**
   * @notice Emitted when a list of supported domains is removed
   * @param _domains The domains removed
   */
  event SupportedDomainsRemoved(uint32[] _domains);

  /**
   * @notice Emitted when the minimum supported domains for solver configs is updated
   * @param _oldMinSolverSupportedDomains The old minimum supported domains for solver configs
   * @param _newMinSolverSupportedDomains The new minimum supported domains for solver configs
   */
  event MinSolverSupportedDomainsUpdated(uint8 _oldMinSolverSupportedDomains, uint8 _newMinSolverSupportedDomains);

  /**
   * @notice Emitted when the expiry time buffer for intents is updated
   * @param _oldExpiryTimeBuffer The old expiry time buffer
   * @param _newExpiryTimeBuffer The new expiry time buffer
   */
  event ExpiryTimeBufferUpdated(uint48 _oldExpiryTimeBuffer, uint48 _newExpiryTimeBuffer);

  /**
   * @notice Emitted when the epoch length is updated
   * @param _oldEpochLength The old epoch length
   * @param _newEpochLength The new epoch length
   */
  event EpochLengthUpdated(uint48 _oldEpochLength, uint48 _newEpochLength);

  /**
   * @notice Emitted when the gas configuration is updated
   * @param _oldGasConfig The old gas config
   * @param _newGasConfig The new gas config
   */
  event GasConfigUpdated(IHubStorage.GasConfig _oldGasConfig, IHubStorage.GasConfig _newGasConfig);
  /**
   * @notice Emitted when the gateway address is updated
   * @param _oldGateway The old gateway address
   * @param _newGateway The new gateway address
   */
  event GatewayUpdated(address _oldGateway, address _newGateway);

  /**
   * @notice Emitted when the mailbox address is updated
   * @param _mailbox The new mailbox address
   * @param _domains The domains being updated
   * @param _messageIds The message IDs of the update messages
   */
  event MailboxUpdated(bytes32 _mailbox, uint32[] _domains, bytes32[] _messageIds);

  /**
   * @notice Emitted when the Gateway address is updated
   * @param _gateway The new gateway address
   * @param _domains The domains being updated
   * @param _messageIds The message IDs of the update messages
   */
  event GatewayUpdated(bytes32 _gateway, uint32[] _domains, bytes32[] _messageIds);

  /**
   * @notice Emitted when the security module address is updated
   * @param _securityModule The new security module address
   * @param _domains The domains being updated
   * @param _messageIds The message IDs of the update messages
   */
  event SecurityModuleUpdated(address _securityModule, uint32[] _domains, bytes32[] _messageIds);

  /**
   * @notice Emitted when the maximum discount dbps is set
   * @param _tickerHash The asset ticker hash
   * @param _oldMaxDiscountDbps The old maximum discount dbps
   * @param _newMaxDiscountDbps The new maximum discount dbps
   */
  event MaxDiscountDbpsSet(bytes32 _tickerHash, uint24 _oldMaxDiscountDbps, uint24 _newMaxDiscountDbps);

  /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when caller is not authorized to call the function
   */
  error ProtocolManager_Unauthorized();

  /**
   * @notice Thrown when the role does not exist
   */
  error ProtocolManager_InvalidRole();

  /**
   * @notice Thrown when the delay for accepting new ownership is not elapsed
   */
  error ProtocolManager_AcceptOwnership_DelayNotElapsed();

  /**
   * @notice Thrown when the ownership is not accepted by the proposed owner
   */
  error ProtocolManager_AcceptOwnership_NotProposedOwner();

  /**
   * @notice Thrown when the supportedDomain is already added
   * @param _domain The already supported domain id
   */
  error ProtocolManager_AddSupportedDomains_SupportedDomainAlreadyAdded(uint32 _domain);

  /**
   * @notice Thrown when the supportedDomain is not found
   * @param _domain The unsupported domain id
   */
  error ProtocolManager_RemoveSupportedDomains_SupportedDomainNotFound(uint32 _domain);

  /**
   * @notice Thrown when trying to set an invalid max discount dbps
   */
  error ProtocolManager_SetMaxDiscountDbps_InvalidDiscount();

  /**
   * @notice Thrown when trying to update the epoch length to an invalid value
   */
  error ProtocolManager_UpdateEpochLength_InvalidEpochLength();

  /*//////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Proposes a new contract owner
   * @dev Can only be called by the current owner
   * @param _newOwner Address of the proposed new owner
   */
  function proposeOwner(
    address _newOwner
  ) external;

  /**
   * @notice Accepts the role of owner for the contract
   * @dev Can only be called by the proposed owner
   */
  function acceptOwnership() external;

  /**
   * @notice Updates the lighthouse address
   * @dev Can only be called by the owner
   * @param _lighthouse Address of the new lighthouse
   */
  function updateLighthouse(
    address _lighthouse
  ) external payable;

  /**
   * @notice Updates the watchtower address
   * @dev Can only be called by the owner
   * @param _watchtower Address of the new watchtower
   */
  function updateWatchtower(
    address _watchtower
  ) external payable;

  /**
   * @notice Updates the delay for accepting new ownership
   * @dev Can only be called by the owner
   * @param _acceptanceDelay New delay for accepting ownership
   */
  function updateAcceptanceDelay(
    uint256 _acceptanceDelay
  ) external;

  /**
   * @notice Assigns a role to an account
   * @dev Requires the caller to have the ADMIN role
   * @param _account Address of the account receiving the role
   * @param _role Role being assigned
   */
  function assignRole(address _account, IHubStorage.Role _role) external;

  /**
   * @notice Adds a list of supported domains
   * @dev Requires the caller to have the OWNER role
   * @param _domains The domains being added and their block gas limit
   */
  function addSupportedDomains(
    IHubStorage.DomainSetup[] calldata _domains
  ) external;

  /**
   * @notice Removes a list of supported domains
   * @dev Requires the caller to have the ONWER role
   * @param _domains The domains being removed
   */
  function removeSupportedDomains(
    uint32[] calldata _domains
  ) external;

  /**
   * @notice Pauses the contract, disabling certain operations
   * @dev Can only be called by authorized addresses (owner or lighthouse)
   */
  function pause() external;

  /**
   * @notice Unpauses the contract, enabling all operations
   * @dev Can only be called by authorized addresses (owner or lighthouse)
   */
  function unpause() external;

  /**
   * @notice Updates the minimum supported domains for solver configs
   * @dev Can only be called by the owner
   * @param _newMinSolverSupportedDomains The new minimum supported domains for solver configs
   */
  function updateMinSolverSupportedDomains(
    uint8 _newMinSolverSupportedDomains
  ) external;

  /**
   * @notice Updates the mailbox address in the hub gateway
   * @dev Can only be called by the owner
   * @param _mailbox Address of the new mailbox
   */
  function updateMailbox(
    address _mailbox
  ) external;

  /**
   * @notice Updates the mailbox address for a list of domains
   * @dev Can only be called by the owner
   * @param _mailbox Address of the new mailbox
   * @param _domains The domains being updated
   */
  function updateMailbox(bytes32 _mailbox, uint32[] calldata _domains) external payable;

  /**
   * @notice Updates the security module address
   * @dev Can only be called by the owner
   * @param _securityModule Address of the new security module
   */
  function updateSecurityModule(
    address _securityModule
  ) external;

  /**
   * @notice Updates the gateway address
   * @dev Can only be called by the owner
   * @param _newGateway Address of the new gateway
   */
  function updateGateway(
    address _newGateway
  ) external;

  /**
   * @notice Updates the gateway address for a list of domains
   * @dev Can only be called by the owner
   * @param _newGateway Address of the new gateway
   * @param _domains The domains being updated
   */
  function updateGateway(bytes32 _newGateway, uint32[] calldata _domains) external payable;

  /**
   * @notice Updates the gateway address for a chainId
   * @dev Can only be called by the owner
   * @param _chainId The chain ID
   * @param _gateway Address of the new gateway
   */
  function updateChainGateway(uint32 _chainId, bytes32 _gateway) external;

  /**
   * @notice Removes the gateway address for a chainId
   * @dev Can only be called by the owner
   * @param _chainId The chain ID
   */
  function removeChainGateway(
    uint32 _chainId
  ) external;

  /**
   * @notice Updates the expiry time buffer for intents
   * @dev Can only be called by the owner
   * @param _newExpiryTimeBuffer The new expiry time buffer
   */
  function updateExpiryTimeBuffer(
    uint48 _newExpiryTimeBuffer
  ) external;

  /**
   * @notice Updates the epoch length
   * @dev Can only be called by the owner
   * @param _newEpochLength The new epoch length
   */
  function updateEpochLength(
    uint48 _newEpochLength
  ) external;

  /**
   * @notice Updates the messaging gas config
   * @param _newGasConfig The new gas config
   */
  function updateGasConfig(
    IHubStorage.GasConfig calldata _newGasConfig
  ) external;

  /**
   * @notice Sets the maximum discount dbps
   * @dev Can only be called by the owner
   * @param _tickerHash The asset ticker hash
   * @param _maxDiscountDbps The new maximum discount dbps
   */
  function setMaxDiscountDbps(bytes32 _tickerHash, uint24 _maxDiscountDbps) external;

  /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice returns the set of supported domains for Everclear
   * @return _supportedDomains The set of supported domains
   */
  function supportedDomains() external view returns (uint32[] memory _supportedDomains);
}
