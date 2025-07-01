// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/*

Coded for Everclear with ♥ by

░██╗░░░░░░░██╗░█████╗░███╗░░██╗██████╗░███████╗██████╗░██╗░░░░░░█████╗░███╗░░██╗██████╗░
░██║░░██╗░░██║██╔══██╗████╗░██║██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗
░╚██╗████╗██╔╝██║░░██║██╔██╗██║██║░░██║█████╗░░██████╔╝██║░░░░░███████║██╔██╗██║██║░░██║
░░████╔═████║░██║░░██║██║╚████║██║░░██║██╔══╝░░██╔══██╗██║░░░░░██╔══██║██║╚████║██║░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝██║░╚███║██████╔╝███████╗██║░░██║███████╗██║░░██║██║░╚███║██████╔╝
░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚══╝╚═════╝░╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░

https://defi.sucks

*/

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';
import {IEverclearHubV2} from 'interfaces/hub/IEverclearHubV2.sol';
import {IHandlerV2} from 'interfaces/hub/IHandlerV2.sol';

import {IAssetManagerV2} from 'interfaces/hub/IAssetManagerV2.sol';
import {IMessageReceiver} from 'interfaces/hub/IHubMessageReceiver.sol';
import {IProtocolManagerV2} from 'interfaces/hub/IProtocolManagerV2.sol';

import {ISettlerV2} from 'interfaces/hub/ISettlerV2.sol';
import {IUsersManager} from 'interfaces/hub/IUsersManager.sol';

import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {HubStorageV2} from 'contracts/hub/HubStorageV2.sol';

/**
 * @title EverclearHubV2
 * @notice The EverclearHub contract is the main entry point for the Everclear protocol
 */
contract EverclearHubV2 is HubStorageV2, UUPSUpgradeable, IEverclearHubV2 {
  using Uint32Set for Uint32Set.Set;

  constructor() {
    _disableInitializers();
  }

  /*///////////////////////////////////////////////////////////////
                    SETTLER MODULE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISettlerV2
  function processDepositsAndInvoices(bytes32, uint32, uint32, uint32) external {
    _delegate(_SETTLEMENT_MODULE);
  }

  /// @inheritdoc ISettlerV2
  function processSettlementQueue(uint32, uint32) external payable whenNotPaused {
    _delegate(_SETTLEMENT_MODULE);
  }

  /// @inheritdoc ISettlerV2
  function processSettlementQueueViaRelayer(
    uint32,
    uint32,
    address,
    uint256,
    uint256,
    uint256,
    bytes calldata
  ) external whenNotPaused {
    _delegate(_SETTLEMENT_MODULE);
  }

  /*///////////////////////////////////////////////////////////////
                    HANDLER MODULE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IHandlerV2
  function handleExpiredIntents(
    bytes32[] calldata
  ) external payable whenNotPaused {
    _delegate(_HANDLER_MODULE);
  }

  /// @inheritdoc IHandlerV2
  function returnUnsupportedIntent(
    bytes32
  ) external payable whenNotPaused {
    _delegate(_HANDLER_MODULE);
  }

  /// @inheritdoc IHandlerV2
  function withdrawFees(bytes32, bytes32, uint256, uint32[] calldata) external {
    _delegate(_HANDLER_MODULE);
  }

  /*///////////////////////////////////////////////////////////////
                  MESSAGE RECEIVER MODULE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IMessageReceiver
  function receiveMessage(
    bytes calldata
  ) external override {
    _delegate(_MESSAGE_RECEIVER_MODULE);
  }

  /*///////////////////////////////////////////////////////////////
                      ASSET MANAGER MODULE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IAssetManagerV2
  function setAdoptedForAsset(
    AssetConfig calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IAssetManagerV2
  function setTokenConfigs(
    TokenSetup[] calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IAssetManagerV2
  function setPrioritizedStrategy(bytes32, IEverclearV2.Strategy) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IAssetManagerV2
  function setLastClosedEpochProcessed(
    SetLastClosedEpochProcessedParams calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IAssetManagerV2
  function setDiscountPerEpoch(bytes32, uint24) external {
    _delegate(_MANAGER_MODULE);
  }

  /*///////////////////////////////////////////////////////////////
                  SOLVER MANAGER MODULE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IUsersManager
  function setUserSupportedDomains(
    uint32[] calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IUsersManager
  function setUpdateVirtualBalance(
    bool
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /*///////////////////////////////////////////////////////////////
                  PROTOCOL MANAGER MODULE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IProtocolManagerV2
  function proposeOwner(
    address
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function acceptOwnership() external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateLighthouse(
    address
  ) external payable {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateWatchtower(
    address
  ) external payable {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateAcceptanceDelay(
    uint256
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function assignRole(address, Role) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function addSupportedDomains(
    DomainSetup[] calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function removeSupportedDomains(
    uint32[] calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function pause() external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function unpause() external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateMinSolverSupportedDomains(
    uint8
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateMailbox(
    address
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateMailbox(bytes32, uint32[] calldata) external payable {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateSecurityModule(
    address
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateGateway(
    address
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateGateway(bytes32, uint32[] calldata) external payable {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateChainGateway(uint32, bytes32) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function removeChainGateway(
    uint32
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateExpiryTimeBuffer(
    uint48
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateEpochLength(
    uint48
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function updateGasConfig(
    GasConfig calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManagerV2
  function setMaxDiscountDbps(bytes32, uint24) external {
    _delegate(_MANAGER_MODULE);
  }

  /*///////////////////////////////////////////////////////////////
                        UPGRADE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEverclearHubV2
  function updateModuleAddress(bytes32 _type, address _newAddress) external onlyOwner {
    address _previousAddress = modules[_type];
    modules[_type] = _newAddress;
    emit ModuleAddressUpdated(_type, _previousAddress, _newAddress);
  }

  /// @inheritdoc IEverclearHubV2
  function userSupportedDomains(
    bytes32 _owner
  ) external view returns (uint32[] memory _supportedDomains) {
    _supportedDomains = _usersSupportedDomains[_owner].memValues();
  }

  /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEverclearHubV2
  function supportedDomains() external view returns (uint32[] memory __supportedDomains) {
    return _supportedDomains.memValues();
  }

  /**
   * @notice Initialize the EverclearHub contract
   * @param _settler The address of the settler module
   * @param _manager The address of the manager module
   * @param _handler The address of the handler module
   * @param _messageReceiver The address of the message receiver module
   */
  function initialize(
    address _settler,
    address _manager,
    address _handler,
    address _messageReceiver
  ) public reinitializer(2) {
    modules[_SETTLEMENT_MODULE] = _settler;
    modules[_MANAGER_MODULE] = _manager;
    modules[_HANDLER_MODULE] = _handler;
    modules[_MESSAGE_RECEIVER_MODULE] = _messageReceiver;
  }

  function _authorizeUpgrade(
    address _newImplementation
  ) internal override onlyOwner {}

  /**
   * @notice Perform a `delegatcall`
   * @param _type The module identifier to delegate execution to
   */
  function _delegate(
    bytes32 _type
  ) internal {
    address _delegatee = modules[_type];
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize())

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas(), _delegatee, 0, calldatasize(), 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())

      switch result
      // delegatecall returns 0 on error.
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }
}
