// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IGatewayV2} from 'interfaces/common/IGatewayV2.sol';

import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

/**
 * @title IHubGateway
 * @notice Interface for the HubGateway contract, sends and receives messages to and from the transport layer
 */
interface IHubGatewayV2 is IGatewayV2 {
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

  /**
   * @notice Thrown when there is a zero address for an activeMailbox
   * @param _chainId The id for the domain given
   */
  error HubGateway_Mailbox_InvalidOriginDomain(uint32 _chainId);

  /**
   * @notice Thrown when the length of the mailboxes and chainIds arrays do not match
   */
  error Gateway_Initialize_MismatchedArrays();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Initialize Gateway variables
   * @param _mailboxes The list of mailboxes on Hub for each chain
   * @param _chainIds The list of chains
   */
  function initialize(IMailbox[] memory _mailboxes, uint32[] memory _chainIds) external;

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

  /**
   * @notice the active mailbox for the origin
   * @param _origin the chain sending the message
   * @param _mailbox the new mailbox address
   */
  function updateActiveMailbox(uint32 _origin, address _mailbox) external;

  /**
   * @notice Disables the active mailbox for the origin
   * @param _origin The chain id of the origin
   */
  function disableActiveMailbox(
    uint32 _origin
  ) external;

  /*///////////////////////////////////////////////////////////////
                              VIEWS
  //////////////////////////////////////////////////////////////*/
  /**
   */
  function mailboxes(
    uint32 _chainId
  ) external view returns (IMailbox _mailbox);

  /**
   * @notice Returns the chain gateway address for the chain id
   * @param _chainId The chain id
   * @return _gateway The address of the gateway
   */
  function chainGateways(
    uint32 _chainId
  ) external view returns (bytes32 _gateway);

  /**
   * @notice Returns the mailbox for a given domain
   * @param _origin The origin domain of the message
   * @return _mailbox The mailbox contract
   */
  function activeMailbox(
    uint32 _origin
  ) external view returns (IMailbox _mailbox);
}
