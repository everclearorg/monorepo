// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { StdStorage, stdStorage } from 'forge-std/StdStorage.sol';

import { IInterchainSecurityModule } from '@hyperlane/interfaces/IInterchainSecurityModule.sol';

import { Vm } from 'forge-std/Vm.sol';
import { console } from 'forge-std/console.sol';

import { MessageLib } from 'contracts/common/MessageLib.sol';
import { TypeCasts } from 'contracts/common/TypeCasts.sol';

import { IEverclear } from 'interfaces/common/IEverclear.sol';
import { IEverclearHub } from 'interfaces/hub/IEverclearHub.sol';

import { ISettler } from 'interfaces/hub/ISettler.sol';

import { IntegrationBase } from 'test/integration/IntegrationBase.t.sol';

import { Constants } from 'test/utils/Constants.sol';

import { TestERC20 } from '../../utils/TestERC20.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { ERC20, IXERC20, XERC20 } from 'test/utils/TestXToken.sol';

contract Intent_Integration is IntegrationBase {
  using stdStorage for StdStorage;
  using TypeCasts for address;

  bytes32 internal _intentId;
  IEverclear.Intent internal _intent;
  IEverclear.FillMessage internal _fillMessage;

  function test_IntentViaFeeAdapter_Unsupported_FeeInTransacting() public {
    /*///////////////////////////////////////////////////////////////
                         ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    // Deal unsupported token to user including fee
    uint256 _tokenFee = 1 ether;
    address _unsupportedToken = address(new TestERC20('Token', 'TKN'));
    deal(_unsupportedToken, _user, 100 ether + _tokenFee);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);

    // approve tokens
    vm.prank(_user);
    IERC20(_unsupportedToken).approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _dest = new uint32[](1);
    _dest[0] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    (_intentId, _intent) = sepoliaFeeAdapter.newIntent(
      _dest,
      _user,
      _unsupportedToken,
      _unsupportedToken,
      100 ether,
      Constants.MAX_FEE,
      uint48(1 days),
      '',
      _tokenFee
    );

    // create intent message
    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    _intents[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    sepoliaEverclearSpoke.processIntentQueue{ value: 1 ether }(_intents);

    // expect to send fee to fee recipient
    assertEq(IERC20(_unsupportedToken).balanceOf(sepoliaFeeAdapter.feeRecipient()), _tokenFee);

    // expect the sepoliaEverclearSpoke balance to be 100 ether in unsupported token
    assertEq(IERC20(_unsupportedToken).balanceOf(address(sepoliaFeeAdapter)), 0 ether);
    assertEq(IERC20(_unsupportedToken).balanceOf(address(sepoliaEverclearSpoke)), 100 ether);

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

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessage);

    vm.recordLogs();

    // user must claim unsupported intent
    deal(_user, 100 ether);
    vm.prank(_user);
    hub.returnUnsupportedIntent{ value: 1 ether }(_intentId);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    /*///////////////////////////////////////////////////////////////
                          ORIGIN DOMAIN 
    //////////////////////////////////////////////////////////////*/

    // switch to origin fork
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

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    sepoliaMailbox.process(bytes(''), _settlementMessageFormatted);

    // expect the _user's balance to be 100 ether
    assertEq(IERC20(_unsupportedToken).balanceOf(address(sepoliaFeeAdapter)), 0 ether);
    assertEq(IERC20(_unsupportedToken).balanceOf(_user), 0 ether);
    assertEq(
      sepoliaEverclearSpoke.balances(_unsupportedToken.toBytes32(), address(sepoliaFeeAdapter).toBytes32()),
      100 ether
    );

    // returning the unsupported intent to the user
    vm.prank(_owner);
    sepoliaFeeAdapter.returnUnsupportedIntent(_unsupportedToken, 100 ether, _user);

    // expect the _user's balance to be 100 ether, sepoliaEverclearSpoke balance to be 0, and sepoliaFeeAdapter virtual balance to be 0
    assertEq(IERC20(_unsupportedToken).balanceOf(_user), 100 ether);
    assertEq(IERC20(_unsupportedToken).balanceOf(address(sepoliaEverclearSpoke)), 0);
    assertEq(
      sepoliaEverclearSpoke.balances(_unsupportedToken.toBytes32(), address(sepoliaFeeAdapter).toBytes32()),
      0 ether
    );
  }

  function test_Intent_Slow_SingleDomain_XERC20_UnsupportedDestination_FeeInTransacting() public {
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
    // not using deal here because if the next operation is a mint in the same origin for the user it will cause arithmetic overflow
    XERC20(address(sepoliaXToken)).mockMint(_user, _intentAmount + _feeAmount);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaFeeAdapter), type(uint256).max);

    // build destinations array
    uint32[] memory _destA = new uint32[](1);
    // setting unsupported destination
    _destA[0] = 422;

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
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(_user), 0);
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

    vm.recordLogs();

    vm.deal(_user, 100 ether);
    vm.prank(_user);
    hub.returnUnsupportedIntent{ value: 1 ether }(_intentId);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bytes memory _settlementMessageBody = abi.decode(entries[0].data, (bytes));

    assertEq(
      uint8(hub.contexts(_intentId).status),
      uint8(IEverclear.IntentStatus.UNSUPPORTED_RETURNED),
      'invalid status'
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
    assertEq(
      sepoliaEverclearSpoke.balances(address(sepoliaXToken).toBytes32(), address(sepoliaFeeAdapter).toBytes32()),
      _intentAmount
    );

    // pushing the virtual balance to the user
    vm.prank(_owner);
    sepoliaFeeAdapter.returnUnsupportedIntent(address(sepoliaXToken), _intentAmount, _user);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(_user), _intentAmount);
    assertEq(
      sepoliaEverclearSpoke.balances(address(sepoliaXToken).toBytes32(), address(sepoliaFeeAdapter).toBytes32()),
      0
    );
  }
}
