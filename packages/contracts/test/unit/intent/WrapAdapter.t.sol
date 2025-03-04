// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {WrapAdapter} from 'contracts/intent/WrapAdapter.sol';
import {TestExtended} from '../../utils/TestExtended.sol';
import {TestNoETHFallback} from '../../utils/TestNoETHFallback.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IXERC20} from 'interfaces/common/IXERC20.sol';
import {IXERC20Lockbox} from 'interfaces/intent/IXERC20Lockbox.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {IWrapAdapter} from 'interfaces/intent/IWrapAdapter.sol';
import {ISpokeStorage} from 'interfaces/intent/ISpokeStorage.sol';
import {IWETH} from 'interfaces/intent/IWETH.sol';

import {StdStorage, stdStorage} from 'test/utils/TestExtended.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

contract TestWrapAdapter is WrapAdapter {
    constructor(address _weth, address _spoke, address _owner) WrapAdapter(_weth, _spoke, _owner) {}
    function unwrap(address _outputAsset, uint256 _amountOut, address _unwrapReceiver, bytes32 _intentId) external {
        _unwrap(_outputAsset, _amountOut, _unwrapReceiver, _intentId);
    }

    function decodeArbitraryData(bytes calldata _data) external returns (address, address) {
        return _decodeArbitraryData(_data);
    }
}

contract BaseTest is TestExtended {
    using TypeCasts for bytes32;
    using stdStorage for StdStorage;

    TestWrapAdapter public wrapAdapter;

    address immutable WETH = makeAddr("WETH");
    address immutable OWNER = makeAddr("OWNER");
    address immutable SPOKE = makeAddr("SPOKE");
    address immutable RECIPIENT = makeAddr("RECIPIENT");

    function setUp() public {
        wrapAdapter = new TestWrapAdapter(WETH, SPOKE, OWNER);
    }

    // Mocking functionality
    function mockExecuteIntentCalldata(IEverclear.Intent memory _intent) internal {
        vm.mockCall(
        address(SPOKE),
        abi.encodeWithSelector(IEverclearSpoke.executeIntentCalldata.selector),
        ""
        );
        vm.expectCall(address(SPOKE), abi.encodeWithSelector(IEverclearSpoke.executeIntentCalldata.selector, _intent));
    }

    function mockWETHWithdraw(uint256 _amount) internal {
        vm.mockCall(
        address(WETH),
        abi.encodeWithSelector(IWETH.withdraw.selector, _amount),
        ""
        );
        vm.expectCall(address(WETH), abi.encodeWithSelector(IWETH.withdraw.selector, _amount));
    }

    function mockWETHDeposit(uint256 _amount) internal {
        vm.mockCall(
        address(WETH),
        _amount,
        abi.encodeWithSelector(IWETH.deposit.selector),
        ""
        );
        vm.expectCall(address(WETH), _amount, abi.encodeWithSelector(IWETH.deposit.selector));
    }

    function mockWETHApprove(address _spender, uint256 _amount) internal {
        vm.mockCall(
        address(WETH),
        abi.encodeWithSelector(IWETH.approve.selector, _spender, _amount),
        abi.encode(true)
        );
        vm.expectCall(address(WETH), abi.encodeWithSelector(IWETH.approve.selector, _spender, _amount));
    }

    function mockStatus(
        bytes32 _intentId,
        IEverclear.IntentStatus _status
    ) internal {
        vm.mockCall(
        address(SPOKE),
        abi.encodeWithSelector(ISpokeStorage.status.selector),
        abi.encode(_status)
        );
        vm.expectCall(address(SPOKE), abi.encodeWithSelector(ISpokeStorage.status.selector, _intentId));
    }

    function mockNewIntent(IEverclear.Intent memory _intent) internal {
        bytes32 _intentId = keccak256(abi.encode(_intent));
        bytes4 funcSelector = bytes4(keccak256("newIntent(uint32[],address,address,address,uint256,uint24,uint48,bytes)"));

        vm.mockCall(
            address(SPOKE),
            abi.encodeWithSelector(
                funcSelector,
                _intent.destinations,
                _intent.receiver.toAddress(),
                _intent.inputAsset.toAddress(),
                _intent.outputAsset.toAddress(),
                _intent.amount,
                _intent.maxFee,
                _intent.ttl,
                _intent.data
            ),
            abi.encode(_intentId, _intent)
        );
        vm.expectCall(
            address(SPOKE), 
            abi.encodeWithSelector(
                funcSelector,
                _intent.destinations,
                _intent.receiver.toAddress(),
                _intent.inputAsset.toAddress(),
                _intent.outputAsset.toAddress(),
                _intent.amount,
                _intent.maxFee,
                _intent.ttl,
                _intent.data
            )
        );
    }
}

contract Unit_WrapAdapter_UpdateSpoke is BaseTest {    
    event SpokeUpdated(address _oldSpoke, address _newSpoke);

    function test_updateEverclearSpoke(address _newSpoke) public {
        vm.assume(_newSpoke != address(0));

        vm.startPrank(wrapAdapter.owner());
        _expectEmit(address(wrapAdapter));
        emit SpokeUpdated(SPOKE, _newSpoke);
        wrapAdapter.updateEverclearSpoke(_newSpoke);
        vm.stopPrank();

        assertEq(address(wrapAdapter.everclearSpoke()), _newSpoke);
    }

    function test_Revert_updateEverclearSpoke_NotOwner(address _newSpoke) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        wrapAdapter.updateEverclearSpoke(_newSpoke);
    }

    function test_Revert_updateEverclearSpoke_InvalidAddress() public {
        address _newSpoke = address(0);

        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(IWrapAdapter.Invalid_Address.selector);
        wrapAdapter.updateEverclearSpoke(_newSpoke);
        vm.stopPrank();
    }
}

contract Unit_WrapAdapter_UnwrapIntent is BaseTest {
    using TypeCasts for bytes32;
    using TypeCasts for address;

    function test_unwrapAsset_XERC20Success(IEverclear.Intent memory _intent, uint256 _amountOut, address _unwrapReceiver) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_amountOut <= _intent.amount);
        vm.assume(_amountOut < type(uint256).max / 2);
        vm.assume(_unwrapReceiver != address(0));

        // Configure data - receiver + callReceiver are wrapAdapter and unwrapReceiver != address(0)
        _intent.receiver = address(wrapAdapter).toBytes32();
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _unwrapReceiver);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Deploy and deal XERC20
        (bytes32 _nativeToken, bytes32 _xerc20token) = deployAndDealXERC20Token(address(wrapAdapter), address(wrapAdapter).toBytes32(), _amountOut);
        _intent.outputAsset = _xerc20token;
        assertEq(IERC20(_xerc20token.toAddress()).balanceOf(address(wrapAdapter)), _amountOut);
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(address(wrapAdapter)), 0);
        uint256 _nativeBalance = IERC20(_nativeToken.toAddress()).balanceOf(address(_unwrapReceiver));

        // Mocking the expected calls
        mockExecuteIntentCalldata(_intent);

        // Unwrapping the asset
        vm.startPrank(wrapAdapter.owner());
        wrapAdapter.unwrapAsset(_intent, _amountOut);
        vm.stopPrank(); 

        // Checking state change
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(_unwrapReceiver), _nativeBalance + _amountOut);
    }

    function test_unwrapAsset_WETHSuccess(IEverclear.Intent memory _intent, uint256 _amountOut) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_amountOut <= _intent.amount);
        address _unwrapReceiver = RECIPIENT;

        // Configure data - receiver + callReceiver are wrapAdapter and unwrapReceiver != address(0)
        _intent.receiver = address(wrapAdapter).toBytes32();
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _unwrapReceiver);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Configuring output asset to be WETH
        _intent.outputAsset = WETH.toBytes32();
        uint256 _nativeBalance = address(_unwrapReceiver).balance;

        // Mocking the expected calls
        mockExecuteIntentCalldata(_intent);
        mockWETHWithdraw(_amountOut);

        // Dealing the ETH amount that will be sent from wrapAdapter
        deal(address(wrapAdapter), _amountOut);

        // Unwrapping the asset
        vm.startPrank(wrapAdapter.owner());
        wrapAdapter.unwrapAsset(_intent, _amountOut);
        vm.stopPrank(); 

        // Checking state change
        assertEq(address(_unwrapReceiver).balance, _nativeBalance + _amountOut);
    }

    function test_Revert_unwrapAsset_InvalidReceiver(IEverclear.Intent memory _intent, uint256 _amountOut) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_amountOut <= _intent.amount);

        // Configuring the receive to be invalid
        vm.assume(_intent.receiver.toAddress() != address(wrapAdapter));

        // Configure data
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, RECIPIENT);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Calling unwrap function and expecting revert
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(abi.encodeWithSelector(IWrapAdapter.Invalid_Receiver.selector, _intent.receiver.toAddress()));
        wrapAdapter.unwrapAsset(_intent, _amountOut);
        vm.stopPrank(); 
    }

    function test_Revert_unwrapAsset_InvalidCallback(IEverclear.Intent memory _intent, uint256 _amountOut, address _callReceiver) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_amountOut <= _intent.amount);
        _intent.receiver = address(wrapAdapter).toBytes32();

        // Configuring the callReceiver as invalid in data
        vm.assume(_callReceiver != address(wrapAdapter));
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, RECIPIENT);
        _intent.data = abi.encode(_callReceiver, _adapterCallbackCalldata);

        // Calling unwrap function and expecting revert
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(abi.encodeWithSelector(IWrapAdapter.Invalid_Callback.selector, _callReceiver));
        wrapAdapter.unwrapAsset(_intent, _amountOut);
        vm.stopPrank(); 
    }

    function test_Revert_unwrapAsset_InvalidOutputAmount(IEverclear.Intent memory _intent, uint256 _amountOut) public {
        vm.assume(_intent.amount > 0);
        _intent.receiver = address(wrapAdapter).toBytes32();
        
        // Configuring the amountOut to be invalid
        vm.assume(_amountOut > _intent.amount);

        // Configure data
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, RECIPIENT);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Calling unwrap function and expecting revert
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(abi.encodeWithSelector(IWrapAdapter.Invalid_Output_Amount.selector));
        wrapAdapter.unwrapAsset(_intent, _amountOut);
        vm.stopPrank(); 
    }

    function test_Revert_unwrapAsset_InvalidUnwrapReceiver(IEverclear.Intent memory _intent, uint256 _amountOut) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_amountOut <= _intent.amount);
        _intent.receiver = address(wrapAdapter).toBytes32();
        
        // Configuring the recipient to be invalid
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, address(0));
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Calling unwrap function and expecting revert
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(abi.encodeWithSelector(IWrapAdapter.Invalid_Unwrap_Receiver.selector));
        wrapAdapter.unwrapAsset(_intent, _amountOut);
        vm.stopPrank(); 
    }

    function test_Revert_unwrapAsset_WETH_TransferETHFailure(IEverclear.Intent memory _intent, uint256 _amountOut) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_amountOut <= _intent.amount);
        
        // Configuring unwrapReceiver as contract without receive fallback
        address _unwrapReceiver = address(new TestNoETHFallback());

        // Configure data - receiver + callReceiver are wrapAdapter and unwrapReceiver != address(0)
        _intent.receiver = address(wrapAdapter).toBytes32();
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _unwrapReceiver);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Configuring output asset to be WETH
        _intent.outputAsset = WETH.toBytes32();

        // Mocking the expected calls
        mockExecuteIntentCalldata(_intent);
        mockWETHWithdraw(_amountOut);

        // Dealing the ETH amount that will be sent from wrapAdapter
        deal(address(wrapAdapter), _amountOut);

        // Unwrapping the asset
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(IWrapAdapter.Transfer_ETH_Failure.selector);
        wrapAdapter.unwrapAsset(_intent, _amountOut);
        vm.stopPrank(); 
    }
}

contract Unit_WrapAdapter_UnwrapInvalidCalldata is BaseTest {
    using TypeCasts for address;
    using TypeCasts for bytes32;

    function test_unwrapInvalidCalldata_Success_XERC20(IEverclear.Intent memory _intent, uint256 _amountOut, address _unwrapReceiver) public {
        // Configuring valid amountOut and receiver to pass Invalid_Receiver revert
        vm.assume(_amountOut < _intent.amount);
        vm.assume(_amountOut < type(uint256).max / 2);
        vm.assume(_unwrapReceiver != address(0));
        _intent.receiver = address(wrapAdapter).toBytes32();

        // Deploy and deal XERC20 to be unwrapped
        (bytes32 _nativeToken, bytes32 _xerc20token) = deployAndDealXERC20Token(address(wrapAdapter), address(wrapAdapter).toBytes32(), _amountOut);
        _intent.outputAsset = _xerc20token;
        assertEq(IERC20(_xerc20token.toAddress()).balanceOf(address(wrapAdapter)), _amountOut);
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(address(wrapAdapter)), 0);
        uint256 _nativeBalance = IERC20(_nativeToken.toAddress()).balanceOf(address(_unwrapReceiver));

        // Configuring incorrect calldata size to target reverting on SETTLED status check
        _intent.data = new bytes(32);
        bytes32 _intentId = keccak256(abi.encode(_intent));
        mockStatus(_intentId, IEverclear.IntentStatus.SETTLED);
        
        // Unwrapping the asset
        vm.startPrank(wrapAdapter.owner());
        wrapAdapter.unwrapInvalidCalldata(_intent, _amountOut, _unwrapReceiver);
        vm.stopPrank();

        // Checking state change
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(_unwrapReceiver), _nativeBalance + _amountOut);
    }
    
    function test_unwrapInvalidCalldata_Success_WETH(IEverclear.Intent memory _intent, uint256 _amountOut) public {
        // Configuring valid amountOut and receiver to pass Invalid_Receiver revert
        vm.assume(_amountOut <= _intent.amount);
        // vm.assume(_unwrapReceiver != address(0));
        _intent.receiver = address(wrapAdapter).toBytes32();
        address _unwrapReceiver = RECIPIENT;

        // Configuring output asset to be WETH and dealing the ETH amount that will be sent from wrapAdapter
        _intent.outputAsset = WETH.toBytes32();
        uint256 _nativeBalance = address(_unwrapReceiver).balance;
        deal(address(wrapAdapter), _amountOut);

        // Configuring incorrect calldata size to target reverting on SETTLED status check
        _intent.data = new bytes(32);
        bytes32 _intentId = keccak256(abi.encode(_intent));
        mockStatus(_intentId, IEverclear.IntentStatus.SETTLED);
        mockWETHWithdraw(_amountOut);

        // Unwrapping the asset
        vm.startPrank(wrapAdapter.owner());
        wrapAdapter.unwrapInvalidCalldata(_intent, _amountOut, _unwrapReceiver);
        vm.stopPrank();

        // Checking state change
        assertEq(address(_unwrapReceiver).balance, _nativeBalance + _amountOut);
    }

    function test_Revert_unwrapInvalidCalldata_OnlyOwner(IEverclear.Intent memory _intent, uint256 _amount, address _receiver) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        wrapAdapter.unwrapInvalidCalldata(_intent, _amount, _receiver);
    }

    function test_Revert_unwrapInvalidCalldata_InvalidAlreadyProcessed(IEverclear.Intent memory _intent, uint256 _amountOut, address _unwrapReceiver) public {
        //////////////////// Successfully unwrapping the asset ////////////////////////
        // Configuring valid amountOut and receiver to pass Invalid_Receiver revert
        vm.assume(_amountOut < _intent.amount);
        vm.assume(_amountOut < type(uint256).max / 2);
        vm.assume(_unwrapReceiver != address(0));
        _intent.receiver = address(wrapAdapter).toBytes32();

        // Deploy and deal XERC20 to be unwrapped
        (bytes32 _nativeToken, bytes32 _xerc20token) = deployAndDealXERC20Token(address(wrapAdapter), address(wrapAdapter).toBytes32(), _amountOut);
        _intent.outputAsset = _xerc20token;
        assertEq(IERC20(_xerc20token.toAddress()).balanceOf(address(wrapAdapter)), _amountOut);
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(address(wrapAdapter)), 0);
        uint256 _nativeBalance = IERC20(_nativeToken.toAddress()).balanceOf(address(_unwrapReceiver));

        // Configuring incorrect calldata size to target reverting on SETTLED status check
        _intent.data = new bytes(32);
        bytes32 _intentId = keccak256(abi.encode(_intent));
        mockStatus(_intentId, IEverclear.IntentStatus.SETTLED);
        
        // Unwrapping the asset
        vm.startPrank(wrapAdapter.owner());
        wrapAdapter.unwrapInvalidCalldata(_intent, _amountOut, _unwrapReceiver);

        // Checking state change
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(_unwrapReceiver), _nativeBalance + _amountOut);
        
        //////////////////// Reverting on retry of same intent ////////////////////////
        vm.expectRevert(IWrapAdapter.Invalid_Already_Processed.selector);
        wrapAdapter.unwrapInvalidCalldata(_intent, _amountOut, _unwrapReceiver);

        vm.stopPrank();
    }

    function test_Revert_unwrapInvalidCalldata_InvalidReceiver(IEverclear.Intent memory _intent, uint256 _amount, address _receiver) public {
        vm.assume(_intent.receiver.toAddress() != address(wrapAdapter));
        
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(abi.encodeWithSelector(IWrapAdapter.Invalid_Receiver.selector, _intent.receiver.toAddress()));
        wrapAdapter.unwrapInvalidCalldata(_intent, _amount, _receiver);
        vm.stopPrank();
    }

    function test_Revert_unwrapInvalidCalldata_InvalidOutputAmount(IEverclear.Intent memory _intent, uint256 _amountOut, address _receiver) public {
        // Configuring the receiver to pass Invalid_Receiver revert
        _intent.receiver = address(wrapAdapter).toBytes32();

        // Configuring invalid amountOut to cause revert
        vm.assume(_amountOut >_intent.amount);
        
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(IWrapAdapter.Invalid_Output_Amount.selector);
        wrapAdapter.unwrapInvalidCalldata(_intent, _amountOut, _receiver);
        vm.stopPrank();
    }

    function test_Revert_unwrapInvalidCalldata_InvalidManualProcessing(IEverclear.Intent memory _intent, uint256 _amountOut, address _receiver) public {
        // Configuring valid amountOut and receiver to pass Invalid_Receiver revert
        vm.assume(_amountOut < _intent.amount);
        vm.assume(_receiver != address(0));
        _intent.receiver = address(wrapAdapter).toBytes32();

        // Configuring invalid manual processing to cause revert i.e. call data was correctly constructed
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _receiver);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);
        
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(IWrapAdapter.Invalid_Manual_Processing.selector);
        wrapAdapter.unwrapInvalidCalldata(_intent, _amountOut, _receiver);
        vm.stopPrank();
    }

    function test_Revert_unwrapInvalidCalldata_InvalidStatus(IEverclear.Intent memory _intent, uint256 _amountOut, address _receiver) public {
        // Configuring valid amountOut and receiver to pass Invalid_Receiver revert
        vm.assume(_amountOut < _intent.amount);
        _intent.receiver = address(wrapAdapter).toBytes32();

        // Configuring incorrect calldata size to target reverting on SETTLED status check
        _intent.data = new bytes(32);
        bytes32 _intentId = keccak256(abi.encode(_intent));
        mockStatus(_intentId, IEverclear.IntentStatus.NONE);
        
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(IWrapAdapter.Invalid_Status.selector);
        wrapAdapter.unwrapInvalidCalldata(_intent, _amountOut, _receiver);
        vm.stopPrank();
    }
}

contract Unit_WrapAdapter_AdapterCallback is BaseTest {
    function test_Revert_adapterCallback_InvalidSpokeCaller() public {
        bytes memory _message;

        vm.expectRevert(abi.encodeWithSelector(IWrapAdapter.Invalid_Spoke_Caller.selector, address(this)));
        wrapAdapter.adapterCallback(_message);
    }
}

contract Unit_WrapAdapter_WrapAndSendIntent is BaseTest {
    using TypeCasts for address;
    using TypeCasts for bytes32;

        /**
    * @notice Test that the wrap XERC20 call works
    * @param _intent The intent being forward to EverclearSpoke
    * @param _caller The caller of the function
    */
    function test_wrapAndSendIntent_XERC20Success(IEverclear.Intent memory _intent, address _caller) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_intent.amount < type(uint256).max / 2);
        vm.assume(_caller != address(0));

        // Deploy and deal XERC20 to be unwrapped
        (bytes32 _nativeToken, bytes32 _xerc20token) = deployAndDealXERC20Native(address(wrapAdapter), _caller.toBytes32(), _intent.amount);
        _intent.inputAsset = _xerc20token;

        // Fetching the balances for the caller
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(_caller), _intent.amount);
        assertEq(IERC20(_xerc20token.toAddress()).balanceOf(_caller), 0);
        uint256 _xerc20Balance = IERC20(_xerc20token.toAddress()).balanceOf(address(wrapAdapter));

        // Construct valid calldata
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _caller);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Mocking the call to the newIntent function
        mockNewIntent(_intent);

        // Sending the wrap transaction
        vm.startPrank(_caller);
        IERC20(_nativeToken.toAddress()).approve(address(wrapAdapter), _intent.amount);
        wrapAdapter.wrapAndSendIntent(_intent, IERC20(_nativeToken.toAddress()));
        vm.stopPrank();
        
        // Checking balance state - no funds transferred as mocked i.e. XERC20 balance will be in wrapAdapter
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(address(wrapAdapter)), 0);
        assertEq(IERC20(_xerc20token.toAddress()).balanceOf(address(wrapAdapter)), _xerc20Balance + _intent.amount);
    }

    /**
    * @notice Test that the wrap ETH call works
    * @param _intent The intent being forward to EverclearSpoke
    * @param _caller The caller of the function
    */
    function test_wrapAndSendIntent_ETHSuccess(IEverclear.Intent memory _intent, address _caller) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_caller != address(0));

        // WETH info
        _intent.inputAsset = WETH.toBytes32();

        // Construct valid calldata
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _caller);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Fetching the balances for the caller
        deal(_caller, _intent.amount);
        assertEq(_caller.balance, _intent.amount);

        // Mocking the call to the newIntent function
        mockWETHDeposit(_intent.amount);
        mockWETHApprove(address(wrapAdapter.everclearSpoke()), _intent.amount);
        mockNewIntent(_intent);

        // Sending the wrap transaction
        vm.startPrank(_caller);
        wrapAdapter.wrapAndSendIntent{value: _intent.amount}(_intent, IERC20(address(0)));
        vm.stopPrank();
    }

    function test_Revert_wrapAndSendIntent_InvalidCallReceiver(IEverclear.Intent memory _intent, address _caller) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_caller != address(0));

        // Configuring the callReceiver as invalid
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, address(0x123));
        _intent.data = abi.encode(address(0), _adapterCallbackCalldata);

        // Sending the wrap transaction
        vm.startPrank(_caller);
        vm.expectRevert(IWrapAdapter.Invalid_Call_Receiver.selector);
        wrapAdapter.wrapAndSendIntent(_intent, IERC20(address(0)));
        vm.stopPrank();
    }

    function test_Revert_wrapAndSentIntent_InvalidUnwrapReceiver(IEverclear.Intent memory _intent, address _caller) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_caller != address(0));

        // Configuring the unwrapReceiver as invalid
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, address(0));
        _intent.data = abi.encode(address(0x123), _adapterCallbackCalldata);

        // Sending the wrap transaction
        vm.startPrank(_caller);
        vm.expectRevert(IWrapAdapter.Invalid_Unwrap_Receiver.selector);
        wrapAdapter.wrapAndSendIntent(_intent, IERC20(address(0)));
        vm.stopPrank();
    }

    /**
    * @notice Test that wrapAndSendIntent reverts when amount is 0
    * @param _intent The intent 
    * @param _assetToWrap The asset to wrap
     */
    function test_Revert_wrapAndSendIntent_InvalidInputAmount(IEverclear.Intent memory _intent, IERC20 _assetToWrap, address _caller) public {
        vm.assume(_caller != address(0));
        _intent.amount = 0;

        // Construct valid calldata
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _caller);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        vm.expectRevert(IWrapAdapter.Invalid_Input_Amount.selector);
        wrapAdapter.wrapAndSendIntent(_intent, _assetToWrap);
    }

    function test_Revert_wrapAndSendIntent_InvalidLockbox(IEverclear.Intent memory _intent, address _caller) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_intent.amount < type(uint256).max / 2);
        vm.assume(_caller != address(0));

        /// Construct valid calldata
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _caller);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Deploying the XERC20 token
        (, bytes32 _xerc20token) = deployAndDealXERC20Native(address(wrapAdapter), _caller.toBytes32(), _intent.amount);
        _intent.inputAsset = _xerc20token;

        // Sending the wrap transaction - using an invalid native token to cause revert
        vm.startPrank(_caller);
        vm.expectRevert(IWrapAdapter.Invalid_Lockbox.selector);
        wrapAdapter.wrapAndSendIntent(_intent, IERC20(address(0x123)));
    }

   function test_Revert_wrapAndSendIntent_InvalidMsgValue(IEverclear.Intent memory _intent, address _caller) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_caller != address(0));

        // WETH info
        _intent.inputAsset = WETH.toBytes32();

        /// Construct valid calldata
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _caller);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Sending the wrap transaction
        vm.startPrank(_caller);
        vm.expectRevert(IWrapAdapter.Invalid_Msg_Value.selector);
        wrapAdapter.wrapAndSendIntent{value: 0}(_intent, IERC20(address(0)));
        vm.stopPrank();
    }
}


contract Unit_WrapAdapter_Unwrap is BaseTest {
    using TypeCasts for address;
    using TypeCasts for bytes32;

    function test_unwrap_XERC20Success(uint256 _amountOut, bytes32 _intentId, address _unwrapReceiver) public {
        vm.assume(_amountOut> 0);
        vm.assume(_unwrapReceiver != address(0));
        vm.assume(_amountOut < type(uint256).max / 2);

        // Deploy and deal XERC20
        (bytes32 _nativeToken, bytes32 _xerc20token) = deployAndDealXERC20Token(address(wrapAdapter), address(wrapAdapter).toBytes32(), _amountOut);
        address _outputAsset = _xerc20token.toAddress();
        assertEq(IERC20(_xerc20token.toAddress()).balanceOf(address(wrapAdapter)), _amountOut);
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(address(wrapAdapter)), 0);
        uint256 _nativeBalance = IERC20(_nativeToken.toAddress()).balanceOf(address(_unwrapReceiver));

        // Unwrapping the asset
        vm.startPrank(wrapAdapter.owner());
        wrapAdapter.unwrap(_outputAsset, _amountOut, _unwrapReceiver, _intentId);
        vm.stopPrank(); 

        // Checking state change
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(_unwrapReceiver), _nativeBalance + _amountOut);
    }

    function test_unwrap_WETH_Success(uint256 _amountOut, bytes32 _intentId) public {
        vm.assume(_amountOut> 0);
        address _unwrapReceiver = RECIPIENT;

        // Configuring output asset to be WETH
        address _outputAsset = WETH;

        // Storing the eth balance for the unwrapReceiver
        uint256 _nativeBalance = address(_unwrapReceiver).balance;

        // Mocking the expected calls
        mockWETHWithdraw(_amountOut);

        // Dealing the ETH amount that will be sent from wrapAdapter
        deal(address(wrapAdapter), _amountOut);

        // Unwrapping the asset
        vm.startPrank(wrapAdapter.owner());
        wrapAdapter.unwrap(_outputAsset, _amountOut, _unwrapReceiver, _intentId);
        vm.stopPrank(); 

        // Checking state change
        assertEq(address(_unwrapReceiver).balance, _nativeBalance + _amountOut);
    }

    function testRevert_unwrap_WETH_TransferETHFailure(uint256 _amountOut, bytes32 _intentId) public {
        vm.assume(_amountOut> 0);
        
        // Configuring unwrapReceiver as contract without receive fallback
        address _unwrapReceiver = address(new TestNoETHFallback());

        // Configuring output asset to be WETH
        address _outputAsset = WETH;

        // Mocking the expected calls
        mockWETHWithdraw(_amountOut);

        // Dealing the ETH amount that will be sent from wrapAdapter
        deal(address(wrapAdapter), _amountOut);

        // Unwrapping the asset
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(IWrapAdapter.Transfer_ETH_Failure.selector);
        wrapAdapter.unwrap(_outputAsset, _amountOut, _unwrapReceiver, _intentId);
        vm.stopPrank(); 
    }
}

contract Unit_WrapAdapter_DecodeArbitraryData is BaseTest {
    function test_decodeArbitraryData_EmptyData() public  {
        bytes memory _data = new bytes(0);

        (address _callReceiver, address _unwrapReceiver) = wrapAdapter.decodeArbitraryData(_data);
        assertEq(_callReceiver, address(0));
        assertEq(_unwrapReceiver, address(0));
    }

    function test_decodeArbitraryData_Not160(uint256 _byteSize) public  {
        vm.assume(_byteSize < 50000);
        vm.assume(_byteSize != 160);
        bytes memory _data = new bytes(_byteSize);

        (address _callReceiver, address _unwrapReceiver) = wrapAdapter.decodeArbitraryData(_data);
        assertEq(_callReceiver, address(0));
        assertEq(_unwrapReceiver, address(0));
    }

    function test_decodeArbitraryData_ValidBytes(address _unwrapReceiver) public  {
        address _callReceiver = address(wrapAdapter);

        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _unwrapReceiver);
        bytes memory _data = abi.encode(_callReceiver, _adapterCallbackCalldata);
        (address _decodedCallReceiver, address _decodedUnwrapReceiver) = wrapAdapter.decodeArbitraryData(_data);
        assertEq(_decodedCallReceiver, _callReceiver);
        assertEq(_decodedUnwrapReceiver, _unwrapReceiver);
    }
}