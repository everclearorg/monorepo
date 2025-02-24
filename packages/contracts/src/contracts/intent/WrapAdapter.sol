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
        // Storing the amountOut in transien1PtStorage
        assembly {
            tstore(0, 1)
        }

        // Expect the receiver of the intent ot be this address
        if(_intent.receiver.toAddress() != address(this)) revert Invalid_Receiver(_intent.receiver.toAddress());

        // Expect the calldata to execute everclearSpokeCallback
        (address _callReceiver, ) = abi.decode(_intent.data, (address, bytes));
        if(_callReceiver != address(this)) revert Invalid_Callback(_callReceiver);

        // NOTE: This will revert if the intent hasn't been marked as SETTLED on this chain
        everclearSpoke.executeIntentCalldata(_intent);

        // Checking the amount being sent is less than the amountOut
        // NOTE: May not be the case if receiving rewards
        if(_amountOut > _intent.amount) revert Invalid_Output_Amount();
        
        // TODO: Will need to decode the receiver from calldata or similar 
        address _receiver = address(0);
        if(_receiver == address(0)) revert Invalid_Receiver(_receiver);
        
        address _outputAsset = _intent.outputAsset.toAddress();
        if(_outputAsset != address(WETH)) {
            // Fetching lockbox info
            IXERC20Lockbox _lockbox = IXERC20Lockbox(IXERC20(_outputAsset).lockbox());
            _lockbox.withdraw(_amountOut);
            _lockbox.ERC20().safeTransfer(_receiver, _amountOut);
        } else {
            WETH.withdraw(_amountOut);
            (bool success, ) = payable(_receiver).call{value: _amountOut}("");
            if(!success) revert Transfer_ETH_Failure();
        }

        // Clearing transient storage
        assembly {
            tstore(0, 0)
        }
				
		// Emitting event once completed
        bytes32 _intentId = keccak256(abi.encode(_intent));
        emit UnwrapClosed(_intentId, _outputAsset, _amountOut);
    }

    function everclearSpokeCallback(bytes memory) external view onlySpoke {
        assembly {
            if tload(0) { revert(0, 0) }
        }
    }

    /*///////////////////////////////////////////////////////////////
                       EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    // NOTE: Lockbox is configured as an input - assuming some XERC20s may not be deployed via registry
    // TODO: IF we expect 100% of XERC20s will be deployed via Registry we will need to remove xERC20 balance check + add lockbox logic
    function wrapAndSendIntent(IEverclear.Intent calldata _intent, IERC20 _assetToWrap, IXERC20Lockbox _lockbox) external payable {
        if(_intent.amount == 0) revert Invalid_Input_Amount();

        if (address(_assetToWrap) != address(0)) {
            // TODO: Caching the xERC20 balance of the address - may need to replace with registry logic
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
}