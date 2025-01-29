// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TestExtended} from '../../utils/TestExtended.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {UnsafeUpgrades} from '@upgrades/Upgrades.sol';

import {Gateway, IGateway} from 'contracts/common/Gateway.sol';

import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

contract TestGateway is Gateway {
  function initialize(address _owner, address _mailbox, address _receiver, address _interchainSecurityModule) external {
    _initializeGateway(_owner, _mailbox, _receiver, _interchainSecurityModule);
  }

  mapping(uint32 _chainId => bytes32 _gateway) public chainGateways;

  function setGateway(uint32 _chainId, bytes32 _gateway) external {
    chainGateways[_chainId] = _gateway;
  }

  function _getGateway(
    uint32 _chainId
  ) internal view override returns (bytes32 _gateway) {
    return chainGateways[_chainId];
  }

  function _checkValidSender(uint32, bytes32) internal pure override {}
}

contract BaseTest is TestExtended {
  TestGateway internal gateway;

  address immutable OWNER = makeAddr('OWNER');
  address immutable MAILBOX = makeAddr('MAILBOX');
  address immutable RECEIVER = makeAddr('RECEIVER');
  address immutable INTERCHAIN_SECURITY_MODULE = makeAddr('INTERCHAIN_SECURITY_MODULE');

  function setUp() public {
    gateway = deployGatewayProxy(OWNER, MAILBOX, RECEIVER, INTERCHAIN_SECURITY_MODULE);
  }

  function deployGatewayProxy(
    address _owner,
    address _mailbox,
    address _receiver,
    address _interchainSecurityModule
  ) internal returns (TestGateway _gateway) {
    address _impl = address(new TestGateway());
    _gateway = TestGateway(
      payable(
        UnsafeUpgrades.deployUUPSProxy(
          _impl, abi.encodeCall(TestGateway.initialize, (_owner, _mailbox, _receiver, _interchainSecurityModule))
        )
      )
    );
  }

  function _mockGateway(uint32 _chainId, bytes32 _chainGateway) internal {
    gateway.setGateway(_chainId, _chainGateway);
  }

  function _mockMailboxDispatch(
    uint32 _chainId,
    bytes32 _chainGateway,
    bytes calldata _message,
    uint256 _fee,
    uint256 _gasLimit
  ) internal returns (bytes32 _messageId) {
    _messageId = keccak256(abi.encode(_chainId, _chainGateway, _message));
    bytes memory _metadata = StandardHookMetadata.formatMetadata(0, _gasLimit, address(gateway), '');
    vm.mockCall(
      MAILBOX,
      _fee,
      abi.encodeWithSignature('dispatch(uint32,bytes32,bytes,bytes)', _chainId, _chainGateway, _message, _metadata),
      abi.encode(_messageId)
    );
    vm.expectCall(
      MAILBOX,
      _fee,
      abi.encodeWithSignature('dispatch(uint32,bytes32,bytes,bytes)', _chainId, _chainGateway, _message, _metadata)
    );
  }

  function _mockMailboxQuoteMessage(
    uint32 _chainId,
    bytes32 _chainGateway,
    bytes calldata _message,
    uint256 _fee,
    uint256 _gasLimit
  ) internal {
    bytes memory _metadata = StandardHookMetadata.formatMetadata(0, _gasLimit, address(gateway), '');
    vm.mockCall(
      MAILBOX,
      abi.encodeWithSignature('quoteDispatch(uint32,bytes32,bytes,bytes)', _chainId, _chainGateway, _message, _metadata),
      abi.encode(_fee)
    );
    vm.expectCall(
      MAILBOX,
      abi.encodeWithSignature('quoteDispatch(uint32,bytes32,bytes,bytes)', _chainId, _chainGateway, _message, _metadata)
    );
  }

  function _mockReceiver(
    bytes calldata _message
  ) internal {
    vm.mockCall(RECEIVER, abi.encodeWithSelector(IMessageReceiver.receiveMessage.selector, _message), abi.encode(true));
    vm.expectCall(RECEIVER, abi.encodeWithSelector(IMessageReceiver.receiveMessage.selector, _message));
  }

  function _mockValidSender(uint32 _origin, bytes32 _sender) internal {
    vm.mockCall(
      address(gateway), abi.encodeWithSignature('_checkValidSender(uint32,bytes32)', _origin, _sender), abi.encode(true)
    );
  }
}

contract Unit_Initialization is BaseTest {
  /**
   * @notice Test the initialization of the Gateway contract
   */
  function test_Initialization(
    address _owner,
    address _mailbox,
    address _receiver,
    address _interchainSecurityModule
  ) public {
    vm.assume(
      _owner != address(0) && _mailbox != address(0) && _receiver != address(0)
        && _interchainSecurityModule != address(0)
    );
    gateway = deployGatewayProxy(_owner, _mailbox, _receiver, _interchainSecurityModule);

    assertEq(gateway.owner(), _owner);
    assertEq(address(gateway.mailbox()), _mailbox);
    assertEq(address(gateway.receiver()), _receiver);
    assertEq(address(gateway.interchainSecurityModule()), _interchainSecurityModule);
  }
}

contract Unit_SendMessage is BaseTest {
  /**
   * @notice Test the `sendMessage` function
   */
  function test_SendMessage(
    uint32 _chainId,
    bytes calldata _message,
    bytes32 _chainGateway,
    uint256 _fee,
    uint256 _gasLimit
  ) public {
    // avoid overflow
    vm.assume(_fee < 1e30);
    _mockGateway(_chainId, _chainGateway);
    bytes32 _expectedMessageId = _mockMailboxDispatch(_chainId, _chainGateway, _message, _fee, _gasLimit);

    deal(RECEIVER, _fee);

    vm.startPrank(RECEIVER);
    (bytes32 _messageId, uint256 _feeSpent) = gateway.sendMessage{value: _fee}(_chainId, _message, _gasLimit);

    assertEq(_messageId, _expectedMessageId);
    // Fee is not spont because mocked call doesn't consume the fee
    assertEq(_feeSpent, 0);
  }

  /**
   * @notice Check that sendMessage reverts when called by a non-receiver address
   */
  function test_Revert_SendMessage_NotReceiver(
    address _caller,
    uint32 _chainId,
    bytes calldata _message,
    uint256 _fee,
    uint256 _gasLimit
  ) public {
    vm.assume(_fee < 1e30);
    vm.assume(_caller != RECEIVER);
    deal(_caller, _fee);

    vm.expectRevert(IGateway.Gateway_SendMessage_UnauthorizedCaller.selector);

    vm.prank(_caller);
    gateway.sendMessage{value: _fee}(_chainId, _message, _gasLimit);
  }

  /**
   * @notice Test sending a message using the contract gas tank
   */
  function test_SendMessage_UsingGasTank(
    uint32 _chainId,
    bytes calldata _message,
    bytes32 _chainGateway,
    uint256 _fee,
    uint256 _gasLimit
  ) public {
    vm.assume(_fee < 1e30);
    _mockGateway(_chainId, _chainGateway);
    bytes32 _expectedMessageId = _mockMailboxDispatch(_chainId, _chainGateway, _message, _fee, _gasLimit);

    deal(address(gateway), _fee);

    vm.startPrank(RECEIVER);
    (bytes32 _messageId, uint256 _feeSpent) = gateway.sendMessage(_chainId, _message, _fee, _gasLimit);

    assertEq(_messageId, _expectedMessageId);
    assertEq(_feeSpent, 0);
  }

  /**
   * @notice Check that sendMessage reverts when the contract gas tank has insufficient balance
   */
  function test_Revert_SendMessage_UsingGasTank_InsufficientBalance(
    uint32 _chainId,
    bytes calldata _message,
    bytes32 _chainGateway,
    uint256 _fee,
    uint256 _gasLimit
  ) public {
    vm.assume(_fee < 1e30);
    vm.assume(_fee > address(gateway).balance);
    _mockGateway(_chainId, _chainGateway);

    vm.expectRevert(IGateway.Gateway_SendMessage_InsufficientBalance.selector);

    vm.startPrank(RECEIVER);
    gateway.sendMessage(_chainId, _message, _fee, _gasLimit);
  }

  /**
   * @notice Check that sendMessage reverts when called by a non-receiver address using the contract gas tank
   */
  function test_Revert_SendMessage_UsingGasTank_NotReceiver(
    address _caller,
    uint32 _chainId,
    bytes calldata _message,
    uint256 _fee,
    uint256 _gasLimit
  ) public {
    vm.assume(_fee < 1e30);
    vm.assume(_caller != RECEIVER);
    deal(_caller, _fee);

    vm.expectRevert(IGateway.Gateway_SendMessage_UnauthorizedCaller.selector);

    vm.prank(_caller);
    gateway.sendMessage(_chainId, _message, _fee, _gasLimit);
  }
}

contract Unit_HandleMessage is BaseTest {
  /**
   * @notice Test the `handle` function, assert the receiver is called
   */
  function test_Handle(uint32 _origin, bytes32 _sender, bytes calldata _message) public {
    _mockReceiver(_message);

    vm.prank(MAILBOX);
    gateway.handle(_origin, _sender, _message);
  }

  /**
   * @notice Check that handle reverts when called by a non-mailbox address
   */
  function test_Revert_Handle_NotMailbox(
    address _caller,
    uint32 _origin,
    bytes32 _sender,
    bytes calldata _message
  ) public {
    vm.assume(_caller != MAILBOX);

    vm.expectRevert(IGateway.Gateway_Handle_NotCalledByMailbox.selector);

    vm.prank(_caller);
    gateway.handle(_origin, _sender, _message);
  }
}

contract Unit_QuoteMessage is BaseTest {
  using TypeCasts for address;
  /**
   * @notice Test the `quoteMessage` function, check the mailbox is called with the correct parameters
   */

  function test_QuoteMessage(
    uint32 _chainId,
    bytes calldata _message,
    address _chainGateway,
    uint256 _fee,
    uint256 _gasLimit
  ) public {
    _mockGateway(_chainId, _chainGateway.toBytes32());

    _mockMailboxQuoteMessage(_chainId, _chainGateway.toBytes32(), _message, _fee, _gasLimit);

    uint256 _quotedFee = gateway.quoteMessage(_chainId, _message, _gasLimit);

    assertEq(_quotedFee, _fee);
  }
}
