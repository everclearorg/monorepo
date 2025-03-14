// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IEverclear} from '../common/IEverclear.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IXERC20Lockbox} from './IXERC20Lockbox.sol';

interface IWrapAdapter {
    /*///////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
    * @notice Emitted when EverclearSpoke address is updated
    * @param _oldSpoke The old spoke address
    * @param _newSpoke The new spoke address
     */
    event SpokeUpdated(address _oldSpoke, address _newSpoke);

    /**
    * @notice Emitted when relayers are updated
    * @param _relayers The list of relayers being updated
    * @param _status The status of the relayers
     */
    event RelayersUpdated(address[] _relayers, bool[] _status);

    /**
    * @notice Emitted when an intent that needs to be unwrapped is opened i.e. via sendUnwrapIntent
    * @param _intentId The ID of the intent
    * @param _intent The intent that was opened
    * @param _sender The address that sent the intent
     */
    event UnwrapOpened(bytes32 _intentId, IEverclear.Intent _intent, address _sender);

    /**
    * @notice Emitted when an intent is unwrapped
    * @param _intentId The ID of the intent
    * @param _outputAsset The output asset
    * @param _amountOut The amount of output asset
    * @param _receiver The address to send the output asset to
     */
    event UnwrapClosed(bytes32 _intentId, address _outputAsset, uint256 _amountOut, address _receiver);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
    * @notice Thrown when the intent status is not SETTLED
    */
    error Invalid_Status();

    /**
    * @notice Thrown when an input address is invalid
     */
    error Invalid_Address();

    /**
    * @notice Thrown when _unwrapAsset input is not ERC20() returned from lockbox
     */
    error Invalid_Lockbox();

    /**
    * @notice Thrown when ETH transfer fails
     */
    error Transfer_ETH_Failure();

    /**
    * @notice Thrown when input amount is zero
     */
    error Invalid_Input_Amount();

    /**
    * @notice Thrown when msg.value is not equal to the intent amount
     */
    error Invalid_Msg_Value();

    /**
    * @notice Thrown when output amount is more than original intent amount
     */
    error Invalid_Output_Amount();

    /**
    * @notice Thrown when the intent calldata is valid and unwrapInvalidIntent is called
     */
    error Invalid_Manual_Processing();

    /**
    * @notice Thrown when intent has already been processed with unwrapInvalidIntent
     */
    error Invalid_Already_Processed();

    /**
    * @notice Thrown when validataCalldata returns invalid callReceiver address
     */
    error Invalid_Call_Receiver();

    /**
    * @notice Thrown when unwrapReceiver is address(0)
     */
    error Invalid_Unwrap_Receiver();

    /**
    * @notice Thrown when function selector in calldata is not adapterCallback(bytes)
     */
    error Invalid_Selector();

    /**
    * @notice Thrown when outputAsset is bytes32(0)
     */
    error Invalid_Output_Asset();

    /**
    * @notice Thrown when intent array is not the same length as amountOut
     */
    error Invalid_Array_Length();

    /**
    * @notice Thrown when the callback is called but active is zer
     */
     error Invalid_Activity();

    /**
    * @notice Thrown when adapterCallback receives call from address that is not the configured spoke
     */
    error Invalid_Spoke_Caller(address _sender);

    /**
    * @notice Thrown when the receiver in the intent struct was not configured as the WrapAdapter
     */
    error Invalid_Receiver(address _receiver);

    /**
    * @notice Thrown when the address in the calldata is not the WrapAdapter
     */
    error Invalid_Callback(address _callback);

    /**
    *@notice Thrown when the signer recovered is not an approved relayer
     */
     error Invalid_Relayer(address _invalidSigner);

    /*///////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
    * @notice Updates the spoke address
    * @param _newSpoke The new spoke address
     */
    function updateEverclearSpoke(address _newSpoke) external;

    /**
    * @notice Batch unwraps intents and sends the output assets to the receivers
    * @param _intents Array of intents
    * @param _amountsOut Array of amounts to send to the receiver
     */
    function batchUnwrapIntent(IEverclear.Intent[] calldata _intents, uint256[] calldata _amountsOut, bytes[] calldata _signature) external;

    /**
    * @notice Unwrap an intent and send the output asset to the receiver
    * @param _intent The intent to unwrap
    * @param _amountOut The amount of output asset to send to the receiver
     */
    function unwrapIntent(IEverclear.Intent calldata _intent, uint256 _amountOut, bytes calldata _signature) external;

    /**
    * @notice Wraps an intent and calls newIntent on the spoke
    * @dev This will revert if the _assetToWrap is not the correct XERC20 or invalid msg.value is sent for WETH path
    * @param _intent The intent to send to newIntent
    * @param _assetToWrap The asset to wrap
     */
    function wrapAndSendIntent(IEverclear.Intent calldata _intent, IERC20 _assetToWrap, bool _shouldUnwrap) external payable returns (bytes32 _intentId);

    /**
    * @notice Sends an unwrap intent to the spoke
    * @dev Checks calldata is valid and emits UnwrapOpened event
    * @param _intent The intent to send to newIntent
     */
    function sendUnwrapIntent(IEverclear.Intent calldata _intent) external returns (bytes32 _intentId);

    /**
    * @notice Callback function used by EverclearSpoke
    * @dev OnlySpoke modifier will lead to reverts for calls from any other address
    * @dev Data field is unusued in this implementation
    * @param _data The data to pass to the adapter
    */
    function adapterCallback(bytes memory _data) external;

    /**
    * @notice Unwrap an invalid intent and send the output asset to the receiver
    * @dev Intent is invalid if the calldata is configured incorrectly i.e. callReceiver not address(this), receiver is address(0), and/or selector not adapterCallback(bytes)
    * @param _intent The intent to unwrap
    * @param _amount The amount of input asset to send to the receiver
    * @param _receiver The address to send the output asset to
     */
    function unwrapInvalidIntent(IEverclear.Intent calldata _intent, uint256 _amount, address _receiver, bytes calldata _signature) external;

    /**
    * @notice Validates the calldata in the intent
    * @param _intent The intent to validate
     */
    function validateIntentCalldata(IEverclear.Intent memory _intent) external view;
}