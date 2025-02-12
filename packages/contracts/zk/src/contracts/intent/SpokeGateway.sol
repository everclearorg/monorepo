// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {Gateway} from 'contracts/common/Gateway.sol';

import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';

contract SpokeGateway is Gateway, UUPSUpgradeable, ISpokeGateway {
  uint32 public EVERCLEAR_ID;
  bytes32 public EVERCLEAR_GATEWAY;

  constructor() Gateway() {}

  /*//////////////////////////////////////////////////////////////
                        GATEWAY FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISpokeGateway
  function initialize(
    address _owner,
    address _mailbox,
    address _receiver,
    address _interchainSecurityModule,
    uint32 _everclearId,
    bytes32 _hubGateway
  ) external initializer {
    _initializeGateway(_owner, _mailbox, _receiver, _interchainSecurityModule);
    EVERCLEAR_ID = _everclearId;
    EVERCLEAR_GATEWAY = _hubGateway;
  }

  /**
   * @notice Checks that the upgrade function is called by the owner
   */
  function _authorizeUpgrade(
    address
  ) internal override onlyOwner {}

  /**
   * @notice Always returns the address for the HubGateway on the Everclear domain
   * @return _gateway The address of the everyclear gateway
   */
  function _getGateway(
    uint32
  ) internal view override(Gateway) returns (bytes32 _gateway) {
    return EVERCLEAR_GATEWAY;
  }

  /**
   * @notice Checks that the incoming message was sent by the HubGateway on the Everclear domain
   * @param _origin The origin domain of the message
   * @param _sender The sender of the message
   */
  function _checkValidSender(uint32 _origin, bytes32 _sender) internal view override(Gateway) {
    if (_origin != EVERCLEAR_ID) revert Gateway_Handle_InvalidOriginDomain();
    if (_sender != EVERCLEAR_GATEWAY) revert Gateway_Handle_InvalidSender();
  }
}
