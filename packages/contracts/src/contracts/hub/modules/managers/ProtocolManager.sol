// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Constants as Common} from 'contracts/common/Constants.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {IProtocolManager} from 'interfaces/hub/IProtocolManager.sol';

import {HubStorage} from 'contracts/hub/HubStorage.sol';

abstract contract ProtocolManager is HubStorage, IProtocolManager {
  using Uint32Set for Uint32Set.Set;
  using TypeCasts for address;
  using TypeCasts for bytes32;

  /*//////////////////////////////////////////////////////////////
                            LOCAL UPDATES
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IProtocolManager
  function proposeOwner(
    address _newOwner
  ) external onlyOwner {
    proposedOwner = _newOwner;
    proposedOwnershipTimestamp = block.timestamp;

    emit OwnershipProposed(_newOwner, proposedOwnershipTimestamp);
  }

  /// @inheritdoc IProtocolManager
  function acceptOwnership() external {
    if (msg.sender != proposedOwner) {
      revert ProtocolManager_AcceptOwnership_NotProposedOwner();
    }
    if (block.timestamp <= proposedOwnershipTimestamp + acceptanceDelay) {
      revert ProtocolManager_AcceptOwnership_DelayNotElapsed();
    }

    address oldOwner = owner;
    owner = proposedOwner;

    emit OwnershipTransferred(oldOwner, owner);
  }

  /// @inheritdoc IProtocolManager
  function updateAcceptanceDelay(
    uint256 _newAcceptanceDelay
  ) external hasRole(Role.ADMIN) {
    uint256 _oldAcceptanceDelay = acceptanceDelay;
    acceptanceDelay = _newAcceptanceDelay;

    emit AcceptanceDelayUpdated(_oldAcceptanceDelay, _newAcceptanceDelay);
  }

  /// @inheritdoc IProtocolManager
  function updateGateway(
    address _newGateway
  ) external onlyOwner validAddress(_newGateway) {
    address _oldGateway = address(hubGateway);
    hubGateway = IHubGateway(_newGateway);

    emit GatewayUpdated(_oldGateway, _newGateway);
  }

  /// @inheritdoc IProtocolManager
  function assignRole(address _account, Role _role) external {
    if (msg.sender != owner && (roles[msg.sender] != Role.ADMIN || _role == Role.ADMIN)) {
      revert ProtocolManager_Unauthorized();
    }

    roles[_account] = _role;

    emit RoleAssigned(_account, _role);
  }

  /// @inheritdoc IProtocolManager
  function addSupportedDomains(
    DomainSetup[] calldata _domains
  ) external hasRole(Role.ADMIN) {
    for (uint256 _i; _i < _domains.length; _i++) {
      uint32 _id = _domains[_i].id;
      if (!_supportedDomains.add(_id)) {
        revert ProtocolManager_AddSupportedDomains_SupportedDomainAlreadyAdded(_id);
      }
      domainGasLimit[_id] = _domains[_i].blockGasLimit;
    }

    emit SupportedDomainsAdded(_domains);
  }

  /// @inheritdoc IProtocolManager
  function removeSupportedDomains(
    uint32[] calldata _domains
  ) external hasRole(Role.ADMIN) {
    for (uint256 _i; _i < _domains.length; _i++) {
      if (!_supportedDomains.remove(_domains[_i])) {
        revert ProtocolManager_RemoveSupportedDomains_SupportedDomainNotFound(_domains[_i]);
      }
    }

    emit SupportedDomainsRemoved(_domains);
  }

  /// @inheritdoc IProtocolManager
  function pause() external pauseAuthorized {
    paused = true;
    emit Paused();
  }

  /// @inheritdoc IProtocolManager
  function unpause() external pauseAuthorized {
    paused = false;
    emit Unpaused();
  }

  /// @inheritdoc IProtocolManager
  function updateMinSolverSupportedDomains(
    uint8 _newMinSolverSupportedDomains
  ) external hasRole(Role.ADMIN) {
    uint8 _oldMinSolverSupportedDomains = minSolverSupportedDomains;
    minSolverSupportedDomains = _newMinSolverSupportedDomains;

    emit MinSolverSupportedDomainsUpdated(_oldMinSolverSupportedDomains, _newMinSolverSupportedDomains);
  }

  /// @inheritdoc IProtocolManager
  function updateExpiryTimeBuffer(
    uint48 _newExpiryTimeBuffer
  ) external hasRole(Role.ADMIN) {
    uint48 _oldExpiryTimeBuffer = expiryTimeBuffer;
    expiryTimeBuffer = _newExpiryTimeBuffer;

    emit ExpiryTimeBufferUpdated(_oldExpiryTimeBuffer, _newExpiryTimeBuffer);
  }

  /// @inheritdoc IProtocolManager
  function updateEpochLength(
    uint48 _newEpochLength
  ) external hasRole(Role.ADMIN) {
    if (_newEpochLength == 0) {
      revert ProtocolManager_UpdateEpochLength_InvalidEpochLength();
    }

    // enforce the update of the carry epoch
    _carryEpoch = getCurrentEpoch();
    _lastBlockNumberCarryEpochUpdated = block.number;

    uint48 _oldEpochLength = epochLength;
    epochLength = _newEpochLength;

    emit EpochLengthUpdated(_oldEpochLength, _newEpochLength);
  }

  /// @inheritdoc IProtocolManager
  function updateGasConfig(
    GasConfig calldata _newGasConfig
  ) external hasRole(Role.ADMIN) {
    if (_newGasConfig.bufferDBPS > Common.DBPS_DENOMINATOR) {
      revert HubStorage_InvalidDbpsValue();
    }
    GasConfig memory _oldGasConfig = gasConfig;
    gasConfig = _newGasConfig;
    emit GasConfigUpdated(_oldGasConfig, _newGasConfig);
  }

  /*//////////////////////////////////////////////////////////////
                            GATEWAY UPDATES
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IProtocolManager
  function updateMailbox(
    address _newMailbox
  ) external onlyOwner {
    hubGateway.updateMailbox(_newMailbox);
  }

  /// @inheritdoc IProtocolManager
  function updateSecurityModule(
    address _newSecurityModule
  ) external onlyOwner {
    hubGateway.updateSecurityModule(_newSecurityModule);
  }

  /// @inheritdoc IProtocolManager
  function updateChainGateway(uint32 _chainId, bytes32 _gateway) external onlyOwner {
    hubGateway.setChainGateway(_chainId, _gateway);
  }

  /// @inheritdoc IProtocolManager
  function removeChainGateway(
    uint32 _chainId
  ) external onlyOwner {
    hubGateway.removeChainGateway(_chainId);
  }

  /*//////////////////////////////////////////////////////////////
                        SPECIFIC DOMAIN UPDATES
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IProtocolManager
  function updateMailbox(
    bytes32 _newMailbox,
    uint32[] calldata _domains
  ) external payable onlyOwner validAddress(_newMailbox.toAddress()) {
    bytes memory _message = MessageLib.formatAddressUpdateMessage(Common.MAILBOX_HASH, _newMailbox);

    bytes32[] memory _messageIds = _propagateToDomains(_message, _domains);

    emit MailboxUpdated(_newMailbox, _domains, _messageIds);
  }

  /// @inheritdoc IProtocolManager
  function updateGateway(
    bytes32 _newGateway,
    uint32[] calldata _domains
  ) external payable onlyOwner validAddress(_newGateway.toAddress()) {
    bytes memory _message = MessageLib.formatAddressUpdateMessage(Common.GATEWAY_HASH, _newGateway);

    bytes32[] memory _messageIds = _propagateToDomains(_message, _domains);

    emit GatewayUpdated(_newGateway, _domains, _messageIds);
  }

  /*//////////////////////////////////////////////////////////////
                          CROSS-CHAIN UPDATES
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IProtocolManager
  function updateLighthouse(
    address _newLighthouse
  ) external payable onlyOwner validAddress(_newLighthouse) {
    address _oldLighthouse = lighthouse;
    lighthouse = _newLighthouse;

    bytes memory _message = MessageLib.formatAddressUpdateMessage(Common.LIGHTHOUSE_HASH, _newLighthouse.toBytes32());

    bytes32[] memory _messageIds = _propagateMessage(_message);

    emit LighthouseUpdated(_oldLighthouse, _newLighthouse, _messageIds);
  }

  /// @inheritdoc IProtocolManager
  function updateWatchtower(
    address _newWatchtower
  ) external payable onlyOwner validAddress(_newWatchtower) {
    address _oldWatchtower = watchtower;
    watchtower = _newWatchtower;

    bytes memory _message = MessageLib.formatAddressUpdateMessage(Common.WATCHTOWER_HASH, _newWatchtower.toBytes32());

    bytes32[] memory _messageIds = _propagateMessage(_message);

    emit WatchtowerUpdated(_oldWatchtower, _newWatchtower, _messageIds);
  }

  /// @inheritdoc IProtocolManager
  function setMaxDiscountDbps(bytes32 _tickerHash, uint24 _maxDiscountDbps) external hasRole(Role.ADMIN) {
    if (_maxDiscountDbps > Common.DBPS_DENOMINATOR) {
      revert ProtocolManager_SetMaxDiscountDbps_InvalidDiscount();
    }
    TokenConfig storage _tokenConfig = _tokenConfigs[_tickerHash];
    uint24 _oldMaxDiscountDbps = _tokenConfig.maxDiscountDbps;
    _tokenConfig.maxDiscountDbps = _maxDiscountDbps;
    emit MaxDiscountDbpsSet(_tickerHash, _oldMaxDiscountDbps, _maxDiscountDbps);
  }
  /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IProtocolManager
  function supportedDomains() external view returns (uint32[] memory __supportedDomains) {
    return _supportedDomains.memValues();
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Propagate a message to all supported domains
   * @param _message The message to be propagated
   * @return _messageIds The ids of the messages
   */
  function _propagateMessage(
    bytes memory _message
  ) internal returns (bytes32[] memory _messageIds) {
    uint32[] memory _domains = _supportedDomains.memValues();
    _messageIds = _propagateToDomains(_message, _domains);
  }

  /**
   * @notice Propagate a message to a list of domains
   * @param _message The message to be propagated
   * @param _domains The list of domains
   * @return _messageIds The ids of the messages
   */
  function _propagateToDomains(
    bytes memory _message,
    uint32[] memory _domains
  ) internal returns (bytes32[] memory _messageIds) {
    _messageIds = new bytes32[](_domains.length);
    uint256 _value = msg.value / _domains.length;
    for (uint256 _i; _i < _domains.length; _i++) {
      (_messageIds[_i],) =
        IHubGateway(hubGateway).sendMessage{value: _value}(_domains[_i], _message, Common.DEFAULT_GAS_LIMIT);
    }
  }
}
