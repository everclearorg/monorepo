// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {TestExtended} from '../../utils/TestExtended.sol';
import {IXERC20Module, XERC20Module} from 'contracts/intent/modules/XERC20Module.sol';
import {IXERC20} from 'interfaces/common/IXERC20.sol';
import {StdStorage, stdStorage} from 'test/utils/TestExtended.sol';

contract BaseTest is TestExtended {
  using stdStorage for StdStorage;

  XERC20Module internal xerc20Module;

  address immutable SPOKE = makeAddr('SPOKE');
  address immutable ASSET = makeAddr('ASSET');
  address immutable RECIPIENT = makeAddr('RECIPIENT');
  address immutable FALLBACK_RECIPIENT = makeAddr('FALLBACK_RECIPIENT');

  function setUp() public {
    xerc20Module = new XERC20Module(SPOKE);
  }

  function mockMintingCurrentLimit(
    uint256 _limit
  ) internal {
    vm.mockCall(
      ASSET, abi.encodeWithSelector(IXERC20.mintingCurrentLimitOf.selector, address(xerc20Module)), abi.encode(_limit)
    );
  }

  function mockBurningMaxLimit(
    uint256 _limit
  ) internal {
    vm.mockCall(
      ASSET, abi.encodeWithSelector(IXERC20.burningMaxLimitOf.selector, address(xerc20Module)), abi.encode(_limit)
    );
  }

  function mockMintable(address _user, address _asset, uint256 _amount) internal {
    stdstore.target(address(xerc20Module)).sig(xerc20Module.mintable.selector).with_key(_user).with_key(_asset)
      .checked_write(_amount);
  }

  function expectMintCall(
    uint256 _amount
  ) internal {
    vm.expectCall(ASSET, abi.encodeWithSelector(IXERC20.mint.selector, RECIPIENT, _amount));
  }

  function expectBurnCall(
    uint256 _amount
  ) internal {
    vm.expectCall(ASSET, abi.encodeWithSelector(IXERC20.burn.selector, RECIPIENT, _amount));
  }
}

contract Unit_XERC20ModuleMintStrategy is BaseTest {
  /**
   * @notice Test that the mint strategy is handled correctly
   * @param _amount The amount to mint
   * @param _limit The current minting limit
   */
  function test_HandleMintStrategy(uint256 _amount, uint256 _limit) public {
    vm.assume(_amount <= _limit);
    vm.assume(_amount > 0);

    mockMintingCurrentLimit(_limit);
    expectMintCall(_amount);

    vm.prank(SPOKE);
    bool success = xerc20Module.handleMintStrategy(ASSET, RECIPIENT, FALLBACK_RECIPIENT, _amount, '');

    assertTrue(success);
    assertEq(xerc20Module.mintable(FALLBACK_RECIPIENT, ASSET), 0);
  }

  /**
   * @notice Test the mint strategy with fallback recipient
   * @param _amount The amount to mint
   * @param _limit The current minting limit
   */
  function test_HandleMintStrategy_Fallback(uint256 _amount, uint256 _limit) public {
    vm.assume(_amount > _limit);
    vm.assume(_limit > 0);

    mockMintingCurrentLimit(_limit);

    vm.prank(SPOKE);
    bool success = xerc20Module.handleMintStrategy(ASSET, RECIPIENT, FALLBACK_RECIPIENT, _amount, '');

    assertFalse(success);
    assertEq(xerc20Module.mintable(FALLBACK_RECIPIENT, ASSET), _amount);
  }

  /**
   * @notice Test that the mint strategy reverts when the caller is not the spoke
   * @param caller The address of the caller
   * @param _amount The amount to mint
   */
  function test_Revert_HandleMintStrategy_NotSpoke(address caller, uint256 _amount) public {
    vm.assume(caller != SPOKE);

    vm.expectRevert(IXERC20Module.XERC20Module_HandleStrategy_OnlySpoke.selector);

    vm.prank(caller);
    xerc20Module.handleMintStrategy(ASSET, RECIPIENT, FALLBACK_RECIPIENT, _amount, '');
  }
}

contract Unit_XERC20ModuleBurnStrategy is BaseTest {
  /**
   * @notice Test that the burn strategy is handled correctly
   * @param _amount The amount to burn
   * @param _limit The current burning limit
   */
  function test_HandleBurnStrategy(uint256 _amount, uint256 _limit) public {
    vm.assume(_amount <= _limit);
    vm.assume(_amount > 0);

    mockBurningMaxLimit(_limit);
    expectBurnCall(_amount);

    vm.prank(SPOKE);
    xerc20Module.handleBurnStrategy(ASSET, RECIPIENT, _amount, '');
  }

  /**
   * @notice Test the burn strategy with insufficient burning limit
   * @param _amount The amount to burn
   * @param _limit The current burning limit
   */
  function test_Revert_HandleBurnStrategy_InsufficientBurningLimit(uint256 _amount, uint256 _limit) public {
    vm.assume(_amount > _limit);
    vm.assume(_limit > 0);

    mockBurningMaxLimit(_limit);

    vm.expectRevert(
      abi.encodeWithSelector(
        IXERC20Module.XERC20Module_HandleBurnStrategy_InsufficientBurningLimit.selector, ASSET, _limit, _amount
      )
    );

    vm.prank(SPOKE);
    xerc20Module.handleBurnStrategy(ASSET, RECIPIENT, _amount, '');
  }

  /**
   * @notice Test that the burn strategy reverts when the caller is not the spoke
   * @param caller The address of the caller
   * @param _amount The amount to burn
   */
  function test_Revert_HandleBurnStrategy_NotSpoke(address caller, uint256 _amount) public {
    vm.assume(caller != SPOKE);

    vm.expectRevert(IXERC20Module.XERC20Module_HandleStrategy_OnlySpoke.selector);

    vm.prank(caller);
    xerc20Module.handleBurnStrategy(ASSET, RECIPIENT, _amount, '');
  }
}

contract Unit_XERC20ModuleMintDebt is BaseTest {
  /**
   * @notice Test that the mint debt is handled correctly
   * @param _amount The amount to mint
   * @param _limit The current minting limit
   */
  function test_MintDebt(uint256 _amount, uint256 _limit) public {
    vm.assume(_amount <= _limit);
    vm.assume(_amount > 0);

    _amount = xerc20Module.mintable(RECIPIENT, ASSET);

    vm.mockCall(
      ASSET, abi.encodeWithSelector(IXERC20.mintingMaxLimitOf.selector, address(xerc20Module)), abi.encode(_limit)
    );

    expectMintCall(_amount);

    xerc20Module.mintDebt(ASSET, RECIPIENT, _amount);

    assertEq(xerc20Module.mintable(RECIPIENT, ASSET), 0);
  }

  /**
   * @notice Test the mint debt with insufficient minting limit
   * @param _amount The amount to mint
   * @param _limit The current minting limit
   */
  function test_Revert_MintDebt_InsufficientMintingLimit(uint256 _amount, uint256 _limit) public {
    vm.assume(_amount > _limit);
    vm.assume(_limit > 0);

    mockMintable(RECIPIENT, ASSET, _amount);

    vm.mockCall(
      ASSET, abi.encodeWithSelector(IXERC20.mintingMaxLimitOf.selector, address(xerc20Module)), abi.encode(_limit)
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        IXERC20Module.XERC20Module_MintDebt_InsufficientMintingLimit.selector, ASSET, _limit, _amount
      )
    );

    xerc20Module.mintDebt(ASSET, RECIPIENT, _amount);
  }
}
