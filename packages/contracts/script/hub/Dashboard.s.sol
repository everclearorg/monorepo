// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {HubGateway} from 'contracts/hub/HubGateway.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';

import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

contract Dashboard is Script, ScriptUtils {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  struct OwnershipData {
    address owner;
    address proposedOwner;
    uint256 proposedOwnershipTimestamp;
  }

  struct ModulesData {
    address settlementModule;
    address handlerModule;
    address messageReceiverModule;
    address managerModule;
  }

  struct GeneralInformation {
    uint32[] supportedDomains;
    bool initialized;
    uint256 acceptanceDelay;
    uint48 epochLength;
    // uint48 currentEpoch;
    uint48 expiryTimeBuffer;
    uint64 paymentNonce;
    IHubGateway hubGateway;
    address lightHouse;
    uint8 minSolverSupportedDomains;
  }

  struct GatewayData {
    address owner;
    address mailbox;
    address receiver;
    address ism;
    uint32[] domains;
    address[] gateways;
  }

  /**
   * @notice The module type hash for the settlement module
   */
  bytes32 internal constant _SETTLEMENT_MODULE = keccak256('settlement_module');

  /**
   * @notice The module type hash for the handler module
   */
  bytes32 internal constant _HANDLER_MODULE = keccak256('handler_module');

  /**
   * @notice The module type hash for the message receiver module
   */
  bytes32 internal constant _MESSAGE_RECEIVER_MODULE = keccak256('message_receiver_module');

  /**
   * @notice The module type hash for the manager module
   */
  bytes32 internal constant _MANAGER_MODULE = keccak256('manager_module');

  function run(
    address _hub
  ) public view {
    IEverclearHub _everclearHub = IEverclearHub(_hub);

    // general information
    GeneralInformation memory _generalInformation = _getGeneralInformation(_everclearHub);

    // modules
    ModulesData memory _modulesData = _getModulesData(_everclearHub);

    // owner
    OwnershipData memory _ownershipData = _getOwnershipData(_everclearHub);
    bool _paused = _everclearHub.paused();
    address _watchTower = _everclearHub.watchtower();

    // gas config
    (uint256 _settlementBaseGasUnits, uint256 _averageGasUnitsPerSettlement, uint256 _bufferDBPS) =
      _everclearHub.gasConfig();

    // gateway data
    GatewayData memory _gatewayData = _getGatewayData(_everclearHub);
    console.log('================================== Hub Dashboard ==================================');

    // Owner section
    console.log('Owner                                  ', _ownershipData.owner);
    console.log('Proposed Owner                         ', _ownershipData.proposedOwner);
    console.log('Proposed Ownership Timestamp           ', _ownershipData.proposedOwnershipTimestamp);

    // Paused status
    console.log('Paused                                 ', _paused);

    // Supported Domains
    console.log('Supported Domains                      ');
    for (uint256 i = 0; i < _generalInformation.supportedDomains.length; i++) {
      console.log('[', i, '] Spoke domain                     ', _generalInformation.supportedDomains[i]);
    }

    // General Information
    console.log('Initialized                            ', _generalInformation.initialized);
    console.log('Acceptance Delay                       ', _generalInformation.acceptanceDelay);
    console.log('Epoch Length                           ', _generalInformation.epochLength);
    // console.log('Current Epoch                          ', _generalInformation.currentEpoch);
    console.log('Expiry Time Buffer                     ', _generalInformation.expiryTimeBuffer);
    console.log('Payment Nonce                          ', _generalInformation.paymentNonce);
    console.log('Hub Gateway                            ', address(_generalInformation.hubGateway));
    console.log('Lighthouse                             ', _generalInformation.lightHouse);
    console.log('Watchtower                             ', _watchTower);
    console.log('Min Solver Supported Domains           ', _generalInformation.minSolverSupportedDomains);

    // Modules Data
    console.log('Settlement Module                      ', _modulesData.settlementModule);
    console.log('Handler Module                         ', _modulesData.handlerModule);
    console.log('Message Receiver Module                ', _modulesData.messageReceiverModule);
    console.log('Manager Module                         ', _modulesData.managerModule);

    // Gas Configurations
    console.log('Settlement Base Gas Units              ', _settlementBaseGasUnits);
    console.log('Average Gas Units Per Settlement       ', _averageGasUnitsPerSettlement);
    console.log('Buffer DBPS                            ', _bufferDBPS);

    // Gateway Data
    console.log('Gateway owner                          ', _gatewayData.owner);
    console.log('Gateway mailbox                        ', _gatewayData.mailbox);
    console.log('Gateway receiver                       ', _gatewayData.receiver);
    console.log('Gateway ism                            ', _gatewayData.ism);
    console.log('Chain gateways                         ');
    for (uint256 i = 0; i < _gatewayData.domains.length; i++) {
      console.log('[', i, '] Spoke domain                     ', _gatewayData.domains[i]);
      console.log('[', i, '] Chain gateway                    ', _gatewayData.gateways[i]);
    }
    console.log('================================== Hub Dashboard ==================================');
  }

  function _getOwnershipData(
    IEverclearHub _hub
  ) internal view returns (OwnershipData memory _data) {
    address _owner = _hub.owner();
    address _proposedOwner = _hub.proposedOwner();
    uint256 _proposedOwnershipTimestamp = _hub.proposedOwnershipTimestamp();

    _data = OwnershipData({
      owner: _owner,
      proposedOwner: _proposedOwner,
      proposedOwnershipTimestamp: _proposedOwnershipTimestamp
    });
  }

  function _getModulesData(
    IEverclearHub _hub
  ) internal view returns (ModulesData memory _data) {
    address _settlementModule = _hub.modules(_SETTLEMENT_MODULE);
    address _handlerModule = _hub.modules(_HANDLER_MODULE);
    address _messageReceiverModule = _hub.modules(_MESSAGE_RECEIVER_MODULE);
    address _managerModule = _hub.modules(_MANAGER_MODULE);
    _data = ModulesData({
      settlementModule: _settlementModule,
      handlerModule: _handlerModule,
      messageReceiverModule: _messageReceiverModule,
      managerModule: _managerModule
    });
  }

  function _getGeneralInformation(
    IEverclearHub _hub
  ) internal view returns (GeneralInformation memory _data) {
    uint32[] memory _supportedDomains = _hub.supportedDomains();
    bool _initialized = _hub.initialized();
    uint256 _acceptanceDelay = _hub.acceptanceDelay();
    uint48 _epochLength = _hub.epochLength();
    // NOTE: reverts in foundry bc foundry using `block.number` = everclear block, and
    // onchain contracts on arbitrum use `block.number` = l1 block
    // uint48 _currentEpoch = _hub.getCurrentEpoch();
    uint48 _expiryTimeBuffer = _hub.expiryTimeBuffer();
    uint64 _paymentNonce = _hub.paymentNonce();
    IHubGateway _hubGateway = _hub.hubGateway();
    address _lightHouse = _hub.lighthouse();
    uint8 _minSolverSupportedDomains = _hub.minSolverSupportedDomains();

    _data = GeneralInformation({
      supportedDomains: _supportedDomains,
      initialized: _initialized,
      acceptanceDelay: _acceptanceDelay,
      epochLength: _epochLength,
      // currentEpoch: _currentEpoch,
      expiryTimeBuffer: _expiryTimeBuffer,
      paymentNonce: _paymentNonce,
      hubGateway: _hubGateway,
      lightHouse: _lightHouse,
      minSolverSupportedDomains: _minSolverSupportedDomains
    });
  }

  function _getGatewayData(
    IEverclearHub _hub
  ) internal view returns (GatewayData memory _data) {
    HubGateway _hubGateway = HubGateway(payable(address(_hub.hubGateway())));
    address _owner = _hubGateway.owner();
    address _mailbox = address(_hubGateway.mailbox());
    address _receiver = address(_hubGateway.receiver());
    address _ism = address(_hubGateway.interchainSecurityModule());
    uint32[] memory _supported = _hub.supportedDomains();
    address[] memory _gateways = new address[](_supported.length);
    for (uint256 i = 0; i < _supported.length; i++) {
      _gateways[i] = _hubGateway.chainGateways(_supported[i]).toAddress();
    }

    _data = GatewayData({
      owner: _owner,
      mailbox: _mailbox,
      receiver: _receiver,
      ism: _ism,
      domains: _supported,
      gateways: _gateways
    });
  }
}
