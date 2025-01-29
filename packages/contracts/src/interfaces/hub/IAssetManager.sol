// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

/**
 * @title IAssetManager
 * @notice Interface for the AssetManager contract
 */
interface IAssetManager {
  /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Struct for setting the last epoch processed for an array of assets
   * @param lastEpochProcessed The last epoch processed for the assets
   * @param tickerHashes The hashes of the ticker symbols to set the last epoch processed for
   */
  struct SetLastClosedEpochProcessedParams {
    uint48 lastEpochProcessed;
    bytes32[] tickerHashes;
  }

  /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when the asset configuration is set
   * @param _config The asset configuration
   */
  event AssetConfigSet(IHubStorage.AssetConfig _config);

  /**
   * @notice Emitted when the token configurations are set
   * @param _configs The token configurations
   */
  event TokenConfigsSet(IHubStorage.TokenSetup[] _configs);

  /**
   * @notice Emitted when the prioritized strategy is set for an asset
   * @param _tickerHash The hash of the ticker symbol of the asset
   * @param _strategy The strategy to be prioritized for the asset
   */
  event PrioritizedStrategySet(bytes32 _tickerHash, IEverclear.Strategy _strategy);

  /**
   * @notice Emitted when the discount per epoch is set for an asset
   * @param _tickerHash The hash of the ticker symbol
   * @param _oldDiscountPerEpoch The old discount per epoch
   * @param _newDiscountPerEpoch The new discount per epoch
   */
  event DiscountPerEpochSet(bytes32 _tickerHash, uint24 _oldDiscountPerEpoch, uint24 _newDiscountPerEpoch);

  /**
   * @notice Emitted when the last epoch processed is set for an array of assets
   * @param _params The parameters for setting the last epoch processed
   */
  event LastEpochProcessedSet(SetLastClosedEpochProcessedParams _params);

  /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Thrown when the ticker hash of TokenSetup does not match the ticker hash of the nested AssetConfig
   */
  error AssetManager_SetTokenConfigs_TickerHashMismatch();

  /**
   * @notice Thrown when the protocol fees sum set for an asset exceeds the DBPS_DENOMINATOR
   */
  error AssetManager_SetTokenConfigs_FeesExceedsDenominator();

  /*//////////////////////////////////////////////////////////////
                                LOGIC
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Set the adpoted configuration for an asset
   * @dev Requires the caller to have the ASSET_MANAGER role
   * @param _config The asset configuration struct
   */
  function setAdoptedForAsset(
    IHubStorage.AssetConfig calldata _config
  ) external;

  /**
   * @notice Set bulk token configurations
   * @dev Requires the caller to have the ASSET_MANAGER role
   * @param _configs The array of token configurations
   */
  function setTokenConfigs(
    IHubStorage.TokenSetup[] calldata _configs
  ) external;

  /**
   * @notice Set the prioritized strategy for an Asset
   * @dev Requires the caller to have the ASSET_MANAGER role
   * @param _tickerHash The hash of the ticker symbol
   * @param _strategy The strategy to be prioritized for the asset
   */
  function setPrioritizedStrategy(bytes32 _tickerHash, IEverclear.Strategy _strategy) external;

  /**
   * @notice Set the discount per epoch for an asset
   * @dev Requires the caller to have the ASSET_MANAGER role
   * @param _tickerHash The hash of the ticker symbol
   * @param _discountPerEpoch The discount per epoch
   */
  function setDiscountPerEpoch(bytes32 _tickerHash, uint24 _discountPerEpoch) external;

  /**
   * @notice Set the last epoch processed for an array of assets
   * @dev Requires the caller to have the ASSET_MANAGER role
   * @param _params The parameters for setting the last epoch processed
   */
  function setLastClosedEpochProcessed(
    SetLastClosedEpochProcessedParams calldata _params
  ) external;
}
