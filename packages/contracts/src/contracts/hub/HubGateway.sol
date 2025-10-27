// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {Gateway} from 'contracts/common/Gateway.sol';

import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';

contract HubGateway is Gateway, UUPSUpgradeable, IHubGateway {
  /// @inheritdoc IHubGateway
  mapping(uint32 _chainId => bytes32 _gateway) public chainGateways;

  constructor() Gateway() {}

  /*//////////////////////////////////////////////////////////////
                        GATEWAY FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IHubGateway
  function initialize(
    address _owner,
    address _mailbox,
    address _receiver,
    address _interchainSecurityModule
  ) external initializer {
    _initializeGateway(_owner, _mailbox, _receiver, _interchainSecurityModule);
  }

  /*//////////////////////////////////////////////////////////////
                         HUB FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IHubGateway
  function setChainGateway(uint32 _chainId, bytes32 _gateway) external onlyReceiver validAddress(_gateway) {
    chainGateways[_chainId] = _gateway;
    emit ChainGatewayAdded(_chainId, _gateway);
  }

  /// @inheritdoc IHubGateway
  function removeChainGateway(
    uint32 _chainId
  ) external onlyReceiver {
    bytes32 _gateway = chainGateways[_chainId];
    if (_gateway == 0) revert HubGateway_RemoveGateway_GatewayAlreadyRemoved(_chainId);
    delete chainGateways[_chainId];
    emit ChainGatewayRemoved(_chainId, _gateway);
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
  function _checkValidSender(uint32 _origin, bytes32 _sender) internal view override(Gateway) {
    bytes32 _gateway = chainGateways[_origin];
    if (_sender != _gateway) revert Gateway_Handle_InvalidSender();
  }

  /**
   * @notice Returns the address of the gateway for the given domain
   * @param _domain The domain of the message
   * @return _gateway The address of the gateway
   */
  function _getGateway(
    uint32 _domain
  ) internal view override(Gateway) returns (bytes32 _gateway) {
    _gateway = chainGateways[_domain];
    if (_gateway == 0) revert Gateway_Handle_InvalidOriginDomain();
  }
}
