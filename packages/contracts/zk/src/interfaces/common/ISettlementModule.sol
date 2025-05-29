// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title ISettlementModule
 * @notice Interface for the base settlement module
 */
interface ISettlementModule {
  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Handle a mint action for a specific strategy
   * @param _asset The address of the asset to mint
   * @param _recipient The recipient of the minted assets
   * @param _fallbackRecipient The fallback recipient of the minted assets (in case of failure)
   * @param _amount The amount to mint
   * @param _data Extra data needed by some modules
   * @return _success The outcome of the minting strategy
   * @dev In case of failure, the parent module will handle the operation accordingly
   */
  function handleMintStrategy(
    address _asset,
    address _recipient,
    address _fallbackRecipient,
    uint256 _amount,
    bytes calldata _data
  ) external returns (bool _success);

  /**
   * @notice Handle a burn action for a specific strategy
   * @param _asset The address of the asset to burn
   * @param _user The user whose assets are being burned
   * @param _amount The amount to burn
   * @param _data Extra data needed by some modules
   * @dev In case of failure, the `newIntent` flow will revert
   */
  function handleBurnStrategy(address _asset, address _user, uint256 _amount, bytes calldata _data) external;
}
