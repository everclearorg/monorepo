// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable, Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IPermit2} from 'interfaces/common/IPermit2.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {IFeeAdapter} from 'interfaces/intent/IFeeAdapter.sol';

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
  IEverclearSpoke public immutable spoke;

  // @inheritdoc IFeeAdapter
  address public immutable xerc20Module;

  /// @inheritdoc IFeeAdapter
  address public feeRecipient;

  /// @inheritdoc IFeeAdapter
  IPermit2 public constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

  ////////////////////
  /// Constructor ////
  ////////////////////
  constructor(address _spoke, address _feeRecipient, address _xerc20Module, address _owner) Ownable(_owner) {
    spoke = IEverclearSpoke(_spoke);
    xerc20Module = _xerc20Module;
    _updateFeeRecipient(_feeRecipient);
  }

  ////////////////////
  ////// Admin ///////
  ////////////////////

  /// @inheritdoc IFeeAdapter
  function updateFeeRecipient(
    address _feeRecipient
  ) external onlyOwner {
    _updateFeeRecipient(_feeRecipient);
  }

  /// @inheritdoc IFeeAdapter
  function returnUnsupportedIntent(address _asset, uint256 _amount, address _recipient) external onlyOwner {
    spoke.withdraw(_asset, _amount);
    _pushTokens(_recipient, _asset, _amount);
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

    // Create intent
    (_intentId, _intent) =
      _newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, _maxFee, _ttl, _data, _fee);
  }

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
    IEverclearSpoke.Permit2Params calldata _permit2Params,
    uint256 _fee
  ) external payable returns (bytes32 _intentId, IEverclear.Intent memory _intent) {
    // Transfer from caller using permit2
    _pullWithPermit2(_inputAsset, _amount + _fee, _permit2Params);

    // Call internal helper to create intent
    (_intentId, _intent) =
      _newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, _maxFee, _ttl, _data, _fee);
  }

  /// @inheritdoc IFeeAdapter
  function newOrderSplitEvenly(
    uint32 _numIntents,
    uint256 _fee,
    OrderParameters memory _params
  ) external payable returns (bytes32 _orderId, bytes32[] memory _intentIds) {
    // Transfer once from the user
    _pullTokens(msg.sender, _params.inputAsset, _params.amount + _fee);

    // Send fees to recipient
    _handleFees(_fee, msg.value, _params.inputAsset);

    // Approve the spoke contract if needed
    _approveSpokeIfNeeded(_params.inputAsset, _params.amount);

    // Initialising array length
    _intentIds = new bytes32[](_numIntents);

    // Create `_numIntents` intents with the same params and `_amount` divided
    // equally across all created intents.
    uint256 _toSend = _params.amount / _numIntents;
    for (uint256 i; i < _numIntents - 1; i++) {
      // Create new intent
      (bytes32 _intentId,) = spoke.newIntent(
        _params.destinations,
        _params.receiver,
        _params.inputAsset,
        _params.outputAsset,
        _toSend,
        _params.maxFee,
        _params.ttl,
        _params.data
      );
      _intentIds[i] = _intentId;
    }

    // Create a final intent here with the remainder of balance
    (bytes32 _intentId,) = spoke.newIntent(
      _params.destinations,
      _params.receiver,
      _params.inputAsset,
      _params.outputAsset,
      _params.amount - (_toSend * (_numIntents - 1)), // handles remainder gracefully
      _params.maxFee,
      _params.ttl,
      _params.data
    );

    // Add to array
    _intentIds[_numIntents - 1] = _intentId;

    // Calculate order id
    _orderId = keccak256(abi.encode(_intentIds));

    // Emit order information event
    emit OrderCreated(_orderId, msg.sender.toBytes32(), _intentIds, _fee, msg.value);
  }

  /// @inheritdoc IFeeAdapter
  function newOrder(
    uint256 _fee,
    OrderParameters[] memory _params
  ) external payable returns (bytes32 _orderId, bytes32[] memory _intentIds) {
    uint256 _numIntents = _params.length;

    {
      // Get the asset
      address _asset = _params[0].inputAsset;

      // Get the sum of the order amounts
      uint256 _orderSum;
      for (uint256 i; i < _numIntents; i++) {
        _orderSum += _params[i].amount;
        if (_params[i].inputAsset != _asset) {
          revert MultipleOrderAssets();
        }
      }

      // Transfer once from the user
      _pullTokens(msg.sender, _asset, _orderSum + _fee);

      // Approve the spoke contract if needed
      _approveSpokeIfNeeded(_asset, _orderSum);

      // Send fees to recipient
      _handleFees(_fee, msg.value, _asset);
    }

    // Initialising array length
    _intentIds = new bytes32[](_numIntents);
    for (uint256 i; i < _numIntents; i++) {
      // Create new intent
      (bytes32 _intentId,) = spoke.newIntent(
        _params[i].destinations,
        _params[i].receiver,
        _params[i].inputAsset,
        _params[i].outputAsset,
        _params[i].amount,
        _params[i].maxFee,
        _params[i].ttl,
        _params[i].data
      );
      _intentIds[i] = _intentId;
    }

    // Calculate order id
    _orderId = keccak256(abi.encode(_intentIds));

    // Emit order event
    emit OrderCreated(_orderId, msg.sender.toBytes32(), _intentIds, _fee, msg.value);
  }

  ////////////////////
  ///// Internal /////
  ////////////////////

  /**
   * @notice Internal function to create a new intent
   * @param _destinations Array of destination chain IDs
   * @param _receiver Address of the receiver on the destination chain
   * @param _inputAsset Address of the input asset
   * @param _outputAsset Address of the output asset
   * @param _amount Amount of input asset to transfer
   * @param _maxFee Maximum fee in basis points that can be charged
   * @param _ttl Time-to-live for the intent
   * @param _data Additional data for the intent
   * @param _fee Fee amount to be sent to the fee recipient
   * @return _intentId The ID of the created intent
   * @return _intent The created intent object
   */
  function _newIntent(
    uint32[] memory _destinations,
    address _receiver,
    address _inputAsset,
    address _outputAsset,
    uint256 _amount,
    uint24 _maxFee,
    uint48 _ttl,
    bytes calldata _data,
    uint256 _fee
  ) internal returns (bytes32 _intentId, IEverclear.Intent memory _intent) {
    // Send fees to recipient
    _handleFees(_fee, msg.value, _inputAsset);

    // Approve the spoke contract if needed
    _approveSpokeIfNeeded(_inputAsset, _amount);

    // Create new intent
    (_intentId, _intent) =
      spoke.newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, _maxFee, _ttl, _data);

    // Emit event
    emit IntentWithFeesAdded(_intentId, msg.sender.toBytes32(), _fee, msg.value);
    return (_intentId, _intent);
  }

  /**
   * @notice Updates the fee recipient
   * @param _feeRecipient New recipient
   */
  function _updateFeeRecipient(
    address _feeRecipient
  ) internal {
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
    // Checking if the strategy is default or not
    address spender;
    IEverclear.Strategy _strategy = spoke.strategies(_asset);
    if (_strategy == IEverclear.Strategy.DEFAULT) spender = address(spoke);
    else spender = xerc20Module;

    // Approve the spoke contract if needed
    IERC20 _token = IERC20(_asset);
    uint256 _current = _token.allowance(address(this), spender);
    if (_current >= _minimum) {
      return;
    }

    // Approve to 0
    if (_current != 0) {
      _token.safeDecreaseAllowance(spender, _current);
    }

    // Approve to max
    _token.safeIncreaseAllowance(spender, type(uint256).max);
  }

  /**
   * @notice Transfers tokens from the caller to this contract using Permit2
   * @dev Uses the Permit2 contract to transfer tokens with a signature
   * @param _asset The token to transfer
   * @param _amount The amount to transfer
   * @param _permit2Params The permit2 parameters including nonce, deadline, and signature
   */
  function _pullWithPermit2(
    address _asset,
    uint256 _amount,
    IEverclearSpoke.Permit2Params calldata _permit2Params
  ) internal {
    // Transfer from caller using permit2
    PERMIT2.permitTransferFrom(
      IPermit2.PermitTransferFrom({
        permitted: IPermit2.TokenPermissions({token: IERC20(_asset), amount: _amount}),
        nonce: _permit2Params.nonce,
        deadline: _permit2Params.deadline
      }),
      IPermit2.SignatureTransferDetails({to: address(this), requestedAmount: _amount}),
      msg.sender,
      _permit2Params.signature
    );
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
