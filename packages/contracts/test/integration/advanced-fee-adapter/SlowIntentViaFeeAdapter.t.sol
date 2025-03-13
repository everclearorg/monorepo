// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { StdStorage, stdStorage } from 'forge-std/StdStorage.sol';

import { ERC20, IXERC20, XERC20 } from 'test/utils/TestXToken.sol';

import { IInterchainSecurityModule } from '@hyperlane/interfaces/IInterchainSecurityModule.sol';

import { Vm } from 'forge-std/Vm.sol';
import { console } from 'forge-std/console.sol';

import { MessageLib } from 'contracts/common/MessageLib.sol';
import { TypeCasts } from 'contracts/common/TypeCasts.sol';
import { AssetUtils } from 'contracts/common/AssetUtils.sol';

import { IEverclear } from 'interfaces/common/IEverclear.sol';
import { IEverclearHub } from 'interfaces/hub/IEverclearHub.sol';
import { IEverclearSpoke } from 'interfaces/intent/IEverclearSpoke.sol';

import { ISettler } from 'interfaces/hub/ISettler.sol';

import { IntegrationBase } from 'test/integration/IntegrationBase.t.sol';

import { Constants } from 'test/utils/Constants.sol';

import { IFeeAdapter } from 'interfaces/intent/IFeeAdapter.sol';

contract NewIntentViaFeeAdapter_Integration is IntegrationBase {
  using stdStorage for StdStorage;
  using TypeCasts for address;

  bytes32 internal _intentId;
  IEverclear.Intent internal _intent;
  IEverclear.FillMessage internal _fillMessage;

  function test_IntentViaFeeAdapter_HappyPath_Slow_Default_FeeInTransacting() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    uint256 _tokenFee = 1 ether;
    deal(address(oUSDT), _user, 110 ether);

    // approve tokens
    vm.prank(_user);
    oUSDT.approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _destA = new uint32[](1);
    _destA[0] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = sepoliaFeeAdapter.newIntent(
      _destA,
      _user,
      address(oUSDT),
      address(dUSDT),
      100 ether,
      Constants.MAX_FEE,
      0,
      _intentCalldata,
      _tokenFee
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsA);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(oUSDT.balanceOf(sepoliaFeeAdapter.feeRecipient()), _tokenFee);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), 100 ether);
    assertEq(oUSDT.balanceOf(_user), 110 ether - 100 ether - _tokenFee);
    assertEq(oUSDT.balanceOf(address(sepoliaFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyA = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessageA = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyA
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageA),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageA);

    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to destination fork
    vm.selectFork(BSC_TESTNET_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    deal(address(dUSDT), _user2, 110 ether);

    // approve tokens
    vm.prank(_user2);
    dUSDT.approve(address(bscFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _destB = new uint32[](1);
    _destB[0] = ETHEREUM_SEPOLIA_ID;

    // create new intent
    vm.prank(_user2);

    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = bscFeeAdapter.newIntent(
      _destB,
      _user2,
      address(dUSDT),
      address(oUSDT),
      100 ether,
      Constants.MAX_FEE,
      0,
      '',
      _tokenFee
    );

    // create intent message
    IEverclear.Intent[] memory _intentsB = new IEverclear.Intent[](1);
    _intentsB[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsB);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(dUSDT.balanceOf(bscFeeAdapter.feeRecipient()), _tokenFee);
    assertEq(dUSDT.balanceOf(address(bscEverclearSpoke)), 100 ether);
    assertEq(dUSDT.balanceOf(_user2), 110 ether - 100 ether - _tokenFee);
    assertEq(dUSDT.balanceOf(address(bscFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyB = MessageLib.formatIntentMessageBatch(_intentsB);
    bytes memory _intentMessageB = _formatHLMessage(
      3,
      1337,
      BSC_TESTNET_ID,
      address(bscSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyB
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageB),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageB);

    vm.roll(block.number + hub.epochLength());

    hub.processDepositsAndInvoices(keccak256('USDT'), 0, 0, 0);

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{ value: 1 ether }(ETHEREUM_SEPOLIA_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    /*///////////////////////////////////////////////////////////////
                          SETTLEMENT DOMAIN 
    //////////////////////////////////////////////////////////////*/

    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    bytes memory _settlementMessageFormatted = _formatHLMessage(
      3,
      1337,
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      _body(_settlementMessageBody)
    );

    // mock call to ISM
    vm.mockCall(
      address(sepoliaISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted),
      abi.encode(true)
    );

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    sepoliaMailbox.process(bytes(''), _settlementMessageFormatted);

    // expect user balance to increase by the settlement amount minus protocol fee
    uint256 _amountAfterFees = 100 ether - ((totalProtocolFees * 100 ether) / Constants.DBPS_DENOMINATOR);
    assertEq(oUSDT.balanceOf(_user2), _amountAfterFees);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), 100 ether - _amountAfterFees);
  }

  function test_IntentViaFeeAdapter_HappyPath_Slow_Default_FeeInEth() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);

    // deal origin usdt to user
    uint256 _ethFee = 1 ether;
    deal(address(oUSDT), _user, 110 ether);

    // deal the eth to the user
    vm.deal(_user, _ethFee);

    // approve tokens
    vm.prank(_user);
    oUSDT.approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _destA = new uint32[](1);
    _destA[0] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    uint256 _intentAmount = 100 ether;
    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = sepoliaFeeAdapter.newIntent{ value: _ethFee }(
      _destA,
      _user,
      address(oUSDT),
      address(dUSDT),
      _intentAmount,
      Constants.MAX_FEE,
      0,
      _intentCalldata,
      0
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsA);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(sepoliaFeeAdapter.feeRecipient().balance, _ethFee);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), _intentAmount);
    assertEq(oUSDT.balanceOf(_user), 110 ether - _intentAmount);
    assertEq(oUSDT.balanceOf(address(sepoliaFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyA = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessageA = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyA
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageA),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageA);

    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to destination fork
    vm.selectFork(BSC_TESTNET_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    deal(address(dUSDT), _user2, 110 ether);
    // deal the eth to the user
    vm.deal(_user2, _ethFee);

    // approve tokens
    vm.prank(_user2);
    dUSDT.approve(address(bscFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _destB = new uint32[](1);
    _destB[0] = ETHEREUM_SEPOLIA_ID;

    // create new intent
    vm.prank(_user2);

    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = bscFeeAdapter.newIntent{ value: _ethFee }(
      _destB,
      _user2,
      address(dUSDT),
      address(oUSDT),
      _intentAmount,
      Constants.MAX_FEE,
      0,
      '',
      0
    );

    // create intent message
    IEverclear.Intent[] memory _intentsB = new IEverclear.Intent[](1);
    _intentsB[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsB);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(bscFeeAdapter.feeRecipient().balance, _ethFee);
    assertEq(dUSDT.balanceOf(address(bscEverclearSpoke)), _intentAmount);
    assertEq(dUSDT.balanceOf(_user2), 110 ether - _intentAmount);
    assertEq(dUSDT.balanceOf(address(bscFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyB = MessageLib.formatIntentMessageBatch(_intentsB);
    bytes memory _intentMessageB = _formatHLMessage(
      3,
      1337,
      BSC_TESTNET_ID,
      address(bscSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyB
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageB),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageB);

    vm.roll(block.number + hub.epochLength());

    hub.processDepositsAndInvoices(keccak256('USDT'), 0, 0, 0);

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{ value: 1 ether }(ETHEREUM_SEPOLIA_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    /*///////////////////////////////////////////////////////////////
                          SETTLEMENT DOMAIN 
    //////////////////////////////////////////////////////////////*/

    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    bytes memory _settlementMessageFormatted = _formatHLMessage(
      3,
      1337,
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      _body(_settlementMessageBody)
    );

    // mock call to ISM
    vm.mockCall(
      address(sepoliaISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted),
      abi.encode(true)
    );

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    sepoliaMailbox.process(bytes(''), _settlementMessageFormatted);

    // expect user balance to increase by the settlement amount minus protocol fee
    // _intentAmount - (totalProtocolFees * _intentAmount / Constants.DBPS_DENOMINATOR);
    uint256 _amountAfterFees = _intentAmount - ((totalProtocolFees * _intentAmount) / Constants.DBPS_DENOMINATOR);
    assertEq(oUSDT.balanceOf(_user2), _amountAfterFees);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), _intentAmount - _amountAfterFees);
  }

  function test_Intent_Slow_SingleDomain_XERC20_FeeInTransacting() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/
    uint256 _intentAmount = 100 ether;
    uint256 _feeAmount = 1 ether;

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin sepoliaXToken to user
    deal(address(sepoliaXToken), _user, 110 ether);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _destA = new uint32[](1);
    _destA[0] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = sepoliaFeeAdapter.newIntent(
      _destA,
      _user,
      address(sepoliaXToken),
      address(bscXToken),
      _intentAmount,
      Constants.MAX_FEE,
      0,
      _intentCalldata,
      _feeAmount
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsA);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(sepoliaFeeAdapter.feeRecipient()), _feeAmount);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(address(sepoliaEverclearSpoke)), 0);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(_user), 110 ether - _intentAmount - _feeAmount);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(address(sepoliaFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyA = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessageA = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyA
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageA),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageA);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN
    //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{ value: 1 ether }(BSC_TESTNET_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    (bytes32 _head, bytes32 _tail, uint256 _nonce, uint256 _length) = hub.invoices(keccak256('TXT'));
    assertEq(_head, 0, 'head should be 0');
    assertEq(_tail, 0, 'tail should be 0');
    assertEq(_nonce, 0, 'nonce should be 0');
    assertEq(_length, 0, 'length should be 0');

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

    uint256 _amountAfterFees = _intentAmount - ((totalProtocolFees * _intentAmount) / Constants.DBPS_DENOMINATOR);
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), _amountAfterFees);
  }

  function test_Intent_Slow_SingleDomain_XERC20_FeeInEth() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/
    uint256 _intentAmount = 100 ether;
    uint256 _feeAmount = 1 ether;

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin sepoliaXToken to user
    deal(address(sepoliaXToken), _user, 110 ether);
    vm.deal(_user, _feeAmount);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _destA = new uint32[](1);
    _destA[0] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = sepoliaFeeAdapter.newIntent{ value: _feeAmount }(
      _destA,
      _user,
      address(sepoliaXToken),
      address(bscXToken),
      _intentAmount,
      Constants.MAX_FEE,
      0,
      _intentCalldata,
      0
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsA);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(sepoliaFeeAdapter.feeRecipient().balance, _feeAmount);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(address(sepoliaEverclearSpoke)), 0);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(_user), 110 ether - _intentAmount);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(address(sepoliaFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyA = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessageA = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyA
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageA),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageA);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN
    //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{ value: 1 ether }(BSC_TESTNET_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    (bytes32 _head, bytes32 _tail, uint256 _nonce, uint256 _length) = hub.invoices(keccak256('TXT'));
    assertEq(_head, 0, 'head should be 0');
    assertEq(_tail, 0, 'tail should be 0');
    assertEq(_nonce, 0, 'nonce should be 0');
    assertEq(_length, 0, 'length should be 0');

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

    uint256 _amountAfterFees = _intentAmount - ((totalProtocolFees * _intentAmount) / Constants.DBPS_DENOMINATOR);
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), _amountAfterFees);
  }

  function test_Intent_Slow_MultipleDomain_XERC20_FeeInTransacting() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/
    uint256 _intentAmount = 100 ether;
    uint256 _feeAmount = 1 ether;

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin sepoliaXToken to user
    deal(address(sepoliaXToken), _user, 110 ether);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _destA = new uint32[](2);
    _destA[0] = BSC_TESTNET_ID;
    _destA[1] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = sepoliaFeeAdapter.newIntent(
      _destA,
      _user,
      address(sepoliaXToken),
      address(0),
      _intentAmount,
      Constants.MAX_FEE,
      0,
      _intentCalldata,
      _feeAmount
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsA);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(sepoliaFeeAdapter.feeRecipient()), _feeAmount);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(address(sepoliaEverclearSpoke)), 0);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(_user), 110 ether - _intentAmount - _feeAmount);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(address(sepoliaFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyA = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessageA = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyA
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageA),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageA);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN
    //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{ value: 1 ether }(BSC_TESTNET_ID, 1);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    (bytes32 _head, bytes32 _tail, uint256 _nonce, uint256 _length) = hub.invoices(keccak256('TXT'));
    assertEq(_head, 0, 'head should be 0');
    assertEq(_tail, 0, 'tail should be 0');
    assertEq(_nonce, 0, 'nonce should be 0');
    assertEq(_length, 0, 'length should be 0');

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

    uint256 _amountAfterFees = _intentAmount - ((totalProtocolFees * _intentAmount) / Constants.DBPS_DENOMINATOR);
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), _amountAfterFees);
  }
}

contract NewOrderSplitEvenly_Integration is IntegrationBase {
  using TypeCasts for address;

  function test_NewOrderSplitEvenly_HappyPath_FeeInTransacting(uint32 _numOfIntents) public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/
    vm.assume(_numOfIntents < 10);
    if (_numOfIntents < 2) _numOfIntents = 2;

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);

    // deal origin usdt to user
    deal(address(oUSDT), _user, 110 ether);

    // approve tokens
    vm.prank(_user);
    oUSDT.approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _dests = new uint32[](1);
    _dests[0] = BSC_TESTNET_ID;

    // building the params
    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    IFeeAdapter.OrderParameters memory _params = IFeeAdapter.OrderParameters({
      destinations: _dests,
      receiver: _user,
      inputAsset: address(oUSDT),
      outputAsset: address(dUSDT),
      amount: 100 ether,
      maxFee: Constants.MAX_FEE,
      ttl: 0,
      data: _intentCalldata
    });

    // creating intent w/ ttl == 0 (slow path intent)
    uint64 _nonce = sepoliaEverclearSpoke.nonce() + 1;

    vm.prank(_user);
    (, bytes32[] memory _intentIds) = sepoliaFeeAdapter.newOrderSplitEvenly(
      _numOfIntents,
      1 ether, // token fee
      _params
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = _generateEvenSplitIntentsAndConfirmStatusIsAdded(
      address(sepoliaFeeAdapter),
      _nonce,
      _numOfIntents,
      sepoliaEverclearSpoke.DOMAIN(),
      sepoliaEverclearSpoke,
      _params
    );

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsA);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(_intentIds.length, _numOfIntents);
    assertEq(oUSDT.balanceOf(sepoliaFeeAdapter.feeRecipient()), 1 ether);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), 100 ether);
    assertEq(oUSDT.balanceOf(_user), 110 ether - 100 ether - 1 ether);
    assertEq(oUSDT.balanceOf(address(sepoliaFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/
    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyA = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessageA = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyA
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageA),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageA);

    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to destination fork
    vm.selectFork(BSC_TESTNET_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    deal(address(dUSDT), _user2, 110 ether);

    // approve tokens
    vm.prank(_user2);
    dUSDT.approve(address(bscFeeAdapter), type(uint256).max);

    // build destinations array
    _dests = new uint32[](1);
    _dests[0] = ETHEREUM_SEPOLIA_ID;

    // creating intent w/ ttl == 0 (slow path intent)
    _nonce = sepoliaEverclearSpoke.nonce() + 1;

    // Updating the params to reflect the new destination and tokens
    _params.destinations = _dests;
    _params.inputAsset = address(dUSDT);
    _params.outputAsset = address(oUSDT);
    _params.receiver = _user2;

    vm.prank(_user2);
    (, _intentIds) = bscFeeAdapter.newOrderSplitEvenly(_numOfIntents, 1 ether, _params);

    // create intent message
    IEverclear.Intent[] memory _intentsB = _generateEvenSplitIntentsAndConfirmStatusIsAdded(
      address(sepoliaFeeAdapter),
      _nonce,
      _numOfIntents,
      bscEverclearSpoke.DOMAIN(),
      bscEverclearSpoke,
      _params
    );

    // process intent queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsB);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(_intentIds.length, _numOfIntents);
    assertEq(dUSDT.balanceOf(bscFeeAdapter.feeRecipient()), 1 ether);
    assertEq(dUSDT.balanceOf(address(bscEverclearSpoke)), 100 ether);
    assertEq(dUSDT.balanceOf(_user2), 110 ether - 100 ether - 1 ether);
    assertEq(dUSDT.balanceOf(address(bscFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    {
      bytes memory _intentMessageBodyB = MessageLib.formatIntentMessageBatch(_intentsB);
      bytes memory _intentMessageB = _formatHLMessage(
        3,
        1337,
        BSC_TESTNET_ID,
        address(bscSpokeGateway).toBytes32(),
        HUB_CHAIN_ID,
        address(hubGateway).toBytes32(),
        _intentMessageBodyB
      );

      // mock call to ISM
      vm.mockCall(
        address(hubISM),
        abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageB),
        abi.encode(true)
      );

      // deliver intent message to hub
      vm.prank(makeAddr('caller'));
      hubMailbox.process(bytes(''), _intentMessageB);

      vm.roll(block.number + hub.epochLength());

      hub.processDepositsAndInvoices(keccak256('USDT'), 0, 0, 0);

      vm.recordLogs();

      // process settlement queue
      vm.deal(LIGHTHOUSE, 100 ether);
      vm.prank(LIGHTHOUSE);
      hub.processSettlementQueue{ value: 1 ether }(ETHEREUM_SEPOLIA_ID, _numOfIntents);
    }

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    /*///////////////////////////////////////////////////////////////
                          SETTLEMENT DOMAIN
    //////////////////////////////////////////////////////////////*/

    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // Calculating the amountAfterFees
    uint256 _amountAfterFees = _calculateAmountAfterFeesForIntentArray(_intentsB, address(oUSDT));

    bytes memory _settlementMessageFormatted = _formatHLMessage(
      3,
      1337,
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      _body(_settlementMessageBody)
    );

    // mock call to ISM
    vm.mockCall(
      address(sepoliaISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted),
      abi.encode(true)
    );

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    sepoliaMailbox.process(bytes(''), _settlementMessageFormatted);

    // expect user balance to increase by the settlement amount minus protocol fee
    assertEq(oUSDT.balanceOf(_user2), _amountAfterFees);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), 100 ether - _amountAfterFees);
  }

  function test_NewOrderSplitEvenly_HappyPath_FeeInEth(uint32 _numOfIntents) public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/
    vm.assume(_numOfIntents < 10);
    if (_numOfIntents < 2) _numOfIntents = 2;

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.deal(_user, 1 ether);

    // deal origin usdt to user
    deal(address(oUSDT), _user, 110 ether);

    // approve tokens
    vm.prank(_user);
    oUSDT.approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _dests = new uint32[](1);
    _dests[0] = BSC_TESTNET_ID;

    // building the params
    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    IFeeAdapter.OrderParameters memory _params = IFeeAdapter.OrderParameters({
      destinations: _dests,
      receiver: _user,
      inputAsset: address(oUSDT),
      outputAsset: address(dUSDT),
      amount: 100 ether,
      maxFee: Constants.MAX_FEE,
      ttl: 0,
      data: _intentCalldata
    });

    // creating intent w/ ttl == 0 (slow path intent)
    uint64 _nonce = sepoliaEverclearSpoke.nonce() + 1;

    vm.prank(_user);
    (, bytes32[] memory _intentIds) = sepoliaFeeAdapter.newOrderSplitEvenly{ value: 1 ether }(
      _numOfIntents,
      0, // token fee
      _params
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = _generateEvenSplitIntentsAndConfirmStatusIsAdded(
      address(sepoliaFeeAdapter),
      _nonce,
      _numOfIntents,
      sepoliaEverclearSpoke.DOMAIN(),
      sepoliaEverclearSpoke,
      _params
    );

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsA);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(_intentIds.length, _numOfIntents);
    assertEq(sepoliaFeeAdapter.feeRecipient().balance, 1 ether);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), 100 ether);
    assertEq(oUSDT.balanceOf(_user), 110 ether - 100 ether);
    assertEq(oUSDT.balanceOf(address(sepoliaFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/
    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyA = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessageA = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyA
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageA),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageA);

    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to destination fork
    vm.selectFork(BSC_TESTNET_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.deal(_user2, 1 ether);

    // deal origin usdt to user
    deal(address(dUSDT), _user2, 110 ether);

    // approve tokens
    vm.prank(_user2);
    dUSDT.approve(address(bscFeeAdapter), type(uint256).max);

    // build destinations array
    _dests = new uint32[](1);
    _dests[0] = ETHEREUM_SEPOLIA_ID;

    // creating intent w/ ttl == 0 (slow path intent)
    _nonce = sepoliaEverclearSpoke.nonce() + 1;

    // Updating the params to reflect the new destination and tokens
    _params.destinations = _dests;
    _params.inputAsset = address(dUSDT);
    _params.outputAsset = address(oUSDT);
    _params.receiver = _user2;

    vm.prank(_user2);
    (, _intentIds) = bscFeeAdapter.newOrderSplitEvenly{ value: 1 ether }(_numOfIntents, 0, _params);

    // create intent message
    IEverclear.Intent[] memory _intentsB = _generateEvenSplitIntentsAndConfirmStatusIsAdded(
      address(sepoliaFeeAdapter),
      _nonce,
      _numOfIntents,
      bscEverclearSpoke.DOMAIN(),
      bscEverclearSpoke,
      _params
    );

    // process intent queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsB);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(_intentIds.length, _numOfIntents);
    assertEq(bscFeeAdapter.feeRecipient().balance, 1 ether);
    assertEq(dUSDT.balanceOf(address(bscEverclearSpoke)), 100 ether);
    assertEq(dUSDT.balanceOf(_user2), 110 ether - 100 ether);
    assertEq(dUSDT.balanceOf(address(bscFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    {
      bytes memory _intentMessageBodyB = MessageLib.formatIntentMessageBatch(_intentsB);
      bytes memory _intentMessageB = _formatHLMessage(
        3,
        1337,
        BSC_TESTNET_ID,
        address(bscSpokeGateway).toBytes32(),
        HUB_CHAIN_ID,
        address(hubGateway).toBytes32(),
        _intentMessageBodyB
      );

      // mock call to ISM
      vm.mockCall(
        address(hubISM),
        abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageB),
        abi.encode(true)
      );

      // deliver intent message to hub
      vm.prank(makeAddr('caller'));
      hubMailbox.process(bytes(''), _intentMessageB);

      vm.roll(block.number + hub.epochLength());

      hub.processDepositsAndInvoices(keccak256('USDT'), 0, 0, 0);

      vm.recordLogs();

      // process settlement queue
      vm.deal(LIGHTHOUSE, 100 ether);
      vm.prank(LIGHTHOUSE);
      hub.processSettlementQueue{ value: 1 ether }(ETHEREUM_SEPOLIA_ID, _numOfIntents);
    }

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    /*///////////////////////////////////////////////////////////////
                          SETTLEMENT DOMAIN
    //////////////////////////////////////////////////////////////*/

    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // Calculating the amountAfterFees
    uint256 _amountAfterFees = _calculateAmountAfterFeesForIntentArray(_intentsB, address(oUSDT));

    bytes memory _settlementMessageFormatted = _formatHLMessage(
      3,
      1337,
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      _body(_settlementMessageBody)
    );

    // mock call to ISM
    vm.mockCall(
      address(sepoliaISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted),
      abi.encode(true)
    );

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    sepoliaMailbox.process(bytes(''), _settlementMessageFormatted);

    // expect user balance to increase by the settlement amount minus protocol fee
    assertEq(oUSDT.balanceOf(_user2), _amountAfterFees);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), 100 ether - _amountAfterFees);
  }
}

contract NewOrder_Integration is IntegrationBase {
  using TypeCasts for address;

  function test_NewOrder_HappyPath_FeeInTransacting() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/
    uint256 _amountOne = 100 ether;
    uint256 _amountTwo = 50 ether;

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);

    // deal origin usdt to user
    uint256 _intentSum = uint256(_amountOne) + uint256(_amountTwo);
    deal(address(oUSDT), _user, _intentSum + 1 ether);

    // approve tokens
    vm.prank(_user);
    oUSDT.approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _dests = new uint32[](1);
    _dests[0] = BSC_TESTNET_ID;

    // building the params
    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    IFeeAdapter.OrderParameters[] memory _params = new IFeeAdapter.OrderParameters[](2);
    _params[0] = IFeeAdapter.OrderParameters({
      destinations: _dests,
      receiver: _user,
      inputAsset: address(oUSDT),
      outputAsset: address(dUSDT),
      amount: _amountOne,
      maxFee: Constants.MAX_FEE,
      ttl: 0,
      data: _intentCalldata
    });
    _params[1] = IFeeAdapter.OrderParameters({
      destinations: _dests,
      receiver: _user,
      inputAsset: address(oUSDT),
      outputAsset: address(dUSDT),
      amount: _amountTwo,
      maxFee: Constants.MAX_FEE,
      ttl: 0,
      data: _intentCalldata
    });

    // creating intent w/ ttl == 0 (slow path intent)
    uint64 _nonce = sepoliaEverclearSpoke.nonce() + 1;

    vm.prank(_user);
    (, bytes32[] memory _intentIds) = sepoliaFeeAdapter.newOrder(
      1 ether, // token fee
      _params
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = _generateUnknownSplitIntentsAndConfirmStatusIsAdded(
      address(sepoliaFeeAdapter),
      _nonce,
      sepoliaEverclearSpoke.DOMAIN(),
      sepoliaEverclearSpoke,
      _params
    );

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsA);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(_intentIds.length, 2);
    assertEq(oUSDT.balanceOf(sepoliaFeeAdapter.feeRecipient()), 1 ether);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), _intentSum);
    assertEq(oUSDT.balanceOf(_user), 0);
    assertEq(oUSDT.balanceOf(address(sepoliaFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/
    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyA = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessageA = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyA
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageA),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageA);

    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to destination fork
    vm.selectFork(BSC_TESTNET_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    deal(address(dUSDT), _user2, _intentSum + 1 ether);

    // approve tokens
    vm.prank(_user2);
    dUSDT.approve(address(bscFeeAdapter), type(uint256).max);

    // build destinations array
    _dests = new uint32[](1);
    _dests[0] = ETHEREUM_SEPOLIA_ID;

    // creating intent w/ ttl == 0 (slow path intent)
    _nonce = bscEverclearSpoke.nonce() + 1;

    // Updating the params to reflect the new destination and tokens
    _params[0].destinations = _dests;
    _params[0].inputAsset = address(dUSDT);
    _params[0].outputAsset = address(oUSDT);
    _params[0].receiver = _user2;

    _params[1].destinations = _dests;
    _params[1].inputAsset = address(dUSDT);
    _params[1].outputAsset = address(oUSDT);
    _params[1].receiver = _user2;

    vm.prank(_user2);
    (, _intentIds) = bscFeeAdapter.newOrder(1 ether, _params);

    // create intent message
    IEverclear.Intent[] memory _intentsB = _generateUnknownSplitIntentsAndConfirmStatusIsAdded(
      address(bscFeeAdapter),
      _nonce,
      bscEverclearSpoke.DOMAIN(),
      bscEverclearSpoke,
      _params
    );

    // Normalised amounts and calculating expected amountAfter fees
    uint256[] memory _normalisedAmounts = new uint256[](2);
    _normalisedAmounts[0] = _normaliseAmount(_amountOne, address(dUSDT));
    _normalisedAmounts[1] = _normaliseAmount(_amountTwo, address(dUSDT));

    // process intent queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsB);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(_intentIds.length, 2);
    assertEq(dUSDT.balanceOf(bscFeeAdapter.feeRecipient()), 1 ether);
    assertEq(dUSDT.balanceOf(address(bscEverclearSpoke)), _intentSum);
    assertEq(dUSDT.balanceOf(_user2), 0);
    assertEq(dUSDT.balanceOf(address(bscFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    {
      bytes memory _intentMessageBodyB = MessageLib.formatIntentMessageBatch(_intentsB);
      bytes memory _intentMessageB = _formatHLMessage(
        3,
        1337,
        BSC_TESTNET_ID,
        address(bscSpokeGateway).toBytes32(),
        HUB_CHAIN_ID,
        address(hubGateway).toBytes32(),
        _intentMessageBodyB
      );

      // mock call to ISM
      vm.mockCall(
        address(hubISM),
        abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageB),
        abi.encode(true)
      );

      // deliver intent message to hub
      vm.prank(makeAddr('caller'));
      hubMailbox.process(bytes(''), _intentMessageB);

      vm.roll(block.number + hub.epochLength());

      hub.processDepositsAndInvoices(keccak256('USDT'), 0, 0, 0);

      vm.recordLogs();

      // process settlement queue
      vm.deal(LIGHTHOUSE, 100 ether);
      vm.prank(LIGHTHOUSE);
      hub.processSettlementQueue{ value: 1 ether }(ETHEREUM_SEPOLIA_ID, 2);
    }

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    /*///////////////////////////////////////////////////////////////
                          SETTLEMENT DOMAIN
    //////////////////////////////////////////////////////////////*/

    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // Calculating the amountAfter fees
    uint256 _amountAfterFees = _calculateAmountAfterFeesForMultipleIntents(_normalisedAmounts, address(oUSDT));
    uint256 _spokeBalance = _intentSum - _amountAfterFees;

    // Executing the settlement
    bytes memory _settlementMessageFormatted = _formatHLMessage(
      3,
      1337,
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      _body(_settlementMessageBody)
    );

    // mock call to ISM
    vm.mockCall(
      address(sepoliaISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted),
      abi.encode(true)
    );

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    sepoliaMailbox.process(bytes(''), _settlementMessageFormatted);

    // expect user balance to increase by the settlement amount minus protocol fee
    assertEq(oUSDT.balanceOf(_user2), _amountAfterFees);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), _spokeBalance);
  }

  function test_NewOrder_HappyPath_FeeInEth() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/
    uint256 _amountOne = 100 ether;
    uint256 _amountTwo = 50 ether;

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);

    // deal origin usdt to user
    _amountOne = _amountOne / 2;
    uint256 _intentSum = uint256(_amountOne) + uint256(_amountTwo);
    deal(address(oUSDT), _user, _intentSum);
    vm.deal(_user, 1 ether);

    // approve tokens
    vm.prank(_user);
    oUSDT.approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _dests = new uint32[](1);
    _dests[0] = BSC_TESTNET_ID;

    // building the params
    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    IFeeAdapter.OrderParameters[] memory _params = new IFeeAdapter.OrderParameters[](2);
    _params[0] = IFeeAdapter.OrderParameters({
      destinations: _dests,
      receiver: _user,
      inputAsset: address(oUSDT),
      outputAsset: address(dUSDT),
      amount: _amountOne,
      maxFee: Constants.MAX_FEE,
      ttl: 0,
      data: _intentCalldata
    });
    _params[1] = IFeeAdapter.OrderParameters({
      destinations: _dests,
      receiver: _user,
      inputAsset: address(oUSDT),
      outputAsset: address(dUSDT),
      amount: _amountTwo,
      maxFee: Constants.MAX_FEE,
      ttl: 0,
      data: _intentCalldata
    });

    // creating intent w/ ttl == 0 (slow path intent)
    uint64 _nonce = sepoliaEverclearSpoke.nonce() + 1;

    vm.prank(_user);
    (, bytes32[] memory _intentIds) = sepoliaFeeAdapter.newOrder{ value: 1 ether }(
      0, // token fee
      _params
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = _generateUnknownSplitIntentsAndConfirmStatusIsAdded(
      address(sepoliaFeeAdapter),
      _nonce,
      sepoliaEverclearSpoke.DOMAIN(),
      sepoliaEverclearSpoke,
      _params
    );

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsA);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(_intentIds.length, 2);
    assertEq(sepoliaFeeAdapter.feeRecipient().balance, 1 ether);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), _intentSum);
    assertEq(oUSDT.balanceOf(_user), 0);
    assertEq(oUSDT.balanceOf(address(sepoliaFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/
    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBodyA = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessageA = _formatHLMessage(
      3,
      1337,
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBodyA
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageA),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessageA);

    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to destination fork
    vm.selectFork(BSC_TESTNET_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    deal(address(dUSDT), _user2, _intentSum);
    vm.deal(_user2, 1 ether);

    // approve tokens
    vm.prank(_user2);
    dUSDT.approve(address(bscFeeAdapter), type(uint256).max);

    // build destinations array
    _dests = new uint32[](1);
    _dests[0] = ETHEREUM_SEPOLIA_ID;

    // creating intent w/ ttl == 0 (slow path intent)
    _nonce = bscEverclearSpoke.nonce() + 1;

    // Updating the params to reflect the new destination and tokens
    _params[0].destinations = _dests;
    _params[0].inputAsset = address(dUSDT);
    _params[0].outputAsset = address(oUSDT);
    _params[0].receiver = _user2;

    _params[1].destinations = _dests;
    _params[1].inputAsset = address(dUSDT);
    _params[1].outputAsset = address(oUSDT);
    _params[1].receiver = _user2;

    vm.prank(_user2);
    (, _intentIds) = bscFeeAdapter.newOrder{ value: 1 ether }(0, _params);

    // create intent message
    IEverclear.Intent[] memory _intentsB = _generateUnknownSplitIntentsAndConfirmStatusIsAdded(
      address(bscFeeAdapter),
      _nonce,
      bscEverclearSpoke.DOMAIN(),
      bscEverclearSpoke,
      _params
    );

    // Normalised amounts and calculating expected amountAfter fees
    uint256[] memory _normalisedAmounts = new uint256[](2);
    _normalisedAmounts[0] = _normaliseAmount(_amountOne, address(dUSDT));
    _normalisedAmounts[1] = _normaliseAmount(_amountTwo, address(dUSDT));

    // process intent queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processIntentQueue{ value: 1 ether }(_intentsB);

    // asserting the fee was sent to the adapter recipient and spoke balances are updated
    assertEq(_intentIds.length, 2);
    assertEq(bscFeeAdapter.feeRecipient().balance, 1 ether);
    assertEq(dUSDT.balanceOf(address(bscEverclearSpoke)), _intentSum);
    assertEq(dUSDT.balanceOf(_user2), 0);
    assertEq(dUSDT.balanceOf(address(bscFeeAdapter)), 0);

    /*///////////////////////////////////////////////////////////////
                          EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    {
      bytes memory _intentMessageBodyB = MessageLib.formatIntentMessageBatch(_intentsB);
      bytes memory _intentMessageB = _formatHLMessage(
        3,
        1337,
        BSC_TESTNET_ID,
        address(bscSpokeGateway).toBytes32(),
        HUB_CHAIN_ID,
        address(hubGateway).toBytes32(),
        _intentMessageBodyB
      );

      // mock call to ISM
      vm.mockCall(
        address(hubISM),
        abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessageB),
        abi.encode(true)
      );

      // deliver intent message to hub
      vm.prank(makeAddr('caller'));
      hubMailbox.process(bytes(''), _intentMessageB);

      vm.roll(block.number + hub.epochLength());

      hub.processDepositsAndInvoices(keccak256('USDT'), 0, 0, 0);

      vm.recordLogs();

      // process settlement queue
      vm.deal(LIGHTHOUSE, 100 ether);
      vm.prank(LIGHTHOUSE);
      hub.processSettlementQueue{ value: 1 ether }(ETHEREUM_SEPOLIA_ID, 2);
    }

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    /*///////////////////////////////////////////////////////////////
                          SETTLEMENT DOMAIN
    //////////////////////////////////////////////////////////////*/

    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // Calculating the amountAfter fees
    uint256 _amountAfterFees = _calculateAmountAfterFeesForMultipleIntents(_normalisedAmounts, address(oUSDT));
    uint256 _balance = _intentSum - _amountAfterFees;

    // Executing the settlement
    bytes memory _settlementMessageFormatted = _formatHLMessage(
      3,
      1337,
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      ETHEREUM_SEPOLIA_ID,
      address(sepoliaSpokeGateway).toBytes32(),
      _body(_settlementMessageBody)
    );

    // mock call to ISM
    vm.mockCall(
      address(sepoliaISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted),
      abi.encode(true)
    );

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    sepoliaMailbox.process(bytes(''), _settlementMessageFormatted);

    // expect user balance to increase by the settlement amount minus protocol fee
    assertEq(oUSDT.balanceOf(_user2), _amountAfterFees);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), _balance);
  }
}
