// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {GatewayV2} from 'contracts/common/GatewayV2.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IHubGatewayV2} from 'interfaces/hub/IHubGatewayV2.sol';

import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

import {IGatewayV2} from 'interfaces/common/IGatewayV2.sol';

contract HubGatewayV2 is GatewayV2, UUPSUpgradeable, IHubGatewayV2 {
  using TypeCasts for address;

  /// @inheritdoc IHubGatewayV2
  mapping(uint32 _chainId => bytes32 _gateway) public chainGateways;

  /**
   * Configurable Mailbox Update  ************************
   */
  /// @inheritdoc IHubGatewayV2
  mapping(uint32 => IMailbox) public mailboxes;

  constructor() GatewayV2() {}

  /*//////////////////////////////////////////////////////////////
                        GATEWAY FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IHubGatewayV2
  function initialize(
    IMailbox[] memory _mailboxes,
    uint32[] memory _chainIds
  ) external reinitializer(2) onlyOwner {
    if (_mailboxes.length != _chainIds.length) {
      revert Gateway_Initialize_MismatchedArrays();
    }
    for (uint256 i; i < _mailboxes.length; i++) {
      mailboxes[_chainIds[i]] = _mailboxes[i];
      emit ActiveMailboxUpdated(_chainIds[i], address(0), address(_mailboxes[i]));
    }
  }

  /*//////////////////////////////////////////////////////////////
                         HUB FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IHubGatewayV2
  function setChainGateway(
    uint32 _chainId,
    bytes32 _gateway
  ) external onlyReceiver validAddress(_gateway) {
    chainGateways[_chainId] = _gateway;
    emit ChainGatewayAdded(_chainId, _gateway);
  }

  /// @inheritdoc IHubGatewayV2
  function removeChainGateway(
    uint32 _chainId
  ) external onlyReceiver {
    bytes32 _gateway = chainGateways[_chainId];
    if (_gateway == 0) revert HubGateway_RemoveGateway_GatewayAlreadyRemoved(_chainId);
    delete chainGateways[_chainId];
    emit ChainGatewayRemoved(_chainId, _gateway);
  }

  /// @inheritdoc IHubGatewayV2
  function updateActiveMailbox(
    uint32 _origin,
    address _newMailbox
  ) external onlyOwner validAddress(_newMailbox.toBytes32()) {
    address _oldMailbox = address(mailboxes[_origin]);
    mailboxes[_origin] = IMailbox(_newMailbox);
    emit ActiveMailboxUpdated(_origin, _oldMailbox, _newMailbox);
  }

  /// @inheritdoc IHubGatewayV2
  function disableActiveMailbox(
    uint32 _origin
  ) external onlyOwner {
    address _oldMailbox = address(mailboxes[_origin]);
    delete mailboxes[_origin];
    emit ActiveMailboxUpdated(_origin, _oldMailbox, address(0));
  }

  /// @inheritdoc IHubGatewayV2
  function activeMailbox(
    uint32 _origin
  ) public view returns (IMailbox _mailbox) {
    return _activeMailbox(_origin);
  }

  /**
   * @notice Checks there is an active mailbox for the origin address
   */
  function _activeMailbox(
    uint32 _origin
  ) internal view override(GatewayV2) returns (IMailbox) {
    IMailbox _mailbox = mailboxes[_origin];
    if (address(_mailbox) == address(0)) {
      revert HubGateway_Mailbox_InvalidOriginDomain(_origin);
    }
    return _mailbox;
  }

  /**
   * @notice Checks that the upgrade function is called by the owner
   */
  function _authorizeUpgrade(
    address
  ) internal override onlyOwner {}

  /**
   * @notice Checks that the incoming message was sent by the gateway on the origin domain
   * @param _origin The origin domain of the message
   * @param _sender The sender of the message
   */
  function _checkValidSender(
    uint32 _origin,
    bytes32 _sender
  ) internal view override(GatewayV2) {
    bytes32 _gateway = chainGateways[_origin];
    if (_sender != _gateway) revert Gateway_Handle_InvalidSender();
  }

  /**
   * @notice Returns the address of the gateway for the given domain
   * @dev Reverts if no gateway is set for the domain
   * @param _domain The domain of the message
   * @return _gateway The address of the gateway
   */
  function _getGateway(
    uint32 _domain
  ) internal view override(GatewayV2) returns (bytes32 _gateway) {
    _gateway = chainGateways[_domain];
    if (_gateway == 0) revert Gateway_Handle_InvalidOriginDomain();
  }
}
