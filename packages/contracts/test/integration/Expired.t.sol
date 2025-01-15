// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Vm} from 'forge-std/Vm.sol';
import {console} from 'forge-std/console.sol';

import {AssetUtils} from 'contracts/common/AssetUtils.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';

import {ISettler} from 'interfaces/hub/ISettler.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract Intent_Integration is IntegrationBase {
  using stdStorage for StdStorage;
  using TypeCasts for address;

  bytes32 internal _intentId;
  bytes32 internal _expiredIntentId;
  IEverclear.Intent internal _intent;
  IEverclear.Intent internal _expiredIntent;
  IEverclear.FillMessage internal _fillMessage;

  function test_Intent_Expired_Default() public {
    /*///////////////////////////////////////////////////////////////
                         ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    uint256 _amountIn = AssetUtils.normalizeDecimals(18, 6, 100 ether);
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    deal(address(oUSDT), _user, _amountIn);

    // approve tokens
    vm.prank(_user);
    oUSDT.approve(address(sepoliaEverclearSpoke), type(uint256).max);

    // build destinations array
    uint32[] memory _dest = new uint32[](1);
    _dest[0] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    bytes memory _calldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent
    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _dest, _user, address(oUSDT), address(dUSDT), _amountIn, Constants.MAX_FEE, uint48(1 days), _calldata
    );

    // saving expired id
    _expiredIntentId = _intentId;
    _expiredIntent = _intent;

    // create intent message
    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    _intents[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{value: 1 ether}(_intents);

    /*///////////////////////////////////////////////////////////////
                         EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    // craft intent message
    bytes memory _intentMessageBody = MessageLib.formatIntentMessageBatch(_intents);
    bytes memory _intentMessage = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBody
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessage),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessage);

    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to destination fork
    vm.selectFork(BSC_TESTNET_FORK);

    // warp to expired timestamp
    vm.warp(_intent.timestamp + _intent.ttl + 1);

    // deal output asset to solver
    uint256 _depositAmount = 100 ether * (10 ** (18 - 6));
    deal(address(dUSDT), _solver2, _depositAmount);

    vm.startPrank(_solver2);
    // approve Everclear spoke
    dUSDT.approve(address(bscEverclearSpoke), type(uint256).max);

    // deposit output asset
    bscEverclearSpoke.deposit(address(dUSDT), _depositAmount);

    // should revert as it is now expired
    vm.expectRevert(abi.encodeWithSelector(IEverclearSpoke.EverclearSpoke_FillIntent_IntentExpired.selector, _intentId));

    // execute user intent
    bscEverclearSpoke.fillIntent(_intent, _intent.maxFee);

    vm.stopPrank();

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user2
    deal(address(dUSDT), _user2, 100 ether);

    // approve tokens
    vm.prank(_user2);
    dUSDT.approve(address(bscEverclearSpoke), type(uint256).max);

    // build destinations array
    uint32[] memory _dest2 = new uint32[](1);
    _dest2[0] = ETHEREUM_SEPOLIA_ID;

    // create new intent
    vm.prank(_user2);

    // create intent to have custodied assets
    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _dest2, _user2, address(dUSDT), address(oUSDT), 100 ether, Constants.MAX_FEE, uint48(1 days), ''
    );

    // create intent message
    IEverclear.Intent[] memory _intents2 = new IEverclear.Intent[](1);
    _intents2[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processIntentQueue{value: 1 ether}(_intents2);

    /*///////////////////////////////////////////////////////////////
                         EVERCLEAR DOMAIN 
    //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBody2 = MessageLib.formatIntentMessageBatch(_intents2);
    bytes memory _intentMessage2 = _formatHLMessage(
      3,
      1337,
      BSC_TESTNET_ID,
      address(bscSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBody2
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessage2),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessage2);

    // warp to expired timestamp
    vm.warp(_intent.timestamp + _intent.ttl + hub.expiryTimeBuffer());

    bytes32[] memory _expired = new bytes32[](1);
    _expired[0] = _expiredIntentId;

    vm.roll(block.number + hub.epochLength());

    vm.prank(_user);
    hub.handleExpiredIntents(_expired);

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{value: 1 ether}(BSC_TESTNET_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    /*///////////////////////////////////////////////////////////////
                         SETTLEMENT DOMAIN 
    //////////////////////////////////////////////////////////////*/

    vm.selectFork(BSC_TESTNET_FORK);

    bytes memory _settlementMessageFormatted = _formatHLMessage(
      3,
      1337,
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      BSC_TESTNET_ID,
      address(bscSpokeGateway).toBytes32(),
      _body(_settlementMessageBody)
    );

    // mock call to ISM
    vm.mockCall(
      address(bscTestnetISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted),
      abi.encode(true)
    );

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    bscMailbox.process(bytes(''), _settlementMessageFormatted);

    bscEverclearSpoke.executeIntentCalldata(_expiredIntent);
  }

  function test_Intent_Expired_XERC20() public {
    /*///////////////////////////////////////////////////////////////
                         ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin xtoken to user
    deal(address(sepoliaXToken), _user, 100 ether);

    // approve tokens
    vm.prank(_user);
    IERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    // build destinations array
    uint32[] memory _dest = new uint32[](1);
    _dest[0] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    bytes memory _calldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent
    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _dest, _user, address(sepoliaXToken), address(bscXToken), 100 ether, Constants.MAX_FEE, uint48(1 days), _calldata
    );

    // saving expired id
    _expiredIntentId = _intentId;
    _expiredIntent = _intent;

    // create intent message
    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    _intents[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{value: 1 ether}(_intents);

    /*///////////////////////////////////////////////////////////////
                         EVERCLEAR DOMAIN 
    //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    // craft intent message
    bytes memory _intentMessageBody = MessageLib.formatIntentMessageBatch(_intents);
    bytes memory _intentMessage = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBody
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessage),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessage);

    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to destination fork
    vm.selectFork(BSC_TESTNET_FORK);

    // warp to expired timestamp
    vm.warp(_intent.timestamp + _intent.ttl + 1);

    // should revert as it is now expired
    vm.expectRevert(abi.encodeWithSelector(IEverclearSpoke.EverclearSpoke_FillIntent_IntentExpired.selector, _intentId));

    // try to fill user intent
    vm.prank(_solver2);
    bscEverclearSpoke.fillIntent(_intent, _intent.maxFee);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin xtoken to user
    deal(address(bscXToken), _user2, 100 ether);

    // approve tokens for burning
    vm.prank(_user2);
    IERC20(address(bscXToken)).approve(address(bscXERC20Module), type(uint256).max);

    // build destinations array
    uint32[] memory _dest2 = new uint32[](1);
    _dest2[0] = ETHEREUM_SEPOLIA_ID;

    // create new intent
    vm.prank(_user2);

    // create intent to have custodied assets
    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _dest2, _user2, address(bscXToken), address(sepoliaXToken), 100 ether, Constants.MAX_FEE, uint48(1 days), ''
    );

    // create intent message
    IEverclear.Intent[] memory _intents2 = new IEverclear.Intent[](1);
    _intents2[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processIntentQueue{value: 1 ether}(_intents2);

    /*///////////////////////////////////////////////////////////////
                         EVERCLEAR DOMAIN 
    //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBody2 = MessageLib.formatIntentMessageBatch(_intents2);
    bytes memory _intentMessage2 = _formatHLMessage(
      3,
      1337,
      BSC_TESTNET_ID,
      address(bscSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBody2
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessage2),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessage2);

    // warp to expired timestamp
    vm.warp(_intent.timestamp + _intent.ttl + hub.expiryTimeBuffer());

    bytes32[] memory _expired = new bytes32[](1);
    _expired[0] = _expiredIntentId;

    vm.roll(block.number + hub.epochLength());

    vm.prank(_user);
    hub.handleExpiredIntents(_expired);

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{value: 1 ether}(BSC_TESTNET_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    /*///////////////////////////////////////////////////////////////
                         SETTLEMENT DOMAIN 
    //////////////////////////////////////////////////////////////*/

    vm.selectFork(BSC_TESTNET_FORK);

    bytes memory _settlementMessageFormatted = _formatHLMessage(
      3,
      1337,
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      BSC_TESTNET_ID,
      address(bscSpokeGateway).toBytes32(),
      _body(_settlementMessageBody)
    );

    // mock call to ISM
    vm.mockCall(
      address(bscTestnetISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted),
      abi.encode(true)
    );

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    bscMailbox.process(bytes(''), _settlementMessageFormatted);

    bscEverclearSpoke.executeIntentCalldata(_expiredIntent);
  }
}
