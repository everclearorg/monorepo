// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {CallExecutor, ICallExecutor} from 'contracts/intent/CallExecutor.sol';

import {TestExtended} from 'test/utils/TestExtended.sol';

import {StdStorage, stdStorage} from 'test/utils/TestExtended.sol';

contract BaseTest is TestExtended {
  using stdStorage for StdStorage;

  ICallExecutor callExecutor;
  MockContract mockContract;
  MockSpoke mockSpoke;

  function setUp() public virtual {
    callExecutor = new CallExecutor();
    mockContract = new MockContract();
    mockSpoke = new MockSpoke(callExecutor);
  }

  function _mockNonce(
    uint256 _nonce
  ) internal {
    stdstore.target(address(mockContract)).sig(MockContract.nonce.selector).checked_write(_nonce);
  }
}

contract MockContract {
  uint256 internal _nonce;

  function increaseNonce() public payable returns (uint256 _newNonce) {
    _nonce = nonce() + 1; //using public method to be able to mock previous nonce
    _newNonce = _nonce;
  }

  function nonce() public view returns (uint256) {
    return _nonce;
  }

  function getSender() public view returns (address) {
    return msg.sender;
  }
}

contract MockSpoke {
  ICallExecutor callExecutor;

  constructor(
    ICallExecutor _callExecutor
  ) {
    callExecutor = _callExecutor;
  }

  function executeCall(address _target, bytes calldata _data) public returns (bool _success, bytes memory _returnData) {
    (_success, _returnData) = callExecutor.excessivelySafeCall(_target, 100_000, 0, 100, _data);
  }
}

contract Unit_ExcessivelySafeCall is BaseTest {
  /**
   * @notice Test that the function is permissionless
   * @param _caller The address of the caller
   * @param _previousNonce The nonce of the mock contract
   * @param _gas The gas to be used in the call
   * @param _value The value to be sent in the call
   * @param _maxCopy The maximum amount of data to be copied
   */
  function test_isPermissionless(
    address _caller,
    uint256 _previousNonce,
    uint256 _gas,
    uint256 _value,
    uint16 _maxCopy
  ) public {
    vm.assume(_caller != address(0));
    vm.assume(_previousNonce < type(uint256).max);
    vm.assume(_gas >= 100_000);
    vm.assume(_maxCopy >= 100);
    vm.deal(address(callExecutor), _value);

    _mockNonce(_previousNonce);

    vm.prank(_caller);

    vm.expectCall(address(mockContract), abi.encodeWithSignature('increaseNonce()'));

    (bool _success, bytes memory _returnData) = callExecutor.excessivelySafeCall(
      address(mockContract), _gas, _value, _maxCopy, abi.encodeWithSignature('increaseNonce()')
    );

    assertTrue(_success, 'Call failed');
    assertEq(_returnData, abi.encode(_previousNonce + 1));
  }

  /**
   * @notice Test that the function handles failed calls correctly
   * @param _caller The address of the caller
   */
  function test_SenderIsNotComposedContract(
    address _caller
  ) public {
    vm.assume(_caller != address(0));
    vm.assume(_caller != address(mockContract));

    vm.prank(_caller);

    vm.expectCall(address(mockContract), abi.encodeWithSignature('getSender()'));

    (bool _success, bytes memory _returnData) =
      mockSpoke.executeCall(address(mockContract), abi.encodeWithSignature('getSender()'));

    assertTrue(_success, 'Call failed');
    assertEq(_returnData, abi.encode(address(callExecutor)));
  }
}
