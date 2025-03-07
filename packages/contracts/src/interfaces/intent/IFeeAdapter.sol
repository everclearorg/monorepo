// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IEverclear } from '../common/IEverclear.sol';
import { IEverclearSpoke } from './IEverclearSpoke.sol';
import { ISpokeGateway } from './ISpokeGateway.sol';

interface IFeeAdapter {
  /**
   * @notice Emitted when a new intent is created with fees
   * @param _intentId The ID of the created intent
   * @param _initiator The address of the user who initiated the intent
   * @param _tokenFee The amount of token fees paid
   * @param _nativeFee The amount of native token fees paid
   */
  event IntentWithFeesAdded(
    bytes32 indexed _intentId,
    bytes32 indexed _initiator,
    uint256 _tokenFee,
    uint256 _nativeFee
  );

  /**
   * @notice Emitted when the fee recipient is updated
   * @param _updated The new fee recipient address
   * @param _previous The previous fee recipient address
   */
  event FeeRecipientUpdated(address indexed _updated, address indexed _previous);

  /**
   * @notice Returns the spoke contract address
   * @return The EverclearSpoke contract interface
   */
  function spoke() external view returns (IEverclearSpoke);

  /**
   * @notice Returns the current fee recipient address
   * @return The address that receives fees
   */
  function feeRecipient() external view returns (address);

  /**
   * @notice Creates a new intent with fees
   * @param _destinations Array of destination domains, preference ordered
   * @param _receiver Address of the receiver on the destination chain
   * @param _inputAsset Address of the input asset
   * @param _outputAsset Address of the output asset
   * @param _amount Amount of input asset to use for the intent
   * @param _maxFee Maximum fee percentage allowed for the intent
   * @param _ttl Time-to-live for the intent in seconds
   * @param _data Additional data for the intent
   * @param _fee Token fee amount to be sent to the fee recipient
   * @return _intentId The ID of the created intent
   * @return _intent The created intent object
   */
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
  ) external payable returns (bytes32, IEverclear.Intent memory);

  /**
   * @notice Updates the fee recipient address
   * @dev Can only be called by the owner of the contract
   * @param _feeRecipient The new address that will receive fees
   */
  function updateFeeRecipient(address _feeRecipient) external;
}
