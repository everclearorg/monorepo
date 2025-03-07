// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Ownable } from '@openzeppelin/contracts/access/Ownable2Step.sol';
import { IERC20Errors } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import { IEverclearSpoke } from 'interfaces/intent/IEverclearSpoke.sol';
import { IPermit2 } from 'interfaces/common/IPermit2.sol';

import { StdStorage, stdStorage, Vm } from 'forge-std/Test.sol';
import { Constants } from 'test/utils/Constants.sol';
import { TestExtended } from 'test/utils/TestExtended.sol';

import { TypeCasts } from 'contracts/common/TypeCasts.sol';
import { FeeAdapter, IFeeAdapter } from 'contracts/intent/FeeAdapter.sol';

contract BaseTest is TestExtended {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  FeeAdapter adapter;
  address inputAsset;
  address immutable FEE_RECIPIENT = makeAddr('FEE_RECIPIENT');
  address immutable SPOKE = makeAddr('SPOKE');
  address immutable OWNER = makeAddr('OWNER');
  address immutable USER = makeAddr('USER');

  function setUp() public {
    adapter = new FeeAdapter(SPOKE, FEE_RECIPIENT, OWNER);
    // fund user with asset
    inputAsset = deployAndDeal(USER, 1000 ether).toAddress();
    // fund user with eth
    vm.deal(USER, 1000 ether);
  }

  function getRecipientBalance(address _asset) public returns (uint256 balance) {
    balance = _asset == address(0) ? FEE_RECIPIENT.balance : IERC20(_asset).balanceOf(FEE_RECIPIENT);
  }

  function mockNewIntentCall(bytes32 _intentId, IEverclearSpoke.Intent memory _intent) internal {
    vm.mockCall(SPOKE, abi.encodeWithSelector(hex'4a943d21'), abi.encode(_intentId, _intent));
  }

  function mockNewIntentRevert() internal {
    // vm.mockCallRevert(SPOKE, abi.encodeWithSelector(hex'4a943d21'), keccak256('fail'));
  }

  function expectFeeTransferCall(address _feeAsset, uint256 _fee) internal {
    if (_feeAsset == address(0)) {
      vm.expectCall(FEE_RECIPIENT, _fee, hex'', 1);
    } else {
      vm.expectCall(_feeAsset, abi.encodeCall(IERC20.transfer, (FEE_RECIPIENT, _fee)), 1);
    }
  }

  function expectNewIntentCall(
    uint32[] memory _destinations,
    address _receiver,
    address _inputAsset,
    address _outputAsset,
    uint256 _amount,
    uint24 _maxFee,
    uint48 _ttl,
    bytes calldata _data
  ) internal {
    vm.expectCall(
      SPOKE,
      abi.encodeWithSelector(
        hex'4a943d21', // new intent
        _destinations,
        _receiver,
        _inputAsset,
        _outputAsset,
        _amount,
        _maxFee,
        _ttl,
        _data
      ),
      1
    );
  }
}

contract Unit_UpdateFeeRecipient is BaseTest {
  function test_Revert_UpdateFeeRecipient_NotOwner(address _newRecipient) public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _newRecipient));
    vm.prank(_newRecipient);
    adapter.updateFeeRecipient(_newRecipient);
  }

  function test_UpdateFeeRecipient(address _newRecipient) public {
    vm.expectEmit();
    emit IFeeAdapter.FeeRecipientUpdated(_newRecipient, FEE_RECIPIENT);

    vm.startPrank(OWNER);
    adapter.updateFeeRecipient(_newRecipient);
    vm.stopPrank();

    assertEq(adapter.feeRecipient(), _newRecipient);
  }
}

contract Unit_NewIntent is BaseTest {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  function test_Revert_NewIntent_InsufficientBalance(uint256 _amount) public {
    vm.assume(_amount > 0);

    // fund user with asset
    inputAsset = deployAndDeal(USER, _amount / 2).toAddress();

    // Approve amount
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amount);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = 1;

    vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, USER, _amount / 2, _amount));
    vm.prank(USER);
    adapter.newIntent(_destinations, USER, inputAsset, address(0), _amount, 0, 0, hex'', 0);
  }

  function test_Revert_NewIntent_InsufficientAllowance(uint256 _amount) public {
    vm.assume(_amount > 0);

    // fund user with asset
    inputAsset = deployAndDeal(USER, _amount).toAddress();

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = 1;

    vm.expectRevert(
      abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(adapter), 0, _amount)
    );
    vm.prank(USER);
    adapter.newIntent(_destinations, USER, inputAsset, address(0), _amount, 0, 0, hex'', 0);
  }

  function test_NewIntent_FeeInNative(uint256 _amount, uint256 _fee, uint32 _destination) public {
    vm.assume(_amount > 0);
    vm.assume(_fee > 0);

    // Fund user with eth
    vm.deal(USER, _fee);

    // Fund user with token
    inputAsset = deployAndDeal(USER, _amount).toAddress();

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amount);

    // Mock call to spoke
    bytes32 _intentId = bytes32(uint(1));
    IEverclearSpoke.Intent memory _intent;
    mockNewIntentCall(_intentId, _intent);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    vm.expectEmit();
    emit IFeeAdapter.IntentWithFeesAdded(_intentId, USER.toBytes32(), 0, _fee);

    vm.prank(USER);
    (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) = adapter.newIntent{ value: _fee }(
      _destinations,
      USER,
      inputAsset,
      address(0),
      _amount,
      0,
      0,
      hex'',
      0
    );
    assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
    assertEq(_returnedId, _intentId, 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _fee, 'recipient didnt get fee');
    assertEq(address(adapter).balance, 0, 'adapter balance nonzero');
  }

  function test_NewIntent_FeeInTransacting(uint256 _amountWithFee, uint32 _destination) public {
    vm.assume(_amountWithFee > 0);
    uint256 _fee = _amountWithFee / 2;
    uint256 _amount = _amountWithFee - _fee;

    // Fund user with token
    inputAsset = deployAndDeal(USER, _amountWithFee).toAddress();

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amountWithFee);

    // Mock call to spoke
    bytes32 _intentId = bytes32(uint(1));
    IEverclearSpoke.Intent memory _intent;
    mockNewIntentCall(_intentId, _intent);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    vm.expectEmit();
    emit IFeeAdapter.IntentWithFeesAdded(_intentId, USER.toBytes32(), _fee, 0);

    vm.prank(USER);
    (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) = adapter.newIntent(
      _destinations,
      USER,
      inputAsset,
      address(0),
      _amount,
      0,
      0,
      hex'',
      _fee
    );
    assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
    assertEq(_returnedId, _intentId, 'returned id != id');
    assertEq(IERC20(inputAsset).balanceOf(adapter.feeRecipient()), _fee, 'recipient didnt get fee');
    assertEq(IERC20(inputAsset).balanceOf(address(adapter)), _amount, 'adapter token balance != amount');
  }

  function test_NewIntent_FeeInTransactingAndNative(
    uint256 _tokenAmountWithFee,
    uint256 _nativeFee,
    uint32 _destination
  ) public {
    vm.assume(_tokenAmountWithFee > 0);
    uint256 _fee = _tokenAmountWithFee / 2;
    uint256 _amount = _tokenAmountWithFee - _fee;

    // Fund user with eth
    vm.deal(USER, _nativeFee);

    // Fund user with token
    inputAsset = deployAndDeal(USER, _tokenAmountWithFee).toAddress();

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _tokenAmountWithFee);

    {
      // Mock call to spoke
      IEverclearSpoke.Intent memory _intent;
      mockNewIntentCall(bytes32(uint(1)), _intent);

      // Generate intent params
      uint32[] memory _destinations = new uint32[](1);
      _destinations[0] = _destination;

      vm.expectEmit();
      emit IFeeAdapter.IntentWithFeesAdded(bytes32(uint(1)), USER.toBytes32(), _fee, _nativeFee);

      vm.prank(USER);
      (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) = adapter.newIntent{ value: _nativeFee }(
        _destinations,
        USER,
        inputAsset,
        address(0),
        _amount,
        0,
        0,
        hex'',
        _fee
      );
      assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
      assertEq(_returnedId, bytes32(uint(1)), 'returned id != id');
    }
    assertEq(adapter.feeRecipient().balance, _nativeFee, 'recipient didnt get native fee');
    assertEq(address(adapter).balance, 0, 'adapter eth balance != 0');
    assertEq(IERC20(inputAsset).balanceOf(adapter.feeRecipient()), _fee, 'recipient didnt get token fee');
    assertEq(
      IERC20(inputAsset).balanceOf(address(adapter)),
      _tokenAmountWithFee - _fee,
      'adapter token balance != amount'
    );
  }

  function test_NewIntent_SufficientSpokeAllowance(uint256 _amount, uint256 _fee, uint32 _destination) public {
    vm.assume(_amount > 0);
    vm.assume(_amount < UINT256_MAX / 2);
    vm.assume(_fee > 0);

    // Fund user with eth
    vm.deal(USER, _fee);

    // Fund user with token
    inputAsset = deployAndDeal(USER, _amount).toAddress();

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amount);

    // Approve to the spoke
    vm.prank(address(adapter));
    IERC20(inputAsset).approve(SPOKE, _amount);

    // Mock call to spoke
    bytes32 _intentId = bytes32(uint(1));
    IEverclearSpoke.Intent memory _intent;
    mockNewIntentCall(_intentId, _intent);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    vm.expectEmit();
    emit IFeeAdapter.IntentWithFeesAdded(_intentId, USER.toBytes32(), 0, _fee);

    // should have 0 approve calls from adapter
    vm.expectCall(address(adapter), 0, abi.encodeWithSelector(IERC20.approve.selector, SPOKE, _amount), 0);

    vm.prank(USER);
    (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) = adapter.newIntent{ value: _fee }(
      _destinations,
      USER,
      inputAsset,
      address(0),
      _amount,
      0,
      0,
      hex'',
      0
    );
    assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
    assertEq(_returnedId, _intentId, 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _fee, 'recipient didnt get fee');
    assertEq(address(adapter).balance, 0, 'adapter balance nonzero');
  }

  function test_NewIntent_Permit2(uint256 _amount, uint256 _fee, uint32 _destination) public {
    vm.assume(_amount > 0);
    vm.assume(_fee > 0);

    // Fund user with eth
    vm.deal(USER, _fee);

    // Fund user with token
    inputAsset = deployAndDeal(USER, _amount).toAddress();

    // Approve amount to adapter using permit2
    IEverclearSpoke.Permit2Params memory _permit2Params;
    vm.mockCall(Constants.PERMIT2, abi.encodeWithSelector(IPermit2.permitTransferFrom.selector), abi.encode(true));
    deal(inputAsset, address(adapter), _amount);

    // Mock call to spoke
    bytes32 _intentId = bytes32(uint(1));
    IEverclearSpoke.Intent memory _intent;
    mockNewIntentCall(_intentId, _intent);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    vm.expectEmit();
    emit IFeeAdapter.IntentWithFeesAdded(_intentId, USER.toBytes32(), 0, _fee);

    vm.prank(USER);
    (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) = adapter.newIntent{ value: _fee }(
      _destinations,
      USER,
      inputAsset,
      address(0),
      _amount,
      0,
      0,
      hex'',
      _permit2Params,
      0
    );
    assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
    assertEq(_returnedId, _intentId, 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _fee, 'recipient didnt get fee');
    assertEq(address(adapter).balance, 0, 'adapter balance nonzero');
  }
}
