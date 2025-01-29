// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

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

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IHandler} from 'interfaces/hub/IHandler.sol';

import {IAssetManager} from 'interfaces/hub/IAssetManager.sol';
import {IMessageReceiver} from 'interfaces/hub/IHubMessageReceiver.sol';
import {IProtocolManager} from 'interfaces/hub/IProtocolManager.sol';

import {ISettler} from 'interfaces/hub/ISettler.sol';
import {IUsersManager} from 'interfaces/hub/IUsersManager.sol';

import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {HubStorage} from 'contracts/hub/HubStorage.sol';

/**
 * @title EverclearHub
 * @notice The EverclearHub contract is the main entry point for the Everclear protocol
 */
contract EverclearHub is HubStorage, UUPSUpgradeable, IEverclearHub {
  using Uint32Set for Uint32Set.Set;

  constructor() {
    _disableInitializers();
  }

  /*///////////////////////////////////////////////////////////////
                    SETTLER MODULE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISettler
  function processDepositsAndInvoices(bytes32, uint32, uint32, uint32) external {
    _delegate(_SETTLEMENT_MODULE);
  }

  /// @inheritdoc ISettler
  function processSettlementQueue(uint32, uint32) external payable whenNotPaused {
    _delegate(_SETTLEMENT_MODULE);
  }

  /// @inheritdoc ISettler
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

  /// @inheritdoc IHandler
  function handleExpiredIntents(
    bytes32[] calldata
  ) external payable whenNotPaused {
    _delegate(_HANDLER_MODULE);
  }

  /// @inheritdoc IHandler
  function returnUnsupportedIntent(
    bytes32
  ) external payable whenNotPaused {
    _delegate(_HANDLER_MODULE);
  }

  /// @inheritdoc IHandler
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

  /// @inheritdoc IAssetManager
  function setAdoptedForAsset(
    AssetConfig calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IAssetManager
  function setTokenConfigs(
    TokenSetup[] calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IAssetManager
  function setPrioritizedStrategy(bytes32, IEverclear.Strategy) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IAssetManager
  function setLastClosedEpochProcessed(
    SetLastClosedEpochProcessedParams calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IAssetManager
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

  /// @inheritdoc IProtocolManager
  function proposeOwner(
    address
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function acceptOwnership() external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateLighthouse(
    address
  ) external payable {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateWatchtower(
    address
  ) external payable {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateAcceptanceDelay(
    uint256
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function assignRole(address, Role) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function addSupportedDomains(
    DomainSetup[] calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function removeSupportedDomains(
    uint32[] calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function pause() external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function unpause() external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateMinSolverSupportedDomains(
    uint8
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateMailbox(
    address
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateMailbox(bytes32, uint32[] calldata) external payable {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateSecurityModule(
    address
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateGateway(
    address
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateGateway(bytes32, uint32[] calldata) external payable {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateChainGateway(uint32, bytes32) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function removeChainGateway(
    uint32
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateExpiryTimeBuffer(
    uint48
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateEpochLength(
    uint48
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function updateGasConfig(
    GasConfig calldata
  ) external {
    _delegate(_MANAGER_MODULE);
  }

  /// @inheritdoc IProtocolManager
  function setMaxDiscountDbps(bytes32, uint24) external {
    _delegate(_MANAGER_MODULE);
  }

  /*///////////////////////////////////////////////////////////////
                        UPGRADE FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEverclearHub
  function updateModuleAddress(bytes32 _type, address _newAddress) external onlyOwner {
    address _previousAddress = modules[_type];
    modules[_type] = _newAddress;
    emit ModuleAddressUpdated(_type, _previousAddress, _newAddress);
  }

  /// @inheritdoc IEverclearHub
  function userSupportedDomains(
    bytes32 _owner
  ) external view returns (uint32[] memory _supportedDomains) {
    _supportedDomains = _usersSupportedDomains[_owner].memValues();
  }

  /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IEverclearHub
  function supportedDomains() external view returns (uint32[] memory __supportedDomains) {
    return _supportedDomains.memValues();
  }

  /**
   * @notice Initialize the EverclearHub contract
   * @param _init The hub initialization parameters
   */
  function initialize(
    HubInitializationParams calldata _init
  ) public initializer {
    owner = _init.owner;
    roles[_init.admin] = Role.ADMIN;
    hubGateway = _init.hubGateway;
    lighthouse = _init.lighthouse;
    acceptanceDelay = _init.acceptanceDelay;
    minSolverSupportedDomains = _init.minSolverSupportedDomains;
    expiryTimeBuffer = _init.expiryTimeBuffer;
    epochLength = _init.epochLength;

    gasConfig.settlementBaseGasUnits = _init.settlementBaseGasUnits;
    gasConfig.averageGasUnitsPerSettlement = _init.averageGasUnitsPerSettlement;
    gasConfig.bufferDBPS = _init.bufferDBPS;

    modules[_SETTLEMENT_MODULE] = _init.settler;
    modules[_MANAGER_MODULE] = _init.manager;
    modules[_HANDLER_MODULE] = _init.handler;
    modules[_MESSAGE_RECEIVER_MODULE] = _init.messageReceiver;
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
