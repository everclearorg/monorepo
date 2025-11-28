// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IGatewayV3} from 'interfaces/common/IGatewayV3.sol';

/**
 * @title ISpokeGatewayV2
 * @notice Interface for the SpokeGateway contract, sends and receives messages to and from the transport layer
 */
interface ISpokeGatewayV2 is IGatewayV3 {
  /**
   * @notice Thrown when the message origin is invalid
   */
  error GatewayV3_Handle_InvalidOriginDomain();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Initialize Gateway variables
   * @param _owner The owner of the Gateway contract
   * @param _receiver The local message receiver (EverclearHub / EverclearSpoke)
   * @param _interchainSecurityModule The chosen interchain security module
   * @param _everclearId The Everclear hub chain id
   * @param _hubGateway The `HubGateway` gateway address
   * @param _polymerProver The address of the Polymer prover contract
   * @param _hyperlaneMailbox The address of the Hyperlane mailbox contract
   * @param _ccipMailbox The address of the CCIP mailbox contract
   * @param _polymerMailbox The address of the Polymer mailbox contract
   * @dev Only called once on initialization
   */
  function initialize(
    address _owner,
    address _receiver,
    address _interchainSecurityModule,
    uint32 _everclearId,
    bytes32 _hubGateway,
    address _polymerProver,
    address _hyperlaneMailbox,
    address _ccipMailbox,
    address _polymerMailbox
  ) external;

  /**
   * @notice Updates the mailbox
   * @param _mailbox The new mailbox address
   * @dev only called by the `receiver`
   */
  function updateMailbox(
    address _mailbox
  ) external;

  /*///////////////////////////////////////////////////////////////
                              VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the Everclear hub chain id
   * @return _hubChainId The Everclear chain id
   */
  function EVERCLEAR_ID() external view returns (uint32 _hubChainId);

  /**
   * @notice Returns the `HubGateway` gateway address
   * @return _hubGateway The `HubGateway` address
   */
  function EVERCLEAR_GATEWAY() external view returns (bytes32 _hubGateway);

  /**
   * @notice Returns the transport layer message routing smart contract
   * @dev this is independent of the transport layer used, adopting mailbox name because its descriptive enough
   *      using address instead of specific interface to be independent from HL or any other TL
   * @return _mailbox The mailbox contract
   */
  function mailbox() external view returns (address _mailbox);
}
