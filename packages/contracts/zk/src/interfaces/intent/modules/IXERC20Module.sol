// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';

/**
 * @title Interface
 * @notice Interface for
 */
interface IXERC20Module is ISettlementModule {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when debt is minted in favor of a user
   * @param _asset The address of the minted asset
   * @param _recipient The address of the minted tokens recipient
   * @param _amount The amount of tokens minted
   */
  event DebtMinted(address indexed _asset, address indexed _recipient, uint256 _amount);

  /**
   * @notice Emitted when the handle mint strategy fails
   * @param _asset The address of the minted asset
   * @param _recipient The address of the minted tokens recipient
   * @param _amount The amount of tokens minted
   */
  event HandleMintStrategyFailed(address indexed _asset, address indexed _recipient, uint256 _amount);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the XERC20 minting limit is lower than the amount being minted
   * @param _asset The address of the asset
   * @param _limit The hit limit
   * @param _amount The amount trying to be minted
   */
  error XERC20Module_MintDebt_InsufficientMintingLimit(address _asset, uint256 _limit, uint256 _amount);

  /**
   * @notice Thrown when the XERC20 burning limit is lower than the amount being burned
   * @param _asset The address of the asset
   * @param _limit The hit limit
   * @param _amount The amount trying to be burned
   */
  error XERC20Module_HandleBurnStrategy_InsufficientBurningLimit(address _asset, uint256 _limit, uint256 _amount);

  /**
   * @notice Thrown when the caller is not the `EverclearSpoke`
   */
  error XERC20Module_HandleStrategy_OnlySpoke();

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Mints owed assets to an account
   * @param _asset The address of the asset to mint
   * @param _recipient The recipient of the minted assets
   * @param _amount The amount to mint
   */
  function mintDebt(address _asset, address _recipient, uint256 _amount) external;

  /*///////////////////////////////////////////////////////////////
                              VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the address of the local `EverclearSpoke`
   * @return _spoke The address of the `EverclearSpoke`
   */
  function spoke() external view returns (address _spoke);

  /**
   * @notice Returns the amount of tokens mintable by a user
   * @param _account The address of the owed user
   * @param _asset The address of the mintable asset
   * @return _amount The total mintable amount
   */
  function mintable(address _account, address _asset) external view returns (uint256 _amount);
}
