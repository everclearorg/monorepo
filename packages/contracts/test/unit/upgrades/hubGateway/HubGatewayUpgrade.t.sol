// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Deploy} from 'script/utils/Deploy.sol';
import {UpgradeHelper} from 'test//utils/UpgradeHelper.sol';
import {BaseTest} from 'test/unit/hub/HubGateway.t.sol';

import {GatewayV2} from 'contracts/common/GatewayV2.sol';
import {HubGatewayV2} from 'contracts/hub/HubGatewayV2.sol';

import {IGatewayV2} from 'interfaces/common/IGatewayV2.sol';
import {IHubGatewayV2} from 'interfaces/hub/IHubGatewayV2.sol';

import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';

contract TestHubGatewayV2 is HubGatewayV2 {
  function checkValidSender(uint32 _origin, bytes32 _sender) external view {
    return _checkValidSender(_origin, _sender);
  }

  function getGateway(
    uint32 _domain
  ) external view returns (bytes32) {
    return _getGateway(_domain);
  }
}

contract HubGatewayUpgrade is BaseTest, UpgradeHelper {
  using TypeCasts for bytes32;
  using TypeCasts for address;

  bytes32 public constant GATEWAY_2 = keccak256(abi.encodePacked('1'));
  bytes32 public constant GATEWAY_3 = keccak256(abi.encodePacked('2'));
  address public constant MAILBOX_2 = address(0x456);
  address public constant MAILBOX_3 = address(0x789);
  bytes32 public constant INVALID_MAILBOX = bytes32(uint256(uint160(address(0x999))));

  TestHubGatewayV2 public hubGatewayProxy;

  function test_hubGatewayUpgrade_upgrade() external {
    // Setting up the test
    _setupTest();

    // Storing the state before upgrading
    (address _prevMailbox, address _prevReceiver, address _prevInterchainSecurityModule) = _cacheState();

    // Configuring inputs for the mailbox update
    address[] memory _mailboxes = new address[](2);
    _mailboxes[0] = MAILBOX_2;
    _mailboxes[1] = MAILBOX_3;
    uint32[] memory _chainIds = new uint32[](2);
    _chainIds[0] = 1;
    _chainIds[1] = 10;

    // Upgrading the hubGateway
    address _hubGatewayV2 = address(new HubGatewayV2());
    vm.startPrank(OWNER);
    hubGatewayProxy.upgradeToAndCall(
      _hubGatewayV2, abi.encodeWithSelector(HubGatewayV2.initialize.selector, _mailboxes, _chainIds)
    );
    vm.stopPrank();

    // Checking the newly configured activeMailboxes
    address _mainnetMailbox = address(hubGatewayProxy.activeMailbox(1));
    address _optimismMailbox = address(hubGatewayProxy.activeMailbox(10));
    assertEq(_mainnetMailbox, MAILBOX_2);
    assertEq(_optimismMailbox, MAILBOX_3);

    // Checking the state
    (address _currentMailbox, address _currentReceiver, address _currentInterchainSecurityModule) = _cacheState();
    assertEq(_prevMailbox, _currentMailbox);
    assertEq(_prevReceiver, _currentReceiver);
    assertEq(_prevInterchainSecurityModule, _currentInterchainSecurityModule);

    // Checking the configured chainGateways
    assertEq(hubGatewayProxy.chainGateways(1), GATEWAY_2);
    assertEq(hubGatewayProxy.chainGateways(10), GATEWAY_3);
  }

  ////////////////////////////////////// Public Functions //////////////////////////////////////
  // TODO:
  function test_hubGatewayUpgrade_sendMessageWithoutFee() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Mocking the message expected to send to the activeMailbox
    address activeMailbox = address(hubGatewayProxy.activeMailbox(1));
    bytes32 _expectedMessageId = keccak256(abi.encodePacked('Expected Message'));
    uint256 _expectedFee = 2e16;

    // Sending a message without the fee
    vm.prank(RECEIVER);
    (bytes32 messageId, uint256 feeSpent) = hubGatewayProxy.sendMessage(1, 'Hello, World!', 500_000);
    assertEq(messageId, _expectedMessageId);
    assertEq(feeSpent, _expectedFee);
  }

  // TODO:
  function test_hubGatewayUpgrade_sendMessageWithFee() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Sending the fee amount to the wallet
    vm.deal(address(hubGatewayProxy), 1001);

    // Mocking the message expected to send to the activeMailbox
    address activeMailbox = address(hubGatewayProxy.activeMailbox(1));
    bytes32 _expectedMessageId = keccak256(abi.encodePacked('Expected Message'));
    uint256 _expectedFee = 2e16;

    // Sending a message with the fee
    vm.prank(RECEIVER);
    (bytes32 messageId, uint256 feeSpent) = hubGatewayProxy.sendMessage(1, 'Hello, World!', 1000, 500_000);
    assertEq(messageId, _expectedMessageId);
    assertEq(feeSpent, _expectedFee);
  }

  // TODO:
  function test_hubGatewayUpgrade_handle() public {}

  function test_hubGatewayUpgrade_setChainGateway() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Setting the chain gateway
    bytes32 paddedAddress = bytes32(uint256(uint160(address(0x456))));
    vm.startPrank(RECEIVER);
    hubGatewayProxy.setChainGateway(1, paddedAddress);
    vm.stopPrank();

    // Checking the chainGateway
    assertEq(hubGatewayProxy.chainGateways(1), paddedAddress);
  }

  function test_hubGatewayUpgrade_removeChainGateway() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Setting the chain gateway
    bytes32 paddedAddress = bytes32(uint256(uint160(address(0x456))));
    vm.startPrank(RECEIVER);
    hubGatewayProxy.setChainGateway(1, paddedAddress);
    assertEq(hubGatewayProxy.chainGateways(1), paddedAddress);

    // Removing the chain gateway
    hubGatewayProxy.removeChainGateway(1);
    assertEq(hubGatewayProxy.chainGateways(1), bytes32(0));
  }

  function test_hubGatewayUpgrade_updateActiveMailbox() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Updating a mailbox address
    vm.startPrank(OWNER);
    hubGatewayProxy.updateActiveMailbox(1, address(0x99));
    vm.stopPrank();

    // Asserting the update
    assertEq(address(hubGatewayProxy.activeMailbox(1)), address(0x99));
  }

  function test_hubGatewayUpgrade_disableActiveMailbox() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Setting a mailbox to zero address
    vm.startPrank(OWNER);
    hubGatewayProxy.disableActiveMailbox(1);
    vm.stopPrank();

    // Asserting the disable
    assertEq(address(hubGatewayProxy.mailboxes(1)), address(0));
    vm.expectRevert(abi.encodeWithSelector(IHubGatewayV2.HubGateway_Mailbox_InvalidOriginDomain.selector, 1));
    address(hubGatewayProxy.activeMailbox(1));
  }

  function test_hubGatewayUpgrade_updateSecurityModule() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Updating the security module
    vm.startPrank(RECEIVER);
    hubGatewayProxy.updateSecurityModule(address(0x123));
    vm.stopPrank();

    // Asserting the update
    assertEq(address(hubGatewayProxy.interchainSecurityModule()), address(0x123));
  }

  // TODO:
  function test_hubGatewayUpgrade_quoteMessage() public {}

  ////////////////////////////// Internal Functions /////////////////////////
  function test_hubGatewayUpgrade_checkValidSender() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Setting the chainGateway
    bytes32 paddedAddress = bytes32(uint256(uint160(address(0x456))));
    vm.startPrank(RECEIVER);
    hubGatewayProxy.setChainGateway(1, paddedAddress);
    assertEq(hubGatewayProxy.chainGateways(1), paddedAddress);
    vm.stopPrank();

    // Checking valid sender - expecting no revert
    hubGatewayProxy.checkValidSender(1, paddedAddress);
  }

  function test_hubGatewayUpgrade_getGateway() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Setting the chainGateway
    bytes32 paddedAddress = bytes32(uint256(uint160(address(0x456))));
    vm.startPrank(RECEIVER);
    hubGatewayProxy.setChainGateway(1, paddedAddress);
    vm.stopPrank();
    assertEq(hubGatewayProxy.chainGateways(1), paddedAddress);

    // Checking the return from getGateway
    assertEq(hubGatewayProxy.getGateway(1), paddedAddress);
  }

  ////////////////////////////// Revert Cases //////////////////////////////
  function testRevert_hubGatewayUpgrade_initialize_InvalidInitialization() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to initialize again
    IMailbox[] memory _mailboxes = new IMailbox[](2);
    uint32[] memory _chainIds = new uint32[](2);
    _mailboxes[0] = IMailbox(address(0x123));
    _mailboxes[1] = IMailbox(address(0x456));
    _chainIds[0] = 1;
    _chainIds[1] = 2;

    // should revert on initialize
    vm.startPrank(OWNER);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    hubGatewayProxy.initialize(_mailboxes, _chainIds);
    vm.stopPrank();
  }

  function testRevert_hubGatewayUpgrade_initialize_Gateway_Initialize_MismatchedArrays() public {
    // Setting up and updating the gateway
    _setupTest();

    // Initializing with incorrect sized arrays
    IMailbox[] memory _mailboxes = new IMailbox[](2);
    uint32[] memory _chainIds = new uint32[](1);
    _mailboxes[0] = IMailbox(address(0x123));
    _mailboxes[1] = IMailbox(address(0x456));
    _chainIds[0] = 1;

    // should revert on initialize
    address _hubGatewayV2 = address(new TestHubGatewayV2());
    vm.startPrank(OWNER);
    vm.expectRevert(IHubGatewayV2.Gateway_Initialize_MismatchedArrays.selector);
    hubGatewayProxy.upgradeToAndCall(
      _hubGatewayV2, abi.encodeWithSelector(HubGatewayV2.initialize.selector, _mailboxes, _chainIds)
    );
    vm.stopPrank();
  }

  function testRevert_hubGatewayUpgrade_removeChainGateway_GatewayAlreadyRemoved() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // trying to remove a chain gateway that does not exist
    vm.startPrank(RECEIVER);
    vm.expectRevert(
      abi.encodeWithSelector(IHubGatewayV2.HubGateway_RemoveGateway_GatewayAlreadyRemoved.selector, 42_161)
    );
    hubGatewayProxy.removeChainGateway(42_161);
    vm.stopPrank();
  }

  function testRevert_hubGatewayUpgrade_checkValidSender_InvalidSender() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Checking invalidSender - expecting revert
    bytes32 invalidPaddedAddress = bytes32(uint256(uint160(address(0x789))));
    vm.expectRevert(IGatewayV2.Gateway_Handle_InvalidSender.selector);
    hubGatewayProxy.checkValidSender(1, invalidPaddedAddress);
  }

  function testRevert_hubGatewayUpgrade_getGateway_InvalidOriginDomain() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Checking invalidOriginDomain - expecting revert
    vm.expectRevert(IGatewayV2.Gateway_Handle_InvalidOriginDomain.selector);
    hubGatewayProxy.getGateway(42_161);
  }

  function testRevert_hubGatewayUpgrade_SendMessage_ZeroedMailbox() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // funding the gateway with enough ETH
    vm.deal(address(hubGatewayProxy), 1 ether);

    // setting the mailbox to zero
    vm.prank(OWNER);
    hubGatewayProxy.updateActiveMailbox(1, address(0));

    // Trying to send a message with a zeroed mailbox
    vm.startPrank(address(hubGatewayProxy.receiver()));
    vm.expectRevert(abi.encodeWithSelector(IHubGatewayV2.HubGateway_Mailbox_InvalidOriginDomain.selector, 1));
    hubGatewayProxy.sendMessage(1, 'test message', 0, 100_000);
    vm.stopPrank();
  }

  function testRevert_hubGatewayUpgrade_SendMessage_InsufficientBalance() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to send a message without enough balance
    vm.startPrank(address(hubGatewayProxy.receiver()));
    vm.expectRevert(IGatewayV2.Gateway_SendMessage_InsufficientBalance.selector);
    hubGatewayProxy.sendMessage(1, 'test message', 1000, 100_000);
    vm.stopPrank();
  }

  // TODO:
  function testRevert_hubGatewayUpgrade_SendMessage_UnsuccessfulRebate() public {}

  ////////////////////////////// Revert Cases - Address Input //////////////////////////////
  function testRevert_hubGatewayUpgrade_setChainGateway_InvalidAddress() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to set a chain gateway with an invalid address
    vm.startPrank(RECEIVER);
    vm.expectRevert(IGatewayV2.Gateway_ZeroAddress.selector);
    hubGatewayProxy.setChainGateway(1, bytes32(0));
    vm.stopPrank();
  }

  function testRevert_hubGatewayUpgrade_updateSecurityModule_InvalidAddress() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to update the security module with an invalid address
    vm.startPrank(RECEIVER);
    vm.expectRevert(IGatewayV2.Gateway_ZeroAddress.selector);
    hubGatewayProxy.updateSecurityModule(address(0));
    vm.stopPrank();
  }

  function testRevert_hubGatewayUpgrade_updateActiveMailbox_InvalidAddress() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to update the active mailbox with an invalid address
    vm.startPrank(OWNER);
    vm.expectRevert(IGatewayV2.Gateway_ZeroAddress.selector);
    hubGatewayProxy.updateActiveMailbox(1, address(0));
    vm.stopPrank();
  }

  ////////////////////////////// Revert Cases - Access Control //////////////////////////////
  function testRevert_hubGatewayUpgrade_initialize_NotOwner() public {
    // Setting up and updating the gateway
    _setupTest();

    // Trying to initialize again
    IMailbox[] memory _mailboxes = new IMailbox[](2);
    uint32[] memory _chainIds = new uint32[](2);
    _mailboxes[0] = IMailbox(address(0x123));
    _mailboxes[1] = IMailbox(address(0x456));
    _chainIds[0] = 1;
    _chainIds[1] = 2;

    // should revert on initialize
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this)));
    hubGatewayProxy.initialize(_mailboxes, _chainIds);
  }

  function testRevert_hubGatewayUpgrade_setChainGateway_UnauthorizedCaller() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to set a chain gateway as an unauthorized caller
    bytes32 paddedAddress = bytes32(uint256(uint160(address(0x456))));
    vm.expectRevert(IGatewayV2.Gateway_SendMessage_UnauthorizedCaller.selector);
    hubGatewayProxy.setChainGateway(1, paddedAddress);
  }

  function testRevert_hubGatewayUpgrade_removeChainGateway_UnauthorizedCaller() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to remove a chain gateway as an unauthorized caller
    vm.expectRevert(IGatewayV2.Gateway_SendMessage_UnauthorizedCaller.selector);
    hubGatewayProxy.removeChainGateway(1);
  }

  function testRevert_hubGatewayUpgrade_upgradeToAndCall_NotOwner() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to upgrade the gateway as a non-owner
    address newGateway = address(new TestHubGatewayV2());
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this)));
    hubGatewayProxy.upgradeToAndCall(newGateway, '');
  }

  function testRevert_hubGatewayUpgrade_sendMessageWithoutFee_UnauthorizedCaller() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to send a message without fee as an unauthorized caller
    vm.expectRevert(IGatewayV2.Gateway_SendMessage_UnauthorizedCaller.selector);
    hubGatewayProxy.sendMessage(1, 'test message', 0, 100_000);
  }

  function testRevert_hubGatewayUpgrade_sendMessageWithFee_UnauthorizedCaller() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to send a message with fee as an unauthorized caller
    vm.expectRevert(IGatewayV2.Gateway_SendMessage_UnauthorizedCaller.selector);
    hubGatewayProxy.sendMessage(1, 'test message', 1000, 100_000);
  }

  function testRevert_hubGatewayUpgrade_handle_NotCalledByMailbox() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to handle a message not called by the mailbox
    vm.expectRevert(IGatewayV2.Gateway_Handle_NotCalledByMailbox.selector);
    hubGatewayProxy.handle(1, INVALID_MAILBOX, 'test message');
  }

  function testRevert_hubGatewayUpgrade_updateActiveMailbox_NotOwner() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to update the active mailbox as a non-owner
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this)));
    hubGatewayProxy.updateActiveMailbox(1, address(0x123));
  }

  function testRevert_hubGatewayUpgrade_updateSecurityModule_UnauthorizedCaller() public {
    // Setting up and updating the gateway
    _setupTest();
    _upgradeGateway();

    // Trying to update the security module as an unauthorized caller
    vm.expectRevert(IGatewayV2.Gateway_SendMessage_UnauthorizedCaller.selector);
    hubGatewayProxy.updateSecurityModule(address(0x123));
  }

  ////////////////////////////////////// Helpers //////////////////////////////////////
  function _cacheState() internal view returns (address _mailbox, address _receiver, address _interchainSecurityModule) {
    _mailbox = address(hubGatewayProxy.mailbox());
    _receiver = address(hubGatewayProxy.receiver());
    _interchainSecurityModule = address(hubGatewayProxy.interchainSecurityModule());
  }

  function _setupTest() public {
    // Deploying HubGateway contract on Hub
    hubGatewayProxy = TestHubGatewayV2(payable(address(hubGateway)));

    // Configuring the gateways
    vm.startPrank(address(hubGatewayProxy.receiver()));
    hubGatewayProxy.setChainGateway(1, GATEWAY_2);
    hubGatewayProxy.setChainGateway(10, GATEWAY_3);
    assertEq(hubGatewayProxy.chainGateways(1), GATEWAY_2);
    assertEq(hubGatewayProxy.chainGateways(10), GATEWAY_3);

    // Asserting the config
    assertEq(address(hubGatewayProxy.mailbox()), MAILBOX);
    assertEq(address(hubGatewayProxy.receiver()), RECEIVER);
    assertEq(address(hubGatewayProxy.interchainSecurityModule()), SECURITY_MODULE);
    vm.stopPrank();
  }

  function _upgradeGateway() internal {
    // Configuring inputs for the mailbox update
    address[] memory _mailboxes = new address[](2);
    _mailboxes[0] = MAILBOX_2;
    _mailboxes[1] = MAILBOX_3;
    uint32[] memory _chainIds = new uint32[](2);
    _chainIds[0] = 1;
    _chainIds[1] = 10;

    // Upgrading the hubGateway
    address _hubGatewayV2 = address(new TestHubGatewayV2());
    vm.startPrank(OWNER);
    hubGatewayProxy.upgradeToAndCall(
      _hubGatewayV2, abi.encodeWithSelector(HubGatewayV2.initialize.selector, _mailboxes, _chainIds)
    );
    vm.stopPrank();

    // Asserting mailboxes
    assertEq(address(hubGatewayProxy.activeMailbox(1)), MAILBOX_2);
    assertEq(address(hubGatewayProxy.activeMailbox(10)), MAILBOX_3);

    // Asserting the gateways
    assertEq(hubGatewayProxy.chainGateways(1), GATEWAY_2);
    assertEq(hubGatewayProxy.chainGateways(10), GATEWAY_3);

    // Asserting same owner
    assertEq(hubGatewayProxy.owner(), OWNER);
  }
}
