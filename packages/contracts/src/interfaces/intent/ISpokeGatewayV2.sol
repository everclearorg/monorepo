// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IGatewayV3} from 'interfaces/common/IGatewayV3.sol';

/**
 * @title ISpokeGatewayV2
 * @notice Interface for the SpokeGateway contract, sends and receives messages to and from the transport layer
 */
interface ISpokeGatewayV2 is IGatewayV3 {
  event HyperlaneMailboxUpdated(address _oldMailbox, address _newMailbox);
  event CCIPMailboxUpdated(address _oldMailbox, address _newMailbox);
  event CCIPMappingsUpdated(uint256[] _everclearId, uint256[] _ccipChainId);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Initialize Gateway variables
   * @param _polymerProver The address of the Polymer Prover contract
   * @dev Only called once on initialization
   */
  function initialize(address _polymerProver, address _hyperlaneMailbox, address _ccipMailbox) external;

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
