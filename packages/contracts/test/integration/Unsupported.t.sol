// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

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

import {TestERC20} from '../utils/TestERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Intent_Integration is IntegrationBase {
  using stdStorage for StdStorage;
  using TypeCasts for address;

  bytes32 internal _intentId;
  IEverclear.Intent internal _intent;
  IEverclear.FillMessage internal _fillMessage;

  function test_Intent_Unsupported() public {
    /*///////////////////////////////////////////////////////////////
                         ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // select origin fork
    vm.selectFork(ETHEREUM_SEPOLIA_FORK);

    address _unsupportedToken = address(new TestERC20('Token', 'TKN'));
    deal(_unsupportedToken, _user, 100 ether);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);

    // approve tokens
    vm.prank(_user);
    IERC20(_unsupportedToken).approve(address(sepoliaEverclearSpoke), type(uint256).max);

    // build destinations array
    uint32[] memory _dest = new uint32[](1);
    _dest[0] = BSC_TESTNET_ID;

    // create new intent
    vm.prank(_user);

    (_intentId, _intent) = sepoliaEverclearSpoke.newIntent(
      _dest, _user, _unsupportedToken, _unsupportedToken, 100 ether, Constants.MAX_FEE, uint48(1 days), ''
    );

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

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessage);

    vm.recordLogs();

    // user must claim unsupported intent
    deal(_user, 100 ether);
    vm.prank(_user);
    hub.returnUnsupportedIntent{value: 1 ether}(_intentId);

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
  }
}
