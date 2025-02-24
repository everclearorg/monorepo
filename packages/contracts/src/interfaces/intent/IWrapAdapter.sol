// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IEverclear} from '../common/IEverclear.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IXERC20Lockbox} from './IXERC20Lockbox.sol';

interface IWrapAdapter {
    function updateEverclearSpoke(address _newSpoke) external;

    function unwrapAsset(IEverclear.Intent calldata _intent, uint256 _amountOut) external;

    function wrapAndSendIntent(IEverclear.Intent calldata _intent, IERC20 _assetToWrap, IXERC20Lockbox _lockbox) external payable;

    function everclearSpokeCallback(bytes memory _data) external;

    // Events
    event SpokeUpdated(address _oldSpoke, address _newSpoke);
    event UnwrapOpened(bytes32 _intentId, IEverclear.Intent _intent);
    event UnwrapClosed(bytes32 _intentId, address _outputAsset, uint256 _amountOut);

    // Errors
    error Invalid_Address();
    error Invalid_Lockbox();
    error Transfer_ETH_Failure();
    error Invalid_Input_Amount();
    error Invalid_Output_Amount();
    error Invalid_Spoke_Caller(address _sender);
    error Invalid_Receiver(address _receiver);
    error Invalid_Callback(address _callback);
}