// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { Address } from '@openzeppelin/contracts/utils/Address.sol';
import { Ownable2Step, Ownable } from '@openzeppelin/contracts/access/Ownable2Step.sol';

import { TypeCasts } from 'contracts/common/TypeCasts.sol';

import { IEverclear } from 'interfaces/common/IEverclear.sol';
import { IFeeAdapter } from 'interfaces/intent/IFeeAdapter.sol';
import { IEverclearSpoke } from 'interfaces/intent/IEverclearSpoke.sol';
import { ISpokeGateway } from 'interfaces/intent/ISpokeGateway.sol';

contract FeeAdapter is IFeeAdapter, Ownable2Step {
  ////////////////////
  //// Libraries /////
  ////////////////////
  using SafeERC20 for IERC20;
  using TypeCasts for address;
  using TypeCasts for bytes32;

  ////////////////////
  ///// Storage //////
  ////////////////////

  /// @inheritdoc IFeeAdapter
  IEverclearSpoke public spoke;

  /// @inheritdoc IFeeAdapter
  address public feeRecipient;

  ////////////////////
  /// Constructor ////
  ////////////////////
  constructor(address _spoke, address _feeRecipient, address _owner) Ownable(_owner) {
    spoke = IEverclearSpoke(_spoke);
    _updateFeeRecipient(_feeRecipient);
  }

  ////////////////////
  ////// Admin ///////
  ////////////////////

  /// @inheritdoc IFeeAdapter
  function updateFeeRecipient(address _feeRecipient) external onlyOwner {
    _updateFeeRecipient(_feeRecipient);
  }

  ////////////////////
  ///// External /////
  ////////////////////

  /// @inheritdoc IFeeAdapter
  function newIntent(
    uint32[] memory _destinations,
    address _receiver,
    address _inputAsset,
    address _outputAsset,
    uint256 _amount,
    uint24 _maxFee,
    uint48 _ttl,
    bytes calldata _data,
    uint256 _fee
  ) external payable returns (bytes32 _intentId, IEverclear.Intent memory _intent) {
    // Transfer from caller
    _pullTokens(msg.sender, _inputAsset, _amount + _fee);

    // Send fees to recipient
    _handleFees(_fee, msg.value, _inputAsset);

    // Approve the spoke contract if needed
    _approveSpokeIfNeeded(_inputAsset, _amount);

    // Create new intent
    (bytes32 _intentId, IEverclear.Intent memory _intent) = spoke.newIntent(
      _destinations,
      _receiver,
      _inputAsset,
      _outputAsset,
      _amount,
      _maxFee,
      _ttl,
      _data
    );

    // Emit event
    emit IntentWithFeesAdded(_intentId, msg.sender.toBytes32(), _fee, msg.value);
    return (_intentId, _intent);
  }

  ////////////////////
  ///// Internal /////
  ////////////////////

  /**
   * @notice Updates the fee recipient
   * @param _feeRecipient New recipient
   */
  function _updateFeeRecipient(address _feeRecipient) internal {
    emit FeeRecipientUpdated(_feeRecipient, feeRecipient);
    feeRecipient = _feeRecipient;
  }

  /**
   * @notice Sends fees to recipient
   * @param _tokenFee Amount in transacting asset to send to recipient
   * @param _nativeFee Amount in native asset to send to recipient
   */
  function _handleFees(uint256 _tokenFee, uint256 _nativeFee, address _inputAsset) internal {
    // Handle token fees if exist
    if (_tokenFee > 0) {
      _pushTokens(feeRecipient, _inputAsset, _tokenFee);
    }

    // Handle native tokens
    if (_nativeFee > 0) {
      Address.sendValue(payable(feeRecipient), _nativeFee);
    }
  }

  /**
   * @notice Approves the maximum uint value to the gateway.
   * @dev Approving the max reduces gas for following intents.
   * @param _asset Asset to approve to spoke.
   * @param _minimum Minimum required approval budget.
   */
  function _approveSpokeIfNeeded(address _asset, uint256 _minimum) internal {
    // Approve the spoke contract if needed
    IERC20 _token = IERC20(_asset);
    uint256 _current = _token.allowance(address(this), address(spoke));
    if (_current >= _minimum) {
      return;
    }

    // Approve to 0
    if (_current != 0) {
      _token.safeDecreaseAllowance(address(spoke), _current);
    }

    // Approve to max
    _token.safeIncreaseAllowance(address(spoke), type(uint256).max);
  }

  /**
   * @notice Pull tokens from the sender to the contract
   * @param _sender The address of the sender
   * @param _asset The address of the asset
   * @param _amount The amount of the asset
   */
  function _pullTokens(address _sender, address _asset, uint256 _amount) internal {
    IERC20(_asset).safeTransferFrom(_sender, address(this), _amount);
  }

  /**
   * @notice Push tokens from the contract to the recipient
   * @param _recipient The address of the recipient
   * @param _asset The address of the asset
   * @param _amount The amount of the asset
   */
  function _pushTokens(address _recipient, address _asset, uint256 _amount) internal {
    IERC20(_asset).safeTransfer(_recipient, _amount);
  }
}
