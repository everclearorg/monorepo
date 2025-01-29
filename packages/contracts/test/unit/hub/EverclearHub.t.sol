// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TestExtended} from '../../utils/TestExtended.sol';

import {Deploy} from 'utils/Deploy.sol';

import {EverclearHub, IEverclearHub} from 'contracts/hub/EverclearHub.sol';

import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

import {IAssetManager} from 'interfaces/hub/IAssetManager.sol';
import {IHandler} from 'interfaces/hub/IHandler.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';
import {IProtocolManager} from 'interfaces/hub/IProtocolManager.sol';
import {ISettler} from 'interfaces/hub/ISettler.sol';
import {IUsersManager} from 'interfaces/hub/IUsersManager.sol';

contract BaseTest is TestExtended {
  IEverclearHub internal everclearHub;

  address immutable OWNER = makeAddr('OWNER');
  address immutable ADMIN = makeAddr('ADMIN');
  address immutable MANAGER = makeAddr('MANAGER');
  address immutable SETTLER = makeAddr('SETTLER');
  address immutable HANDLER = makeAddr('HANDLER');
  address immutable MESSAGE_RECEIVER = makeAddr('MESSAGE_RECEIVER');
  address immutable LIGHTHOUSE = makeAddr('LIGHTHOUSE');
  IHubGateway immutable HUB_GATEWAY = IHubGateway(makeAddr('HUB_GATEWAY'));
  uint256 immutable ACCETPANCE_DELAY = 1;
  uint256 immutable SETTLEMENT_BASE_GAS_UNITS = 100;
  uint256 immutable AVERAGE_GAS_UNITS_PER_SETTLEMENT = 1;
  uint256 immutable BUFFER_DBPS = 1;
  uint8 immutable MIN_SOLVER_SUPPORTED_DOMAINS = 1;
  uint48 immutable EXPIRY_TIME_BUFFER = 3 hours;
  uint48 immutable EPOCH_LENGTH = 25; // blocks
  uint24 immutable DISCOUNT_PER_EPOCH = 1000; // 1%

  bytes32 internal constant SETTLEMENT_MODULE = keccak256('settlement_module');
  bytes32 internal constant HANDLER_MODULE = keccak256('handler_module');
  bytes32 internal constant MESSAGE_RECEIVER_MODULE = keccak256('message_receiver_module');
  bytes32 internal constant MANAGER_MODULE = keccak256('manager_module');

  function setUp() public {
    IEverclearHub.HubInitializationParams memory _params = IEverclearHub.HubInitializationParams({
      owner: OWNER,
      admin: ADMIN,
      manager: MANAGER,
      settler: SETTLER,
      handler: HANDLER,
      messageReceiver: MESSAGE_RECEIVER,
      lighthouse: LIGHTHOUSE,
      hubGateway: HUB_GATEWAY,
      acceptanceDelay: ACCETPANCE_DELAY,
      expiryTimeBuffer: EXPIRY_TIME_BUFFER,
      epochLength: EPOCH_LENGTH,
      discountPerEpoch: DISCOUNT_PER_EPOCH,
      minSolverSupportedDomains: MIN_SOLVER_SUPPORTED_DOMAINS,
      settlementBaseGasUnits: SETTLEMENT_BASE_GAS_UNITS,
      averageGasUnitsPerSettlement: AVERAGE_GAS_UNITS_PER_SETTLEMENT,
      bufferDBPS: BUFFER_DBPS
    });

    everclearHub = Deploy.EverclearHubProxy(_params);
  }
}

contract Unit_Initialization is BaseTest {
  /**
   * @notice Tests the initialization of the EverclearHub contract
   * @param _init The initialization parameters
   */
  function test_Initialization(
    IEverclearHub.HubInitializationParams calldata _init
  ) public {
    vm.assume(_init.owner != address(0));
    everclearHub = Deploy.EverclearHubProxy(_init);

    assertEq(everclearHub.owner(), _init.owner);
    assertEq(uint8(everclearHub.roles(_init.admin)), uint8(IHubStorage.Role.ADMIN));
    assertEq(address(everclearHub.hubGateway()), address(_init.hubGateway));
    assertEq(everclearHub.lighthouse(), _init.lighthouse);
    assertEq(everclearHub.acceptanceDelay(), _init.acceptanceDelay);
    assertEq(everclearHub.minSolverSupportedDomains(), _init.minSolverSupportedDomains);
    assertEq(everclearHub.expiryTimeBuffer(), _init.expiryTimeBuffer);
    assertEq(everclearHub.epochLength(), _init.epochLength);
    assertEq(everclearHub.modules(SETTLEMENT_MODULE), _init.settler);
    assertEq(everclearHub.modules(MANAGER_MODULE), _init.manager);
    assertEq(everclearHub.modules(HANDLER_MODULE), _init.handler);
    assertEq(everclearHub.modules(MESSAGE_RECEIVER_MODULE), _init.messageReceiver);
  }
}

contract Unit_Settler is BaseTest {
  /**
   * @notice Tests the processDepositsAndInvoices function
   * @param _tickerHash The ticker hash
   */
  function test_ProcessDepositsAndInvoices(
    bytes32 _tickerHash
  ) public {
    vm.mockCall(
      SETTLER, abi.encodeWithSelector(ISettler.processDepositsAndInvoices.selector, _tickerHash, 0, 0, 0), abi.encode(0)
    );
    vm.expectCall(SETTLER, abi.encodeWithSelector(ISettler.processDepositsAndInvoices.selector, _tickerHash, 0, 0, 0));

    everclearHub.processDepositsAndInvoices(_tickerHash, 0, 0, 0);
  }

  /**
   * @notice Tests the processSettlementQueue function
   * @param _domain The domain
   * @param _amount The amount
   */
  function test_ProcessSettlementQueue(uint32 _domain, uint32 _amount) public {
    vm.mockCall(
      SETTLER, abi.encodeWithSelector(ISettler.processSettlementQueue.selector, _domain, _amount), abi.encode(0)
    );
    vm.expectCall(SETTLER, abi.encodeWithSelector(ISettler.processSettlementQueue.selector, _domain, _amount));

    everclearHub.processSettlementQueue(_domain, _amount);
  }

  /**
   * @notice Tests the processSettlementQueueViaRelayer function
   * @param _domain The domain
   * @param _amount The amount
   * @param _relayer The relayer
   * @param _ttl The time to live
   * @param _nonce The nonce
   * @param _bufferDBPS The buffer DBPS
   * @param _signature The signature
   */
  function test_ProcessSettlementQueueViaRelayer(
    uint32 _domain,
    uint32 _amount,
    address _relayer,
    uint256 _ttl,
    uint256 _nonce,
    uint256 _bufferDBPS,
    bytes calldata _signature
  ) public {
    assumeNotPrecompile(_relayer);
    vm.mockCall(
      SETTLER,
      abi.encodeWithSelector(
        ISettler.processSettlementQueueViaRelayer.selector,
        _domain,
        _amount,
        _relayer,
        _ttl,
        _nonce,
        _bufferDBPS,
        _signature
      ),
      abi.encode(0)
    );
    vm.expectCall(
      SETTLER,
      abi.encodeWithSelector(
        ISettler.processSettlementQueueViaRelayer.selector,
        _domain,
        _amount,
        _relayer,
        _ttl,
        _nonce,
        _bufferDBPS,
        _signature
      )
    );

    everclearHub.processSettlementQueueViaRelayer(_domain, _amount, _relayer, _ttl, _nonce, _bufferDBPS, _signature);
  }
}

contract Unit_Handler is BaseTest {
  /**
   * @notice Tests the handleExpiredIntents function
   * @param _intentIds The intent IDs
   */
  function test_HandleExpiredIntents(
    bytes32[] calldata _intentIds
  ) public {
    vm.mockCall(HANDLER, abi.encodeWithSelector(IHandler.handleExpiredIntents.selector, _intentIds), abi.encode(0));
    vm.expectCall(HANDLER, abi.encodeWithSelector(IHandler.handleExpiredIntents.selector, _intentIds));

    everclearHub.handleExpiredIntents(_intentIds);
  }

  /**
   * @notice Tests the returnUnsupportedIntent function
   * @param _intentId The intent ID
   */
  function test_ReturnUnsupportedIntent(
    bytes32 _intentId
  ) public {
    vm.mockCall(HANDLER, abi.encodeWithSelector(IHandler.returnUnsupportedIntent.selector, _intentId), abi.encode(0));
    vm.expectCall(HANDLER, abi.encodeWithSelector(IHandler.returnUnsupportedIntent.selector, _intentId));

    everclearHub.returnUnsupportedIntent(_intentId);
  }

  /**
   * @notice Tests the withdrawFees function
   * @param _tickerHash The ticker hash
   * @param _intentId The intent ID
   * @param _amount The amount
   * @param _domains The domains
   */
  function test_WithdrawFees(
    bytes32 _tickerHash,
    bytes32 _intentId,
    uint256 _amount,
    uint32[] calldata _domains
  ) public {
    vm.mockCall(
      HANDLER,
      abi.encodeWithSelector(IHandler.withdrawFees.selector, _tickerHash, _intentId, _amount, _domains),
      abi.encode(0)
    );
    vm.expectCall(
      HANDLER, abi.encodeWithSelector(IHandler.withdrawFees.selector, _tickerHash, _intentId, _amount, _domains)
    );

    everclearHub.withdrawFees(_tickerHash, _intentId, _amount, _domains);
  }
}

contract Unit_MessageReceiver is BaseTest {
  /**
   * @notice Tests the receiveMessage function
   * @param _message The message received
   */
  function test_ReceiveMessage(
    bytes calldata _message
  ) public {
    vm.mockCall(
      MESSAGE_RECEIVER, abi.encodeWithSelector(IMessageReceiver.receiveMessage.selector, _message), abi.encode(0)
    );
    vm.expectCall(MESSAGE_RECEIVER, abi.encodeWithSelector(IMessageReceiver.receiveMessage.selector, _message));

    everclearHub.receiveMessage(_message);
  }
}

contract Unit_AssetManager is BaseTest {
  /**
   * @notice Tests the setAdoptedForAsset function
   * @param _tickerHash The ticker hash
   * @param _adopted The adopted
   * @param _domain The domain
   * @param _approval The approval
   * @param _strategySeed The strategy seed
   */
  function test_SetAdoptedForAsset(
    bytes32 _tickerHash,
    bytes32 _adopted,
    uint32 _domain,
    bool _approval,
    uint8 _strategySeed
  ) public {
    IEverclear.Strategy _strategy = IEverclear.Strategy(bound(_strategySeed, 0, uint256(type(IEverclear.Strategy).max)));

    IHubStorage.AssetConfig memory _assetConfig =
      IHubStorage.AssetConfig(_tickerHash, _adopted, _domain, _approval, _strategy);

    vm.mockCall(MANAGER, abi.encodeWithSelector(IAssetManager.setAdoptedForAsset.selector, _assetConfig), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IAssetManager.setAdoptedForAsset.selector, _assetConfig));

    everclearHub.setAdoptedForAsset(_assetConfig);
  }

  /**
   * @notice Tests the setTokenConfigs function
   * @param _tickerHashes The ticker hashes
   * @param _maxDiscountDBPSs The max discount DBPSs
   * @param _discountPerEpochs The discount per epochs
   * @param _fees The fees
   * @param _tickerHash The ticker hash
   * @param _adopted The adopted
   * @param _domain The domain
   * @param _approval The approval
   * @param _strategiesSeed The strategies seed
   */
  function test_SetTokenConfigs(
    bytes32[MAX_FUZZED_ARRAY_LENGTH] calldata _tickerHashes,
    uint24[MAX_FUZZED_ARRAY_LENGTH] calldata _maxDiscountDBPSs,
    uint24[MAX_FUZZED_ARRAY_LENGTH] calldata _discountPerEpochs,
    IHubStorage.Fee[][MAX_FUZZED_ARRAY_LENGTH] calldata _fees,
    bytes32[MAX_FUZZED_ARRAY_LENGTH] calldata _tickerHash,
    bytes32[MAX_FUZZED_ARRAY_LENGTH] calldata _adopted,
    uint32[MAX_FUZZED_ARRAY_LENGTH] calldata _domain,
    bool[MAX_FUZZED_ARRAY_LENGTH] calldata _approval,
    uint8[MAX_FUZZED_ARRAY_LENGTH] calldata _strategiesSeed
  ) public {
    IHubStorage.TokenSetup[] memory _config = new IHubStorage.TokenSetup[](MAX_FUZZED_ARRAY_LENGTH);

    for (uint8 _i; _i < MAX_FUZZED_ARRAY_LENGTH; _i++) {
      IHubStorage.AssetConfig[] memory _assetConfigs = new IHubStorage.AssetConfig[](2);

      _assetConfigs[0] = IHubStorage.AssetConfig(
        _tickerHash[_i],
        _adopted[_i],
        _domain[_i],
        _approval[_i],
        IEverclear.Strategy(bound(_strategiesSeed[_i], 0, uint256(type(IEverclear.Strategy).max)))
      );

      _assetConfigs[1] = IHubStorage.AssetConfig(
        _tickerHash[_i],
        _adopted[_i],
        _domain[_i],
        _approval[_i],
        IEverclear.Strategy(bound(_strategiesSeed[_i], 0, uint256(type(IEverclear.Strategy).max)))
      );

      _config[_i] = IHubStorage.TokenSetup(
        _tickerHashes[_i],
        true,
        IEverclear.Strategy.XERC20,
        _maxDiscountDBPSs[_i],
        _discountPerEpochs[_i],
        _fees[_i],
        _assetConfigs
      );
    }

    vm.mockCall(MANAGER, abi.encodeWithSelector(IAssetManager.setTokenConfigs.selector, _config), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IAssetManager.setTokenConfigs.selector, _config));

    everclearHub.setTokenConfigs(_config);
  }

  /**
   * @notice Tests the setPrioritizedStrategy function
   * @param _tickerHash The ticker hash
   * @param _strategySeed The strategy seed
   */
  function test_SetPrioritizedStrategy(bytes32 _tickerHash, uint8 _strategySeed) public {
    IEverclear.Strategy _strategy = IEverclear.Strategy(bound(_strategySeed, 0, uint256(type(IEverclear.Strategy).max)));

    vm.mockCall(
      MANAGER,
      abi.encodeWithSelector(IAssetManager.setPrioritizedStrategy.selector, _tickerHash, _strategy),
      abi.encode(0)
    );
    vm.expectCall(
      MANAGER, abi.encodeWithSelector(IAssetManager.setPrioritizedStrategy.selector, _tickerHash, _strategy)
    );

    everclearHub.setPrioritizedStrategy(_tickerHash, _strategy);
  }

  /**
   * @notice Tests the setLastClosedEpochProcessed function
   * @param _params The parameters for setting the last epoch processed
   */
  function test_SetLastClosedEpochProcessed(
    IAssetManager.SetLastClosedEpochProcessedParams calldata _params
  ) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSelector(IAssetManager.setLastClosedEpochProcessed.selector, _params), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSelector(IAssetManager.setLastClosedEpochProcessed.selector, _params));

    everclearHub.setLastClosedEpochProcessed(_params);
  }

  /**
   * @notice Tests the setDiscountPerEpoch function
   * @param _tickerHash The ticker hash
   * @param _discountPerEpoch The discount per epoch
   */
  function test_SetDiscountPerEpoch(bytes32 _tickerHash, uint24 _discountPerEpoch) public {
    vm.mockCall(
      MANAGER,
      abi.encodeWithSelector(IAssetManager.setDiscountPerEpoch.selector, _tickerHash, _discountPerEpoch),
      abi.encode(0)
    );
    vm.expectCall(
      MANAGER, abi.encodeWithSelector(IAssetManager.setDiscountPerEpoch.selector, _tickerHash, _discountPerEpoch)
    );

    everclearHub.setDiscountPerEpoch(_tickerHash, _discountPerEpoch);
  }
}

contract Unit_Solver is BaseTest {
  /**
   * @notice Tests the setUserSupportedDomains function
   * @param _supportedDomains The supported domains
   */
  function test_SetUser(
    uint32[] calldata _supportedDomains
  ) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSelector(IUsersManager.setUserSupportedDomains.selector, _supportedDomains), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSelector(IUsersManager.setUserSupportedDomains.selector, _supportedDomains));

    everclearHub.setUserSupportedDomains(_supportedDomains);
  }

  /**
   * @notice Tests the setUpdateVirtualBalance function
   * @param _status The status
   */
  function test_UpdateVirtualBalance(
    bool _status
  ) public {
    vm.mockCall(MANAGER, abi.encodeWithSelector(IUsersManager.setUpdateVirtualBalance.selector, _status), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IUsersManager.setUpdateVirtualBalance.selector, _status));

    everclearHub.setUpdateVirtualBalance(_status);
  }
}

contract Unit_ProtocolManager is BaseTest {
  /**
   * @notice Tests the proposeOwner function
   * @param _newOwner The new owner
   */
  function test_ProposeOwner(
    address _newOwner
  ) public {
    vm.mockCall(MANAGER, abi.encodeWithSelector(IProtocolManager.proposeOwner.selector, _newOwner), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.proposeOwner.selector, _newOwner));

    everclearHub.proposeOwner(_newOwner);
  }

  /**
   * @notice Tests the acceptOwnership function
   */
  function test_AcceptOwnership() public {
    vm.mockCall(MANAGER, abi.encodeWithSelector(IProtocolManager.acceptOwnership.selector), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.acceptOwnership.selector));

    everclearHub.acceptOwnership();
  }

  /**
   * @notice Tests the updateLighthouse function
   * @param _newLighthouse The new lighthouse
   */
  function test_UpdateLighthouse(
    address _newLighthouse
  ) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSelector(IProtocolManager.updateLighthouse.selector, _newLighthouse), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.updateLighthouse.selector, _newLighthouse));

    everclearHub.updateLighthouse(_newLighthouse);
  }

  /**
   * @notice Tests the updateWatchtower function
   * @param _newWatchtower The new watchtower
   */
  function test_UpdateWatchtower(
    address _newWatchtower
  ) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSelector(IProtocolManager.updateWatchtower.selector, _newWatchtower), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.updateWatchtower.selector, _newWatchtower));

    everclearHub.updateWatchtower(_newWatchtower);
  }

  /**
   * @notice Tests the updateAcceptanceDelay function
   * @param _newDelay The new delay
   */
  function test_UpdateAcceptanceDelay(
    uint256 _newDelay
  ) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSelector(IProtocolManager.updateAcceptanceDelay.selector, _newDelay), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.updateAcceptanceDelay.selector, _newDelay));

    everclearHub.updateAcceptanceDelay(_newDelay);
  }

  /**
   * @notice Tests the assignRole function
   * @param _account The account
   * @param _role The role
   */
  function test_AssignRole(address _account, uint256 _role) public {
    IHubStorage.Role _role = IHubStorage.Role(bound(_role, 0, uint256(type(IHubStorage.Role).max)));

    vm.mockCall(MANAGER, abi.encodeWithSelector(IProtocolManager.assignRole.selector, _account, _role), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.assignRole.selector, _account, _role));

    everclearHub.assignRole(_account, IHubStorage.Role(_role));
  }

  /**
   * @notice Tests the addSupportedDomains function
   * @param _domains The domains
   */
  function test_AddSupportedDomains(
    IHubStorage.DomainSetup[] calldata _domains
  ) public {
    vm.mockCall(MANAGER, abi.encodeWithSelector(IProtocolManager.addSupportedDomains.selector, _domains), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.addSupportedDomains.selector, _domains));

    everclearHub.addSupportedDomains(_domains);
  }

  /**
   * @notice Tests the removeSupportedDomains function
   * @param _domains The domains to remove
   */
  function test_RemoveSupportedDomains(
    uint32[] calldata _domains
  ) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSelector(IProtocolManager.removeSupportedDomains.selector, _domains), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.removeSupportedDomains.selector, _domains));

    everclearHub.removeSupportedDomains(_domains);
  }

  /**
   * @notice Tests pausing the contract
   */
  function test_Pause() public {
    vm.mockCall(MANAGER, abi.encodeWithSelector(IProtocolManager.pause.selector), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.pause.selector));

    everclearHub.pause();
  }

  /**
   * @notice Tests unpausing the contract
   */
  function test_Unpause() public {
    vm.mockCall(MANAGER, abi.encodeWithSelector(IProtocolManager.unpause.selector), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.unpause.selector));

    everclearHub.unpause();
  }

  /**
   * @notice Tests the updateMinSolverSupportedDomains function
   * @param _newMin The new minimum
   */
  function test_UpdateMinSolverSupportedDomains(
    uint8 _newMin
  ) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSelector(IProtocolManager.updateMinSolverSupportedDomains.selector, _newMin), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.updateMinSolverSupportedDomains.selector, _newMin));

    everclearHub.updateMinSolverSupportedDomains(_newMin);
  }

  /**
   * @notice Tests the updateMailbox function
   * @param _newMailbox The new mailbox
   */
  function test_UpdateMailbox(
    address _newMailbox
  ) public {
    vm.mockCall(MANAGER, abi.encodeWithSignature('updateMailbox(address)', _newMailbox), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSignature('updateMailbox(address)', _newMailbox));

    everclearHub.updateMailbox(_newMailbox);
  }

  /**
   * @notice Tests the updateMailbox functions with multiple domains
   * @param _newMailbox The new mailbox
   * @param _domains The domains
   */
  function test_UpdateMailboxWithDomains(bytes32 _newMailbox, uint32[] calldata _domains) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSignature('updateMailbox(bytes32,uint32[])', _newMailbox, _domains), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSignature('updateMailbox(bytes32,uint32[])', _newMailbox, _domains));

    everclearHub.updateMailbox(_newMailbox, _domains);
  }

  /**
   * @notice Tests the updateSecurityModule function
   * @param _newSecurityModule The new security module
   */
  function test_UpdateSecurityModule(
    address _newSecurityModule
  ) public {
    vm.mockCall(MANAGER, abi.encodeWithSignature('updateSecurityModule(address)', _newSecurityModule), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSignature('updateSecurityModule(address)', _newSecurityModule));

    everclearHub.updateSecurityModule(_newSecurityModule);
  }

  /**
   * @notice Tests the updateGateway function
   * @param _newGateway The new gateway
   */
  function test_UpdateGateway(
    address _newGateway
  ) public {
    vm.mockCall(MANAGER, abi.encodeWithSignature('updateGateway(address)', _newGateway), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSignature('updateGateway(address)', _newGateway));

    everclearHub.updateGateway(_newGateway);
  }

  /**
   * @notice Tests the updateGateway function with multiple domains
   * @param _newGateway The new gateway
   * @param _domains The domains
   */
  function test_UpdateGatewayWithDomains(bytes32 _newGateway, uint32[] calldata _domains) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSignature('updateGateway(bytes32,uint32[])', _newGateway, _domains), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSignature('updateGateway(bytes32,uint32[])', _newGateway, _domains));

    everclearHub.updateGateway(_newGateway, _domains);
  }

  /**
   * @notice Tests the updateChainGateway function
   * @param _chainId The chain ID
   * @param _gateway The gateway
   */
  function test_UpdateChainGateway(uint32 _chainId, bytes32 _gateway) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSelector(IProtocolManager.updateChainGateway.selector, _chainId, _gateway), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.updateChainGateway.selector, _chainId, _gateway));

    everclearHub.updateChainGateway(_chainId, _gateway);
  }

  /**
   * @notice Tests the removeChainGateway function
   * @param _chainId The chain ID
   */
  function test_RemoveChainGateway(
    uint32 _chainId
  ) public {
    vm.mockCall(MANAGER, abi.encodeWithSelector(IProtocolManager.removeChainGateway.selector, _chainId), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.removeChainGateway.selector, _chainId));

    everclearHub.removeChainGateway(_chainId);
  }

  /**
   * @notice Tests the updateExpiryTimeBuffer function
   * @param _newBuffer The new buffer
   */
  function test_UpdateExpiryTimeBuffer(
    uint48 _newBuffer
  ) public {
    vm.mockCall(
      MANAGER, abi.encodeWithSelector(IProtocolManager.updateExpiryTimeBuffer.selector, _newBuffer), abi.encode(0)
    );
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.updateExpiryTimeBuffer.selector, _newBuffer));

    everclearHub.updateExpiryTimeBuffer(_newBuffer);
  }

  /**
   * @notice Tests the setDiscountPerEpoch function
   * @param _tickerHash The ticker hash
   * @param _newDiscount The new discount
   */
  function test_SetDiscountPerEpoch(bytes32 _tickerHash, uint24 _newDiscount) public {
    vm.mockCall(
      MANAGER,
      abi.encodeWithSelector(IAssetManager.setDiscountPerEpoch.selector, _tickerHash, _newDiscount),
      abi.encode(0)
    );
    vm.expectCall(
      MANAGER, abi.encodeWithSelector(IAssetManager.setDiscountPerEpoch.selector, _tickerHash, _newDiscount)
    );

    everclearHub.setDiscountPerEpoch(_tickerHash, _newDiscount);
  }

  /**
   * @notice Tests the updateEpochLength function
   * @param _newLength The new length
   */
  function test_UpdateEpochLength(
    uint48 _newLength
  ) public {
    vm.mockCall(MANAGER, abi.encodeWithSelector(IProtocolManager.updateEpochLength.selector, _newLength), abi.encode(0));
    vm.expectCall(MANAGER, abi.encodeWithSelector(IProtocolManager.updateEpochLength.selector, _newLength));

    everclearHub.updateEpochLength(_newLength);
  }

  /**
   * @notice Tests the setMaxDiscountDbps function
   * @param _tickerHash The ticker hash
   * @param _newMaxDiscount The new max discount
   */
  function test_SetMaxDiscountDbps(bytes32 _tickerHash, uint24 _newMaxDiscount) public {
    vm.mockCall(
      MANAGER,
      abi.encodeWithSelector(IProtocolManager.setMaxDiscountDbps.selector, _tickerHash, _newMaxDiscount),
      abi.encode(0)
    );
    vm.expectCall(
      MANAGER, abi.encodeWithSelector(IProtocolManager.setMaxDiscountDbps.selector, _tickerHash, _newMaxDiscount)
    );

    everclearHub.setMaxDiscountDbps(_tickerHash, _newMaxDiscount);
  }
}

contract Unit_UpdateFunctions is BaseTest {
  /**
   * @notice Tests the updateModuleAddress function
   * @param _moduleType The module type
   * @param _newAddress The new address
   */
  function test_UpdateModuleAddress(bytes32 _moduleType, address _newAddress) public {
    vm.prank(OWNER);
    everclearHub.updateModuleAddress(_moduleType, _newAddress);

    assertEq(everclearHub.modules(_moduleType), _newAddress);
  }

  /**
   * @notice Tests the updateModuleAddress function with a non-owner caller
   * @param _caller The caller address
   * @param _moduleType The module type
   * @param _newAddress The new address
   */
  function test_Revert_UpdateModuleAddress_NotOwner(address _caller, bytes32 _moduleType, address _newAddress) public {
    vm.assume(_caller != OWNER);
    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);

    vm.prank(_caller);
    everclearHub.updateModuleAddress(_moduleType, _newAddress);
  }
}
