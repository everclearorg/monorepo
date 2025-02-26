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
    bool public entered;

    modifier onlySpoke() {
        if(msg.sender != address(everclearSpoke)) revert Invalid_Spoke_Caller(msg.sender);
        _;
    }

    // modifier entryUpdate() {
    //     if(entered == true) revert Invalid_Entry_State(); 
    //     entered = true;
    //     _;
    //     entered = false;
    // }

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

        // Check intent receiver is this, callReceiver is this, amount is valid, and unwrap receiver is non-zero
        if(_intent.receiver.toAddress() != address(this)) revert Invalid_Receiver(_intent.receiver.toAddress());
        if(_callReceiver != address(this)) revert Invalid_Callback(_callReceiver);
        if(_amountOut > _intent.amount) revert Invalid_Output_Amount();
        if(_unwrapReceiver == address(0)) revert Invalid_Receiver(_unwrapReceiver);

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

        // Emitting event once completed
        emit UnwrapClosed(_intentId, _outputAsset, _amountOut);
    }

    function adapterCallback(bytes memory) external view onlySpoke {}

    /*///////////////////////////////////////////////////////////////
                       EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    // NOTE: Lockbox is configured as an input - assuming some XERC20s may not be deployed via registry
    // TODO: IF we expect 100% of XERC20s will be deployed via Registry we will need to remove xERC20 balance check + add lockbox logic
    function wrapAndSendIntent(IEverclear.Intent calldata _intent, IERC20 _assetToWrap, IXERC20Lockbox _lockbox) external payable {
        if(_intent.amount == 0) revert Invalid_Input_Amount();

        if (address(_assetToWrap) != address(0)) {
            IERC20 _inputAsset = IERC20(_intent.inputAsset.toAddress());
            uint256 _inputBalance = _inputAsset.balanceOf(address(this));

            // Transferring to WrapAdapter and approving the lockbox
            _assetToWrap.safeTransferFrom(msg.sender, address(this), _intent.amount);
            _assetToWrap.approve(address(_lockbox), _intent.amount);

            // Executing the deposit to lockbox and approving the spoke
            _lockbox.deposit(_intent.amount);
            _inputAsset.approve(address(everclearSpoke), _intent.amount);

            // TODO: Checking the lockbox provided sent the expected amount of xERC20 back to the contract - may need to replace with registry logic
            if(_inputAsset.balanceOf(address(this)) != _inputBalance + _intent.amount) revert Invalid_Lockbox();
        } else {
            // Executing the deposit ETH and approving the spoke
            WETH.deposit{value: msg.value}();
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
            _lockbox.withdraw(_amountOut);
            _lockbox.ERC20().safeTransfer(_unwrapReceiver, _amountOut);
        } else {
            WETH.withdraw(_amountOut);
            (bool success, ) = payable(_unwrapReceiver).call{value: _amountOut}("");
            if(!success) revert Transfer_ETH_Failure();
        }

        emit UnwrapClosed(_intentId, _outputAsset, _amountOut);
    }

    function _decodeArbitraryData(bytes memory _data) internal pure returns (address _callReceiver, address _unwrapReceiver) {
        // Handling the callReceiver input
        bytes memory _calldata;
        if(_data.length < 32) return (address(0), address(0));
        else if(_data.length == 32) {
            (_callReceiver) = abi.decode(_data, (address));
            return (_callReceiver, address(0));
        } else if(_data.length > 32) {
            (_callReceiver, _calldata) = abi.decode(_data, (address, bytes));
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
}