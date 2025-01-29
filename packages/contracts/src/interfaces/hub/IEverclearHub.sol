// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IHandler} from 'interfaces/hub/IHandler.sol';
import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {IHubMessageReceiver} from 'interfaces/hub/IHubMessageReceiver.sol';
import {IManager} from 'interfaces/hub/IManager.sol';
import {ISettler} from 'interfaces/hub/ISettler.sol';

/**
 * @title IEverclearHub
 * @notice Interface for the core hub contract
 */
interface IEverclearHub is IEverclear, ISettler, IManager, IHandler, IHubMessageReceiver {
  /*///////////////////////////////////////////////////////////////
                                STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Struct for the hub initialization parameters
   * @param owner The owner of the hub
   * @param admin The admin of the hub
   * @param manager The manager of the hub
   * @param settler The settler of the hub
   * @param handler The handler of the hub
   * @param messageReceiver The message receiver of the hub
   * @param lighthouse The lighthouse of the hub
   * @param hubGateway The gateway of the hub
   * @param acceptanceDelay The delay for accepting intents
   * @param expiryTimeBuffer The buffer for the expiry time
   * @param epochLength The length of the epoch
   * @param discountPerEpoch The discount per epoch
   * @param minSolverSupportedDomains The minimum number of domains supported by the solver
   * @param settlementBaseGasUnits The base gas units for settlement
   * @param averageGasUnitsPerSettlement The average gas units per settlement
   * @param bufferDBPS The buffer in basis points
   */
  struct HubInitializationParams {
    address owner;
    address admin;
    address manager;
    address settler;
    address handler;
    address messageReceiver;
    address lighthouse;
    IHubGateway hubGateway;
    uint256 acceptanceDelay;
    uint48 expiryTimeBuffer;
    uint48 epochLength;
    uint24 discountPerEpoch;
    uint8 minSolverSupportedDomains;
    uint256 settlementBaseGasUnits;
    uint256 averageGasUnitsPerSettlement;
    uint256 bufferDBPS;
  }
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice emitted when a module address is updated
   * @param _type The type of module to update
   * @param _previousAddress The address of the old module
   * @param _newAddress The address of the new module
   */
  event ModuleAddressUpdated(bytes32 _type, address _previousAddress, address _newAddress);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Update a module's address
   * @param _type The hash of the module type
   * @param _newAddress The new address for that module
   */
  function updateModuleAddress(bytes32 _type, address _newAddress) external;

  /**
   * @notice Initialize the hub contract
   * @param _init The hub initialization parameters
   */
  function initialize(
    HubInitializationParams calldata _init
  ) external;

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Get the supported domains for the hub
   * @return _supportedDomains The supported domains
   */
  function supportedDomains() external view returns (uint32[] memory _supportedDomains);

  /**
   * @notice Get the supported domains for a user
   * @param _user The user to get the supported domains for
   * @return _supportedDomains The supported domains
   */
  function userSupportedDomains(
    bytes32 _user
  ) external view returns (uint32[] memory _supportedDomains);
}
