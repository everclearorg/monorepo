// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IUsersManager
 * @notice Interface for the UsersManager contract
 */
interface IUsersManager {
  /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a solver config is updated
   * @param _solver The solver address
   * @param _supportedDomains The supported domains
   */
  event SolverConfigUpdated(bytes32 indexed _solver, uint32[] _supportedDomains);

  /**
   * @notice Emitted when the virtual balance status is updated
   * @param _user The user address (bytes32)
   * @param _status The status
   */
  event IncreaseVirtualBalanceSet(bytes32 indexed _user, bool _status);

  /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the minimum supported domains is not met
   * @param _minSupportedDomains The mininum amount of domains a solver must support
   * @param _supportedDomainsLength The amount of domains the solver is trying to set
   */
  error UsersManager_SetUser_MinimumSupportedDomainsNotMet(
    uint256 _minSupportedDomains, uint256 _supportedDomainsLength
  );

  /**
   * @notice Thrown when the supported domain is not supported
   * @param _domain The id of the unsupported domain
   */
  error UsersManager_SetUser_DomainNotSupported(uint32 _domain);

  /**
   * @notice Thrown when a supported domain is repeated
   * @param _domain The id of the repeated domain
   */
  error UsersManager_SetUser_DuplicatedSupportedDomain(uint32 _domain);

  /*//////////////////////////////////////////////////////////////
                                LOGIC
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Sets the solver for the owner
   * @dev Only the solver owner can call this function
   * @param _supportedDomains The domains supported by the solver
   */
  function setUserSupportedDomains(
    uint32[] calldata _supportedDomains
  ) external;

  /**
   * @notice Set the virtual balance status
   * @param _status The status
   */
  function setUpdateVirtualBalance(
    bool _status
  ) external;
}
