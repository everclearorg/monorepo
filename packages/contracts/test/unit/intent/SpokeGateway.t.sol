// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TestExtended} from '../../utils/TestExtended.sol';
import {UnsafeUpgrades} from '@upgrades/Upgrades.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IGateway} from 'contracts/common/Gateway.sol';
import {ISpokeGateway, SpokeGateway} from 'contracts/intent/SpokeGateway.sol';

contract TestSpokeGateway is SpokeGateway {
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
  using TypeCasts for address;

  TestSpokeGateway internal spokeGateway;

  address immutable OWNER = makeAddr('OWNER');
  address immutable EVERCLEAR_SPOKE = makeAddr('EVERCLEAR_SPOKE');
  address immutable MAILBOX = makeAddr('MAILBOX');
  address immutable SECURITY_MODULE = makeAddr('SECURITY_MODULE');

  function setUp() public {
    spokeGateway = deploySpokeGatewayProxy(
      OWNER, MAILBOX, EVERCLEAR_SPOKE, SECURITY_MODULE, 111_111, makeAddr('hub_gateway').toBytes32()
    );
  }

  function deploySpokeGatewayProxy(
    address _owner,
    address _spoke,
    address _mailbox,
    address _securityModule,
    uint32 _everclearId,
    bytes32 _hubGateway
  ) internal returns (TestSpokeGateway _gateway) {
    address _impl = address(new TestSpokeGateway());
    _gateway = TestSpokeGateway(
      payable(
        UnsafeUpgrades.deployUUPSProxy(
          _impl,
          abi.encodeCall(
            SpokeGateway.initialize, (_owner, _mailbox, _spoke, _securityModule, _everclearId, _hubGateway)
          )
        )
      )
    );
  }
}

contract Unit_Constants is BaseTest {
  using TypeCasts for address;

  /**
   * @notice Test that the contract has the correct constants
   */
  function test_Constants() public {
    assertEq(spokeGateway.EVERCLEAR_ID(), 111_111);
    assertEq(spokeGateway.EVERCLEAR_GATEWAY(), makeAddr('hub_gateway').toBytes32());
  }
}

contract Unit_InternalFunctions is BaseTest {
  using TypeCasts for address;

  /**
   * @notice Test that the gateway is set correctly
   */
  function test_GetGateway(
    uint32 _chaindId
  ) public {
    assertEq(spokeGateway.getGateway(_chaindId), makeAddr('hub_gateway').toBytes32());
  }

  /**
   * @notice Test that the sender chain id is valid
   */
  function test_CheckValidSender() public {
    spokeGateway.checkValidSender(111_111, makeAddr('hub_gateway').toBytes32());
  }

  /**
   * @notice Test that an invalid chain id reverts
   */
  function test_Revert_CheckValidSender_InvalidChainId(
    uint32 _chainId
  ) public {
    vm.assume(_chainId != 111_111);

    vm.expectRevert(abi.encodeWithSelector(IGateway.Gateway_Handle_InvalidOriginDomain.selector));
    spokeGateway.checkValidSender(_chainId, makeAddr('hub_gateway').toBytes32());
  }

  /**
   * @notice Test that an invalid sender reverts
   */
  function test_Revert_CheckValidSender_InvalidSender(
    bytes32 _sender
  ) public {
    vm.assume(_sender != makeAddr('hub_gateway').toBytes32());

    vm.expectRevert(abi.encodeWithSelector(IGateway.Gateway_Handle_InvalidSender.selector));
    spokeGateway.checkValidSender(111_111, _sender);
  }
}
