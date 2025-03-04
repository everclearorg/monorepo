// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IEverclear} from '../../interfaces/common/IEverclear.sol';
import {IEverclearSpoke} from '../../interfaces/intent/IEverclearSpoke.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IWETH} from '../../interfaces/intent/IWETH.sol';
import {IXERC20} from '../../interfaces/intent/IXERC20.sol';
import {IXERC20Lockbox} from '../../interfaces/intent/IXERC20Lockbox.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {IWrapAdapter} from '../../interfaces/intent/IWrapAdapter.sol';

contract WrapAdapter is IWrapAdapter, Ownable {
    using SafeERC20 for IERC20;
    using TypeCasts for bytes32;
    
    IWETH public immutable WETH;
    IEverclearSpoke public everclearSpoke;

    mapping(bytes32 => bool) public manuallyProcessed;

    modifier onlySpoke() {
        if(msg.sender != address(everclearSpoke)) revert Invalid_Spoke_Caller(msg.sender);
        _;
    }

    constructor(address _weth, address _spoke, address _owner) Ownable(_owner) {
        if(_spoke == address(0)) revert Invalid_Address();
        everclearSpoke = IEverclearSpoke(_spoke);
        WETH = IWETH(_weth);
    }

    /*///////////////////////////////////////////////////////////////
                       PERMISSIONED FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function updateEverclearSpoke(address _newSpoke) external onlyOwner {
        if(_newSpoke == address(0)) revert Invalid_Address();

        address _oldSpoke = address(everclearSpoke);
        everclearSpoke = IEverclearSpoke(_newSpoke);

        emit SpokeUpdated(_oldSpoke, _newSpoke);
    }

    function unwrapAsset(IEverclear.Intent calldata _intent, uint256 _amountOut) external onlyOwner {
        // Updating state and configure variables used
        address _outputAsset = _intent.outputAsset.toAddress();
        (address _callReceiver, address _unwrapReceiver) = _decodeArbitraryData(_intent.data);

        // Check intent receiver is this, callReceiver is this, amount is val id, and unwrap receiver is non-zero
        if(_intent.receiver.toAddress() != address(this)) revert Invalid_Receiver(_intent.receiver.toAddress());
        if(_callReceiver != address(this)) revert Invalid_Callback(_callReceiver);
        if(_amountOut > _intent.amount) revert Invalid_Output_Amount();
        if(_unwrapReceiver == address(0)) revert Invalid_Unwrap_Receiver();

        // Execute on spoke - update status and executes callback - reverts if !SETTLED
        everclearSpoke.executeIntentCalldata(_intent);

        // Unwrapping and emitting
        bytes32 _intentId = keccak256(abi.encode(_intent));
        _unwrap(_outputAsset, _amountOut, _unwrapReceiver, _intentId);
    }

    function unwrapInvalidCalldata(IEverclear.Intent calldata _intent, uint256 _amountOut, address _receiver) external onlyOwner {        
        // Updating state and configure variables used
        address _outputAsset = _intent.outputAsset.toAddress();
        bytes32 _intentId = keccak256(abi.encode(_intent));

        // Checking if already processed
        if(manuallyProcessed[_intentId]) revert Invalid_Already_Processed();
        manuallyProcessed[_intentId] = true;

        // Attempting to decode bytes - processing
        (address _callReceiver, address _unwrapReceiver) = _decodeArbitraryData(_intent.data);

        // Check intent receiver is this, callReceiver is !this OR !unwrap receiver, amount is valid, and intent status is settled
        if(_intent.receiver.toAddress() != address(this)) revert Invalid_Receiver(_intent.receiver.toAddress());
        if(_amountOut > _intent.amount) revert Invalid_Output_Amount();
        
        // Checks the calldata data is invald i.e. should be manually processed
        if(_callReceiver == address(this) && _unwrapReceiver != address(0)) revert Invalid_Manual_Processing();

        // Checks status is SETTLED
        if(everclearSpoke.status(_intentId) != IEverclear.IntentStatus.SETTLED) revert Invalid_Status();

        // Unwraps to an input receiver
        _unwrap(_outputAsset, _amountOut, _receiver, _intentId);
    }

    function adapterCallback(bytes memory) external view onlySpoke {}

    /*///////////////////////////////////////////////////////////////
                       EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function wrapAndSendIntent(IEverclear.Intent calldata _intent, IERC20 _wrapAsset) external payable {
        if(_intent.amount == 0) revert Invalid_Input_Amount();

        // Validating the calldata is correct size and configured with non-zeroed addresses
        _validateCalldata(_intent.data);

        if (address(_wrapAsset) != address(0)) {
            IERC20 _inputAsset = IERC20(_intent.inputAsset.toAddress());

            // Fetching lockbox linked to xERC20 and confirming wrapAsset is correct ERC20
            IXERC20Lockbox _lockbox = IXERC20Lockbox(IXERC20(address(_inputAsset)).lockbox());
            if(_lockbox.ERC20() != _wrapAsset) revert Invalid_Lockbox();

            // Approving the wrapAsset and depositing into the lockbox
            _wrapAsset.safeTransferFrom(msg.sender, address(this), _intent.amount);
            _wrapAsset.approve(address(_lockbox), _intent.amount);
            _lockbox.deposit(_intent.amount);

            // Given EverclearSpoke allowance
            _inputAsset.approve(address(everclearSpoke), _intent.amount);
        } else {
            // Executing the deposit ETH and approving the spoke
            if(msg.value != _intent.amount) revert Invalid_Msg_Value();
            WETH.deposit{value: _intent.amount}();
            WETH.approve(address(everclearSpoke), _intent.amount);
        }

        // Executing the new intent on the Spoke
        everclearSpoke.newIntent(_intent.destinations, _intent.receiver.toAddress(), _intent.inputAsset.toAddress(), _intent.outputAsset.toAddress(), _intent.amount, _intent.maxFee, _intent.ttl, _intent.data);
	       
        // Emitting an unwrap event with the intent info and Id
        bytes32 _intentId = keccak256(abi.encode(_intent));
        emit UnwrapOpened(_intentId, _intent);
    }

    /*///////////////////////////////////////////////////////////////
                       EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _unwrap(address _outputAsset, uint256 _amountOut, address _unwrapReceiver, bytes32 _intentId) internal {
        // Unwrapping WETH or xERC20        
        if(_outputAsset != address(WETH)) {
            // Fetching lockbox info
            IXERC20Lockbox _lockbox = IXERC20Lockbox(IXERC20(_outputAsset).lockbox());

            // Approving the lockbox and withdrawing the xERC20
            IERC20(_outputAsset).approve(address(_lockbox), _amountOut);
            _lockbox.withdraw(_amountOut);
            _lockbox.ERC20().safeTransfer(_unwrapReceiver, _amountOut);
        } else {
            WETH.withdraw(_amountOut);
            (bool success, ) = payable(_unwrapReceiver).call{value: _amountOut}("");
            if(!success) revert Transfer_ETH_Failure();
        }

        emit UnwrapClosed(_intentId, _outputAsset, _amountOut);
    }

    function _decodeArbitraryData(bytes memory _data) internal returns (address _callReceiver, address _unwrapReceiver) {
        // Handling the callReceiver input
        bytes memory _calldata;
        if(_data.length == 160) {
            (_callReceiver, _calldata) = abi.decode(_data, (address, bytes));
        } else {
            return (address(0), address(0));
        }
        
        // Handling the additional data input
        if(_calldata.length == 36) {
            // Fetch the address from remaining 32 bytes
            assembly {
                // Read word starting 4 bytes later - address will occupy lower 20 bytes of 32-byte word
                let addressWord := mload(add(_calldata, 0x24))
                // Shift top 12 bytes (96 bits) so that the lower 20 bytes is a proper address.
                _unwrapReceiver := and(addressWord, 0xffffffffffffffffffffffffffffffffffffffff)
            }
            return (_callReceiver, _unwrapReceiver);
        } else {
            return (_callReceiver, address(0));
        }
    }

    function _validateCalldata(bytes memory _data) internal {
        (address _callReceiver, address _unwrapReceiver) = _decodeArbitraryData(_data);
        if(_callReceiver == address(0)) revert Invalid_Call_Receiver();
        if(_unwrapReceiver == address(0)) revert Invalid_Unwrap_Receiver();
    }
}