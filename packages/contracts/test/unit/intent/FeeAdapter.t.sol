// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {IERC20Errors} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IPermit2} from 'interfaces/common/IPermit2.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {ISpokeStorage} from 'interfaces/intent/ISpokeStorage.sol';

import {StdStorage, Vm, stdStorage} from 'forge-std/Test.sol';
import {Constants} from 'test/utils/Constants.sol';
import {TestExtended} from 'test/utils/TestExtended.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {FeeAdapter, IFeeAdapter} from 'contracts/intent/FeeAdapter.sol';

contract BaseTest is TestExtended {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  FeeAdapter adapter;
  address inputAsset;
  address immutable FEE_RECIPIENT = makeAddr('FEE_RECIPIENT');
  address immutable SPOKE = makeAddr('SPOKE');
  address immutable OWNER = makeAddr('OWNER');
  address immutable USER = makeAddr('USER');
  address immutable XERC20_MODULE = makeAddr('XERC20_MODULE');

  function setUp() public {
    adapter = new FeeAdapter(SPOKE, FEE_RECIPIENT, XERC20_MODULE, OWNER);
    // fund user with asset
    inputAsset = deployAndDeal(USER, 1000 ether).toAddress();
    // fund user with eth
    vm.deal(USER, 1000 ether);
  }

  function getRecipientBalance(
    address _asset
  ) public returns (uint256 balance) {
    balance = _asset == address(0) ? FEE_RECIPIENT.balance : IERC20(_asset).balanceOf(FEE_RECIPIENT);
  }

  function mockNewIntentCall(bytes32 _intentId, IEverclearSpoke.Intent memory _intent) internal {
    vm.mockCall(SPOKE, abi.encodeWithSelector(hex'4a943d21'), abi.encode(_intentId, _intent));
  }

  function mockStrategyCall(address _asset, uint8 _strategy) internal {
    vm.mockCall(SPOKE, abi.encodeWithSelector(ISpokeStorage.strategies.selector, _asset), abi.encode(_strategy));
    vm.expectCall(SPOKE, abi.encodeWithSelector(ISpokeStorage.strategies.selector, _asset));
  }

  function mockNewIntentRevert() internal {
    // vm.mockCallRevert(SPOKE, abi.encodeWithSelector(hex'4a943d21'), keccak256('fail'));
  }

  function mockReturnUnsupportedIntent(address _asset, uint256 _amount) internal {
    vm.mockCall(SPOKE, abi.encodeWithSelector(IEverclearSpoke.withdraw.selector, _asset, _amount), abi.encode(''));
    vm.expectCall(SPOKE, abi.encodeWithSelector(IEverclearSpoke.withdraw.selector, _asset, _amount));
  }

  function mockTransferCall(address _asset, address _recipient, uint256 _amount) internal {
    vm.mockCall(_asset, abi.encodeWithSelector(IERC20.transfer.selector, _recipient, _amount), abi.encode(true));
    vm.expectCall(_asset, abi.encodeWithSelector(IERC20.transfer.selector, _recipient, _amount));
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
  function test_Revert_UpdateFeeRecipient_NotOwner(
    address _newRecipient
  ) public {
    vm.assume(_newRecipient != OWNER);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _newRecipient));
    vm.prank(_newRecipient);
    adapter.updateFeeRecipient(_newRecipient);
  }

  function test_UpdateFeeRecipient(
    address _newRecipient
  ) public {
    vm.expectEmit();
    emit IFeeAdapter.FeeRecipientUpdated(_newRecipient, FEE_RECIPIENT);

    vm.startPrank(OWNER);
    adapter.updateFeeRecipient(_newRecipient);
    vm.stopPrank();

    assertEq(adapter.feeRecipient(), _newRecipient);
  }
}

contract Unit_ReturnUnsupportedIntent is BaseTest {
  function test_Revert_ReturnUnsupportedIntent_NotOwner(
    address _asset,
    uint256 _amount,
    address _receiver,
    address _caller
  ) public {
    vm.assume(_caller != adapter.owner());

    vm.startPrank(_caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    adapter.returnUnsupportedIntent(_asset, _amount, _receiver);
  }

  function test_ReturnUnsupportedIntent_FeeAdapter(address _asset, uint256 _amount, address _receiver) public {
    mockReturnUnsupportedIntent(_asset, _amount);
    mockTransferCall(_asset, _receiver, _amount);

    vm.prank(OWNER);
    adapter.returnUnsupportedIntent(_asset, _amount, _receiver);
  }
}

contract Unit_NewIntent is BaseTest {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  function test_Revert_NewIntent_InsufficientBalance(
    uint256 _amount
  ) public {
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

  function test_Revert_NewIntent_InsufficientAllowance(
    uint256 _amount
  ) public {
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

  function test_NewIntent_FeeInNative_ERC20(uint256 _amount, uint256 _fee, uint32 _destination) public {
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
    bytes32 _intentId = bytes32(uint256(1));
    IEverclearSpoke.Intent memory _intent;
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 0);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    vm.expectEmit();
    emit IFeeAdapter.IntentWithFeesAdded(_intentId, USER.toBytes32(), 0, _fee);

    vm.prank(USER);
    (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) =
      adapter.newIntent{value: _fee}(_destinations, USER, inputAsset, address(0), _amount, 0, 0, hex'', 0);
    assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
    assertEq(_returnedId, _intentId, 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _fee, 'recipient didnt get fee');
    assertEq(address(adapter).balance, 0, 'adapter balance nonzero');
  }

  function test_NewIntent_FeeInTransacting_ERC20(uint256 _amountWithFee, uint32 _destination) public {
    vm.assume(_amountWithFee > 0);
    uint256 _fee = _amountWithFee / 2;
    uint256 _amount = _amountWithFee - _fee;

    // Fund user with token
    inputAsset = deployAndDeal(USER, _amountWithFee).toAddress();

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amountWithFee);

    // Mock call to spoke
    bytes32 _intentId = bytes32(uint256(1));
    IEverclearSpoke.Intent memory _intent;
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 0);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    vm.expectEmit();
    emit IFeeAdapter.IntentWithFeesAdded(_intentId, USER.toBytes32(), _fee, 0);

    vm.prank(USER);
    (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) =
      adapter.newIntent(_destinations, USER, inputAsset, address(0), _amount, 0, 0, hex'', _fee);
    assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
    assertEq(_returnedId, _intentId, 'returned id != id');
    assertEq(IERC20(inputAsset).balanceOf(adapter.feeRecipient()), _fee, 'recipient didnt get fee');
    assertEq(IERC20(inputAsset).balanceOf(address(adapter)), _amount, 'adapter token balance != amount');
  }

  function test_NewIntent_FeeInTransactingAndNative_ERC20(
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
      mockNewIntentCall(bytes32(uint256(1)), _intent);
      mockStrategyCall(inputAsset, 0);

      // Generate intent params
      uint32[] memory _destinations = new uint32[](1);
      _destinations[0] = _destination;

      vm.expectEmit();
      emit IFeeAdapter.IntentWithFeesAdded(bytes32(uint256(1)), USER.toBytes32(), _fee, _nativeFee);

      vm.prank(USER);
      (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) =
        adapter.newIntent{value: _nativeFee}(_destinations, USER, inputAsset, address(0), _amount, 0, 0, hex'', _fee);
      assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
      assertEq(_returnedId, bytes32(uint256(1)), 'returned id != id');
    }
    assertEq(adapter.feeRecipient().balance, _nativeFee, 'recipient didnt get native fee');
    assertEq(address(adapter).balance, 0, 'adapter eth balance != 0');
    assertEq(IERC20(inputAsset).balanceOf(adapter.feeRecipient()), _fee, 'recipient didnt get token fee');
    assertEq(
      IERC20(inputAsset).balanceOf(address(adapter)), _tokenAmountWithFee - _fee, 'adapter token balance != amount'
    );
  }

  function test_NewIntent_SufficientSpokeAllowance_ERC20(uint256 _amount, uint256 _fee, uint32 _destination) public {
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
    bytes32 _intentId = bytes32(uint256(1));
    IEverclearSpoke.Intent memory _intent;
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 0);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    vm.expectEmit();
    emit IFeeAdapter.IntentWithFeesAdded(_intentId, USER.toBytes32(), 0, _fee);

    // should have 0 approve calls from adapter
    vm.expectCall(address(adapter), 0, abi.encodeWithSelector(IERC20.approve.selector, SPOKE, _amount), 0);

    vm.prank(USER);
    (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) =
      adapter.newIntent{value: _fee}(_destinations, USER, inputAsset, address(0), _amount, 0, 0, hex'', 0);
    assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
    assertEq(_returnedId, _intentId, 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _fee, 'recipient didnt get fee');
    assertEq(address(adapter).balance, 0, 'adapter balance nonzero');
  }

  function test_NewIntent_Permit2_ERC20(uint256 _amount, uint256 _fee, uint32 _destination) public {
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
    bytes32 _intentId = bytes32(uint256(1));
    IEverclearSpoke.Intent memory _intent;
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 0);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    vm.expectEmit();
    emit IFeeAdapter.IntentWithFeesAdded(_intentId, USER.toBytes32(), 0, _fee);

    vm.prank(USER);
    (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) = adapter.newIntent{value: _fee}(
      _destinations, USER, inputAsset, address(0), _amount, 0, 0, hex'', _permit2Params, 0
    );
    assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
    assertEq(_returnedId, _intentId, 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _fee, 'recipient didnt get fee');
    assertEq(address(adapter).balance, 0, 'adapter balance nonzero');
  }

  function test_NewIntent_FeeInTransacting_XERC20(uint256 _amountWithFee, uint32 _destination) public {
    vm.assume(_amountWithFee > 0);
    uint256 _fee = _amountWithFee / 2;
    uint256 _amount = _amountWithFee - _fee;

    // Fund user with token
    inputAsset = deployAndDeal(USER, _amountWithFee).toAddress();

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amountWithFee);

    // Mock call to spoke
    bytes32 _intentId = bytes32(uint256(1));
    IEverclearSpoke.Intent memory _intent;
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 1);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    vm.expectEmit();
    emit IFeeAdapter.IntentWithFeesAdded(_intentId, USER.toBytes32(), _fee, 0);

    vm.prank(USER);
    (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) =
      adapter.newIntent(_destinations, USER, inputAsset, address(0), _amount, 0, 0, hex'', _fee);
    assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
    assertEq(_returnedId, _intentId, 'returned id != id');
    assertEq(IERC20(inputAsset).balanceOf(adapter.feeRecipient()), _fee, 'recipient didnt get fee');
    assertEq(IERC20(inputAsset).balanceOf(address(adapter)), _amount, 'adapter token balance != amount');
  }

  function test_NewIntent_SufficientSpokeAllowance_XERC20(uint256 _amount, uint256 _fee, uint32 _destination) public {
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
    IERC20(inputAsset).approve(XERC20_MODULE, _amount);

    // Mock call to spoke
    bytes32 _intentId = bytes32(uint256(1));
    IEverclearSpoke.Intent memory _intent;
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 1);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    vm.expectEmit();
    emit IFeeAdapter.IntentWithFeesAdded(_intentId, USER.toBytes32(), 0, _fee);

    // should have 0 approve calls from adapter
    vm.expectCall(address(adapter), 0, abi.encodeWithSelector(IERC20.approve.selector, SPOKE, _amount), 0);

    vm.prank(USER);
    (bytes32 _returnedId, IEverclearSpoke.Intent memory _returnedIntent) =
      adapter.newIntent{value: _fee}(_destinations, USER, inputAsset, address(0), _amount, 0, 0, hex'', 0);
    assertEq(keccak256(abi.encode(_returnedIntent)), keccak256(abi.encode(_intent)), 'returned intent != intent');
    assertEq(_returnedId, _intentId, 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _fee, 'recipient didnt get fee');
    assertEq(address(adapter).balance, 0, 'adapter balance nonzero');
  }
}

contract Unit_NewOrderSplitEvenly is BaseTest {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  function test_NewOrderSplitEvenly_FeeInTransacting(
    uint256 _amountWithFee,
    uint32 _destination,
    address _receiver,
    uint32 _numOfIntents
  ) public {
    vm.assume(_amountWithFee > 0);
    vm.assume(_numOfIntents < 10);

    uint256 _fee = _amountWithFee / 2;
    uint256 _amount = _amountWithFee - _fee;
    _numOfIntents = _numOfIntents < 2 ? 2 : _numOfIntents;

    // Fund user with token
    inputAsset = deployAndDeal(USER, _amountWithFee).toAddress();

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amountWithFee);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    // Configuring the params for OrderParameters
    IFeeAdapter.OrderParameters memory _params;
    _params.destinations = _destinations;
    _params.receiver = _receiver;
    _params.inputAsset = inputAsset;
    _params.outputAsset = address(0);
    _params.amount = _amount;
    _params.maxFee = 0;
    _params.ttl = 0;
    _params.data = hex'';

    // Configuring the intent
    IEverclearSpoke.Intent memory _intent;
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // Mocking the call
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 0);

    // Sending the order
    vm.prank(USER);
    (bytes32 _orderId, bytes32[] memory _intentIds) = adapter.newOrderSplitEvenly(_numOfIntents, _fee, _params);

    assertEq(_intentIds.length, _numOfIntents, 'intentIds length != numOfIntents');
    assertEq(_orderId, keccak256(abi.encode(_intentIds)), 'returned id != id');
    assertEq(IERC20(inputAsset).balanceOf(adapter.feeRecipient()), _fee, 'recipient didnt get fee');
    assertEq(IERC20(inputAsset).balanceOf(address(adapter)), _amount, 'adapter token balance != amount');
  }

  function test_NewOrderSplitEvenly_FeeInEth(
    uint256 _amount,
    uint256 _fee,
    uint32 _destination,
    address _receiver,
    uint32 _numOfIntents
  ) public {
    vm.assume(_amount > 0);
    vm.assume(_numOfIntents < 10);
    _numOfIntents = _numOfIntents < 2 ? 2 : _numOfIntents;

    // Fund user with token
    inputAsset = deployAndDeal(USER, _amount).toAddress();
    vm.deal(USER, _fee);

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amount);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    // Configuring the params for OrderParameters
    IFeeAdapter.OrderParameters memory _params;
    _params.destinations = _destinations;
    _params.receiver = _receiver;
    _params.inputAsset = inputAsset;
    _params.outputAsset = address(0);
    _params.amount = _amount;
    _params.maxFee = 0;
    _params.ttl = 0;
    _params.data = hex'';

    // Configuring the intent
    IEverclearSpoke.Intent memory _intent;
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // Mocking the call
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 0);

    // Sending the order
    vm.prank(USER);
    (bytes32 _orderId, bytes32[] memory _intentIds) =
      adapter.newOrderSplitEvenly{value: _fee}(_numOfIntents, 0, _params);

    assertEq(_intentIds.length, _numOfIntents, 'intentIds length != numOfIntents');
    assertEq(_orderId, keccak256(abi.encode(_intentIds)), 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _fee, 'recipient didnt get fee');
    assertEq(IERC20(inputAsset).balanceOf(address(adapter)), _amount, 'adapter token balance != amount');
  }

  function test_NewOrderSplitEvenly_FeeInTransactingAndEth(
    uint256 _amountWithFee,
    uint256 _ethFee,
    uint32 _destination,
    address _receiver,
    uint32 _numOfIntents
  ) public {
    vm.assume(_amountWithFee > 0);
    vm.assume(_numOfIntents < 10);

    uint256 _fee = _amountWithFee / 2;
    uint256 _amount = _amountWithFee - _fee;
    _numOfIntents = _numOfIntents < 2 ? 2 : _numOfIntents;

    // Fund user with token
    inputAsset = deployAndDeal(USER, _amountWithFee).toAddress();
    vm.deal(USER, _ethFee);

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amountWithFee);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    // Configuring the params for OrderParameters
    IFeeAdapter.OrderParameters memory _params;
    _params.destinations = _destinations;
    _params.receiver = _receiver;
    _params.inputAsset = inputAsset;
    _params.outputAsset = address(0);
    _params.amount = _amount;
    _params.maxFee = 0;
    _params.ttl = 0;
    _params.data = hex'';

    // Configuring the intent
    IEverclearSpoke.Intent memory _intent;
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // Mocking the call
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 0);

    // Sending the order
    vm.prank(USER);
    (bytes32 _orderId, bytes32[] memory _intentIds) =
      adapter.newOrderSplitEvenly{value: _ethFee}(_numOfIntents, _fee, _params);

    assertEq(_intentIds.length, _numOfIntents, 'intentIds length != numOfIntents');
    assertEq(_orderId, keccak256(abi.encode(_intentIds)), 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _ethFee, 'recipient didnt get eth fee');
    assertEq(IERC20(inputAsset).balanceOf(adapter.feeRecipient()), _fee, 'recipient didnt get fee');
    assertEq(IERC20(inputAsset).balanceOf(address(adapter)), _amount, 'adapter token balance != amount');
  }
}

contract Unit_NewOrder is BaseTest {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  function test_Revert_NewOrder_MultipleOrderAsset(uint256 _fee, address _assetOne, address _assetTwo) public {
    vm.assume(_fee > 0);
    vm.assume(_assetOne != _assetTwo);

    // Configuring the params for OrderParameters
    IFeeAdapter.OrderParameters[] memory _params = new IFeeAdapter.OrderParameters[](2);
    _params[0].inputAsset = _assetOne;
    _params[1].inputAsset = _assetTwo;

    vm.expectRevert(abi.encodeWithSelector(IFeeAdapter.MultipleOrderAssets.selector));
    vm.prank(USER);
    adapter.newOrder(_fee, _params);
  }

  function test_NewOrder_FeeWithTransacting(uint256 _amountWithFee, uint32 _destination, uint256 _numOfIntents) public {
    vm.assume(_amountWithFee > 0);
    vm.assume(_numOfIntents < 10);
    if (_numOfIntents < 2) _numOfIntents = 2;

    uint256 _fee = _amountWithFee / 2;
    uint256 _amount = _amountWithFee - _fee;

    // Ensuring the amount is divisible by the number of intents for ease of balance calculations
    uint256 _remainder = _amount % _numOfIntents;
    _amount = _amount - _remainder;

    // Fund user with token
    _amountWithFee = _amount + _fee;
    inputAsset = deployAndDeal(USER, _amountWithFee).toAddress();

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amountWithFee);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    // Configuring the params for OrderParameters
    IFeeAdapter.OrderParameters[] memory _params = new IFeeAdapter.OrderParameters[](_numOfIntents);
    for (uint256 i; i < _numOfIntents; i++) {
      _params[i].destinations = _destinations;
      _params[i].receiver = USER;
      _params[i].inputAsset = inputAsset;
      _params[i].outputAsset = address(0);
      _params[i].amount = _amount / _numOfIntents;
      _params[i].maxFee = 0;
      _params[i].ttl = 0;
      _params[i].data = hex'';
    }

    // Configuring intent info
    IEverclearSpoke.Intent memory _intent;
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // Mocking the call
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 0);

    // Sending the order
    vm.prank(USER);
    (bytes32 _orderId, bytes32[] memory _intentIds) = adapter.newOrder(_fee, _params);

    assertEq(_intentIds.length, _params.length, 'intentIds length != numOfIntents');
    assertEq(_orderId, keccak256(abi.encode(_intentIds)), 'returned id != id');
    assertEq(IERC20(inputAsset).balanceOf(adapter.feeRecipient()), _fee, 'recipient didnt get fee');
    assertEq(IERC20(inputAsset).balanceOf(address(adapter)), _amount, 'adapter token balance != amount');
  }

  function test_NewOrder_FeeWithEth(uint256 _amount, uint256 _fee, uint32 _destination, uint256 _numOfIntents) public {
    vm.assume(_amount > 0);
    vm.assume(_numOfIntents < 10);
    if (_numOfIntents < 2) _numOfIntents = 2;

    // Ensuring the amount is divisible by the number of intents for ease of balance calculations
    uint256 _remainder = _amount % _numOfIntents;
    _amount = _amount - _remainder;

    // Fund user with token
    inputAsset = deployAndDeal(USER, _amount).toAddress();
    vm.deal(USER, _fee);

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amount);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    // Configuring the params for OrderParameters
    IFeeAdapter.OrderParameters[] memory _params = new IFeeAdapter.OrderParameters[](_numOfIntents);
    for (uint256 i; i < _numOfIntents; i++) {
      _params[i].destinations = _destinations;
      _params[i].receiver = USER;
      _params[i].inputAsset = inputAsset;
      _params[i].outputAsset = address(0);
      _params[i].amount = _amount / _numOfIntents;
      _params[i].maxFee = 0;
      _params[i].ttl = 0;
      _params[i].data = hex'';
    }

    // Configuring intent info
    IEverclearSpoke.Intent memory _intent;
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // Mocking the call
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 0);

    // Sending the order
    vm.prank(USER);
    (bytes32 _orderId, bytes32[] memory _intentIds) = adapter.newOrder{value: _fee}(0, _params);

    assertEq(_intentIds.length, _params.length, 'intentIds length != numOfIntents');
    assertEq(_orderId, keccak256(abi.encode(_intentIds)), 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _fee, 'recipient didnt get fee');
    assertEq(IERC20(inputAsset).balanceOf(address(adapter)), _amount, 'adapter token balance != amount');
  }

  function test_NewOrder_FeeWithTransactingAndEth(
    uint256 _amountWithFee,
    uint256 _ethFee,
    uint32 _destination,
    uint256 _numOfIntents
  ) public {
    vm.assume(_amountWithFee > 0);
    vm.assume(_numOfIntents < 10);
    if (_numOfIntents < 2) _numOfIntents = 2;

    uint256 _fee = _amountWithFee / 2;
    uint256 _amount = _amountWithFee - _fee;

    // Ensuring the amount is divisible by the number of intents for ease of balance calculations
    uint256 _remainder = _amount % _numOfIntents;
    _amount = _amount - _remainder;

    // Fund user with token
    _amountWithFee = _amount + _fee;
    inputAsset = deployAndDeal(USER, _amountWithFee).toAddress();
    vm.deal(USER, _ethFee);

    // Approve amount to adapter
    vm.prank(USER);
    IERC20(inputAsset).approve(address(adapter), _amountWithFee);

    // Generate intent params
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;

    // Configuring the params for OrderParameters
    IFeeAdapter.OrderParameters[] memory _params = new IFeeAdapter.OrderParameters[](_numOfIntents);
    for (uint256 i; i < _numOfIntents; i++) {
      _params[i].destinations = _destinations;
      _params[i].receiver = USER;
      _params[i].inputAsset = inputAsset;
      _params[i].outputAsset = address(0);
      _params[i].amount = _amount / _numOfIntents;
      _params[i].maxFee = 0;
      _params[i].ttl = 0;
      _params[i].data = hex'';
    }

    // Configuring intent info
    IEverclearSpoke.Intent memory _intent;
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // Mocking the call
    mockNewIntentCall(_intentId, _intent);
    mockStrategyCall(inputAsset, 0);

    // Sending the order
    vm.prank(USER);
    (bytes32 _orderId, bytes32[] memory _intentIds) = adapter.newOrder{value: _ethFee}(_fee, _params);

    assertEq(_intentIds.length, _params.length, 'intentIds length != numOfIntents');
    assertEq(_orderId, keccak256(abi.encode(_intentIds)), 'returned id != id');
    assertEq(adapter.feeRecipient().balance, _ethFee, 'recipient didnt get eth fee');
    assertEq(IERC20(inputAsset).balanceOf(adapter.feeRecipient()), _fee, 'recipient didnt get fee');
    assertEq(IERC20(inputAsset).balanceOf(address(adapter)), _amount, 'adapter token balance != amount');
  }
}
