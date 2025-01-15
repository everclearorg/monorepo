// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

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

  event IntentAdded(bytes32 indexed _intentId, uint256 _queueIdx, IEverclear.Intent _intent);
  event IntentProcessed(bytes32 indexed _intentId, IEverclear.IntentStatus indexed _status);
  event IntentFilled(
    bytes32 indexed _intentId,
    address indexed _solver,
    uint256 _totalFeeDBPS,
    uint256 _queueIdx,
    IEverclear.Intent _intent
  );
  event Deposited(address indexed _depositant, address indexed _asset, uint256 _amount);
  event ExternalCalldataExecuted(bytes32 indexed _intentId, bytes _returnData);
  event Settled(bytes32 indexed _intentId, address _account, address _asset, uint256 _amount);

  function test_Intent_HappyPath_Default() public {
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
    uint32[] memory _dest = new uint32[](1);
    _dest[0] = BSC_TESTNET_ID;

    uint256 _prevUserBalance = oUSDT.balanceOf(_user);
    uint256 _prevSpokeBalance = oUSDT.balanceOf(address(sepoliaEverclearSpoke));

    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));

    _intent = IEverclear.Intent({
      initiator: _user.toBytes32(),
      receiver: _user.toBytes32(),
      inputAsset: address(oUSDT).toBytes32(),
      outputAsset: address(dUSDT).toBytes32(),
      maxFee: Constants.MAX_FEE,
      origin: ETHEREUM_SEPOLIA_ID,
      nonce: 1,
      timestamp: uint48(block.timestamp),
      ttl: uint48(1 days),
      amount: 1e32,
      destinations: _dest,
      data: _intentCalldata
    });

    _intentId = keccak256(abi.encode(_intent));

    vm.expectEmit(address(sepoliaEverclearSpoke));
    emit IntentAdded(_intentId, 1, _intent);

    // create new intent
    vm.prank(_user);
    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _dest, _user, address(oUSDT), address(dUSDT), 100 ether, Constants.MAX_FEE, uint48(1 days), _intentCalldata
    );

    assertEq(oUSDT.balanceOf(_user), _prevUserBalance - 100 ether);
    assertEq(oUSDT.balanceOf(address(sepoliaEverclearSpoke)), _prevSpokeBalance + 100 ether);

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
    vm.expectCall(
      address(hubISM), abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessage)
    );

    vm.expectEmit(address(hub));
    emit IntentProcessed(_intentId, IEverclear.IntentStatus.DEPOSIT_PROCESSED);

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessage);

    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to destination fork
    vm.selectFork(BSC_TESTNET_FORK);

    // deal output asset to solver
    uint256 _depositAmount = 100 ether * (10 ** (18 - 6));
    deal(address(dUSDT), _solver2, _depositAmount);

    vm.startPrank(_solver2);
    // approve Everclear spoke
    dUSDT.approve(address(bscEverclearSpoke), type(uint256).max);

    uint256 _prevSolverBalance = dUSDT.balanceOf(_solver2);
    _prevSpokeBalance = dUSDT.balanceOf(address(bscEverclearSpoke));

    vm.expectEmit(address(bscEverclearSpoke));
    emit Deposited(_solver2, address(dUSDT), _depositAmount);

    // deposit output asset
    bscEverclearSpoke.deposit(address(dUSDT), _depositAmount);

    assertEq(dUSDT.balanceOf(_solver2), _prevSolverBalance - _depositAmount);
    assertEq(dUSDT.balanceOf(address(bscEverclearSpoke)), _prevSpokeBalance + _depositAmount);

    vm.mockCall(makeAddr('target'), abi.encodeWithSignature('doSomething()'), abi.encode(true));

    vm.expectEmit(address(bscEverclearSpoke));
    emit ExternalCalldataExecuted(_intentId, abi.encode(true));

    vm.expectEmit(address(bscEverclearSpoke));
    emit IntentFilled(_intentId, _solver2, _intent.maxFee, 1, _intent);

    // execute user intent
    _fillMessage = bscEverclearSpoke.fillIntent(_intent, _intent.maxFee);

    assertEq(
      dUSDT.balanceOf(address(bscEverclearSpoke)), _prevSpokeBalance + (_depositAmount * _intent.maxFee / 100_000)
    );

    vm.stopPrank();

    // deal lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);

    // process fill queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processFillQueue{value: 1 ether}(1);

    /*///////////////////////////////////////////////////////////////
                         EVERCLEAR DOMAIN 
    //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    // create intent message
    IEverclear.FillMessage[] memory _fillMessages = new IEverclear.FillMessage[](1);
    _fillMessages[0] = _fillMessage;

    bytes memory _fillMessageBody = MessageLib.formatFillMessageBatch(_fillMessages);
    bytes memory _fillMessageFormatted = _formatHLMessage(
      3,
      1337,
      BSC_TESTNET_ID,
      address(bscSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _fillMessageBody
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _fillMessageFormatted),
      abi.encode(true)
    );
    vm.expectCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _fillMessageFormatted)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _fillMessageFormatted);

    vm.prank(makeAddr('caller'));
    // process deposits and invoices
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
    vm.expectCall(
      address(sepoliaISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted)
    );

    vm.expectEmit(address(bscEverclearSpoke));
    emit Settled(_intentId, _solver2, address(oUSDT), 100 ether - (100 ether * 3000 / 100_000));

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    sepoliaMailbox.process(bytes(''), _settlementMessageFormatted);
  }

  function test_Intent_HappyPath_XERC20() public {
    /*///////////////////////////////////////////////////////////////
                         ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    deal(address(sepoliaXToken), _user, 110 ether);

    // approve tokens
    vm.prank(_user);
    IERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    // build destinations array
    uint32[] memory _dest = new uint32[](1);
    _dest[0] = BSC_TESTNET_ID;

    uint256 _prevUserBalance = IERC20(address(sepoliaXToken)).balanceOf(_user);
    uint256 _prevSpokeBalance = IERC20(address(sepoliaXToken)).balanceOf(address(sepoliaEverclearSpoke));

    _intent = IEverclear.Intent({
      initiator: _user.toBytes32(),
      receiver: _user.toBytes32(),
      inputAsset: address(sepoliaXToken).toBytes32(),
      outputAsset: address(bscXToken).toBytes32(),
      maxFee: Constants.MAX_FEE,
      origin: ETHEREUM_SEPOLIA_ID,
      nonce: 1,
      timestamp: uint48(block.timestamp),
      ttl: uint48(1 days),
      amount: 100 ether,
      destinations: _dest,
      data: ''
    });

    _intentId = keccak256(abi.encode(_intent));

    vm.expectEmit(address(sepoliaEverclearSpoke));
    emit IntentAdded(_intentId, 1, _intent);

    // create new intent
    vm.prank(_user);

    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _dest, _user, address(sepoliaXToken), address(bscXToken), 100 ether, Constants.MAX_FEE, uint48(1 days), ''
    );

    assertEq(IERC20(address(sepoliaXToken)).balanceOf(_user), _prevUserBalance - 100 ether);

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
    vm.expectCall(
      address(hubISM), abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessage)
    );

    vm.expectEmit(address(hub));
    emit IntentProcessed(_intentId, IEverclear.IntentStatus.DEPOSIT_PROCESSED);

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessage);

    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to destination fork
    vm.selectFork(BSC_TESTNET_FORK);

    // deal output asset to solver
    uint256 _depositAmount = 100 ether;
    deal(address(bscXToken), _solver2, _depositAmount);

    vm.startPrank(_solver2);
    // approve Everclear spoke
    IERC20(address(bscXToken)).approve(address(bscEverclearSpoke), type(uint256).max);

    uint256 _prevSolverBalance = IERC20(address(bscXToken)).balanceOf(_solver2);
    _prevSpokeBalance = IERC20(address(bscXToken)).balanceOf(address(bscEverclearSpoke));

    vm.expectEmit(address(bscEverclearSpoke));
    emit Deposited(_solver2, address(bscXToken), _depositAmount);

    // deposit output asset
    bscEverclearSpoke.deposit(address(bscXToken), _depositAmount);

    assertEq(IERC20(address(bscXToken)).balanceOf(_solver2), _prevSolverBalance - _depositAmount);
    assertEq(IERC20(address(bscXToken)).balanceOf(address(bscEverclearSpoke)), _prevSpokeBalance + _depositAmount);

    vm.expectEmit(address(bscEverclearSpoke));
    emit IntentFilled(_intentId, _solver2, _intent.maxFee, 1, _intent);

    // execute user intent
    _fillMessage = bscEverclearSpoke.fillIntent(_intent, _intent.maxFee);

    assertEq(
      IERC20(address(bscXToken)).balanceOf(address(bscEverclearSpoke)),
      _prevSpokeBalance + (_depositAmount * _intent.maxFee / 100_000)
    );
    assertEq(IERC20(address(bscXToken)).balanceOf(_user), _depositAmount - (_depositAmount * _intent.maxFee / 100_000));

    vm.stopPrank();

    // deal lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);

    // process fill queue
    vm.prank(LIGHTHOUSE);
    bscEverclearSpoke.processFillQueue{value: 1 ether}(1);

    /*///////////////////////////////////////////////////////////////
                         EVERCLEAR DOMAIN 
    //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    // create intent message
    IEverclear.FillMessage[] memory _fillMessages = new IEverclear.FillMessage[](1);
    _fillMessages[0] = _fillMessage;

    bytes memory _fillMessageBody = MessageLib.formatFillMessageBatch(_fillMessages);
    bytes memory _fillMessageFormatted = _formatHLMessage(
      3,
      1337,
      BSC_TESTNET_ID,
      address(bscSpokeGateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _fillMessageBody
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _fillMessageFormatted),
      abi.encode(true)
    );
    vm.expectCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _fillMessageFormatted)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _fillMessageFormatted);

    vm.prank(makeAddr('caller'));
    // process deposits and invoices
    hub.processDepositsAndInvoices(keccak256('TXT'), 0, 0, 0);

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
    vm.expectCall(
      address(sepoliaISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted)
    );

    vm.expectEmit(address(bscEverclearSpoke));
    emit Settled(_intentId, _solver2, address(sepoliaXToken), 100 ether - (100 ether * 3000 / 100_000));

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    sepoliaMailbox.process(bytes(''), _settlementMessageFormatted);
  }
}
