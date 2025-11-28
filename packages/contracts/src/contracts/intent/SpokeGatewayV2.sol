// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {GatewayV3} from 'contracts/common/GatewayV3.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {ISpokeGatewayV2} from 'interfaces/intent/ISpokeGatewayV2.sol';

/// @dev This would be a re-deployment instead of an upgrade
contract SpokeGatewayV2 is GatewayV3, UUPSUpgradeable, ISpokeGatewayV2 {
  using TypeCasts for address;

  uint32 public EVERCLEAR_ID;
  bytes32 public EVERCLEAR_GATEWAY;
  address public mailbox;

  constructor() GatewayV3() {}

  /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @inheritdoc ISpokeGatewayV2
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
  ) external initializer {
    _initializeGateway(
      _owner, _receiver, _interchainSecurityModule, _polymerProver, _hyperlaneMailbox, _ccipMailbox, _polymerMailbox
    );
    EVERCLEAR_ID = _everclearId;
    EVERCLEAR_GATEWAY = _hubGateway;
  }

  function updateMailbox(
    address _newMailbox
  ) external onlyOwner {
    address oldMailbox = mailbox;
    mailbox = _newMailbox;
    emit MailboxUpdated(oldMailbox, _newMailbox);
  }

  /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Checks that the upgrade function is called by the owner
   */
  function _authorizeUpgrade(
    address
  ) internal override onlyOwner {}

  /**
   * @notice Always returns the address for the HubGateway on the Everclear domain
   * @return _gateway The address of the Everclear Hub gateway
   */
  function _getGateway(
    uint32
  ) internal view override(GatewayV3) returns (bytes32 _gateway) {
    return EVERCLEAR_GATEWAY;
  }

  /**
   * @notice Checks that the incoming message was sent by the HubGateway on the Everclear domain
   * @param _origin The origin domain of the message
   * @param _sender The sender of the message
   */
  function _checkValidSender(
    uint32 _origin,
    bytes32 _sender
  ) internal view override(GatewayV3) {
    if (_origin != EVERCLEAR_ID) revert GatewayV3_Handle_InvalidOriginDomain();
    if (_sender != EVERCLEAR_GATEWAY) revert GatewayV3_Handle_InvalidSender();
  }

  function _activeMailbox(
    uint32
  ) internal view override(GatewayV3) returns (address) {
    return mailbox;
  }
}
