// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {WrapAdapter} from 'contracts/intent/WrapAdapter.sol';
import {TestExtended} from '../../utils/TestExtended.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IXERC20} from 'interfaces/common/IXERC20.sol';
import {StdStorage, stdStorage} from 'test/utils/TestExtended.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {IWrapAdapter} from 'interfaces/intent/IWrapAdapter.sol';

contract BaseTest is TestExtended {
    using stdStorage for StdStorage;

    WrapAdapter public wrapAdapter;

    address immutable WETH = makeAddr("WETH");
    address immutable OWNER = makeAddr("OWNER");
    address immutable SPOKE = makeAddr("SPOKE");
    address immutable RECIPIENT = makeAddr("RECIPIENT");

    function setUp() public {
        wrapAdapter = new WrapAdapter(SPOKE, WETH, OWNER);
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

contract Unit_WrapAdapter_WrapAndSendIntent is BaseTest {
    /**
    * @notice Test that the wrap XERC20 call works
    * @param _intent The intent being forward to EverclearSpoke
    * @param _caller The caller of the function
    */
    function test_wrapAndSendIntent_XERC20(IEverclear.Intent memory _intent, address _caller) public {
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

contract Unit_WrapAdapter_UnwrapIntent is BaseTest {}