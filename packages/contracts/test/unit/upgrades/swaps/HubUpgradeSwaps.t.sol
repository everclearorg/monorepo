// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {MessageLibV2} from 'contracts/common/MessageLibV2.sol';

import {ICREATE3, UpgradeHelper} from 'test//utils/UpgradeHelper.sol';
import {BaseTest} from 'test/unit/intent/EverclearSpoke.t.sol';
import {Constants} from 'test/utils/Constants.sol';

import {EverclearHubV2, IEverclearHubV2} from 'contracts/hub/EverclearHubV2.sol';

import {AssetUtils} from 'contracts/common/AssetUtils.sol';
import {HubGateway} from 'contracts/hub/HubGateway.sol';
import {HandlerV2, IHandlerV2} from 'contracts/hub/modules/HandlerV2.sol';
import {HubMessageReceiverV2, IHubMessageReceiverV2} from 'contracts/hub/modules/HubMessageReceiverV2.sol';
import {AssetManagerV2} from 'contracts/hub/modules/managers/AssetManagerV2.sol';

import {IManagerV2, ManagerV2} from 'contracts/hub/modules/ManagerV2.sol';
import {ISettlerV2, SettlerV2} from 'contracts/hub/modules/SettlerV2.sol';

import {IAssetManagerV2} from 'interfaces/hub/IAssetManagerV2.sol';

import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';

import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {IHubStorageV2} from 'interfaces/hub/IHubStorageV2.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {console2} from 'forge-std/console2.sol';

contract HubUpgradeSwaps is BaseTest, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  uint32 internal constant ETHEREUM = 1;
  uint32 internal constant ARBITRUM = 42_161;
  uint32 internal constant OPTIMISM = 10;

  // ============ Upgrade ============ //
  function test_hubUpgradeSwaps_upgrade() public {
    vm.createSelectFork(vm.envString('EVERCLEAR_RPC'), FIXED_EVERCLEAR_BLOCK);

    // Deploying
    // 1 - HubMessageReceiverV2 (incl. SettlerLogicV2)
    hubMessageReceiverV2 = new HubMessageReceiverV2();
    // 2 - HandlerV2
    handlerV2 = new HandlerV2();
    // 3 - SettlerV2
    settlerV2 = new SettlerV2();
    // 4 - Manager
    managerV2 = new ManagerV2();
    // 5 - EverclearHubV2
    everclearHubV2 = new EverclearHubV2();

    // Checking implementation correct and caching the state variables
    hubProxy = IEverclearHubV2(HUB_PROXY);
    address oldImplementation = (vm.load(HUB_PROXY, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, HUB_PROXY_IMPL);

    // Caching state variables
    CachedHubState memory state = _cacheHubState();

    // Initializing with new feeAdapter and upgrading
    bytes memory initializeCalldata = abi.encodeWithSelector(
      EverclearHubV2.initialize.selector,
      address(settlerV2),
      address(managerV2),
      address(handlerV2),
      address(hubMessageReceiverV2)
    );
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, everclearHubV2, initializeCalldata);

    vm.prank(HUB_PROXY_OWNER);
    (bool success,) = address(hubProxy).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(HUB_PROXY, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, address(everclearHubV2));

    // Checking the cached state
    assertEq(state.owner, hubProxy.owner());
    assertEq(state.lighthouse, hubProxy.lighthouse());
    assertEq(state.watchtower, hubProxy.watchtower());
    assertEq(state.hubGateway, address(hubProxy.hubGateway()));
    assertEq(state.epochLength, hubProxy.epochLength());
    assertEq(state.expiryTimeBuffer, hubProxy.expiryTimeBuffer());
    assertEq(address(settlerV2), hubProxy.modules(_SETTLEMENT_MODULE));
    assertEq(address(managerV2), hubProxy.modules(_MANAGER_MODULE));
    assertEq(address(handlerV2), hubProxy.modules(_HANDLER_MODULE));
    assertEq(address(hubMessageReceiverV2), hubProxy.modules(_MESSAGE_RECEIVER_MODULE));
  }

  // NOTE: Epoch issue prevents from working ============ Settler Module ============ //
  function test_hubUpgradeSwaps_processDepositsAndInvoices_NettingDepositsOnly() public {
    _upgradeHub();

    // constructing the intent messages
    // vm.rollFork(2_070_819);
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intentsToProcess, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, true);

    // TODO: This isn't working due to the block.number being returned being incorrect
    // sending message as gateway to the Hub
    IEverclearV2.Intent[] memory _intents = new IEverclearV2.Intent[](1);
    bytes memory _message = MessageLibV2.formatIntentMessageBatch(_intents);
    console2.log(block.number);
    // lastCarryEpochUpdated: 22829519
    assertEq(block.number, 2_070_819);
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_message);
    // _assertIntentsReceived(_intentsToProcess);

    // processing the deposits and invoices
  }

  function _configureIntentMessages(
    uint256 _total,
    address _inputAsset,
    address _outputAsset,
    uint32 _origin,
    uint32[] memory _destinations,
    bool _netting
  ) internal returns (IEverclearV2.Intent[] memory _intents, bytes memory _message) {
    _intents = new IEverclearV2.Intent[](_total);
    for (uint256 i; i < _total; i++) {
      address _initiator = address(uint160(uint256(keccak256(abi.encodePacked(i, 'initiator')))));
      address _receiver = address(uint160(uint256(keccak256(abi.encodePacked(i, 'receiver')))));

      _intents[i] = IEverclearV2.Intent({
        initiator: _initiator.toBytes32(),
        receiver: _receiver.toBytes32(),
        inputAsset: _inputAsset.toBytes32(),
        outputAsset: _outputAsset.toBytes32(),
        origin: _origin,
        nonce: testNonce++,
        timestamp: uint48(block.timestamp),
        ttl: _netting ? 0 : 2 hours,
        amount: 1000e18,
        amountOutMin: _netting ? 0 : 990e18,
        destinations: _destinations,
        data: ''
      });
    }
    _message = MessageLibV2.formatIntentMessageBatch(_intents);
  }

  // function _assertIntentsReceived(
  //   IEverclearV2.Intent[] memory _intents
  // ) internal {
  //   for (uint256 i; i < _intents.length; i++) {
  //     bytes32 _intentId = keccak256(abi.encode(_intents[i]));
  //     IHubStorageV2.IntentContext memory _context = hubProxy.contexts(_intentId);
  //     assertEq(_context.intent.initiator, _intents[i].initiator);
  //     assertEq(_context.intent.receiver, _intents[i].receiver);
  //     assertEq(_context.intent.inputAsset, _intents[i].inputAsset);
  //     assertEq(_context.intent.outputAsset, _intents[i].outputAsset);
  //     assertEq(_context.intent.origin, _intents[i].origin);
  //     assertEq(_context.intent.nonce, _intents[i].nonce);
  //     assertEq(_context.intent.timestamp, _intents[i].timestamp);
  //     assertEq(_context.intent.ttl, _intents[i].ttl);
  //     assertEq(_context.intent.amount, _intents[i].amount);
  //     assertEq(_context.intent.amountOutMin, _intents[i].amountOutMin);
  //     assertEq(_context.intent.destinations.length, _intents[i].destinations.length);
  //     for (uint256 j; j < _context.intent.destinations.length; j++) {
  //       assertEq(_context.intent.destinations[j], _intents[i].destinations[j]);
  //     }
  //     assertEq(_context.intent.data, _intents[i].data);
  //   }
  // }

  // function test_hubUpgradeSwaps_processDepositsAndInvoices_SolverDepositsOnly() public {}

  // function test_hubUpgradeSwaps_processDepositsAndInvoices_NettingAndSolverDeposits() public {}

  // function test_hubUpgradeSwaps_processSettlementQueue_NettingOnly() public {}

  // function test_hubUpgradeSwaps_processSettlementQueue_SolverOnly() public {}

  // function test_hubUpgradeSwaps_processSettlementQueue_NettingAndSolver() public {}

  // ============ Handler Module ============ //
  function test_hubUpgradeSwaps_handleExpiredIntents() public {}

  function test_hubUpgradeSwaps_returnUnsupportedIntent() public {}

  function test_hubUpgradeSwaps_withdrawFees() public {}

  // NOTE: Anything requiring lastProcessedEpoch reverts ============ Receive Message ============ //
  // function test_hubUpgradeSwaps_receiveMessage_IntentNettingPath_ToInvoice() public {}

  // function test_hubUpgradeSwaps_receiveMessage_IntentNettingPath_ToDeposit() public {}

  // // NOTE: State when the intent falls into the invoice branch without being filled
  // function test_hubUpgradeSwaps_receiveMessage_IntentSolverPath_ToDepositProcessed() public {}

  // // NOTE: State when the intent falls into the invoice branch when it has been filled and liquidity exists for solver
  // function test_hubUpgradeSwaps_receiveMessage_IntentSolverPath_ToSettlement() public {}

  // // NOTE: State when the intent falls into the invoice branch when it has been filled and liquidity does not exist for solver
  // function test_hubUpgradeSwaps_receiveMessage_IntentSolverPath_ToInvoice() public {}

  // function test_hubUpgradeSwaps_receiveMessage_FillSolverPath_ToSettlement() public {}

  // function test_hubUpgradeSwaps_receiveMessage_FillSolverPath_ToInvoice() public {}

  function test_hubUpgradeSwaps_receiveMessage_FillSolverPath_ToPending() public {
    // TODO: Should add this to ensure the fill state changes are expected
  }

  // ============ Asset Manager Functions ============ //
  function test_hubUpgradeSwaps_setAdoptedForAssets(
    bytes32 _tickerHash,
    bytes32 _adopted,
    uint32 _domain,
    bool _approval,
    uint8 _strategySeed
  ) public {
    _upgradeHub();
    IEverclearV2.Strategy _strategy =
      IEverclearV2.Strategy(bound(_strategySeed, 0, uint256(type(IEverclearV2.Strategy).max)));

    IHubStorageV2.AssetConfig memory _assetConfig =
      IHubStorageV2.AssetConfig(_tickerHash, _adopted, _domain, _approval, _strategy);

    vm.expectCall(address(hubProxy), abi.encodeWithSelector(IAssetManagerV2.setAdoptedForAsset.selector, _assetConfig));
    vm.prank(hubProxy.owner());
    hubProxy.setAdoptedForAsset(_assetConfig);

    // checking the configured state
    bytes32 _assetHash = keccak256(abi.encode(_adopted, _domain));
    AssetManagerV2.AssetConfig memory config = hubProxy.adoptedForAssets(_assetHash);

    assertEq(config.tickerHash, _tickerHash);
    assertEq(config.adopted, _adopted);
    assertEq(config.domain, _domain);
    assertEq(config.approval, _approval);
    assertEq(uint8(config.strategy), uint8(_strategy));
  }

  function test_hubUpgradeSwaps_setTokenConfigs(
    address _caller,
    uint8 _configsNumber,
    uint8 _adoptedForAssetsNumber,
    uint8 _feesNumber
  ) public {
    _upgradeHub();
    _configsNumber = uint8(bound(uint256(_configsNumber), 1, MAX_FUZZED_ARRAY_LENGTH));
    _adoptedForAssetsNumber = uint8(bound(uint256(_configsNumber), 1, MAX_FUZZED_ARRAY_LENGTH));
    _feesNumber = uint8(bound(uint256(_configsNumber), 1, MAX_FUZZED_ARRAY_LENGTH));

    IHubStorageV2.TokenSetup[] memory _configs = new IHubStorageV2.TokenSetup[](_configsNumber);
    _generateConfigs(_configs, _adoptedForAssetsNumber, _feesNumber);

    vm.prank(hubProxy.owner());
    hubProxy.setTokenConfigs(_configs);

    for (uint8 _i; _i < _configsNumber; _i++) {
      bytes32 _tickerHash = _configs[_i].tickerHash;
      IHubStorageV2.Fee[] memory _fees = hubProxy.tokenFees(_tickerHash);

      assertEq(_fees.length, _feesNumber, 'fees length not set correctly');

      for (uint8 _j; _j < _feesNumber; _j++) {
        assertEq(_fees[_j].recipient, _configs[_i].fees[_j].recipient, 'recipient not set correctly');
        assertEq(_fees[_j].fee, _configs[_i].fees[_j].fee, 'fee not set correctly');
      }

      IHubStorageV2.AssetConfig[] memory _adoptedForAssets = _configs[_i].adoptedForAssets;
      for (uint8 _j; _j < _adoptedForAssets.length; _j++) {
        bytes32 _assetHash =
          keccak256(abi.encode(_configs[_i].adoptedForAssets[_j].adopted, _configs[_i].adoptedForAssets[_j].domain));
        IHubStorageV2.AssetConfig memory _assetConfig = hubProxy.adoptedForAssets(_assetHash);

        assertEq(_assetConfig.tickerHash, _tickerHash, 'ticker hash not set correctly');
        assertEq(_assetConfig.adopted, _adoptedForAssets[_j].adopted, 'adopted not set correctly');
        assertEq(_assetConfig.domain, _adoptedForAssets[_j].domain, 'domain not set correctly');
        assertEq(_assetConfig.approval, _adoptedForAssets[_j].approval, 'approval not set correctly');
        assertEq(uint256(_assetConfig.strategy), uint256(_adoptedForAssets[_j].strategy), 'strategy not set correctly');
      }
    }
  }

  function test_hubUpgradeSwaps_setPrioritizedStrategy(bytes32 _tickerHash, uint8 _strategySeed) public {
    IEverclearV2.Strategy _strategy =
      IEverclearV2.Strategy(bound(_strategySeed, 0, uint256(type(IEverclearV2.Strategy).max)));

    vm.prank(hubProxy.owner());
    hubProxy.setPrioritizedStrategy(_tickerHash, _strategy);

    (,, IEverclearV2.Strategy _prioritizedStrategy) = hubProxy.tokenConfigs(_tickerHash);
    assertEq(uint8(_prioritizedStrategy), uint8(_strategy), 'prioritized strategy not set correctly');
  }

  function test_hubUpgradeSwaps_setLastClosedEpochProcessed() public {}

  function test_hubUpgradeSwaps_setDiscountPerEpoch() public {
    _upgradeHub();

    bytes32 tickerHash = USDC_MAINNET.toBytes32();
    uint24 newDiscountPerEpoch = 0; // Example value

    vm.prank(hubProxy.owner());
    hubProxy.setDiscountPerEpoch(tickerHash, newDiscountPerEpoch);

    (, uint24 discountPerEpoch,) = hubProxy.tokenConfigs(tickerHash);
    assertEq(discountPerEpoch, newDiscountPerEpoch, 'Discount per epoch should be updated');
  }

  // ============ Solver Manager Functions ============ //

  function test_hubUpgradeSwaps_setUserSupportedDomains() public {
    _upgradeHub();

    address user = address(0x1234);
    uint32[] memory supportedDomains = new uint32[](2);
    supportedDomains[0] = ETHEREUM;
    supportedDomains[1] = ARBITRUM;

    vm.prank(user);
    hubProxy.setUserSupportedDomains(supportedDomains);

    uint32[] memory userSupportedDomains = hubProxy.userSupportedDomains(user.toBytes32());
    assertEq(userSupportedDomains.length, 2, 'User should have two supported domains');
    assertEq(userSupportedDomains[0], ETHEREUM, 'First supported domain should be Ethereum');
    assertEq(userSupportedDomains[1], ARBITRUM, 'Second supported domain should be Arbitrum');
  }

  function test_hubUpgradeSwaps_setUpdateVirtualBalance() public {
    _upgradeHub();

    vm.prank(address(0x123));
    hubProxy.setUpdateVirtualBalance(true);

    assertEq(
      EverclearHubV2(address(hubProxy)).updateVirtualBalance(address(0x123).toBytes32()),
      true,
      'Virtual balance should be updated'
    );
  }

  // ============ Protocol Manager Functions ============ //

  function test_hubUpgradeSwaps_proposeOwner() public {
    _upgradeHub();

    vm.prank(hubProxy.owner());
    hubProxy.proposeOwner(address(0x1234));
    assertEq(hubProxy.proposedOwner(), address(0x1234));
    assertEq(hubProxy.proposedOwnershipTimestamp(), block.timestamp);
  }

  function test_hubUpgradeSwaps_acceptOwnership() public {
    _upgradeHub();

    vm.prank(hubProxy.owner());
    hubProxy.proposeOwner(address(0x1234));
    assertEq(hubProxy.proposedOwner(), address(0x1234));
    assertEq(hubProxy.proposedOwnershipTimestamp(), block.timestamp);

    vm.warp(block.timestamp + hubProxy.acceptanceDelay() + 1);
    vm.prank(address(0x1234));
    hubProxy.acceptOwnership();

    assertEq(hubProxy.owner(), address(0x1234));
  }

  function test_hubUpgradeSwaps_updateLighthouse() public {
    _upgradeHub();

    address newLighthouse = address(0x1234);
    vm.deal(hubProxy.owner(), 0.01 ether);

    vm.prank(hubProxy.owner());
    hubProxy.updateLighthouse{value: 0.01 ether}(newLighthouse);

    assertEq(hubProxy.lighthouse(), newLighthouse);
  }

  function test_hubUpgradeSwaps_updateWatchtower() public {
    _upgradeHub();

    address newWatchtower = address(0x1234);
    vm.deal(hubProxy.owner(), 0.01 ether);

    vm.prank(hubProxy.owner());
    hubProxy.updateWatchtower{value: 0.01 ether}(newWatchtower);

    assertEq(hubProxy.watchtower(), newWatchtower);
  }

  function test_hubUpgradeSwaps_updateAcceptanceDelay() public {
    _upgradeHub();

    uint256 newAcceptanceDelay = 3600; // 1 hour
    vm.prank(hubProxy.owner());
    hubProxy.updateAcceptanceDelay(newAcceptanceDelay);

    assertEq(hubProxy.acceptanceDelay(), newAcceptanceDelay);
  }

  function test_hubUpgradeSwaps_assignRole() public {
    _upgradeHub();

    address user = address(0x1234);
    IHubStorageV2.Role role = IHubStorageV2.Role.ADMIN;

    vm.prank(hubProxy.owner());
    hubProxy.assignRole(user, role);

    assertEq(uint8(hubProxy.roles(user)), uint8(role));
  }

  function test_hubUpgradeSwaps_addSupportedDomains() public {
    _upgradeHub();

    IHubStorageV2.DomainSetup[] memory domainSetups = new IHubStorageV2.DomainSetup[](2);
    domainSetups[0] = IHubStorageV2.DomainSetup({id: 911, blockGasLimit: 30_000_000_000});
    domainSetups[1] = IHubStorageV2.DomainSetup({id: 999, blockGasLimit: 15_000_000_000});

    vm.prank(hubProxy.owner());
    hubProxy.addSupportedDomains(domainSetups);

    uint32[] memory supportedDomains = hubProxy.supportedDomains();
    bool _supportedOneAdded = false;
    bool _supportedTwoAdded = false;
    for (uint256 i = 0; i < supportedDomains.length; i++) {
      if (supportedDomains[i] == 911) _supportedOneAdded = true;
      else if (supportedDomains[i] == 999) _supportedTwoAdded = true;
    }

    assertTrue(_supportedOneAdded, 'Domain 911 should be supported');
    assertTrue(_supportedTwoAdded, 'Domain 999 should be supported');
  }

  error DomainUnsupported();

  function test_hubUpgradeSwaps_removeSupportedDomains() public {
    _upgradeHub();

    uint32[] memory _domains = new uint32[](2);
    _domains[0] = 1;
    _domains[1] = 42_161;

    // removing supported domains
    vm.startPrank(hubProxy.owner());
    hubProxy.removeSupportedDomains(_domains);

    uint32[] memory _supportedDomains = hubProxy.supportedDomains();
    for (uint256 i; i < _supportedDomains.length; i++) {
      if (_supportedDomains[i] == 1 || _supportedDomains[i] == 42_161) revert DomainUnsupported();
    }
  }

  function test_hubUpgradeSwaps_pause() public {
    _upgradeHub();

    vm.prank(hubProxy.owner());
    hubProxy.pause();

    assertTrue(hubProxy.paused(), 'Hub should be paused');
  }

  function test_hubUpgradeSwaps_unpause() public {
    _upgradeHub();

    vm.prank(hubProxy.owner());
    hubProxy.pause();
    assertTrue(hubProxy.paused(), 'Hub should be paused');

    vm.prank(hubProxy.owner());
    hubProxy.unpause();

    assertFalse(hubProxy.paused(), 'Hub should be unpaused');
  }

  function test_hubUpgradeSwaps_updateMinSolverSupportedDomains() public {
    _upgradeHub();

    uint8 newMinSolverSupportedDomains = 3;
    vm.prank(hubProxy.owner());
    hubProxy.updateMinSolverSupportedDomains(newMinSolverSupportedDomains);

    assertEq(hubProxy.minSolverSupportedDomains(), newMinSolverSupportedDomains);
  }

  function test_hubUpgradeSwaps_updateMailbox() public {
    _upgradeHub();

    address newMailbox = address(0x1234);
    vm.prank(hubProxy.owner());
    hubProxy.updateMailbox(newMailbox);

    IHubGateway hubGateway = hubProxy.hubGateway();
    assertEq(address(hubGateway.mailbox()), newMailbox);
  }

  function test_hubUpgradeSwaps_updateSecurityModule() public {
    _upgradeHub();

    address newSecurityModule = address(0x1234);
    vm.prank(hubProxy.owner());
    hubProxy.updateSecurityModule(newSecurityModule);

    HubGateway hubGateway = HubGateway(payable(address(hubProxy.hubGateway())));
    assertEq(address(hubGateway.interchainSecurityModule()), newSecurityModule);
  }

  function test_hubUpgradeSwaps_updateGateway() public {
    _upgradeHub();

    address newGateway = address(0x1234);
    vm.prank(hubProxy.owner());
    hubProxy.updateGateway(newGateway);

    IHubGateway hubGateway = hubProxy.hubGateway();
    assertEq(address(hubGateway), newGateway);
  }

  function test_hubUpgradeSwaps_updateChainGateway() public {
    _upgradeHub();

    address newChainGateway = address(0x1234);
    uint32 chainId = 1; // Example chain ID
    vm.prank(hubProxy.owner());
    hubProxy.updateChainGateway(chainId, newChainGateway.toBytes32());

    IHubGateway hubGateway = hubProxy.hubGateway();
    assertEq(hubGateway.chainGateways(chainId), newChainGateway.toBytes32(), 'Chain gateway should be updated');
  }

  function test_hubUpgradeSwaps_removeChainGateway() public {
    _upgradeHub();

    uint32 chainId = 1; // Example chain ID
    vm.prank(hubProxy.owner());
    hubProxy.removeChainGateway(chainId);

    IHubGateway hubGateway = hubProxy.hubGateway();
    assertEq(hubGateway.chainGateways(chainId), bytes32(0), 'Chain gateway should be removed');
  }

  function test_hubUpgradeSwaps_updateExpiryTimeBuffer() public {
    _upgradeHub();

    uint48 newExpiryTimeBuffer = 3600; // 1 hour
    vm.prank(hubProxy.owner());
    hubProxy.updateExpiryTimeBuffer(newExpiryTimeBuffer);

    assertEq(hubProxy.expiryTimeBuffer(), newExpiryTimeBuffer);
  }

  function test_hubUpgradeSwaps_updateEpochLength() public {
    // TODO: This does not work due to block number issue
  }

  function test_hubUpgradeSwaps_updateGasConfig() public {
    _upgradeHub();

    IHubStorageV2.GasConfig memory config = IHubStorageV2.GasConfig({
      settlementBaseGasUnits: 100_000,
      averageGasUnitsPerSettlement: 50_000,
      bufferDBPS: 10_000
    });

    vm.prank(hubProxy.owner());
    hubProxy.updateGasConfig(config);

    (uint256 settlementBaseGasUnits, uint256 averageGasUnitsPerSettlement, uint256 bufferDBPS) = hubProxy.gasConfig();
    assertEq(settlementBaseGasUnits, config.settlementBaseGasUnits);
    assertEq(averageGasUnitsPerSettlement, config.averageGasUnitsPerSettlement);
    assertEq(bufferDBPS, config.bufferDBPS);
  }

  function test_hubUpgradeSwaps_setMaxDiscountDBPS() public {}

  // ============ Upgrades Functions ============ //
  function test_hubUpgradeSwaps_updateModuleAddress_Settlement() public {
    _upgradeHub();

    address newModuleAddress = address(0x1234);

    vm.prank(hubProxy.owner());
    hubProxy.updateModuleAddress(_SETTLEMENT_MODULE, newModuleAddress);

    assertEq(hubProxy.modules(_SETTLEMENT_MODULE), newModuleAddress, 'Module address should be updated');
  }

  function test_hubUpgradeSwaps_updateModuleAddress_Manager() public {
    _upgradeHub();

    address newModuleAddress = address(0x1234);

    vm.prank(hubProxy.owner());
    hubProxy.updateModuleAddress(_MANAGER_MODULE, newModuleAddress);

    assertEq(hubProxy.modules(_MANAGER_MODULE), newModuleAddress, 'Module address should be updated');
  }

  function test_hubUpgradeSwaps_updateModuleAddress_Handler() public {
    _upgradeHub();

    address newModuleAddress = address(0x1234);

    vm.prank(hubProxy.owner());
    hubProxy.updateModuleAddress(_HANDLER_MODULE, newModuleAddress);

    assertEq(hubProxy.modules(_HANDLER_MODULE), newModuleAddress, 'Module address should be updated');
  }

  function test_hubUpgradeSwaps_updateModuleAddress_MessageReceiver() public {
    _upgradeHub();

    address newModuleAddress = address(0x1234);

    vm.prank(hubProxy.owner());
    hubProxy.updateModuleAddress(_MESSAGE_RECEIVER_MODULE, newModuleAddress);

    assertEq(hubProxy.modules(_MESSAGE_RECEIVER_MODULE), newModuleAddress, 'Module address should be updated');
  }

  // ============ Same-chain Swap ============ //
  function test_hubUpgradeSwaps_processIntent_sameChainSwap() public {}

  function test_hubUpgradeSwaps_processFill_sameChainSwap() public {}

  // ============ View Functions ============ //
  function test_hubUpgradeSwaps_supportedDomains() public {}

  // ============ Revert Checks ============ //
  function test_hubUpgradeSwaps_checkUnsupported_DoesNotRevert() public {}
}
