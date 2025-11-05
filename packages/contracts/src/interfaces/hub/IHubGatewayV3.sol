// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IGatewayV3} from 'interfaces/common/IGatewayV3.sol';

import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

/**
 * @title IHubGatewayV3
 * @notice Interface for the HubGateway contract, sends and receives messages to and from the transport layer
 */
interface IHubGatewayV3 is IGatewayV3 {
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

  /**
   * @notice Emitted when the active mailbox is updated
   * @param _origin The origin domain
   * @param _oldMailbox The old mailbox address
   * @param _newMailbox The new mailbox address
   */
  event ActiveMailboxUpdated(uint32 _origin, address _oldMailbox, address _newMailbox);

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

  /**
   * @notice Thrown when the sender is not the appropriate remote Gateway
   */
  error Gateway_Handle_InvalidSender();

  /**
   * @notice Thrown when the message origin is invalid
   */
  error Gateway_Handle_InvalidOriginDomain();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Initialize Gateway variables
   * @param _owner The owner of the gateway
   * @param _receiver The address of the receiver contract on Hub
   * @param _interchainSecurityModule The address of the interchain security module
   * @param _polymerProver The address of the Polymer prover contract
   * @param _hyperlaneMailbox The address of the Hyperlane mailbox contract
   * @param _ccipMailbox The address of the CCIP mailbox contract
   * @param _polymerMailbox The address of the Polymer mailbox contract
   * @param _mailboxes The list of mailboxes on Hub for each chain
   * @param _chainIds The list of chains
   */
  function initialize(
    address _owner,
    address _receiver,
    address _interchainSecurityModule,
    address _polymerProver,
    address _hyperlaneMailbox,
    address _ccipMailbox,
    address _polymerMailbox,
    address[] memory _mailboxes,
    uint32[] memory _chainIds
  ) external;

  /**
   * @notice adds a chain gateway
   * @param _chainId ID of the chain
   * @param _gateway address of the gateway
   * @dev only called by the hub
   */
  function setChainGateway(
    uint32 _chainId,
    bytes32 _gateway
  ) external;

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
  function updateActiveMailbox(
    uint32 _origin,
    address _mailbox
  ) external;

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
  ) external view returns (address _mailbox);

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
   * @param _origin The domain used to find the destination mailbox
   * @return _mailbox The mailbox contract
   */
  function activeMailbox(
    uint32 _origin
  ) external view returns (address _mailbox);
}
