// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {WrapAdapter} from 'contracts/intent/WrapAdapter.sol';
import {TestExtended} from '../../utils/TestExtended.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IXERC20} from 'interfaces/common/IXERC20.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {IWrapAdapter} from 'interfaces/intent/IWrapAdapter.sol';

import {StdStorage, stdStorage} from 'test/utils/TestExtended.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

contract TestWrapAdapter is WrapAdapter {
    constructor(address _weth, address _spoke, address _owner) WrapAdapter(_weth, _spoke, _owner) {}
    function unwrap(address _outputAsset, uint256 _amountOut, address _unwrapReceiver, bytes32 _intentId) external {
        _unwrap(_outputAsset, _amountOut, _unwrapReceiver, _intentId);
    }

    function decodeArbitraryData(bytes calldata _data) external pure returns (address, address) {
        return _decodeArbitraryData(_data);
    }
}

contract BaseTest is TestExtended {
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
    function mockNewIntent(
        IEverclear.Intent memory _intent
    ) internal {
        // vm.mockCall(
        // ASSET, abi.encodeWithSelector(IEverclearSpoke.newIntent.selector, address(wrapAdapter)), abi.encode(_intent.destinations, _intent.receiver.toAddress(), _intent.inputAsset.toAddress(), _intent.outputAsset.toAddress(), _intent.amount, _intent.maxFee, _intent.ttl, _intent.data)
        // );
  }
}

contract Unit_WrapAdapter_UpdateSpoke is BaseTest {    
    event SpokeUpdated(address _oldSpoke, address _newSpoke);

    function test_updateEverclearSpoke(address _newSpoke) public {
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

    function test_Revert_updateEverclearSpoke_InvalidAddress(address _newSpoke) public {
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(IWrapAdapter.Invalid_Address.selector);
        wrapAdapter.updateEverclearSpoke(_newSpoke);
        vm.stopPrank();
    }
}

contract Unit_WrapAdapter_UnwrapIntent is BaseTest {
    using TypeCasts for bytes32;
    using TypeCasts for address;

    function test_unwrapIntent_XERC20Success(IEverclear.Intent memory _intent, uint256 _amountOut, address _unwrapReceiver) public {
        vm.assume(_intent.amount > 0);
        vm.assume(_amountOut <= _intent.amount);
        vm.assume(_unwrapReceiver != address(0));

        // Configure data - receiver + callReceiver are wrapAdapter and unwrapReceiver != address(0)
        _intent.receiver = address(wrapAdapter).toBytes32();
        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _unwrapReceiver);
        _intent.data = abi.encode(address(wrapAdapter), _adapterCallbackCalldata);

        // Deploy and deal XERC20
        (bytes32 _nativeToken, bytes32 _xerc20token) = deployAndDealXERC20Native(address(wrapAdapter).toBytes32(), _amountOut);
        _intent.outputAsset = _xerc20token;
        assertEq(IERC20(_xerc20token.toAddress()).balanceOf(address(wrapAdapter)), _intent.amount);
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(address(wrapAdapter)), 0);
        uint256 _nativeBalance = IERC20(_nativeToken.toAddress()).balanceOf(address(_unwrapReceiver));

        wrapAdapter.unwrapAsset(_intent, _amountOut);
        assertEq(IERC20(_nativeToken.toAddress()).balanceOf(_unwrapReceiver), _nativeBalance + _amountOut);
    }
}

contract Unit_WrapAdapter_UnwrapInvalidCalldata is BaseTest {
    using TypeCasts for address;
    using TypeCasts for bytes32;

    function test_unwrapInvalidCalldata_IncorrectCallReceiver(IEverclear.Intent memory _intent, uint256 _amount, address _receiver) public {}

    function test_unwrapInvalidCalldata_EmptyUnwrapReceiver(IEverclear.Intent memory _intent, uint256 _amount, address _receiver) public {}
    
    function test_Revert_unwrapInvalidCalldata_OnlyOwner(IEverclear.Intent memory _intent, uint256 _amount, address _receiver) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        wrapAdapter.unwrapInvalidCalldata(_intent, _amount, _receiver);
    }

    function test_Revert_unwrapInvalidCalldata_InvalidReceiver(IEverclear.Intent memory _intent, uint256 _amount, address _receiver) public {
        vm.assume(_intent.receiver.toAddress() != address(wrapAdapter));
        
        vm.startPrank(wrapAdapter.owner());
        vm.expectRevert(abi.encodeWithSelector(IWrapAdapter.Invalid_Receiver.selector, _intent.receiver.toAddress()));
        wrapAdapter.unwrapInvalidCalldata(_intent, _amount, _receiver);
        vm.stopPrank();
    }

    function test_Revert_unwrapInvalidCalldata_InvalidOutputAmount(IEverclear.Intent memory _intent, uint256 _amount, address _receiver) public {}

    function test_Revert_unwrapInvalidCalldata_InvalidManualProcessing(IEverclear.Intent memory _intent, uint256 _amount, address _receiver) public {}

    function test_Revert_unwrapInvalidCalldata_InvalidStatus(IEverclear.Intent memory _intent, uint256 _amount, address _receiver) public {}

}

contract Unit_WrapAdapter_AdapterCallback is BaseTest {
    function test_Revert_adapterCallback_InvalidSpokeCaller() public {
        bytes memory _message;

        vm.expectRevert(abi.encodeWithSelector(IWrapAdapter.Invalid_Spoke_Caller.selector, address(this)));
        wrapAdapter.adapterCallback(_message);
    }

    function test_Revert_adapterCallback_StorageEmpty() public {
        bytes memory _message;

        vm.startPrank(address(wrapAdapter.everclearSpoke()));
        vm.expectRevert();
        wrapAdapter.adapterCallback(_message);
        vm.stopPrank();
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
    function test_wrapAndSendIntent_XERC20(IEverclear.Intent memory _intent, address _caller) public {
        vm.assume(_intent.amount > 0);

        bytes32 _token = deployAndDeal(_caller, _intent.amount);
        assertEq(IERC20(_token.toAddress()).balanceOf(_caller), _intent.amount);
    }

    /**
    * @notice Test that the wrap ETH call works
    * @param _intent The intent being forward to EverclearSpoke
    * @param _caller The caller of the function
    */
    function test_wrapAndSendIntent_ETH(IEverclear.Intent memory _intent, address _caller) public {}

    /**
    * @notice Test that wrapAndSendIntent reverts when amount is 0
    * @param _intent The intent 
    * @param _caller The caller of the function
     */
    function test_Revert_wrapAndSendIntent_InvalidInputAmount(IEverclear.Intent memory _intent, address _caller) public {
        _intent.amount = 0;

        vm.expectRevert(IWrapAdapter.Invalid_Input_Amount.selector);

        vm.prank(_caller);
        // wrapAdapter.wrapAndSendIntent(_intent, _assetToWrap, _lockbox);
    }
}


contract Unit_WrapAdapter_Unwrap is BaseTest {}

contract Unit_WrapAdapter_DecodeArbitraryData is BaseTest {
    function test_decodeArbitraryData_EmptyData(uint256 _byteSize) public view {
        vm.assume(_byteSize < 32);
        bytes memory _data = new bytes(_byteSize);

        (address _callReceiver, address _unwrapReceiver) = wrapAdapter.decodeArbitraryData(_data);
        assertEq(_callReceiver, address(0));
        assertEq(_unwrapReceiver, address(0));
    }

    function test_decodeArbitraryData_CallReceiverOnly() public view {
        address _callReceiver = address(wrapAdapter);

        bytes memory _data = abi.encode(_callReceiver);
        (address _decodedCallReceiver, address _unwrapReceiver) = wrapAdapter.decodeArbitraryData(_data);
        assertEq(_decodedCallReceiver, _callReceiver);
        assertEq(_unwrapReceiver, address(0));
    }

    function test_decodeArbitraryData_CallReceiverAndReceiver(address _unwrapReceiver) public view {
        address _callReceiver = address(wrapAdapter);

        bytes memory _adapterCallbackCalldata = abi.encodeWithSelector(WrapAdapter.adapterCallback.selector, _unwrapReceiver);
        bytes memory _data = abi.encode(_callReceiver, _adapterCallbackCalldata);
        (address _decodedCallReceiver, address _decodedUnwrapReceiver) = wrapAdapter.decodeArbitraryData(_data);
        assertEq(_decodedCallReceiver, _callReceiver);
        assertEq(_decodedUnwrapReceiver, _unwrapReceiver);
    }

    function test_decodeArbitraryData_CallReceiverAndInvalidLargeBytes(uint256 _byteSize) public view {
        vm.assume(_byteSize > 36);

        address _callReceiver = address(wrapAdapter);
        bytes memory _calldata = new bytes(_byteSize);

        bytes memory _data = abi.encode(_callReceiver, _calldata);
        (address _decodedCallReceiver, address _unwrapReceiver) = wrapAdapter.decodeArbitraryData(_data);
        assertEq(_decodedCallReceiver, _callReceiver);
        assertEq(_unwrapReceiver, address(0));
    }

    function test_decodeArbitraryData_CallReceiverAndInvalidSmallBytes(uint256 _byteSize) public view {
        vm.assume(_byteSize < 36);

        address _callReceiver = address(wrapAdapter);
        bytes memory _calldata = new bytes(_byteSize);

        bytes memory _data = abi.encode(_callReceiver, _calldata);
        (address _decodedCallReceiver, address _unwrapReceiver) = wrapAdapter.decodeArbitraryData(_data);
        assertEq(_decodedCallReceiver, _callReceiver);
        assertEq(_unwrapReceiver, address(0));
    }
}