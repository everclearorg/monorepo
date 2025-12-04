// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from 'forge-std/Test.sol';
import {console2} from 'forge-std/console2.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';

import {GatewayV3, IGatewayV3} from 'contracts/common/GatewayV3.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {HubGatewayV3, IHubGatewayV3} from 'contracts/hub/HubGatewayV3.sol';
import {ICCIP} from 'interfaces/common/ICCIP.sol';
import {IPolymer} from 'interfaces/common/IPolymer.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';

import {Mocker} from 'test/utils/mocks/Mocker.sol';

/**
 * @title HubGatewayV3Test
 * @notice Comprehensive unit tests for HubGatewayV3 contract
 */
contract HubGatewayV3Test is Test, Mocker {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  // Test contracts
  HubGatewayV3 public gateway;
  HubGatewayV3 public implementation;

  // Mock addresses
  address public owner = address(0x1234);
  address public receiver = address(0x2345);
  address public interchainSecurityModule = address(0x3456);
  address public polymerProver = address(0x4567);
  address public hyperlaneMailbox = address(0x5678);
  address public ccipMailbox = address(0x6789);
  address public polymerMailbox = address(0x789);

  // Chain IDs
  uint32 public constant ETHEREUM = 1;
  uint32 public constant ARBITRUM = 42_161;
  uint32 public constant OPTIMISM = 10;
  uint32 public constant BASE = 8453;
  uint32 public constant EVERCLEAR = 25_327;

  // Gateway addresses for spokes
  bytes32 public ethereumGateway = address(0x12345678919111212).toBytes32();
  bytes32 public arbitrumGateway = address(0x12345678919111213).toBytes32();
  bytes32 public optimismGateway = address(0x12345678919111214).toBytes32();
  bytes32 public baseGateway = address(0x12345678919111215).toBytes32();

  // CCIP chain selectors
  uint256 public constant ETHEREUM_CCIP_SELECTOR = 5_009_297_550_715_157_269;
  uint256 public constant ARBITRUM_CCIP_SELECTOR = 4_949_039_107_694_359_620;

  // Events
  event ChainGatewayAdded(uint32 _chainId, bytes32 _gateway);
  event ChainGatewayRemoved(uint32 _chainId, bytes32 _gateway);
  event ActiveMailboxUpdated(uint32 _origin, address _oldMailbox, address _newMailbox);
  event SecurityModuleUpdated(address _oldSecurityModule, address _newSecurityModule);
  event HyperlaneMailboxUpdated(address _oldMailbox, address _newMailbox);
  event CCIPMailboxUpdated(address _oldMailbox, address _newMailbox);
  event PolymerMailboxUpdated(address _oldMailbox, address _newMailbox);
  event PolymerProverUpdated(address _oldProver, address _newProver);
  event CCIPMappingsUpdated(uint256[] _everclearId, uint256[] _ccipChainId);
  event Dispatch(uint32 indexed destinationDomain, bytes32 indexed recipient, bytes message);

  function setUp() public {
    // Fork Everclear mainnet
    vm.createSelectFork(vm.envString('EVERCLEAR_RPC'));

    // Deploy implementation
    implementation = new HubGatewayV3();

    // Setup initial mailboxes array
    address[] memory mailboxes = new address[](4);
    mailboxes[0] = hyperlaneMailbox;
    mailboxes[1] = hyperlaneMailbox;
    mailboxes[2] = ccipMailbox;
    mailboxes[3] = polymerMailbox;

    uint32[] memory chainIds = new uint32[](4);
    chainIds[0] = ETHEREUM;
    chainIds[1] = ARBITRUM;
    chainIds[2] = OPTIMISM;
    chainIds[3] = BASE;

    // Initialize gateway
    bytes memory initData = abi.encodeWithSelector(
      HubGatewayV3.initialize.selector,
      owner,
      receiver,
      interchainSecurityModule,
      polymerProver,
      hyperlaneMailbox,
      ccipMailbox,
      polymerMailbox,
      mailboxes,
      chainIds
    );

    // Deploy UUPS proxy
    ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
    gateway = HubGatewayV3(payable(address(proxy)));

    // Set CCIP mappings
    uint256[] memory ecChainIds = new uint256[](2);
    ecChainIds[0] = ETHEREUM;
    ecChainIds[1] = ARBITRUM;

    uint256[] memory ccipChainIds = new uint256[](2);
    ccipChainIds[0] = ETHEREUM_CCIP_SELECTOR;
    ccipChainIds[1] = ARBITRUM_CCIP_SELECTOR;

    vm.prank(owner);
    gateway.setCCIPChainIdMappings(ecChainIds, ccipChainIds);

    // Set chain gateways
    vm.startPrank(receiver);
    gateway.setChainGateway(ETHEREUM, ethereumGateway);
    gateway.setChainGateway(ARBITRUM, arbitrumGateway);
    gateway.setChainGateway(OPTIMISM, optimismGateway);
    gateway.setChainGateway(BASE, baseGateway);
    vm.stopPrank();
  }

  // ============ Initialization Tests ============ //

  function test_hubGateway_initialize_success() public {
    // Deploy new instance for testing initialization
    HubGatewayV3 newImpl = new HubGatewayV3();

    address[] memory mailboxes = new address[](2);
    mailboxes[0] = hyperlaneMailbox;
    mailboxes[1] = ccipMailbox;

    uint32[] memory chainIds = new uint32[](2);
    chainIds[0] = ETHEREUM;
    chainIds[1] = ARBITRUM;

    bytes memory initData = abi.encodeWithSelector(
      HubGatewayV3.initialize.selector,
      owner,
      receiver,
      interchainSecurityModule,
      polymerProver,
      hyperlaneMailbox,
      ccipMailbox,
      polymerMailbox,
      mailboxes,
      chainIds
    );

    ERC1967Proxy newProxy = new ERC1967Proxy(address(newImpl), initData);
    HubGatewayV3 newGateway = HubGatewayV3(payable(address(newProxy)));

    // Verify initialization
    assertEq(newGateway.owner(), owner);
    assertEq(address(newGateway.receiver()), receiver);
    assertEq(address(newGateway.interchainSecurityModule()), interchainSecurityModule);
    assertEq(address(newGateway.polymerProver()), polymerProver);
    assertEq(newGateway.hyperlaneMailbox(), hyperlaneMailbox);
    assertEq(newGateway.ccipMailbox(), ccipMailbox);
    assertEq(newGateway.polymerMailbox(), polymerMailbox);
    assertEq(newGateway.mailboxes(ETHEREUM), hyperlaneMailbox);
    assertEq(newGateway.mailboxes(ARBITRUM), ccipMailbox);
  }

  function testRevert_hubGateway_initialize_arrayLengthMismatch() public {
    HubGatewayV3 newImpl = new HubGatewayV3();

    address[] memory mailboxes = new address[](2);
    mailboxes[0] = hyperlaneMailbox;
    mailboxes[1] = ccipMailbox;

    uint32[] memory chainIds = new uint32[](3); // Mismatched length
    chainIds[0] = ETHEREUM;
    chainIds[1] = ARBITRUM;
    chainIds[2] = OPTIMISM;

    bytes memory initData = abi.encodeWithSelector(
      HubGatewayV3.initialize.selector,
      owner,
      receiver,
      interchainSecurityModule,
      polymerProver,
      hyperlaneMailbox,
      ccipMailbox,
      polymerMailbox,
      mailboxes,
      chainIds
    );

    vm.expectRevert(IHubGatewayV3.Gateway_Initialize_MismatchedArrays.selector);
    new ERC1967Proxy(address(newImpl), initData);
  }

  // ============ State Check Tests ============ //

  function test_hubGateway_initializedState() public {
    assertEq(gateway.owner(), owner);
    assertEq(address(gateway.receiver()), receiver);
    assertEq(address(gateway.interchainSecurityModule()), interchainSecurityModule);
    assertEq(address(gateway.polymerProver()), polymerProver);
    assertEq(gateway.hyperlaneMailbox(), hyperlaneMailbox);
    assertEq(gateway.ccipMailbox(), ccipMailbox);
    assertEq(gateway.polymerMailbox(), polymerMailbox);

    // Check mailboxes
    assertEq(gateway.mailboxes(ETHEREUM), hyperlaneMailbox);
    assertEq(gateway.mailboxes(ARBITRUM), hyperlaneMailbox);
    assertEq(gateway.mailboxes(OPTIMISM), ccipMailbox);
    assertEq(gateway.mailboxes(BASE), polymerMailbox);

    // Check chain gateways
    assertEq(gateway.chainGateways(ETHEREUM), ethereumGateway);
    assertEq(gateway.chainGateways(ARBITRUM), arbitrumGateway);
    assertEq(gateway.chainGateways(OPTIMISM), optimismGateway);
    assertEq(gateway.chainGateways(BASE), baseGateway);

    // Check activeMailbox view function
    assertEq(gateway.activeMailbox(ETHEREUM), hyperlaneMailbox);
    assertEq(gateway.activeMailbox(ARBITRUM), hyperlaneMailbox);
  }

  // ============ Owner Functions Tests ============ //

  function test_hubGateway_updateHyperlaneMailbox_success() public {
    address newMailbox = address(0x999);

    vm.expectEmit(true, true, true, true);
    emit HyperlaneMailboxUpdated(hyperlaneMailbox, newMailbox);

    vm.prank(owner);
    gateway.updateHyperlaneMailbox(newMailbox);

    assertEq(gateway.hyperlaneMailbox(), newMailbox);
  }

  function testRevert_hubGateway_updateHyperlaneMailbox_notOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    gateway.updateHyperlaneMailbox(address(0x999));
  }

  function test_hubGateway_updateCCIPMailbox_success() public {
    address newMailbox = address(0x999);

    vm.expectEmit(true, true, true, true);
    emit CCIPMailboxUpdated(ccipMailbox, newMailbox);

    vm.prank(owner);
    gateway.updateCCIPMailbox(newMailbox);

    assertEq(gateway.ccipMailbox(), newMailbox);
  }

  function testRevert_hubGateway_updateCCIPMailbox_notOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    gateway.updateCCIPMailbox(address(0x999));
  }

  function test_hubGateway_updatePolymerMailbox_success() public {
    address newMailbox = address(0x999);

    vm.expectEmit(true, true, true, true);
    emit PolymerMailboxUpdated(polymerMailbox, newMailbox);

    vm.prank(owner);
    gateway.updatePolymerMailbox(newMailbox);

    assertEq(gateway.polymerMailbox(), newMailbox);
  }

  function testRevert_hubGateway_updatePolymerMailbox_notOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    gateway.updatePolymerMailbox(address(0x999));
  }

  function test_hubGateway_updatePolymerProver_success() public {
    address newProver = address(0x999);

    vm.expectEmit(true, true, true, true);
    emit PolymerProverUpdated(polymerProver, newProver);

    vm.prank(owner);
    gateway.updatePolymerProver(newProver);

    assertEq(address(gateway.polymerProver()), newProver);
  }

  function testRevert_hubGateway_updatePolymerProver_notOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    gateway.updatePolymerProver(address(0x999));
  }

  function test_hubGateway_setCCIPChainIdMappings_success() public {
    uint256[] memory ecChainIds = new uint256[](1);
    ecChainIds[0] = BASE;

    uint256[] memory ccipChainIds = new uint256[](1);
    ccipChainIds[0] = 123_456_789;

    vm.expectEmit(true, true, true, true);
    emit CCIPMappingsUpdated(ecChainIds, ccipChainIds);

    vm.prank(owner);
    gateway.setCCIPChainIdMappings(ecChainIds, ccipChainIds);

    assertEq(gateway.ecToCCIPChainId(BASE), 123_456_789);
    assertEq(gateway.ccipToECId(123_456_789), BASE);
  }

  function testRevert_hubGateway_setCCIPChainIdMappings_notOwner() public {
    uint256[] memory ecChainIds = new uint256[](1);
    ecChainIds[0] = BASE;

    uint256[] memory ccipChainIds = new uint256[](1);
    ccipChainIds[0] = 123_456_789;

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    gateway.setCCIPChainIdMappings(ecChainIds, ccipChainIds);
  }

  function testRevert_hubGateway_setCCIPChainIdMappings_arrayLengthMismatch() public {
    uint256[] memory ecChainIds = new uint256[](1);
    ecChainIds[0] = BASE;

    uint256[] memory ccipChainIds = new uint256[](2);
    ccipChainIds[0] = 123_456_789;
    ccipChainIds[1] = 987_654_321;

    vm.prank(owner);
    vm.expectRevert(IGatewayV3.GatewayV3_Domain_ArrayLengthMismatch.selector);
    gateway.setCCIPChainIdMappings(ecChainIds, ccipChainIds);
  }

  function test_hubGateway_updateActiveMailbox_success() public {
    address newMailbox = address(0x999);

    vm.expectEmit(true, true, true, true);
    emit ActiveMailboxUpdated(ETHEREUM, hyperlaneMailbox, newMailbox);

    vm.prank(owner);
    gateway.updateActiveMailbox(ETHEREUM, newMailbox);

    assertEq(gateway.mailboxes(ETHEREUM), newMailbox);
    assertEq(gateway.activeMailbox(ETHEREUM), newMailbox);
  }

  function testRevert_hubGateway_updateActiveMailbox_notOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    gateway.updateActiveMailbox(ETHEREUM, address(0x999));
  }

  function testRevert_hubGateway_updateActiveMailbox_zeroAddress() public {
    vm.prank(owner);
    vm.expectRevert(IGatewayV3.GatewayV3_ZeroAddress.selector);
    gateway.updateActiveMailbox(ETHEREUM, address(0));
  }

  function test_hubGateway_disableActiveMailbox_success() public {
    vm.expectEmit(true, true, true, true);
    emit ActiveMailboxUpdated(ETHEREUM, hyperlaneMailbox, address(0));

    vm.prank(owner);
    gateway.disableActiveMailbox(ETHEREUM);

    assertEq(gateway.mailboxes(ETHEREUM), address(0));
  }

  function testRevert_hubGateway_disableActiveMailbox_notOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    gateway.disableActiveMailbox(ETHEREUM);
  }

  // ============ Receiver Functions Tests ============ //

  function test_hubGateway_setChainGateway_success() public {
    uint32 newChainId = 999;
    bytes32 newGateway = address(0x888).toBytes32();

    vm.expectEmit(true, true, true, true);
    emit ChainGatewayAdded(newChainId, newGateway);

    vm.prank(receiver);
    gateway.setChainGateway(newChainId, newGateway);

    assertEq(gateway.chainGateways(newChainId), newGateway);
  }

  function testRevert_hubGateway_setChainGateway_notReceiver() public {
    vm.expectRevert(IGatewayV3.GatewayV3_SendMessage_UnauthorizedCaller.selector);
    gateway.setChainGateway(999, address(0x888).toBytes32());
  }

  function testRevert_hubGateway_setChainGateway_zeroAddress() public {
    vm.prank(receiver);
    vm.expectRevert(IGatewayV3.GatewayV3_ZeroAddress.selector);
    gateway.setChainGateway(999, bytes32(0));
  }

  function test_hubGateway_removeChainGateway_success() public {
    vm.expectEmit(true, true, true, true);
    emit ChainGatewayRemoved(ETHEREUM, ethereumGateway);

    vm.prank(receiver);
    gateway.removeChainGateway(ETHEREUM);

    assertEq(gateway.chainGateways(ETHEREUM), bytes32(0));
  }

  function testRevert_hubGateway_removeChainGateway_notReceiver() public {
    vm.expectRevert(IGatewayV3.GatewayV3_SendMessage_UnauthorizedCaller.selector);
    gateway.removeChainGateway(ETHEREUM);
  }

  function testRevert_hubGateway_removeChainGateway_alreadyRemoved() public {
    uint32 nonExistentChain = 999;

    vm.prank(receiver);
    vm.expectRevert(
      abi.encodeWithSelector(IHubGatewayV3.HubGateway_RemoveGateway_GatewayAlreadyRemoved.selector, nonExistentChain)
    );
    gateway.removeChainGateway(nonExistentChain);
  }

  function test_hubGateway_updateSecurityModule_success() public {
    address newSecurityModule = address(0x999);

    vm.expectEmit(true, true, true, true);
    emit SecurityModuleUpdated(interchainSecurityModule, newSecurityModule);

    vm.prank(receiver);
    gateway.updateSecurityModule(newSecurityModule);

    assertEq(address(gateway.interchainSecurityModule()), newSecurityModule);
  }

  function testRevert_hubGateway_updateSecurityModule_notReceiver() public {
    vm.expectRevert(IGatewayV3.GatewayV3_SendMessage_UnauthorizedCaller.selector);
    gateway.updateSecurityModule(address(0x999));
  }

  function testRevert_hubGateway_updateSecurityModule_zeroAddress() public {
    vm.prank(receiver);
    vm.expectRevert(IGatewayV3.GatewayV3_ZeroAddress.selector);
    gateway.updateSecurityModule(address(0));
  }

  // ============ Send Message Tests - Hyperlane ============ //

  function test_hubGateway_sendMessage_hyperlane_success() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;
    bytes memory metadata = StandardHookMetadata.formatMetadata(0, gasLimit, address(gateway), '');

    // Mock the mailbox dispatch
    bytes32 expectedMessageId = keccak256(abi.encodePacked('test_message_id'));
    vm.mockCall(
      hyperlaneMailbox,
      abi.encodeWithSignature('dispatch(uint32,bytes32,bytes,bytes)', ETHEREUM, ethereumGateway, message, metadata),
      abi.encode(expectedMessageId)
    );

    // Expect the mailbox to be called with correct parameters
    vm.expectCall(
      hyperlaneMailbox,
      abi.encodeWithSignature('dispatch(uint32,bytes32,bytes,bytes)', ETHEREUM, ethereumGateway, message, metadata)
    );

    vm.prank(receiver);
    (bytes32 messageId, uint256 feeSpent) = gateway.sendMessage(ETHEREUM, message, 0, gasLimit);

    assertEq(messageId, expectedMessageId);
    assertEq(feeSpent, 0);
  }

  function testRevert_hubGateway_sendMessage_hyperlane_notReceiver() public {
    bytes memory message = abi.encode('test message');

    vm.expectRevert(IGatewayV3.GatewayV3_SendMessage_UnauthorizedCaller.selector);
    gateway.sendMessage(ETHEREUM, message, 0, 100_000);
  }

  function testRevert_hubGateway_sendMessage_hyperlane_noGatewaySet() public {
    uint32 unknownChain = 999;
    bytes memory message = abi.encode('test message');

    vm.prank(receiver);
    vm.expectRevert(IHubGatewayV3.Gateway_Handle_InvalidOriginDomain.selector);
    gateway.sendMessage(unknownChain, message, 0, 100_000);
  }

  function testRevert_hubGateway_sendMessage_hyperlane_noMailboxSet() public {
    // Setup a chain with gateway but no mailbox
    uint32 newChain = 999;
    bytes32 newGateway = address(0x888).toBytes32();

    vm.prank(receiver);
    gateway.setChainGateway(newChain, newGateway);

    bytes memory message = abi.encode('test message');

    vm.prank(receiver);
    vm.expectRevert(abi.encodeWithSelector(IHubGatewayV3.HubGateway_Mailbox_InvalidOriginDomain.selector, newChain));
    gateway.sendMessage(newChain, message, 0, 100_000);
  }

  function testRevert_hubGateway_sendMessage_hyperlane_callFailure() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;

    // Mock mailbox to revert
    vm.mockCallRevert(
      hyperlaneMailbox,
      abi.encodeWithSignature('dispatch(uint32,bytes32,bytes,bytes)', ETHEREUM, ethereumGateway, message),
      abi.encode('Mailbox error')
    );

    vm.prank(receiver);
    vm.expectRevert();
    gateway.sendMessage(ETHEREUM, message, gasLimit);
  }

  function test_hubGateway_sendMessage_hyperlane_withFee_success() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;
    uint256 fee = 0.01 ether;
    bytes32 mockMessageId = keccak256('messageId');
    bytes memory metadata = StandardHookMetadata.formatMetadata(0, gasLimit, address(gateway), '');

    // Mock hyperlane mailbox
    MockHyperlaneMailbox mockMailbox = new MockHyperlaneMailbox();
    mockMailbox.setFee(fee);
    mockMailbox.setMessageId(mockMessageId);

    // Update gateway to use mock
    vm.prank(owner);
    gateway.updateHyperlaneMailbox(address(mockMailbox));
    vm.prank(owner);
    gateway.updateActiveMailbox(ETHEREUM, address(mockMailbox));

    // Fund gateway
    vm.deal(address(gateway), 1 ether);
    uint256 gatewayBalanceBefore = address(gateway).balance;

    // Expect the mailbox to be called
    vm.expectCall(
      address(mockMailbox),
      fee,
      abi.encodeWithSignature('dispatch(uint32,bytes32,bytes,bytes)', ETHEREUM, ethereumGateway, message, metadata)
    );

    vm.prank(receiver);
    (bytes32 returnedMessageId, uint256 feeSpent) = gateway.sendMessage(ETHEREUM, message, fee, gasLimit);

    assertEq(returnedMessageId, mockMessageId);
    assertEq(feeSpent, fee);
    assertEq(gatewayBalanceBefore - address(gateway).balance, fee);
  }

  function testRevert_hubGateway_sendMessage_hyperlane_insufficientBalance() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;
    uint256 requestedFee = 1 ether;

    // Gateway has no balance
    assertEq(address(gateway).balance, 0);

    vm.prank(receiver);
    vm.expectRevert(IGatewayV3.GatewayV3_SendMessage_InsufficientBalance.selector);
    gateway.sendMessage(ETHEREUM, message, requestedFee, gasLimit);
  }

  // ============ Send Message Tests - CCIP ============ //

  function test_hubGateway_sendMessage_ccip_success() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;
    bytes32 mockMessageId = keccak256('messageId');

    // Set CCIP mappings
    uint256[] memory ecChainIds = new uint256[](1);
    uint256[] memory ccipChainIds = new uint256[](1);
    ecChainIds[0] = OPTIMISM;
    ccipChainIds[0] = uint256(uint64(1_234_567_890));

    vm.prank(owner);
    gateway.setCCIPChainIdMappings(ecChainIds, ccipChainIds);

    // Mock CCIP mailbox
    MockCCIPMailbox mockCCIPMailbox = new MockCCIPMailbox();
    mockCCIPMailbox.setMessageId(mockMessageId);

    // Update gateway to use mock
    vm.prank(owner);
    gateway.updateCCIPMailbox(address(mockCCIPMailbox));
    vm.prank(owner);
    gateway.updateActiveMailbox(OPTIMISM, address(mockCCIPMailbox));

    // Construct expected CCIP message for expectCall
    bytes memory extraArgs = abi.encodeWithSelector(
      gateway.GENERIC_EXTRA_ARGS_V2_TAG(),
      ICCIP.GenericExtraArgsV2({gasLimit: gasLimit, allowOutOfOrderExecution: true})
    );

    ICCIP.EVM2AnyMessage memory evm2AnyMessage = ICCIP.EVM2AnyMessage({
      receiver: abi.encode(optimismGateway),
      data: message,
      tokenAmounts: new ICCIP.EVMTokenAmount[](0),
      feeToken: address(0),
      extraArgs: extraArgs
    });

    // Expect the CCIP mailbox to be called
    vm.expectCall(
      address(mockCCIPMailbox),
      0,
      abi.encodeWithSignature(
        'ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))', uint64(1_234_567_890), evm2AnyMessage
      )
    );

    vm.prank(receiver);
    (bytes32 returnedMessageId,) = gateway.sendMessage(OPTIMISM, message, gasLimit);

    assertEq(returnedMessageId, mockMessageId);
  }

  function testRevert_hubGateway_sendMessage_ccip_domainNotFound() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;
    uint32 unmappedChain = 999;

    // Set gateway and mailbox but no CCIP mapping
    vm.prank(receiver);
    gateway.setChainGateway(unmappedChain, ethereumGateway);

    vm.prank(owner);
    gateway.updateActiveMailbox(unmappedChain, ccipMailbox);

    vm.prank(receiver);
    vm.expectRevert(IGatewayV3.GatewayV3_Domain_NotFound.selector);
    gateway.sendMessage(unmappedChain, message, gasLimit);
  }

  function testRevert_hubGateway_sendMessage_ccip_callFailure() public {
    // Add CCIP mapping for OPTIMISM
    uint256[] memory ecChainIds = new uint256[](1);
    ecChainIds[0] = OPTIMISM;

    uint256[] memory ccipChainIds = new uint256[](1);
    ccipChainIds[0] = 2_664_363_617_261_496_610; // Optimism CCIP selector

    vm.prank(owner);
    gateway.setCCIPChainIdMappings(ecChainIds, ccipChainIds);

    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;

    // Mock CCIP mailbox to revert
    MockCCIPMailbox mockCCIPMailbox = new MockCCIPMailbox();
    mockCCIPMailbox.setShouldRevert(true);

    vm.prank(owner);
    gateway.updateCCIPMailbox(address(mockCCIPMailbox));
    vm.prank(owner);
    gateway.updateActiveMailbox(OPTIMISM, address(mockCCIPMailbox));

    vm.prank(receiver);
    vm.expectRevert(MockCCIPMailbox.CCIPSendFailed.selector);
    gateway.sendMessage(OPTIMISM, message, gasLimit);
  }

  // ============ Send Message Tests - Polymer ============ //

  function test_hubGateway_sendMessage_polymerEmit_success() public {
    // Set mailbox to POLYMER_EMIT_MAILBOX (address(0x1)) to trigger emit path
    vm.prank(owner);
    gateway.updateActiveMailbox(BASE, address(0x1));

    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;

    vm.expectEmit(true, true, false, true);
    emit Dispatch(BASE, baseGateway, message);

    vm.prank(receiver);
    gateway.sendMessage(BASE, message, 0, gasLimit);
  }

  function test_hubGateway_sendMessage_polymerMailbox_nonEmit_success() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;
    bytes32 mockMessageId = keccak256('polymerMessageId');
    bytes memory metadata = StandardHookMetadata.formatMetadata(0, gasLimit, address(gateway), '');

    // Create a mock polymer mailbox (not the emit sentinel)
    MockHyperlaneMailbox mockPolymerMailbox = new MockHyperlaneMailbox();
    mockPolymerMailbox.setFee(0);
    mockPolymerMailbox.setMessageId(mockMessageId);

    // Update gateway to use the actual polymer mailbox (not emit sentinel)
    vm.prank(owner);
    gateway.updatePolymerMailbox(address(mockPolymerMailbox));
    vm.prank(owner);
    gateway.updateActiveMailbox(BASE, address(mockPolymerMailbox));

    // Expect the polymer mailbox to be called (uses Polymer ID = 1)
    vm.expectCall(
      address(mockPolymerMailbox),
      0,
      abi.encodeWithSignature('dispatch(uint32,bytes32,bytes,bytes)', BASE, baseGateway, message, metadata)
    );

    vm.prank(receiver);
    (bytes32 returnedMessageId,) = gateway.sendMessage(BASE, message, gasLimit);

    assertEq(returnedMessageId, mockMessageId);
  }

  // ============ Receive Message Tests - Hyperlane ============ //

  function test_hubGateway_handle_hyperlane_success() public {
    bytes memory message = abi.encode('incoming message');
    uint32 origin = ETHEREUM;

    // Mock the receiver call
    vm.mockCall(receiver, abi.encodeWithSignature('receiveMessage(bytes)', message), abi.encode(0));

    vm.prank(hyperlaneMailbox);
    gateway.handle(origin, ethereumGateway, message);
  }

  function testRevert_hubGateway_handle_hyperlane_notMailbox() public {
    bytes memory message = abi.encode('incoming message');

    vm.expectRevert(IGatewayV3.GatewayV3_Handle_NotCalledByMailbox.selector);
    gateway.handle(ETHEREUM, ethereumGateway, message);
  }

  function testRevert_hubGateway_handle_hyperlane_invalidSender() public {
    bytes memory message = abi.encode('incoming message');
    bytes32 wrongGateway = address(0x999).toBytes32();

    vm.prank(hyperlaneMailbox);
    vm.expectRevert(IHubGatewayV3.Gateway_Handle_InvalidSender.selector);
    gateway.handle(ETHEREUM, wrongGateway, message);
  }

  function test_hubGateway_handle_polymerMailbox_success() public {
    bytes memory message = abi.encode('incoming polymer message via handle');
    uint32 origin = BASE;

    // Mock the receiver call
    vm.mockCall(receiver, abi.encodeWithSignature('receiveMessage(bytes)', message), abi.encode(0));

    // handle can be called by polymerMailbox directly
    vm.prank(polymerMailbox);
    gateway.handle(origin, baseGateway, message);
  }

  function testRevert_hubGateway_handle_polymerMailbox_invalidSender() public {
    bytes memory message = abi.encode('incoming polymer message');
    bytes32 wrongGateway = address(0x999).toBytes32();

    vm.prank(polymerMailbox);
    vm.expectRevert(IHubGatewayV3.Gateway_Handle_InvalidSender.selector);
    gateway.handle(BASE, wrongGateway, message);
  }

  // ============ Receive Message Tests - CCIP ============ //

  function test_hubGateway_ccipReceive_success() public {
    bytes memory message = abi.encode('incoming ccip message');

    ICCIP.Any2EVMMessage memory ccipMessage = ICCIP.Any2EVMMessage({
      messageId: keccak256('ccip_msg_id'),
      sourceChainSelector: uint64(ETHEREUM_CCIP_SELECTOR),
      sender: abi.encode(ethereumGateway),
      data: message,
      destTokenAmounts: new ICCIP.EVMTokenAmount[](0)
    });

    // Mock the receiver call
    vm.mockCall(receiver, abi.encodeWithSignature('receiveMessage(bytes)', message), abi.encode(0));

    vm.prank(ccipMailbox);
    gateway.ccipReceive(ccipMessage);
  }

  function testRevert_hubGateway_ccipReceive_notMailbox() public {
    ICCIP.Any2EVMMessage memory ccipMessage = ICCIP.Any2EVMMessage({
      messageId: keccak256('ccip_msg_id'),
      sourceChainSelector: uint64(ETHEREUM_CCIP_SELECTOR),
      sender: abi.encode(ethereumGateway),
      data: abi.encode('test'),
      destTokenAmounts: new ICCIP.EVMTokenAmount[](0)
    });

    vm.expectRevert(IGatewayV3.GatewayV3_Handle_NotCalledByMailbox.selector);
    gateway.ccipReceive(ccipMessage);
  }

  function testRevert_hubGateway_ccipReceive_invalidSender() public {
    bytes32 wrongGateway = address(0x999).toBytes32();

    ICCIP.Any2EVMMessage memory ccipMessage = ICCIP.Any2EVMMessage({
      messageId: keccak256('ccip_msg_id'),
      sourceChainSelector: uint64(ETHEREUM_CCIP_SELECTOR),
      sender: abi.encode(wrongGateway),
      data: abi.encode('test'),
      destTokenAmounts: new ICCIP.EVMTokenAmount[](0)
    });

    vm.prank(ccipMailbox);
    vm.expectRevert(IHubGatewayV3.Gateway_Handle_InvalidSender.selector);
    gateway.ccipReceive(ccipMessage);
  }

  function testRevert_hubGateway_ccipReceive_domainNotFoundFromCCIP() public {
    // Test conversion from CCIP chain ID to EC ID when CCIP selector is unmapped
    uint256 unmappedCCIPSelector = 999_999_999;

    ICCIP.Any2EVMMessage memory ccipMessage = ICCIP.Any2EVMMessage({
      messageId: keccak256('ccip_msg_id'),
      sourceChainSelector: uint64(unmappedCCIPSelector),
      sender: abi.encode(ethereumGateway),
      data: abi.encode('test'),
      destTokenAmounts: new ICCIP.EVMTokenAmount[](0)
    });

    vm.prank(ccipMailbox);
    vm.expectRevert(IGatewayV3.GatewayV3_Domain_NotFound.selector);
    gateway.ccipReceive(ccipMessage);
  }

  // ============ Receive Message Tests - Polymer ============ //

  function test_hubGateway_polymerReceive_success() public {
    bytes memory message = abi.encode('incoming polymer message');
    uint32 originChain = ETHEREUM;

    // Construct mock proof data - destination is EVERCLEAR (current chain)
    bytes memory topics = new bytes(96);
    bytes32 eventSelector = keccak256('Dispatch(uint32,bytes32,bytes)');
    bytes32 gatewayAddr = address(gateway).toBytes32();
    assembly {
      mstore(add(topics, 32), eventSelector)
      mstore(add(topics, 64), EVERCLEAR) // destination domain
      mstore(add(topics, 96), gatewayAddr) // recipient (this gateway)
    }

    bytes memory data = abi.encode(message);
    bytes memory proof = abi.encode('mock_proof');

    // Mock polymer prover validation
    vm.mockCall(
      polymerProver,
      abi.encodeWithSignature('validateEvent(bytes)'),
      abi.encode(originChain, ethereumGateway.toAddress(), topics, data)
    );

    // Mock the receiver call
    vm.mockCall(receiver, abi.encodeWithSignature('receiveMessage(bytes)', message), abi.encode(0));

    gateway.polymerReceive(proof);
  }

  function testRevert_hubGateway_polymerReceive_invalidTopicsLength() public {
    bytes memory message = abi.encode('test');
    bytes memory invalidTopics = new bytes(64); // Should be 96
    bytes memory data = abi.encode(message);
    bytes memory proof = abi.encode('mock_proof');

    vm.mockCall(
      polymerProver,
      abi.encodeWithSignature('validateEvent(bytes)'),
      abi.encode(uint32(ETHEREUM), ethereumGateway.toAddress(), invalidTopics, data)
    );

    vm.expectRevert(IGatewayV3.GatewayV3_Handle_InvalidTopicsLength.selector);
    gateway.polymerReceive(proof);
  }

  function testRevert_hubGateway_polymerReceive_invalidEventSelector() public {
    bytes memory message = abi.encode('test');
    bytes memory topics = new bytes(96);
    bytes32 wrongSelector = keccak256('WrongEvent()');

    assembly {
      mstore(add(topics, 32), wrongSelector)
      mstore(add(topics, 64), 1) // origin
      mstore(add(topics, 96), address())
    }

    bytes memory data = abi.encode(message);
    bytes memory proof = abi.encode('mock_proof');

    vm.mockCall(
      polymerProver,
      abi.encodeWithSignature('validateEvent(bytes)'),
      abi.encode(uint32(ETHEREUM), ethereumGateway.toAddress(), topics, data)
    );

    vm.expectRevert(IGatewayV3.GatewayV3_Handle_InvalidEventSelector.selector);
    gateway.polymerReceive(proof);
  }

  function testRevert_hubGateway_polymerReceive_invalidDestinationDomain() public {
    bytes memory message = abi.encode('test');
    bytes memory topics = new bytes(96);
    bytes32 eventSelector = keccak256('Dispatch(uint32,bytes32,bytes)');
    uint32 wrongDestination = 999;

    assembly {
      mstore(add(topics, 32), eventSelector)
      mstore(add(topics, 64), wrongDestination)
      mstore(add(topics, 96), address())
    }

    bytes memory data = abi.encode(message);
    bytes memory proof = abi.encode('mock_proof');

    vm.mockCall(
      polymerProver,
      abi.encodeWithSignature('validateEvent(bytes)'),
      abi.encode(uint32(ETHEREUM), ethereumGateway.toAddress(), topics, data)
    );

    vm.expectRevert(IGatewayV3.GatewayV3_Handle_InvalidDestinationDomain.selector);
    gateway.polymerReceive(proof);
  }

  function testRevert_hubGateway_polymerReceive_invalidRecipient() public {
    bytes memory message = abi.encode('test');
    bytes memory topics = new bytes(96);
    bytes32 eventSelector = keccak256('Dispatch(uint32,bytes32,bytes)');
    bytes32 wrongRecipient = address(0x999).toBytes32();

    assembly {
      mstore(add(topics, 32), eventSelector)
      mstore(add(topics, 64), EVERCLEAR)
      mstore(add(topics, 96), wrongRecipient)
    }

    bytes memory data = abi.encode(message);
    bytes memory proof = abi.encode('mock_proof');

    vm.mockCall(
      polymerProver,
      abi.encodeWithSignature('validateEvent(bytes)'),
      abi.encode(uint32(ETHEREUM), ethereumGateway.toAddress(), topics, data)
    );

    vm.expectRevert(IGatewayV3.GatewayV3_Handle_InvalidRecipient.selector);
    gateway.polymerReceive(proof);
  }

  function testRevert_hubGateway_polymerReceive_proofAlreadyUsed() public {
    bytes memory message = abi.encode('test');
    uint32 originChain = ETHEREUM;

    bytes memory topics = new bytes(96);
    bytes32 eventSelector = keccak256('Dispatch(uint32,bytes32,bytes)');
    bytes32 gatewayAddr = address(gateway).toBytes32();
    assembly {
      mstore(add(topics, 32), eventSelector)
      mstore(add(topics, 64), EVERCLEAR)
      mstore(add(topics, 96), gatewayAddr)
    }

    bytes memory data = abi.encode(message);
    bytes memory proof = abi.encode('mock_proof');

    address sourceContract = ethereumGateway.toAddress();

    vm.mockCall(
      polymerProver,
      abi.encodeWithSignature('validateEvent(bytes)'),
      abi.encode(originChain, sourceContract, topics, data)
    );

    vm.mockCall(receiver, abi.encodeWithSignature('receiveMessage(bytes)', message), abi.encode(0));

    // First call should succeed
    gateway.polymerReceive(proof);

    // Mock again for second call
    vm.mockCall(
      polymerProver,
      abi.encodeWithSignature('validateEvent(bytes)'),
      abi.encode(originChain, sourceContract, topics, data)
    );

    // Second call with same proof should revert
    vm.expectRevert(IGatewayV3.GatewayV3_Handle_ProofAlreadyUsed.selector);
    gateway.polymerReceive(proof);
  }

  // ============ Quote Message Test ============ //

  function test_hubGateway_quoteMessage_success() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;
    uint256 expectedFee = 0.01 ether;

    bytes memory metadata = StandardHookMetadata.formatMetadata(0, gasLimit, address(gateway), '');

    vm.mockCall(
      hyperlaneMailbox,
      abi.encodeWithSignature(
        'quoteDispatch(uint32,bytes32,bytes,bytes)', ETHEREUM, ethereumGateway, message, metadata
      ),
      abi.encode(expectedFee)
    );

    uint256 fee = gateway.quoteMessage(ETHEREUM, message, gasLimit);
    assertEq(fee, expectedFee);
  }

  // Note: quoteMessage currently always uses Hyperlane mailbox regardless of activeMailbox
  // This is by design as it's hardcoded in the contract. The following tests document this behavior.
  function test_hubGateway_quoteMessage_withCCIPMailbox() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;
    uint256 expectedFee = 0.01 ether;

    // Set OPTIMISM to use CCIP mailbox
    vm.prank(owner);
    gateway.updateActiveMailbox(OPTIMISM, ccipMailbox);

    bytes memory metadata = StandardHookMetadata.formatMetadata(0, gasLimit, address(gateway), '');

    // quoteMessage still calls Hyperlane mailbox (hardcoded behavior)
    vm.mockCall(
      hyperlaneMailbox,
      abi.encodeWithSignature(
        'quoteDispatch(uint32,bytes32,bytes,bytes)', OPTIMISM, optimismGateway, message, metadata
      ),
      abi.encode(expectedFee)
    );

    uint256 fee = gateway.quoteMessage(OPTIMISM, message, gasLimit);
    assertEq(fee, expectedFee);
  }

  function test_hubGateway_quoteMessage_withPolymerMailbox() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;
    uint256 expectedFee = 0.01 ether;

    // Set BASE to use Polymer mailbox
    vm.prank(owner);
    gateway.updateActiveMailbox(BASE, polymerMailbox);

    bytes memory metadata = StandardHookMetadata.formatMetadata(0, gasLimit, address(gateway), '');

    // quoteMessage still calls Hyperlane mailbox (hardcoded behavior)
    vm.mockCall(
      hyperlaneMailbox,
      abi.encodeWithSignature('quoteDispatch(uint32,bytes32,bytes,bytes)', BASE, baseGateway, message, metadata),
      abi.encode(expectedFee)
    );

    uint256 fee = gateway.quoteMessage(BASE, message, gasLimit);
    assertEq(fee, expectedFee);
  }

  // ============ Mailbox Selection and Unsupported Paths ============

  function testRevert_hubGateway_sendMessage_unsupportedMailbox() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;

    // Set a mailbox that is not hyperlane, ccip, polymer, or the emit sentinel
    address unsupportedMailbox = address(0x12345);
    vm.prank(owner);
    gateway.updateActiveMailbox(ETHEREUM, unsupportedMailbox);

    vm.prank(receiver);
    vm.expectRevert(IGatewayV3.GatewayV3_SendMessage_UnsupportedMailbox.selector);
    gateway.sendMessage(ETHEREUM, message, gasLimit);
  }

  // ============ Integration Tests - Real Mailboxes ============

  function test_hubGateway_sendMessage_hyperlane_integration() public {
    // Fork Ethereum mainnet
    vm.createSelectFork(vm.envString('MAINNET_RPC'));

    // Real Hyperlane mailbox on Ethereum
    address realHyperlaneMailbox = 0xc005dc82818d67AF737725bD4bf75435d065D239;

    // Deploy fresh gateway for integration test
    HubGatewayV3 newImpl = new HubGatewayV3();

    address[] memory mailboxes = new address[](1);
    mailboxes[0] = realHyperlaneMailbox;

    uint32[] memory chainIds = new uint32[](1);
    chainIds[0] = ARBITRUM;

    bytes memory initData = abi.encodeWithSelector(
      HubGatewayV3.initialize.selector,
      owner,
      receiver,
      interchainSecurityModule,
      polymerProver,
      realHyperlaneMailbox,
      ccipMailbox,
      polymerMailbox,
      mailboxes,
      chainIds
    );

    ERC1967Proxy newProxy = new ERC1967Proxy(address(newImpl), initData);
    HubGatewayV3 integrationGateway = HubGatewayV3(payable(address(newProxy)));

    // Set chain gateway
    vm.prank(receiver);
    integrationGateway.setChainGateway(ARBITRUM, arbitrumGateway);

    bytes memory message = abi.encode('integration test message');
    uint256 gasLimit = 100_000;

    // Quote the message first to get required fee
    uint256 quotedFee = integrationGateway.quoteMessage(ARBITRUM, message, gasLimit);

    // Fund the gateway
    vm.deal(address(integrationGateway), quotedFee + 1 ether);

    // Send message through real Hyperlane mailbox
    vm.prank(receiver);
    (bytes32 messageId, uint256 feeSpent) = integrationGateway.sendMessage(ARBITRUM, message, quotedFee, gasLimit);

    // Verify message was sent (messageId should be non-zero)
    assertTrue(messageId != bytes32(0), 'Message ID should be non-zero');
    assertGt(feeSpent, 0, 'Fee should be spent');
    assertLe(feeSpent, quotedFee, 'Fee spent should not exceed quoted fee');
  }

  function test_hubGateway_sendMessage_ccip_integration() public {
    // Fork Ethereum mainnet
    vm.createSelectFork(vm.envString('MAINNET_RPC'));

    // Real CCIP mailbox on Ethereum
    address realCCIPMailbox = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;

    // Deploy fresh gateway for integration test
    HubGatewayV3 newImpl = new HubGatewayV3();

    address[] memory mailboxes = new address[](1);
    mailboxes[0] = realCCIPMailbox;

    uint32[] memory chainIds = new uint32[](1);
    chainIds[0] = ARBITRUM;

    bytes memory initData = abi.encodeWithSelector(
      HubGatewayV3.initialize.selector,
      owner,
      receiver,
      interchainSecurityModule,
      polymerProver,
      hyperlaneMailbox,
      realCCIPMailbox,
      polymerMailbox,
      mailboxes,
      chainIds
    );

    ERC1967Proxy newProxy = new ERC1967Proxy(address(newImpl), initData);
    HubGatewayV3 integrationGateway = HubGatewayV3(payable(address(newProxy)));

    // Set CCIP chain ID mapping (Arbitrum)
    uint256[] memory ecChainIds = new uint256[](1);
    ecChainIds[0] = ARBITRUM;

    uint256[] memory ccipChainIds = new uint256[](1);
    ccipChainIds[0] = ARBITRUM_CCIP_SELECTOR;

    vm.prank(owner);
    integrationGateway.setCCIPChainIdMappings(ecChainIds, ccipChainIds);

    // Set chain gateway
    vm.prank(receiver);
    integrationGateway.setChainGateway(ARBITRUM, arbitrumGateway);

    bytes memory message = abi.encode('integration test message');
    uint256 gasLimit = 200_000; // CCIP typically needs more gas

    // Fund the gateway generously for CCIP fees
    vm.deal(address(integrationGateway), 10 ether);

    // Send message through real CCIP mailbox
    vm.prank(receiver);
    (bytes32 messageId, uint256 feeSpent) = integrationGateway.sendMessage(ARBITRUM, message, 1 ether, gasLimit);

    // Verify message was sent (messageId should be non-zero)
    assertTrue(messageId != bytes32(0), 'Message ID should be non-zero');
    assertGt(feeSpent, 0, 'Fee should be spent');
  }

  function test_hubGateway_sendMessage_polymer_integration() public {
    // Fork Ethereum mainnet
    vm.createSelectFork(vm.envString('MAINNET_RPC'));

    // Real Polymer mailbox on Ethereum
    address realPolymerMailbox = 0xE4412AEa45a7121042c33b65291d11F71F4d0363;

    // Deploy fresh gateway for integration test
    HubGatewayV3 newImpl = new HubGatewayV3();

    address[] memory mailboxes = new address[](1);
    mailboxes[0] = realPolymerMailbox;

    uint32[] memory chainIds = new uint32[](1);
    chainIds[0] = OPTIMISM;

    bytes memory initData = abi.encodeWithSelector(
      HubGatewayV3.initialize.selector,
      owner,
      receiver,
      interchainSecurityModule,
      polymerProver,
      hyperlaneMailbox,
      ccipMailbox,
      realPolymerMailbox,
      mailboxes,
      chainIds
    );

    ERC1967Proxy newProxy = new ERC1967Proxy(address(newImpl), initData);
    HubGatewayV3 integrationGateway = HubGatewayV3(payable(address(newProxy)));

    // Set chain gateway
    vm.prank(receiver);
    integrationGateway.setChainGateway(OPTIMISM, optimismGateway);

    bytes memory message = abi.encode('integration test message');
    uint256 gasLimit = 100_000;

    // Fund the gateway
    vm.deal(address(integrationGateway), 1 ether);

    // Send message through real Polymer mailbox
    vm.prank(receiver);
    (bytes32 messageId,) = integrationGateway.sendMessage(OPTIMISM, message, 0.1 ether, gasLimit);

    // Verify message was sent (messageId should be non-zero)
    assertTrue(messageId != bytes32(0), 'Message ID should be non-zero');
    // Note: Polymer mailbox may have different fee structure, so we don't assert on feeSpent
  }

  // ============ Initialization and Upgrade Authorization Tests ============

  function testRevert_hubGateway_initialize_doubleInitialize() public {
    // Try to initialize already initialized proxy
    address[] memory mailboxes = new address[](1);
    mailboxes[0] = hyperlaneMailbox;
    uint32[] memory chainIds = new uint32[](1);
    chainIds[0] = ETHEREUM;

    vm.expectRevert();
    gateway.initialize(
      owner,
      receiver,
      interchainSecurityModule,
      polymerProver,
      hyperlaneMailbox,
      ccipMailbox,
      polymerMailbox,
      mailboxes,
      chainIds
    );
  }

  function testRevert_hubGateway_authorizeUpgrade_nonOwner() public {
    // The upgradeToAndCall test already covers owner authorization
    // This test explicitly verifies non-owner cannot upgrade
    HubGatewayV3 newImplementation = new HubGatewayV3();

    vm.prank(address(0x999)); // Non-owner
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x999)));
    gateway.upgradeToAndCall(address(newImplementation), '');
  }

  function testRevert_hubGateway_authorizeUpgrade_receiverCannotUpgrade() public {
    HubGatewayV3 newImplementation = new HubGatewayV3();

    vm.prank(receiver); // Receiver has different permissions, not upgrade
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, receiver));
    gateway.upgradeToAndCall(address(newImplementation), '');
  }

  // ============ Additional Coverage Tests ============

  function testRevert_hubGateway_handle_missingChainGateway() public {
    bytes memory message = abi.encode('incoming message');
    uint32 unknownChain = 999;
    bytes32 unknownGateway = address(0x888).toBytes32();

    // Try to handle from a chain with no gateway configured
    vm.prank(hyperlaneMailbox);
    vm.expectRevert(IHubGatewayV3.Gateway_Handle_InvalidSender.selector);
    gateway.handle(unknownChain, unknownGateway, message);
  }

  function testRevert_hubGateway_ccipReceive_missingChainGateway() public {
    // Set up CCIP message from chain with no configured gateway
    uint32 unknownChain = 999;
    bytes32 unknownGateway = address(0x888).toBytes32();

    // Add CCIP mapping but no chain gateway
    uint256[] memory ecChainIds = new uint256[](1);
    ecChainIds[0] = unknownChain;

    uint256[] memory ccipChainIds = new uint256[](1);
    ccipChainIds[0] = 888_888_888;

    vm.prank(owner);
    gateway.setCCIPChainIdMappings(ecChainIds, ccipChainIds);

    ICCIP.Any2EVMMessage memory ccipMessage = ICCIP.Any2EVMMessage({
      messageId: keccak256('ccip_msg_id'),
      sourceChainSelector: uint64(888_888_888),
      sender: abi.encode(unknownGateway),
      data: abi.encode('test'),
      destTokenAmounts: new ICCIP.EVMTokenAmount[](0)
    });

    vm.prank(ccipMailbox);
    vm.expectRevert(IHubGatewayV3.Gateway_Handle_InvalidSender.selector);
    gateway.ccipReceive(ccipMessage);
  }

  function testRevert_hubGateway_sendMessage_polymerMailbox_callFailure() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;

    // Create a mock polymer mailbox that will revert
    MockRevertingMailbox mockPolymerMailbox = new MockRevertingMailbox();

    // Update gateway to use the reverting polymer mailbox
    vm.prank(owner);
    gateway.updatePolymerMailbox(address(mockPolymerMailbox));
    vm.prank(owner);
    gateway.updateActiveMailbox(BASE, address(mockPolymerMailbox));

    vm.prank(receiver);
    vm.expectRevert(MockRevertingMailbox.MailboxFailed.selector);
    gateway.sendMessage(BASE, message, gasLimit);
  }

  function testRevert_hubGateway_ccipReceive_fromUnmappedSelector() public {
    // Test receiving from a CCIP selector that has no EC mapping
    uint256 unmappedCCIPSelector = 111_111_111;

    ICCIP.Any2EVMMessage memory ccipMessage = ICCIP.Any2EVMMessage({
      messageId: keccak256('ccip_msg_id'),
      sourceChainSelector: uint64(unmappedCCIPSelector),
      sender: abi.encode(ethereumGateway),
      data: abi.encode('test'),
      destTokenAmounts: new ICCIP.EVMTokenAmount[](0)
    });

    vm.prank(ccipMailbox);
    vm.expectRevert(IGatewayV3.GatewayV3_Domain_NotFound.selector);
    gateway.ccipReceive(ccipMessage);
  }

  function testRevert_hubGateway_sendMessage_toUnmappedCCIPChain() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;
    uint32 unmappedChain = 777;

    // Set gateway and CCIP mailbox but no CCIP selector mapping
    vm.prank(receiver);
    gateway.setChainGateway(unmappedChain, ethereumGateway);

    vm.prank(owner);
    gateway.updateActiveMailbox(unmappedChain, ccipMailbox);

    vm.prank(receiver);
    vm.expectRevert(IGatewayV3.GatewayV3_Domain_NotFound.selector);
    gateway.sendMessage(unmappedChain, message, gasLimit);
  }

  function testRevert_hubGateway_activeMailbox_unconfiguredDomain() public {
    uint32 unconfiguredChain = 888;

    vm.expectRevert(
      abi.encodeWithSelector(IHubGatewayV3.HubGateway_Mailbox_InvalidOriginDomain.selector, unconfiguredChain)
    );
    gateway.activeMailbox(unconfiguredChain);
  }

  function testRevert_hubGateway_sendMessage_afterDisablingMailbox() public {
    bytes memory message = abi.encode('test message');
    uint256 gasLimit = 100_000;

    // Disable the mailbox for ETHEREUM
    vm.prank(owner);
    gateway.disableActiveMailbox(ETHEREUM);

    // Try to send message
    vm.prank(receiver);
    vm.expectRevert(abi.encodeWithSelector(IHubGatewayV3.HubGateway_Mailbox_InvalidOriginDomain.selector, ETHEREUM));
    gateway.sendMessage(ETHEREUM, message, gasLimit);
  }

  function test_hubGateway_ccipMappingOverwrite() public {
    // Test that CCIP mappings can be overwritten
    uint256[] memory ecChainIds = new uint256[](1);
    ecChainIds[0] = BASE;

    uint256[] memory ccipChainIds1 = new uint256[](1);
    ccipChainIds1[0] = 111_111_111;

    // Set initial mapping
    vm.prank(owner);
    gateway.setCCIPChainIdMappings(ecChainIds, ccipChainIds1);

    assertEq(gateway.ecToCCIPChainId(BASE), 111_111_111);
    assertEq(gateway.ccipToECId(111_111_111), BASE);

    // Overwrite with new mapping
    uint256[] memory ccipChainIds2 = new uint256[](1);
    ccipChainIds2[0] = 222_222_222;

    vm.prank(owner);
    gateway.setCCIPChainIdMappings(ecChainIds, ccipChainIds2);

    // New mapping should be set
    assertEq(gateway.ecToCCIPChainId(BASE), 222_222_222);
    assertEq(gateway.ccipToECId(222_222_222), BASE);

    // Old mapping should still exist (mappings are additive, not replaced)
    assertEq(gateway.ccipToECId(111_111_111), BASE);
  }

  function test_hubGateway_removeChainGateway_thenAddAgain() public {
    // Remove a chain gateway
    vm.prank(receiver);
    gateway.removeChainGateway(ETHEREUM);

    assertEq(gateway.chainGateways(ETHEREUM), bytes32(0));

    // Add it back
    bytes32 newGateway = address(0x999).toBytes32();
    vm.prank(receiver);
    gateway.setChainGateway(ETHEREUM, newGateway);

    assertEq(gateway.chainGateways(ETHEREUM), newGateway);
  }

  function testRevert_hubGateway_polymerReceive_whenNoGatewayConfigured() public {
    bytes memory message = abi.encode('test');
    uint32 unknownChain = 777;

    bytes memory topics = new bytes(96);
    bytes32 eventSelector = keccak256('Dispatch(uint32,bytes32,bytes)');
    bytes32 gatewayAddr = address(gateway).toBytes32();
    assembly {
      mstore(add(topics, 32), eventSelector)
      mstore(add(topics, 64), EVERCLEAR)
      mstore(add(topics, 96), gatewayAddr)
    }

    bytes memory data = abi.encode(message);
    bytes memory proof = abi.encode('mock_proof');

    address sourceContract = address(0x888);

    vm.mockCall(
      polymerProver,
      abi.encodeWithSignature('validateEvent(bytes)'),
      abi.encode(unknownChain, sourceContract, topics, data)
    );

    vm.expectRevert(IHubGatewayV3.Gateway_Handle_InvalidSender.selector);
    gateway.polymerReceive(proof);
  }

  // Helper function to construct polymer proof
  function _constructPolymerProof(
    uint32 _origin,
    address _sourceContract,
    string memory _messageData
  ) internal returns (bytes memory) {
    bytes memory message = abi.encode(_messageData);
    bytes32[] memory topics = new bytes32[](3);
    topics[0] = keccak256('Dispatch(uint32,bytes32,bytes)');
    topics[1] = bytes32(uint256(block.chainid));
    topics[2] = address(this).toBytes32();

    bytes memory topicsBytes = new bytes(96);
    assembly {
      mstore(add(topicsBytes, 32), mload(add(topics, 32)))
      mstore(add(topicsBytes, 64), mload(add(topics, 64)))
      mstore(add(topicsBytes, 96), mload(add(topics, 96)))
    }

    bytes memory data = abi.encode(message);

    // Mock the polymer prover validation
    vm.mockCall(
      polymerProver,
      abi.encodeWithSelector(IPolymer.validateEvent.selector),
      abi.encode(_origin, _sourceContract, topicsBytes, data)
    );

    return abi.encode('mock_proof');
  }
}

// Helper contract to reject ETH
contract RejectEther {
  error NoETHAccepted();

  receive() external payable {
    revert NoETHAccepted();
  }
}

// Mock Reverting Mailbox for testing call failures
contract MockRevertingMailbox {
  error MailboxFailed();

  function dispatch(
    uint32,
    bytes32,
    bytes calldata,
    bytes calldata
  ) external payable returns (bytes32) {
    revert MailboxFailed();
  }
}

// Mock Hyperlane Mailbox for testing
contract MockHyperlaneMailbox {
  uint256 private _fee;
  bytes32 private _messageId;

  // Allow contract to receive ETH
  receive() external payable {}

  function setFee(
    uint256 fee
  ) external {
    _fee = fee;
  }

  function setMessageId(
    bytes32 messageId
  ) external {
    _messageId = messageId;
  }

  error InsufficientFee();

  function dispatch(
    uint32,
    bytes32,
    bytes calldata,
    bytes calldata
  ) external payable returns (bytes32) {
    if (msg.value < _fee) revert InsufficientFee();
    // Keep only the fee, refund will be handled by gateway
    return _messageId;
  }

  function quoteDispatch(
    uint32,
    bytes32,
    bytes calldata,
    bytes calldata
  ) external view returns (uint256) {
    return _fee;
  }
}

// Mock CCIP Mailbox for testing
contract MockCCIPMailbox {
  bytes32 private _messageId;
  bool private _shouldRevert;

  struct EVM2AnyMessage {
    bytes receiver;
    bytes data;
    EVMTokenAmount[] tokenAmounts;
    address feeToken;
    bytes extraArgs;
  }

  struct EVMTokenAmount {
    address token;
    uint256 amount;
  }

  function setMessageId(
    bytes32 messageId
  ) external {
    _messageId = messageId;
  }

  function setShouldRevert(
    bool shouldRevert
  ) external {
    _shouldRevert = shouldRevert;
  }

  error CCIPSendFailed();

  function ccipSend(
    uint64,
    EVM2AnyMessage calldata
  ) external payable returns (bytes32) {
    if (_shouldRevert) {
      revert CCIPSendFailed();
    }
    return _messageId;
  }
}
