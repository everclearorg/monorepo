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
import {Gateway, HubGateway} from 'contracts/hub/HubGateway.sol';
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

import 'forge-std/StdStorage.sol';

contract HubUpgradeSwaps is BaseTest, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;
  using stdStorage for StdStorage;

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

  // ============ Settler Module ============ //
  function test_hubUpgradeSwaps_processDepositsAndInvoices_NettingDepositsOnly() public {
    _upgradeHub();

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intentsToArbitrum, bytes memory _intentMessage) =
      _configureIntentMessages(2, USDC_MAINNET, address(0), ETHEREUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intentsToArbitrum);

    // Arbitrum to mainnet intents //
    IEverclearV2.Intent[] memory _intentsToMainnet;
    _destinations = _getDestinations(1);
    (_intentsToMainnet, _intentMessage) =
      _configureIntentMessages(2, USDC_ARBITRUM, address(0), ARBITRUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intentsToMainnet);

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    vm.warp(block.timestamp + 3600);
    vm.roll(block.number + 50);
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // asserting the intents status are SETTLED
    bytes32[] memory _intentIds = new bytes32[](2);
    _intentIds[0] = keccak256(abi.encode(_intentsToArbitrum[0]));
    _intentIds[1] = keccak256(abi.encode(_intentsToMainnet[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));
  }

  function test_hubUpradeSwaps_processSettlementQueue_ZeroGasLimit() public {
    _upgradeHub();

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intentsToArbitrum, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, address(0), ETHEREUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intentsToArbitrum);

    // Arbitrum to mainnet intents //
    IEverclearV2.Intent[] memory _intentsToMainnet;
    _destinations = _getDestinations(1);
    (_intentsToMainnet, _intentMessage) =
      _configureIntentMessages(1, USDC_ARBITRUM, address(0), ARBITRUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intentsToMainnet);

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    vm.warp(block.timestamp + 3600);
    vm.roll(block.number + 50);
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // asserting the intents status are SETTLED
    bytes32[] memory _intentIds = new bytes32[](2);
    _intentIds[0] = keccak256(abi.encode(_intentsToArbitrum[0]));
    _intentIds[1] = keccak256(abi.encode(_intentsToMainnet[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing the settlement queue
    bytes memory _calldata =
      _constructSettlementInfo(_intentsToArbitrum[0].receiver, USDC_ARBITRUM.toBytes32(), _intentsToArbitrum);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, 0)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, 0);
  }

  function test_hubUpradeSwaps_processSettlementQueueViaRelayer_ZeroGasLimit() public {
    _upgradeHub();

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intentsToArbitrum, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, address(0), ETHEREUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intentsToArbitrum);

    // Arbitrum to mainnet intents //
    IEverclearV2.Intent[] memory _intentsToMainnet;
    _destinations = _getDestinations(1);
    (_intentsToMainnet, _intentMessage) =
      _configureIntentMessages(1, USDC_ARBITRUM, address(0), ARBITRUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intentsToMainnet);

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    vm.warp(block.timestamp + 3600);
    vm.roll(block.number + 50);
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // asserting the intents status are SETTLED
    bytes32[] memory _intentIds = new bytes32[](2);
    _intentIds[0] = keccak256(abi.encode(_intentsToArbitrum[0]));
    _intentIds[1] = keccak256(abi.encode(_intentsToMainnet[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // constructing call data
    address _relayer = vm.addr(1);
    _updateLighthouse(_relayer);
    bytes memory _calldata =
      _constructSettlementInfo(_intentsToArbitrum[0].receiver, USDC_ARBITRUM.toBytes32(), _intentsToArbitrum);

    // constructing data to sign
    uint256 _nonce = 0;
    bytes memory _payload =
      abi.encode(hubProxy.PROCESS_QUEUE_VIA_RELAYER_TYPEHASH(), ARBITRUM, 1, _relayer, block.timestamp, _nonce, 0);
    bytes memory _sig = _generateSignature(1, _payload);

    // fetching the fee
    uint256 _fee = IHubGateway(hubProxy.hubGateway()).quoteMessage(ARBITRUM, _calldata, 0);

    // processing the settlement
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256,uint256)', ARBITRUM, _calldata, _fee, 0)
    );
    hubProxy.processSettlementQueueViaRelayer(ARBITRUM, 1, _relayer, block.timestamp, _nonce, 0, _sig);
  }

  // ============ Handler Module ============ //
  function test_hubUpgradeSwaps_handleExpiredIntents_Invoiced() public {
    _upgradeHub();

    // processing the deposits and invoices for USDT //
    bytes32 _tickerHash = keccak256('USDT');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDT_MAINNET, USDT_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.DEPOSIT_PROCESSED));

    // warping past the expiration
    vm.warp(block.timestamp + _intents[0].ttl + hubProxy.expiryTimeBuffer() + 1);
    hubProxy.handleExpiredIntents(_intentIds);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.INVOICED));
  }

  function test_hubUpgradeSwaps_handleExpiredIntents_Settled() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDT');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDT_MAINNET, USDT_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.DEPOSIT_PROCESSED));

    // warping past the expiration
    vm.warp(block.timestamp + _intents[0].ttl + hubProxy.expiryTimeBuffer() + 1);
    _updateCustodiedAssets(USDT_ARBITRUM_ASSET_HASH, _intents[0].amount);
    hubProxy.handleExpiredIntents(_intentIds);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));
  }

  function test_hubUpgradeSwaps_returnUnsupportedIntent_Swap() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDT');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDT_MAINNET, AAVE_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);

    // asserting intent state is unsupported
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.UNSUPPORTED));

    // returning the unsupported intent
    hubProxy.returnUnsupportedIntent(_intentIds[0]);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.UNSUPPORTED_RETURNED));
  }

  // ============ Receive Message ============ //
  // ============ Netting Path ============ //
  function test_hubUpgradeSwaps_receiveMessage_IntentNettingPath_Added() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, address(0), ETHEREUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));
  }

  function test_hubUpgradeSwaps_receiveMessage_IntentNettingPath_Settled_Single() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, address(0), ETHEREUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // processing the deposits
    vm.roll(block.number + 20);
    _updateCustodiedAssets(USDC_ARBITRUM_ASSET_HASH, _intents[0].amount);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // checking the settlement
    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_intents[0].receiver, USDC_ARBITRUM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_IntentNettingPath_Settled_Multiple() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intentsToArb, bytes memory _intentMessageT) =
      _configureIntentMessages(5, USDC_MAINNET, address(0), ETHEREUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessageT);
    _assertIntentsReceived(_intentsToArb);

    // Arbitrum to Mainnet intents //
    _destinations = _getDestinations(1);
    (IEverclearV2.Intent[] memory _intentsToMain, bytes memory _intentMessageToMain) =
      _configureIntentMessages(5, USDC_ARBITRUM, address(0), ARBITRUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessageToMain);
    _assertIntentsReceived(_intentsToMain);

    // asserting the intent is in invoiced state for to Main
    bytes32[] memory _intentIds = _generateIds(_intentsToMain);
    _intentIds = _generateAndAddIds(_intentIds, _intentsToArb);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 10, 10, 10);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // checking the settlement
    // processing settlement queue to ARBITRUM
    bytes memory _calldata = _constructSettlementInfoArray(USDC_ARBITRUM.toBytes32(), _intentsToArb);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 5, DEFAULT_GAS_LIMIT);

    // processing the settlement queue to ETHEREUM
    _calldata = _constructSettlementInfoArray(USDC_MAINNET.toBytes32(), _intentsToMain);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 5, DEFAULT_GAS_LIMIT);
  }

  // ============ Solver Path - Bridging ============ //
  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_AddedThenFilled_SingleSolverDestination() public {
    _upgradeHub();

    // processing the deposits, invoices, and settlements for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = _getDestinations(1);
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_FilledThenAdded_SingleSolverDestination() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = _getDestinations(1);
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_FilledThenAdded_MultipleSolverDestinations() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](3);
    _solverDestinations[0] = 42_161;
    _solverDestinations[1] = 1;
    _solverDestinations[2] = 10;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  // ============ Solver Path - Swaps ============ //
  function test_hubUpgradeSwaps_receiveMessage_SolverSwapPath_AddedThenFilled() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](2);
    _solverDestinations[0] = 1;
    _solverDestinations[1] = 10;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );

    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverSwapPath_FilledThenAdded() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](2);
    _solverDestinations[0] = 1;
    _solverDestinations[1] = 10;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  // ============ Solver Path - Destination Adjustment Cases ============ //
  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_FillUnsupportedDomains() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](3);
    _solverDestinations[0] = 99_999;
    _solverDestinations[1] = 1_099_999;
    _solverDestinations[2] = 1_000_000;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.FILLED));
    _fill.destinations = _getDestinations(_intents[0].origin); // should be set to origin only
    _assertFillInfo(_intentIds[0], _fill);

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_FillUnsupportedAsset() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](3);
    _solverDestinations[0] = 1;
    _solverDestinations[1] = 10;
    _solverDestinations[2] = 81_457;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.FILLED));
    _fill.destinations = _getDestinations(_intents[0].origin); // should be set to origin only
    _assertFillInfo(_intentIds[0], _fill);

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_DifferentSettlementDestination() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // processing the settlement queue from the fork //
    hubProxy.processSettlementQueue(OPTIMISM, 1, DEFAULT_GAS_LIMIT);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Adjusting custodied assets //
    // taking liquidity from the origin domain and adding to the settlement domain //
    _updateCustodiedAssets(USDC_MAINNET_ASSET_HASH, 0);
    _updateCustodiedAssets(USDC_OPTIMISM_ASSET_HASH, _intents[0].amount);

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](2);
    _solverDestinations[0] = 10;
    _solverDestinations[1] = 42_161;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );

    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_OPTIMISM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', OPTIMISM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(OPTIMISM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_MemValues_ToSettlement() public {
    _upgradeHub();

    // processing the deposits, invoices, and settlements for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);
    hubProxy.processSettlementQueue(OPTIMISM, 1, DEFAULT_GAS_LIMIT);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Setting the memvalues for the solver //
    address _solver = address(0x123);
    uint32[] memory _domains = new uint32[](2);
    _domains[0] = ARBITRUM;
    _domains[1] = OPTIMISM;
    vm.prank(_solver);
    hubProxy.setUserSupportedDomains(_domains);

    // Configuring liquidity to be 0
    _updateCustodiedAssets(USDC_ARBITRUM_ASSET_HASH, 0);
    _updateCustodiedAssets(USDC_OPTIMISM_ASSET_HASH, _intents[0].amount);

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = _getDestinations(1);
    uint256 _amountOut = _intents[0].amountOutMin;
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_OPTIMISM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', OPTIMISM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(OPTIMISM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverSwapPath_DifferentSettlementDestination() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);
    hubProxy.processSettlementQueue(OPTIMISM, 1, DEFAULT_GAS_LIMIT);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Adjusting custodied assets //
    // taking liquidity from the origin domain and adding to the settlement domain //
    _updateCustodiedAssets(USDC_MAINNET_ASSET_HASH, 0);
    _updateCustodiedAssets(USDC_OPTIMISM_ASSET_HASH, _intents[0].amount);

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](2);
    _solverDestinations[0] = 10;
    _solverDestinations[1] = 42_161;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );

    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_OPTIMISM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', OPTIMISM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(OPTIMISM, 1, DEFAULT_GAS_LIMIT);
  }

  // ============ Solver Path - Deposit Processing Cases ============ //

  function test_hubUpgradeSwaps_receiveMessage_SolverSwapPath_DepositAccruedRewards() public {}

  function test_hubUpgradeSwaps_receiveMessage_SolverSwapPath_DepositProcessedState_FillProcessedIntoSettlement()
    public
  {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDT');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDT_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.DEPOSIT_PROCESSED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](1);
    _solverDestinations[0] = 1;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );

    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDT_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverSwapPath_DepositProcessedState_FillProcessedIntoInvoice() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDT');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDT_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.DEPOSIT_PROCESSED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](1);
    _solverDestinations[0] = 1;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );

    // sending message as gateway to the Hub //
    _updateCustodiedAssets(USDT_ETHEREUM_ASSET_HASH, 0);
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.INVOICED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits
    _updateCustodiedAssets(USDT_ETHEREUM_ASSET_HASH, _intents[0].amount * 2);
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDT_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  // ============ Solver Path - Fill Invoicing Cases ============ //
  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_FilledThenAdded_IntentInvoiced() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDT');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDT_MAINNET, USDT_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](1);
    _solverDestinations[0] = 10;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // sending intent message as gateway to the Hub //
    _updateCustodiedAssets(USDT_OPTIMISM_ASSET_HASH, 0);
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.INVOICED));

    // processing the deposits
    _updateCustodiedAssets(USDT_OPTIMISM_ASSET_HASH, _intents[0].amount);
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDT_OPTIMISM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', OPTIMISM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(OPTIMISM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_FilledThenAdded_IntentSettled() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDT');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDT_MAINNET, USDT_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](1);
    _solverDestinations[0] = 1;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in settled state
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDT_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_InvoicedFill() public {
    _upgradeHub();

    // processing the deposits, invoices, and settlements for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = _getDestinations(42_161);
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.INVOICED));

    // processing the invoice
    _updateCustodiedAssets(USDC_ARBITRUM_ASSET_HASH, _intents[0].amount);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_ARBITRUM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverSwapPath_InvoicedFill() public {
    _upgradeHub();

    // processing the deposits, invoices, and settlements for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = _getDestinations(42_161);
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.INVOICED));

    // processing the invoice
    _updateCustodiedAssets(USDC_ARBITRUM_ASSET_HASH, _intents[0].amount);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_ARBITRUM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, DEFAULT_GAS_LIMIT);
  }

  // ============ Solver Path - Expired Cases ============ //
  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_ExpiredIntoInvoice() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // rolling block forward and timestamp past the ttl
    vm.roll(block.number + 20);
    vm.warp(block.timestamp + _intents[0].ttl + hubProxy.expiryTimeBuffer() + 1);

    // processing the deposits to invoice
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.INVOICED));

    // processing the invoice to a settlement
    _updateCustodiedAssets(USDC_ARBITRUM_ASSET_HASH, _intents[0].amount);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_intents[0].receiver, USDC_ARBITRUM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverSwapPath_ExpiredIntoInvoice() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // rolling block forward and timestamp past the ttl
    vm.roll(block.number + 20);
    vm.warp(block.timestamp + _intents[0].ttl + hubProxy.expiryTimeBuffer() + 1);

    // processing the deposits to invoice
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.INVOICED));

    // processing the invoice to a settlement
    _updateCustodiedAssets(USDC_ARBITRUM_ASSET_HASH, _intents[0].amount);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_intents[0].receiver, USDC_ARBITRUM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_ExpiredIntoSettlement() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // rolling block forward and timestamp past the ttl
    vm.roll(block.number + 20);
    vm.warp(block.timestamp + _intents[0].ttl + hubProxy.expiryTimeBuffer() + 1);

    // processing the deposits to invoice
    _updateCustodiedAssets(USDC_ARBITRUM_ASSET_HASH, _intents[0].amount);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_intents[0].receiver, USDC_ARBITRUM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverSwapPath_ExpiredIntoSettlement() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // rolling block forward and timestamp past the ttl
    vm.roll(block.number + 20);
    vm.warp(block.timestamp + _intents[0].ttl + hubProxy.expiryTimeBuffer() + 1);

    // processing the invoice to a settlement
    _updateCustodiedAssets(USDC_ARBITRUM_ASSET_HASH, _intents[0].amount);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_intents[0].receiver, USDC_ARBITRUM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, DEFAULT_GAS_LIMIT);
  }

  // ============ Swap Path - Same Chain ============ //
  function test_hubUpgradeSwaps_receiveMessage_SolverSameChainSwapPath_AddedThenFilled() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(1);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, WETH_MAINNET, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](1);
    _solverDestinations[0] = 1;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );

    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverSameChainSwapPath_FilledThenAdded() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(1);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, WETH_MAINNET, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = new uint32[](1);
    _solverDestinations[0] = 1;
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_MAINNET.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 1, DEFAULT_GAS_LIMIT);
  }

  // ============ Solver Path - Multiple Cases ============ //
  function test_hubUpgradeSwaps_receiveMessage_SolverBridgePath_MultipleIntentsAndFills() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(5, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = _generateIds(_intents);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    _destinations = _getDestinations(1);
    address[] memory _solvers = _configureSolvers(5);
    uint32[][] memory _solverDestinations = _configureSolverDestinations(_destinations, 5);
    (IEverclearV2.FillMessage[] memory _fills, bytes memory _fillMessage) =
      _configureFillMessages(_intents, _solverDestinations, _solvers);

    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds, _fills);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing the settlements
    bytes memory _calldata = _constructSettlementInfoArrayWithSolvers(USDC_MAINNET.toBytes32(), _intents, _solvers);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 5, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverSwapPath_MultipleIntentsAndFills() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(5, USDC_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = _generateIds(_intents);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    _destinations = _getDestinations(1);
    address[] memory _solvers = _configureSolvers(5);
    uint32[][] memory _solverDestinations = _configureSolverDestinations(_destinations, 5);
    (IEverclearV2.FillMessage[] memory _fills, bytes memory _fillMessage) =
      _configureFillMessages(_intents, _solverDestinations, _solvers);

    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds, _fills);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing the settlements
    bytes memory _calldata = _constructSettlementInfoArrayWithSolvers(USDC_MAINNET.toBytes32(), _intents, _solvers);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 5, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_receiveMessage_SolverSameChainSwapPath_MultipleIntentsAndFills() public {
    _upgradeHub();

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(1);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(5, USDC_MAINNET, WETH_MAINNET, ETHEREUM, _destinations, false);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intents);

    // asserting the intent is in invoiced state
    bytes32[] memory _intentIds = _generateIds(_intents);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    _destinations = _getDestinations(1);
    address[] memory _solvers = _configureSolvers(5);
    uint32[][] memory _solverDestinations = _configureSolverDestinations(_destinations, 5);
    (IEverclearV2.FillMessage[] memory _fills, bytes memory _fillMessage) =
      _configureFillMessages(_intents, _solverDestinations, _solvers);

    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds, _fills);

    // processing the deposits
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing the settlements
    bytes memory _calldata = _constructSettlementInfoArrayWithSolvers(USDC_MAINNET.toBytes32(), _intents, _solvers);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ETHEREUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ETHEREUM, 5, DEFAULT_GAS_LIMIT);
  }

  function _configureToken(
    bytes32 _tickerHash
  ) internal {
    IHubStorageV2.Fee[] memory _fees = new IHubStorageV2.Fee[](1);
    _fees[0] = IHubStorageV2.Fee({recipient: address(0x123), fee: 0}); // 0 BPS

    IHubStorageV2.AssetConfig[] memory _assetConfigs = new IHubStorageV2.AssetConfig[](3);
    /// Optimism
    _assetConfigs[0] = IHubStorageV2.AssetConfig({
      tickerHash: _tickerHash,
      adopted: USDC_MAINNET.toBytes32(),
      domain: 1,
      approval: true,
      strategy: IEverclearV2.Strategy.DEFAULT
    });

    ///// Optimism
    _assetConfigs[1] = IHubStorageV2.AssetConfig({
      tickerHash: _tickerHash,
      adopted: USDC_OPTIMISM.toBytes32(),
      domain: 10,
      approval: true,
      strategy: IEverclearV2.Strategy.DEFAULT
    });

    ///// Arbitrum
    _assetConfigs[2] = IHubStorageV2.AssetConfig({
      tickerHash: _tickerHash,
      adopted: USDC_ARBITRUM.toBytes32(),
      domain: 42_161,
      approval: true,
      strategy: IEverclearV2.Strategy.DEFAULT
    });

    IHubStorageV2.TokenSetup memory _setup = IHubStorageV2.TokenSetup({
      tickerHash: _tickerHash,
      initLastClosedEpochProcessed: false,
      prioritizedStrategy: IEverclearV2.Strategy.XERC20,
      maxDiscountDbps: 1000, // 100 BPS
      discountPerEpoch: 100, // 10 BPS
      fees: _fees,
      adoptedForAssets: _assetConfigs
    });

    IHubStorageV2.TokenSetup[] memory _setupArray = new IHubStorageV2.TokenSetup[](1);
    _setupArray[0] = _setup;

    vm.prank(hubProxy.owner());
    hubProxy.setTokenConfigs(_setupArray);
    (uint24 _maxDiscountDbps, uint24 _discountPerEpoch,) = hubProxy.tokenConfigs(_tickerHash);
    assertEq(_maxDiscountDbps, 1000);
    assertEq(_discountPerEpoch, 100);
  }

  // ============ Discount Maths ============ //
  function test_hubUpgradeSwaps_invoiceNotDiscounted() public {
    _upgradeHub();

    // configuring the discount per epoch to xyz
    bytes32 _tickerHash = keccak256('USDC');
    _configureToken(_tickerHash);

    // processing the deposits, invoices, and settlements for USDC //
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = _getDestinations(42_161);
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits - skipping one epoch ahead (i.e. zero discount)
    vm.roll(block.number + hubProxy.epochLength());
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.INVOICED));

    // processing the invoice
    _updateCustodiedAssets(USDC_ARBITRUM_ASSET_HASH, _intents[0].amount);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    bytes memory _calldata = _constructSettlementInfo(_solver.toBytes32(), USDC_ARBITRUM.toBytes32(), _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_invoiceDiscountedFiveTimes_Swap() public {
    _upgradeHub();

    // configuring the discount per epoch to 10 BPS
    bytes32 _tickerHash = keccak256('USDC');
    _configureToken(_tickerHash);

    // processing the deposits, invoices, and settlements for USDC //
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, WETH_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = _getDestinations(42_161);
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits - skipping one epoch ahead (i.e. zero discount)
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.INVOICED));

    // Creating an intent to match liquidity and rolling to create a discount
    // Arbitrum to Mainnet intents //
    // constructing the intent messages
    vm.roll(block.number + (hubProxy.epochLength() * 5));
    _destinations = _getDestinations(1);
    (IEverclearV2.Intent[] memory _matchIntent, bytes memory _matchIntentMessage) =
      _configureIntentMessages(1, USDC_ARBITRUM, USDC_MAINNET, ARBITRUM, _destinations, true);

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_matchIntentMessage);

    // processing the invoice
    hubProxy.processDepositsAndInvoices(_tickerHash, 2, 2, 2);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    _intents[0].amount = _intents[0].amount - (_intents[0].amount * (100 * 5)) / 100_000;
    bytes memory _calldata =
      _constructSettlementInfoArrayWithCustomId(_solver.toBytes32(), USDC_ARBITRUM.toBytes32(), _intentIds, _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, DEFAULT_GAS_LIMIT);
  }

  function test_hubUpgradeSwaps_invoiceDiscountedTenTimes_Bridge() public {
    _upgradeHub();

    // configuring the discount per epoch to xyz
    bytes32 _tickerHash = keccak256('USDC');
    _configureToken(_tickerHash);

    // processing the deposits, invoices, and settlements for USDC //
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intents, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, USDC_ARBITRUM, ETHEREUM, _destinations, false);
    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = keccak256(abi.encode(_intents[0]));

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED));

    // Sending the fill before the intent arrives
    // constructing the fill message
    uint32[] memory _solverDestinations = _getDestinations(42_161);
    uint256 _amountOut = _intents[0].amountOutMin;
    address _solver = address(0x123);
    (IEverclearV2.FillMessage memory _fill, bytes memory _fillMessage) = _configureFillMessage(
      _intentIds[0],
      _solver,
      _amountOut,
      _solverDestinations,
      USDC_MAINNET.toBytes32(),
      ETHEREUM,
      uint48(block.timestamp)
    );
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_fillMessage);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.ADDED_AND_FILLED));
    _assertFillInfo(_intentIds[0], _fill);

    // processing the deposits - skipping one epoch ahead (i.e. zero discount)
    vm.roll(block.number + 20);
    hubProxy.processDepositsAndInvoices(_tickerHash, 5, 5, 5);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.INVOICED));

    // Creating an intent to lead to a discount - 10 epochs
    // Arbitrum to Mainnet intents //
    // constructing the intent messages
    vm.roll(block.number + (hubProxy.epochLength() * 10));
    _destinations = _getDestinations(1);
    (IEverclearV2.Intent[] memory _matchIntent, bytes memory _matchIntentMessage) =
      _configureIntentMessages(1, USDC_ARBITRUM, USDC_MAINNET, ARBITRUM, _destinations, true);

    // sending intent message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_matchIntentMessage);

    // processing the invoice
    hubProxy.processDepositsAndInvoices(_tickerHash, 2, 2, 2);
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing settlement queue
    _intents[0].amount = _intents[0].amount - (_intents[0].amount * (100 * 10)) / 100_000;
    bytes memory _calldata =
      _constructSettlementInfoArrayWithCustomId(_solver.toBytes32(), USDC_ARBITRUM.toBytes32(), _intentIds, _intents);
    vm.expectCall(
      address(hubProxy.hubGateway()),
      0,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', ARBITRUM, _calldata, DEFAULT_GAS_LIMIT)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, DEFAULT_GAS_LIMIT);
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
    _upgradeHub();

    IEverclearV2.Strategy _strategy =
      IEverclearV2.Strategy(bound(_strategySeed, 0, uint256(type(IEverclearV2.Strategy).max)));

    vm.prank(hubProxy.owner());
    hubProxy.setPrioritizedStrategy(_tickerHash, _strategy);

    (,, IEverclearV2.Strategy _prioritizedStrategy) = hubProxy.tokenConfigs(_tickerHash);
    assertEq(uint8(_prioritizedStrategy), uint8(_strategy), 'prioritized strategy not set correctly');
  }

  function test_hubUpgradeSwaps_setLastClosedEpochProcessed() public {
    _upgradeHub();

    // configuring the params
    uint48 _lastEpochProcessed = uint48(block.number);
    IAssetManagerV2.SetLastClosedEpochProcessedParams memory _params;
    _params.lastEpochProcessed = _lastEpochProcessed;
    _params.tickerHashes = new bytes32[](1);
    _params.tickerHashes[0] = keccak256('USDC');

    // setting the state
    vm.prank(hubProxy.owner());
    hubProxy.setLastClosedEpochProcessed(_params);

    // asserting the state change
    EverclearHubV2 _hub = EverclearHubV2(address(hubProxy));
    assertEq(_hub.lastClosedEpochsProcessed(keccak256('USDC')), _lastEpochProcessed);
  }

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
    _upgradeHub();

    uint48 _epochLength = 55;
    vm.prank(hubProxy.owner());
    hubProxy.updateEpochLength(_epochLength);

    assertEq(hubProxy.epochLength(), _epochLength);
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

  function test_hubUpgradeSwaps_setMaxDiscountDBPS() public {
    _upgradeHub();

    // configuring the inputs
    bytes32 _tickerHash = keccak256('USDC');
    uint24 _maxDiscount = 20_000; // 2000 BPS

    vm.prank(hubProxy.owner());
    hubProxy.setMaxDiscountDbps(_tickerHash, _maxDiscount);

    // EverclearHubV2 _hub = EverclearHubV2(address(hubProxy));
    (uint24 _maxDiscountDbps,,) = hubProxy.tokenConfigs(_tickerHash);
    assertEq(_maxDiscountDbps, _maxDiscount);
  }

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

  // ============ Revert Checks ============ //
  function testRevert_hubUpgradeSwaps_receiveMessage_Unauthorized() public {
    _upgradeHub();

    // configuring the params
    bytes memory _data = abi.encodePacked(uint256(1), uint256(2), uint256(3));

    // expecting revert
    vm.expectRevert(IHubStorageV2.HubStorage_Unauthorized.selector);
    hubProxy.receiveMessage(_data);
  }

  function testRevert_hubUpgradeSwaps_processSettlementQueue_DomainNotsupported() public {
    _upgradeHub();

    // configuring the params
    uint32 unsupportedDomain = 9_999_999;

    // expecting revert
    vm.expectRevert(ISettlerV2.Settler_DomainNotSupported.selector);
    hubProxy.processSettlementQueue(unsupportedDomain, 1, 0);
  }

  function testRevert_hubUpgradeSwaps_processSettlementQueue_BlockGasLimitReached() public {
    _upgradeHub();

    // Mainnet to Arbitrum intents //
    // constructing the intent messages
    uint32[] memory _destinations = _getDestinations(42_161);
    (IEverclearV2.Intent[] memory _intentsToArbitrum, bytes memory _intentMessage) =
      _configureIntentMessages(1, USDC_MAINNET, address(0), ETHEREUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intentsToArbitrum);

    // Arbitrum to mainnet intents //
    IEverclearV2.Intent[] memory _intentsToMainnet;
    _destinations = _getDestinations(1);
    (_intentsToMainnet, _intentMessage) =
      _configureIntentMessages(1, USDC_ARBITRUM, address(0), ARBITRUM, _destinations, true);
    // sending message as gateway to the Hub //
    vm.prank(address(hubProxy.hubGateway()));
    hubProxy.receiveMessage(_intentMessage);
    _assertIntentsReceived(_intentsToMainnet);

    // processing the deposits and invoices for USDC //
    bytes32 _tickerHash = keccak256('USDC');
    vm.warp(block.timestamp + 3600);
    vm.roll(block.number + 50);
    hubProxy.processDepositsAndInvoices(_tickerHash, 500, 500, 500);

    // asserting the intents status are SETTLED
    bytes32[] memory _intentIds = new bytes32[](2);
    _intentIds[0] = keccak256(abi.encode(_intentsToArbitrum[0]));
    _intentIds[1] = keccak256(abi.encode(_intentsToMainnet[0]));
    _assertIntentsState(_intentIds, uint8(IEverclearV2.IntentStatus.SETTLED));

    // processing the settlement queue
    vm.expectRevert(
      abi.encodeWithSelector(ISettlerV2.Settler_DomainBlockGasLimitReached.selector, 30_000_000, type(uint256).max)
    );
    hubProxy.processSettlementQueue(ARBITRUM, 1, type(uint256).max);
  }

  // ============== Helpers ================= //
  function _assertIntentsReceived(
    IEverclearV2.Intent[] memory _intents
  ) internal view {
    for (uint256 i; i < _intents.length; i++) {
      bytes32 _intentId = keccak256(abi.encode(_intents[i]));
      IHubStorageV2.IntentContext memory _context = hubProxy.contexts(_intentId);
      assertEq(_context.intent.initiator, _intents[i].initiator);
      assertEq(_context.intent.receiver, _intents[i].receiver);
      assertEq(_context.intent.inputAsset, _intents[i].inputAsset);
      assertEq(_context.intent.outputAsset, _intents[i].outputAsset);
      assertEq(_context.intent.origin, _intents[i].origin);
      assertEq(_context.intent.nonce, _intents[i].nonce);
      assertEq(_context.intent.timestamp, _intents[i].timestamp);
      assertEq(_context.intent.ttl, _intents[i].ttl);
      assertEq(_context.intent.amount, _intents[i].amount);
      assertEq(_context.intent.amountOutMin, _intents[i].amountOutMin);
      assertEq(_context.intent.destinations.length, _intents[i].destinations.length);
      for (uint256 j; j < _context.intent.destinations.length; j++) {
        assertEq(_context.intent.destinations[j], _intents[i].destinations[j]);
      }
      assertEq(_context.intent.data, _intents[i].data);
    }
  }

  function _assertIntentsState(bytes32[] memory _intentIds, uint8 _state) internal view {
    for (uint256 i; i < _intentIds.length; i++) {
      IHubStorageV2.IntentContext memory _context = hubProxy.contexts(_intentIds[i]);
      assertEq(uint8(_context.status), _state);
    }
  }

  function _configureFillMessage(
    bytes32 _intentId,
    address _solver,
    uint256 _amountOut,
    uint32[] memory _destinations,
    bytes32 _intentInputAsset,
    uint32 _origin,
    uint48 _timestamp
  ) internal pure returns (IEverclearV2.FillMessage memory, bytes memory) {
    IEverclearV2.FillMessage memory _fill = IEverclearV2.FillMessage({
      intentId: _intentId,
      initiator: _solver.toBytes32(),
      solver: _solver.toBytes32(),
      intentInputAsset: _intentInputAsset,
      intentOrigin: _origin,
      amountOut: _amountOut,
      destinations: _destinations,
      executionTimestamp: _timestamp
    });

    IEverclearV2.FillMessage[] memory _fillMessages = new IEverclearV2.FillMessage[](1);
    _fillMessages[0] = _fill;
    bytes memory _fillMessage = MessageLibV2.formatFillMessageBatch(_fillMessages);
    return (_fill, _fillMessage);
  }

  function _assertFillInfo(bytes32 _intentId, IEverclearV2.FillMessage memory _fill) internal view {
    IHubStorageV2.IntentContext memory _context = hubProxy.contexts(_intentId);
    assertEq(_context.solver, _fill.solver);
    assertEq(_context.amountOut, _fill.amountOut);
    assertEq(_context.solverDestinations.length, _fill.destinations.length);
    for (uint256 i; i < _fill.destinations.length; i++) {
      assertEq(_context.solverDestinations[i], _fill.destinations[i]);
    }
  }

  function _assertFillInfo(bytes32[] memory _intentIds, IEverclearV2.FillMessage[] memory _fill) internal view {
    for (uint256 i; i < _intentIds.length; i++) {
      IHubStorageV2.IntentContext memory _context = hubProxy.contexts(_intentIds[i]);
      assertEq(_context.solver, _fill[i].solver);
      assertEq(_context.amountOut, _fill[i].amountOut);
      assertEq(_context.solverDestinations.length, _fill[i].destinations.length);
      for (uint256 j; j < _fill[i].destinations.length; j++) {
        assertEq(_context.solverDestinations[j], _fill[i].destinations[j]);
      }
    }
  }

  function _constructSettlementInfo(
    bytes32 _solver,
    bytes32 _outputAsset,
    IEverclearV2.Intent[] memory _intents
  ) internal pure returns (bytes memory) {
    IEverclearV2.Settlement[] memory _settlementMessages = new IEverclearV2.Settlement[](_intents.length);
    for (uint256 i; i < _intents.length; i++) {
      _settlementMessages[i].intentId = keccak256(abi.encode(_intents[i]));
      _settlementMessages[i].amount = _intents[i].amount;
      _settlementMessages[i].asset = _outputAsset;
      _settlementMessages[i].recipient = _solver;
      _settlementMessages[i].updateVirtualBalance = false;
    }

    bytes memory _message = MessageLibV2.formatSettlementBatch(_settlementMessages);
    return _message;
  }

  function _constructSettlementInfoArrayWithCustomId(
    bytes32 _solver,
    bytes32 _outputAsset,
    bytes32[] memory _intentId,
    IEverclearV2.Intent[] memory _intents
  ) internal pure returns (bytes memory) {
    IEverclearV2.Settlement[] memory _settlementMessages = new IEverclearV2.Settlement[](_intents.length);
    for (uint256 i; i < _intents.length; i++) {
      _settlementMessages[i].intentId = _intentId[i];
      _settlementMessages[i].amount = _intents[i].amount;
      _settlementMessages[i].asset = _outputAsset;
      _settlementMessages[i].recipient = _solver;
      _settlementMessages[i].updateVirtualBalance = false;
    }

    bytes memory _message = MessageLibV2.formatSettlementBatch(_settlementMessages);
    return _message;
  }

  function _constructSettlementInfoArray(
    bytes32 _outputAsset,
    IEverclearV2.Intent[] memory _intents
  ) internal pure returns (bytes memory) {
    IEverclearV2.Settlement[] memory _settlementMessages = new IEverclearV2.Settlement[](_intents.length);
    for (uint256 i; i < _intents.length; i++) {
      _settlementMessages[i].intentId = keccak256(abi.encode(_intents[i]));
      _settlementMessages[i].amount = _intents[i].amount;
      _settlementMessages[i].asset = _outputAsset;
      _settlementMessages[i].recipient = _intents[i].receiver;
      _settlementMessages[i].updateVirtualBalance = false;
    }

    bytes memory _message = MessageLibV2.formatSettlementBatch(_settlementMessages);
    return _message;
  }

  function _constructSettlementInfoArrayWithSolvers(
    bytes32 _outputAsset,
    IEverclearV2.Intent[] memory _intents,
    address[] memory _solvers
  ) internal pure returns (bytes memory) {
    IEverclearV2.Settlement[] memory _settlementMessages = new IEverclearV2.Settlement[](_intents.length);
    for (uint256 i; i < _intents.length; i++) {
      _settlementMessages[i].intentId = keccak256(abi.encode(_intents[i]));
      _settlementMessages[i].amount = _intents[i].amount;
      _settlementMessages[i].asset = _outputAsset;
      _settlementMessages[i].recipient = _solvers[i].toBytes32();
      _settlementMessages[i].updateVirtualBalance = false;
    }

    bytes memory _message = MessageLibV2.formatSettlementBatch(_settlementMessages);
    return _message;
  }

  function _updateCustodiedAssets(bytes32 _assetHash, uint256 _custodiedAssetValue) internal {
    address _target = address(hubProxy);
    stdstore.target(_target).sig('custodiedAssets(bytes32)').with_key(_assetHash).checked_write(_custodiedAssetValue);
    assertEq(hubProxy.custodiedAssets(_assetHash), _custodiedAssetValue);
  }

  function _generateAndAddIds(
    bytes32[] memory _existingIds,
    IEverclearV2.Intent[] memory _newIntents
  ) internal pure returns (bytes32[] memory) {
    bytes32[] memory _newIds = _generateIds(_newIntents);
    bytes32[] memory _combinedIds = new bytes32[](_existingIds.length + _newIds.length);
    for (uint256 i = 0; i < _existingIds.length; i++) {
      _combinedIds[i] = _existingIds[i];
    }
    for (uint256 i = 0; i < _newIds.length; i++) {
      _combinedIds[_existingIds.length + i] = _newIds[i];
    }
    return _combinedIds;
  }

  function _generateIds(
    IEverclearV2.Intent[] memory _intents
  ) internal pure returns (bytes32[] memory) {
    bytes32[] memory _ids = new bytes32[](_intents.length);
    for (uint256 i = 0; i < _intents.length; i++) {
      _ids[i] = keccak256(abi.encode(_intents[i]));
    }
    return _ids;
  }

  function _configureSolverDestinations(
    uint32[] memory _destinations,
    uint256 _length
  ) internal pure returns (uint32[][] memory) {
    uint32[][] memory _solverDestinations = new uint32[][](_length);
    for (uint256 i; i < _solverDestinations.length; i++) {
      _solverDestinations[i] = _destinations;
    }
    return _solverDestinations;
  }

  function _configureFillMessages(
    IEverclearV2.Intent[] memory _intents,
    uint32[][] memory _destinations,
    address[] memory _solvers
  ) internal view returns (IEverclearV2.FillMessage[] memory, bytes memory) {
    IEverclearV2.FillMessage[] memory _fills = new IEverclearV2.FillMessage[](_intents.length);
    for (uint256 i; i < _intents.length; i++) {
      bytes32 _intentId = keccak256(abi.encode(_intents[i]));
      _fills[i] = IEverclearV2.FillMessage({
        intentId: _intentId,
        initiator: _solvers[i].toBytes32(),
        solver: _solvers[i].toBytes32(),
        intentInputAsset: _intents[i].inputAsset,
        intentOrigin: _intents[i].origin,
        amountOut: _intents[i].amountOutMin,
        destinations: _destinations[i],
        executionTimestamp: uint48(block.timestamp)
      });
    }
    bytes memory _fillMessage = MessageLibV2.formatFillMessageBatch(_fills);
    return (_fills, _fillMessage);
  }

  function _configureSolvers(
    uint256 _length
  ) internal pure returns (address[] memory) {
    address[] memory _solvers = new address[](_length);
    for (uint256 i; i < _solvers.length; i++) {
      _solvers[i] = address(uint160(i + 1));
    }
    return _solvers;
  }

  function _updateLighthouse(
    address _newLighthouse
  ) internal {
    vm.prank(hubProxy.owner());
    hubProxy.updateLighthouse{value: 0.01 ether}(_newLighthouse);
    assertEq(hubProxy.lighthouse(), _newLighthouse);
  }
}
