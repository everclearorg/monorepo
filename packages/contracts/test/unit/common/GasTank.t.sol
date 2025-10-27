// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {GasTank, IGasTank} from 'contracts/common/GasTank.sol';

import {TestExtended} from 'test/utils/TestExtended.sol';

import {StdStorage, stdStorage} from 'test/utils/TestExtended.sol';

import {UnsafeUpgrades} from '@upgrades/Upgrades.sol';

contract GasTankForTest is GasTank {
  function publicInit(
    address _owner
  ) public initializer {
    __initializeGasTank(_owner);
  }
}

contract Unit_GasTank is TestExtended {
  using stdStorage for StdStorage;

  event GasTankDeposited(address indexed _sender, uint256 _amount);
  event GasTankWithdrawn(address indexed _sender, uint256 _amount);
  event GasReceiverAuthorized(address indexed _address, bool _authorized);

  IGasTank internal _gasTank;

  address internal immutable _OWNER = makeAddr('OWNER');

  function setUp() public {
    address _impl = address(new GasTankForTest());
    _gasTank =
      GasTank(payable(UnsafeUpgrades.deployUUPSProxy(_impl, abi.encodeCall(GasTankForTest.publicInit, (_OWNER)))));
  }

  function _mockAuthorizedGasReceiver(address _address, bool _isAuthorized) internal {
    stdstore.target(address(_gasTank)).sig(GasTank.isAuthorizedGasReceiver.selector).with_key(_address).checked_write(
      _isAuthorized
    );
  }

  function _mockFailedGasReceipt(address _receiver, uint256 _value) internal {
    vm.mockCallRevert(_receiver, _value, '', abi.encode(false));
  }

  /*//////////////////////////////////////////////////////////////
                              HAPPY PATHS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Test the `fillGasTank` function
   */
  function test_FillGasTank(
    address _depositor,
    uint256 _initialAmount,
    uint256 _amount
  ) public validAddress(_depositor) {
    // Avoid overflow
    vm.assume(_amount <= type(uint256).max - _initialAmount);
    vm.assume(_depositor != address(_gasTank));
    deal(_depositor, _amount);
    deal(address(_gasTank), _initialAmount);

    _expectEmit(address(_gasTank));
    emit GasTankDeposited(_depositor, _amount);

    vm.prank(_depositor);
    // _gasTank.fillGasTank{value: _amount}();
    address(_gasTank).call{value: _amount}('');

    assertEq(address(_gasTank).balance, _initialAmount + _amount);
  }

  /**
   * @notice Test the `withdrawGas` function, as the owner
   */
  function test_WithdrawGasAsOwner(uint256 _initialAmount, uint256 _amount) public {
    vm.assume(_initialAmount >= _amount);
    deal(address(_gasTank), _initialAmount);

    _expectEmit(address(_gasTank));
    emit GasTankWithdrawn(_OWNER, _amount);

    vm.prank(_OWNER);
    _gasTank.withdrawGas(_amount);

    assertEq(address(_gasTank).balance, _initialAmount - _amount);
    assertEq(_OWNER.balance, _amount);
  }

  /**
   * @notice Test the `withdrawGas` function, as an authorized address
   *             Only the owner can authorize addresses
   */
  function test_WithdrawGasAsAuthorizedAddress(
    address _withdrawer,
    uint256 _initialAmount,
    uint256 _amount
  ) public validAddress(_withdrawer) nonContract(_withdrawer) {
    vm.assume(_initialAmount >= _amount);
    vm.assume(_withdrawer != address(_gasTank));
    vm.assume(_withdrawer >= address(20));

    uint256 _prevBalance = _withdrawer.balance;

    _mockAuthorizedGasReceiver(_withdrawer, true);

    deal(address(_gasTank), _initialAmount);
    assertEq(address(_gasTank).balance, _initialAmount);

    _expectEmit(address(_gasTank));
    emit GasTankWithdrawn(_withdrawer, _amount);

    vm.prank(_withdrawer);
    _gasTank.withdrawGas(_amount);

    assertEq(address(_gasTank).balance, _initialAmount - _amount);
    assertEq(_withdrawer.balance, _prevBalance + _amount);
  }

  /**
   * @notice Test the `authorizeGasReceiver` function
   */
  function test_Authorize(
    address _address
  ) public validAddress(_address) {
    _mockAuthorizedGasReceiver(_address, false);
    _expectEmit(address(_gasTank));
    emit GasReceiverAuthorized(_address, true);

    vm.prank(_OWNER);
    _gasTank.authorizeGasReceiver(_address, true);

    assertEq(_gasTank.isAuthorizedGasReceiver(_address), true);
  }

  /*//////////////////////////////////////////////////////////////
                                REVERTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Check that non-authorised addresses cannot withdraw gas
   */
  function test_Revert_WithdrawGas_NotAuthorized(
    address _withdrawer,
    uint256 _initialAmount,
    uint256 _amount
  ) public validAddress(_withdrawer) {
    vm.assume(_initialAmount >= _amount);
    _mockAuthorizedGasReceiver(_withdrawer, false);

    deal(address(_gasTank), _initialAmount);

    vm.prank(_withdrawer);

    vm.expectRevert(abi.encodeWithSelector(IGasTank.GasTank_NotAuthorized.selector));
    _gasTank.withdrawGas(_amount);
  }

  /**
   * @notice Check that an authorized address cannot withdraw more gas than the contract has
   */
  function test_Revert_WithdrawGas_InsufficientFunds(
    address _withdrawer,
    uint256 _amount,
    uint256 _initialAmount
  ) public {
    vm.assume(_initialAmount < _amount);

    deal(address(_gasTank), _initialAmount);
    _mockAuthorizedGasReceiver(_withdrawer, true);

    vm.expectRevert(abi.encodeWithSelector(IGasTank.GasTank_InsufficientFunds.selector));

    vm.prank(_withdrawer);
    _gasTank.withdrawGas(_amount);
  }

  /**
   * @notice Check that an authorized address cannot withdraw gas if the call fails
   */
  function test_Revert_WithdrawGas_FailedCall(
    address _withdrawer,
    uint256 _initialAmount,
    uint256 _amount
  ) public validAddress(_withdrawer) {
    vm.assume(_initialAmount >= _amount);

    _mockAuthorizedGasReceiver(_withdrawer, true);
    _mockFailedGasReceipt(_withdrawer, _amount);

    deal(address(_gasTank), _initialAmount);

    vm.expectRevert(abi.encodeWithSelector(IGasTank.GasTank_CallFailed.selector));

    vm.prank(_withdrawer);
    _gasTank.withdrawGas(_amount);
  }
}
