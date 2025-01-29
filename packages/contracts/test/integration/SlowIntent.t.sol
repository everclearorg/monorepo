// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';

import {Vm} from 'forge-std/Vm.sol';
import {console} from 'forge-std/console.sol';

import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';

import {ISettler} from 'interfaces/hub/ISettler.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract Intent_Integration is IntegrationBase {
  using stdStorage for StdStorage;
  using TypeCasts for address;

  bytes32 internal _intentId;
  IEverclear.Intent internal _intent;
  IEverclear.FillMessage internal _fillMessage;

  function test_Intent_HappyPath_Slow_Default() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    deal(address(oUSDT), _user, 110 ether);

    // approve tokens
    vm.prank(_user);
    oUSDT.approve(address(sepoliaEverclearSpoke), type(uint256).max);

    // build destinations array
    uint32[] memory _destA = new uint32[](1);
    _destA[0] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _destA, _user, address(oUSDT), address(dUSDT), 100 ether, Constants.MAX_FEE, 0, _intentCalldata
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{value: 1 ether}(_intentsA);

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
    dUSDT.approve(address(bscEverclearSpoke), type(uint256).max);

    // build destinations array
    uint32[] memory _destB = new uint32[](1);
    _destB[0] = ETHEREUM_SEPOLIA_ID;

    // create new intent
    vm.prank(_user2);

    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) =
      bscEverclearSpoke.newIntent(_destB, _user2, address(dUSDT), address(oUSDT), 100 ether, Constants.MAX_FEE, 0, '');

    // create intent message
    IEverclear.Intent[] memory _intentsB = new IEverclear.Intent[](1);
    _intentsB[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processIntentQueue{value: 1 ether}(_intentsB);

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
    hub.processSettlementQueue{value: 1 ether}(ETHEREUM_SEPOLIA_ID, 1);

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
  }

  function test_Intent_Slow_SingleDomain_XERC20() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/
    uint256 _intentAmount = 100 ether;

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin sepoliaXToken to user
    deal(address(sepoliaXToken), _user, 110 ether);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    // build destinations array
    uint32[] memory _destA = new uint32[](1);
    _destA[0] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _destA, _user, address(sepoliaXToken), address(bscXToken), _intentAmount, Constants.MAX_FEE, 0, _intentCalldata
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{value: 1 ether}(_intentsA);

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
    hub.processSettlementQueue{value: 1 ether}(BSC_TESTNET_ID, 1);

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

    uint256 _amountAfterFees = _intentAmount - (totalProtocolFees * _intentAmount / Constants.DBPS_DENOMINATOR);
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), _amountAfterFees);
  }

  function test_Intent_Slow_MultipleDomain_XERC20() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/
    uint256 _intentAmount = 100 ether;

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin sepoliaXToken to user
    deal(address(sepoliaXToken), _user, 110 ether);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    // build destinations array
    uint32[] memory _destA = new uint32[](2);
    _destA[0] = BSC_TESTNET_ID;
    _destA[1] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _destA, _user, address(sepoliaXToken), address(0), _intentAmount, Constants.MAX_FEE, 0, _intentCalldata
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{value: 1 ether}(_intentsA);

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
    hub.processSettlementQueue{value: 1 ether}(BSC_TESTNET_ID, 1);

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

    uint256 _amountAfterFees = _intentAmount - (totalProtocolFees * _intentAmount / Constants.DBPS_DENOMINATOR);
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), _amountAfterFees);
  }

  function test_Intent_Slow_SingleDomain_XERC20_UnsupportedDestination() public {
    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/
    uint256 _intentAmount = 100 ether;

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin sepoliaXToken to user
    // not using deal here because if the next operation is a mint in the same origin for the user it will cause arithmetic overflow
    XERC20(address(sepoliaXToken)).mockMint(_user, _intentAmount);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    // build destinations array
    uint32[] memory _destA = new uint32[](1);
    // setting unsupported destination
    _destA[0] = 422;

    // create new intent
    vm.prank(_user);

    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));
    // creating intent w/ ttl == 0 (slow path intent)
    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _destA, _user, address(sepoliaXToken), address(bscXToken), _intentAmount, Constants.MAX_FEE, 0, _intentCalldata
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{value: 1 ether}(_intentsA);

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

    vm.recordLogs();

    vm.deal(_user, 100 ether);
    vm.prank(_user);
    hub.returnUnsupportedIntent{value: 1 ether}(_intentId);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    assertEq(
      uint8(hub.contexts(_intentId).status), uint8(IEverclear.IntentStatus.UNSUPPORTED_RETURNED), 'invalid status'
    );

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
      address(bscSpokeGateway).toBytes32(),
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
    assertEq(sepoliaEverclearSpoke.balances(address(sepoliaXToken).toBytes32(), _user.toBytes32()), _intentAmount);
  }
}
