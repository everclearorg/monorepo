// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestExtended} from '../../utils/TestExtended.sol';
import {UnsafeUpgrades} from '@upgrades/Upgrades.sol';

import {IGateway} from 'contracts/common/Gateway.sol';
import {HubGateway, IHubGateway} from 'contracts/hub/HubGateway.sol';

import {StdStorage, stdStorage} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

contract TestHubGateway is HubGateway {
  function getGateway(
    uint32 _chainId
  ) external view returns (bytes32) {
    return _getGateway(_chainId);
  }

  function checkValidSender(uint32 _origin, bytes32 _sender) external view {
    _checkValidSender(_origin, _sender);
  }
}

contract BaseTest is TestExtended {
  using stdStorage for StdStorage;

  TestHubGateway internal hubGateway;

  address immutable OWNER = makeAddr('OWNER');
  address immutable MAILBOX = makeAddr('MAILBOX');
  address immutable RECEIVER = makeAddr('RECEIVER');
  address immutable SECURITY_MODULE = makeAddr('SECURITY_MODULE');

  function setUp() public {
    hubGateway = deployHubGatewayProxy(OWNER, MAILBOX, RECEIVER, SECURITY_MODULE);
  }

  function deployHubGatewayProxy(
    address _owner,
    address _mailbox,
    address _receiver,
    address _securityModule
  ) internal returns (TestHubGateway _gateway) {
    address _impl = address(new TestHubGateway());
    _gateway = TestHubGateway(
      payable(
        UnsafeUpgrades.deployUUPSProxy(
          _impl, abi.encodeCall(HubGateway.initialize, (_owner, _mailbox, _receiver, _securityModule))
        )
      )
    );
  }

  function _mockGateway(uint32 _chainId, bytes32 _chainGateway) internal {
    stdstore.target(address(hubGateway)).sig(IHubGateway.chainGateways.selector).with_key(_chainId).checked_write(
      _chainGateway
    );
  }
}

contract Unit_AddingChainGateways is BaseTest {
  /**
   * @notice Tests the setChainGateway function
   * @param _chainId The chain ID
   * @param _chainGateway The chain gateway
   */
  function test_SetChainGateway(uint32 _chainId, bytes32 _chainGateway) public {
    vm.assume(_chainGateway != bytes32(0));

    vm.prank(RECEIVER);
    hubGateway.setChainGateway(_chainId, _chainGateway);

    assertEq(hubGateway.chainGateways(_chainId), _chainGateway);
  }

  /**
   * @notice Tests changing the chain gateway for a chain id
   * @param _chainId The chain ID
   * @param _initialGateway The initial gateway
   * @param _chainGateway The chain gateway to change to
   */
  function test_ChangeChainGateway(uint32 _chainId, bytes32 _initialGateway, bytes32 _chainGateway) public {
    vm.assume(_initialGateway != bytes32(0) && _chainGateway != bytes32(0));
    _mockGateway(_chainId, _initialGateway);

    assertEq(hubGateway.chainGateways(_chainId), _initialGateway);

    vm.prank(RECEIVER);
    hubGateway.setChainGateway(_chainId, _chainGateway);

    assertEq(hubGateway.chainGateways(_chainId), _chainGateway);
  }

  /**
   * @notice Tests the setChainGateway function with an invalid address
   * @param _chainId The chain ID
   */
  function test_Revert_SetChainGateway_InvalidAddress(
    uint32 _chainId
  ) public {
    vm.assume(_chainId != 0);

    vm.expectRevert(abi.encodeWithSelector(IGateway.Gateway_ZeroAddress.selector));

    vm.prank(RECEIVER);
    hubGateway.setChainGateway(_chainId, bytes32(0));
  }

  /**
   * @notice Tests the setChainGateway function with an unauthorized caller
   * @param _caller The caller address
   * @param _chainId The chain ID
   * @param _chainGateway The chain gateway
   */
  function test_Revert_SetChainGateway_NonReceiver(address _caller, uint32 _chainId, bytes32 _chainGateway) public {
    vm.assume(_caller != RECEIVER);

    vm.expectRevert(abi.encodeWithSelector(IGateway.Gateway_SendMessage_UnauthorizedCaller.selector));

    hubGateway.setChainGateway(_chainId, _chainGateway);
  }

  /**
   * @notice Tests the removeChainGateway function
   * @param _chainId The chain ID
   * @param _chainGateway The chain gateway
   */
  function test_RemoveChainGateway(uint32 _chainId, bytes32 _chainGateway) public {
    vm.assume(_chainGateway != bytes32(0));

    _mockGateway(_chainId, _chainGateway);

    vm.prank(RECEIVER);
    hubGateway.removeChainGateway(_chainId);

    assertEq(hubGateway.chainGateways(_chainId), bytes32(0));
  }

  /**
   * @notice Tests the removeChainGateway function with an chain gateway already removed
   * @param _chainId The chain ID
   */
  function test_Revert_RemoveChainGateway_GatewayAlreadyRemoved(
    uint32 _chainId
  ) public {
    _mockGateway(_chainId, bytes32(0));

    vm.expectRevert(
      abi.encodeWithSelector(IHubGateway.HubGateway_RemoveGateway_GatewayAlreadyRemoved.selector, _chainId)
    );

    vm.prank(RECEIVER);
    hubGateway.removeChainGateway(_chainId);
  }
}

contract Unit_ValidSender is BaseTest {
  /**
   * @notice Tests the checkValidSender function
   * @param _chainId The chain ID
   * @param _sender The sender
   */
  function test_ValidSender(uint32 _chainId, bytes32 _sender) public {
    vm.assume(_sender != 0);
    _mockGateway(_chainId, _sender);

    vm.prank(RECEIVER);
    hubGateway.checkValidSender(_chainId, _sender);
  }

  /**
   * @notice Tests the checkValidSender function with an invalid chain id
   * @param _chainId The chain ID
   * @param _incorrectChainId The incorrect chain ID
   * @param _sender The sender
   */
  function test_Revert_InvalidSender(uint32 _chainId, uint32 _incorrectChainId, bytes32 _sender) public {
    vm.assume(_chainId != _incorrectChainId);
    vm.assume(_sender != 0);

    _mockGateway(_chainId, _sender);

    vm.expectRevert(abi.encodeWithSelector(IGateway.Gateway_Handle_InvalidSender.selector));
    hubGateway.checkValidSender(_incorrectChainId, _sender);
  }
}
