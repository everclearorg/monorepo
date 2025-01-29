// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IGateway} from 'interfaces/common/IGateway.sol';

/**
 * @title IHubGateway
 * @notice Interface for the HubGateway contract, sends and receives messages to and from the transport layer
 */
interface IHubGateway is IGateway {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a chain gateway is added or updated
   * @param _chainId The id of the chain gateway
   * @param _gateway The address of the gateway
   */
  event ChainGatewayAdded(uint32 _chainId, bytes32 _gateway);

  /**
   * @notice Emitted when a chain gateway is removed
   * @param _chainId The ID of the chain gateway
   * @param _gateway The address of the gateway
   */
  event ChainGatewayRemoved(uint32 _chainId, bytes32 _gateway);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the Gateway being removed is already removed
   * @param _chainId The id for the domain given
   */
  error HubGateway_RemoveGateway_GatewayAlreadyRemoved(uint32 _chainId);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Initialize Gateway variables
   * @param _owner The address of the owner
   * @param _mailbox The address of the local mailbox
   * @param _receiver The address of the local message receiver (EverclearSpoke)
   * @param _interchainSecurityModule The address of the chosen interchain security module
   * @dev Only called once on initialization
   */
  function initialize(address _owner, address _mailbox, address _receiver, address _interchainSecurityModule) external;

  /**
   * @notice adds a chain gateway
   * @param _chainId ID of the chain
   * @param _gateway address of the gateway
   * @dev only called by the hub
   */
  function setChainGateway(uint32 _chainId, bytes32 _gateway) external;

  /**
   * @notice removes a chain gateway
   * @param _chainId the chain id of the gateway to be removed
   * @dev only called by the hub
   */
  function removeChainGateway(
    uint32 _chainId
  ) external;

  /*///////////////////////////////////////////////////////////////
                              VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the chain gateway address for the chain id
   * @param _chainId The chain id
   * @return _gateway The address of the gateway
   */
  function chainGateways(
    uint32 _chainId
  ) external view returns (bytes32 _gateway);
}
