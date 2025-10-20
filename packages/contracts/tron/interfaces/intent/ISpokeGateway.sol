// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IGateway} from 'interfaces/common/IGateway.sol';

/**
 * @title ISpokeGateway
 * @notice Interface for the SpokeGateway contract, sends and receives messages to and from the transport layer
 */
interface ISpokeGateway is IGateway {
  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Initialize Gateway variables
   * @param _owner The address of the owner
   * @param _mailbox The address of the local mailbox
   * @param _receiver The address of the local message receiver (EverclearSpoke)
   * @param _interchainSecurityModule The address of the chosen interchain security module
   * @param _everclearId The id of the Everclear domain
   * @param _hubGateway The bytes32 representation of the Hub gateway
   * @dev Only called once on initialization
   */
  function initialize(
    address _owner,
    address _mailbox,
    address _receiver,
    address _interchainSecurityModule,
    uint32 _everclearId,
    bytes32 _hubGateway
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
}
