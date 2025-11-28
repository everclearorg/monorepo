// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AssetUtils} from 'contracts/common/AssetUtils.sol';
import {Constants} from 'contracts/common/Constants.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';
import {IAssetManagerV2} from 'interfaces/hub/IAssetManagerV2.sol';

import {HubStorageV2} from 'contracts/hub/HubStorageV2.sol';

abstract contract AssetManagerV2 is HubStorageV2, IAssetManagerV2 {
  using Uint32Set for Uint32Set.Set;

  /*//////////////////////////////////////////////////////////////
                                LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IAssetManagerV2
  function setAdoptedForAsset(
    AssetConfig calldata _config
  ) external hasRole(Role.ASSET_MANAGER) {
    _setAdoptedForAsset(_config);
  }

  /// @inheritdoc IAssetManagerV2
  function setTokenConfigs(
    TokenSetup[] calldata _configs
  ) external hasRole(Role.ASSET_MANAGER) {
    for (uint256 _i; _i < _configs.length; _i++) {
      TokenSetup memory _config = _configs[_i];
      _validDbpsSetup(_config.maxDiscountDbps, _config.discountPerEpoch);
      bytes32 _tickerHash = _config.tickerHash;
      AssetConfig[] memory _newAssetConfigs = _config.adoptedForAssets;
      TokenConfig storage _tokenConfig = _tokenConfigs[_tickerHash];
      for (uint256 _j; _j < _newAssetConfigs.length; _j++) {
        if (_newAssetConfigs[_j].tickerHash != _tickerHash) {
          revert AssetManager_SetTokenConfigs_TickerHashMismatch();
        }

        _setAdoptedForAsset(_newAssetConfigs[_j]);
      }
      _tokenConfig.prioritizedStrategy = _config.prioritizedStrategy;
      _tokenConfig.discountPerEpoch = _config.discountPerEpoch;
      _tokenConfig.maxDiscountDbps = _config.maxDiscountDbps;
      Fee[] memory _newFees = _config.fees;
      delete _tokenConfig.fees;
      uint256 _totalProtocolFeesDbps;
      for (uint256 _j; _j < _newFees.length; _j++) {
        _tokenConfig.fees.push(_newFees[_j]);
        _totalProtocolFeesDbps += _newFees[_j].fee;
      }
      if (_totalProtocolFeesDbps > Constants.DBPS_DENOMINATOR) {
        revert AssetManager_SetTokenConfigs_FeesExceedsDenominator();
      }
      if (_config.initLastClosedEpochProcessed) {
        uint48 _currentEpoch = uint48(block.number / epochLength);
        lastClosedEpochsProcessed[_tickerHash] = _currentEpoch > 0 ? _currentEpoch - 1 : 0;
      }
    }
    emit TokenConfigsSet(_configs);
  }

  /// @inheritdoc IAssetManagerV2
  function setPrioritizedStrategy(
    bytes32 _tickerHash,
    IEverclearV2.Strategy _strategy
  ) external hasRole(Role.ASSET_MANAGER) {
    TokenConfig storage _tokenConfig = _tokenConfigs[_tickerHash];
    _tokenConfig.prioritizedStrategy = _strategy;
    emit PrioritizedStrategySet(_tickerHash, _strategy);
  }

  /// @inheritdoc IAssetManagerV2
  function setLastClosedEpochProcessed(
    SetLastClosedEpochProcessedParams calldata _params
  ) external hasRole(Role.ASSET_MANAGER) {
    uint48 _lastEpochProcessed = _params.lastEpochProcessed;
    for (uint256 _i; _i < _params.tickerHashes.length; _i++) {
      bytes32 _tickerHash = _params.tickerHashes[_i];
      lastClosedEpochsProcessed[_tickerHash] = _lastEpochProcessed;
    }
    emit LastEpochProcessedSet(_params);
  }

  /// @inheritdoc IAssetManagerV2
  function setDiscountPerEpoch(
    bytes32 _tickerHash,
    uint24 _discountPerEpoch
  ) external hasRole(Role.ASSET_MANAGER) {
    TokenConfig storage _tokenConfig = _tokenConfigs[_tickerHash];
    _validDbpsSetup(_tokenConfig.maxDiscountDbps, _discountPerEpoch);
    uint24 _oldDiscountPerEpoch = _tokenConfig.discountPerEpoch;
    _tokenConfig.discountPerEpoch = _discountPerEpoch;
    emit DiscountPerEpochSet(_tickerHash, _oldDiscountPerEpoch, _discountPerEpoch);
  }

  /**
   * @notice Set the asset configuration
   * @param _config The asset configuration
   */
  function _setAdoptedForAsset(
    AssetConfig memory _config
  ) internal {
    bytes32 _assetHash = AssetUtils.getAssetHash(_config.adopted, _config.domain);
    _adoptedForAssets[_assetHash] = _config;
    _tokenConfigs[_config.tickerHash].assetHashes[_config.domain] = _assetHash;
    // The set will only add the domain if it is not already present
    _tokenConfigs[_config.tickerHash].domains.add(_config.domain);
    emit AssetConfigSet(_config);
  }

  /**
   * @notice Validate that the max discount bps and the discount per epoch are valid
   * @param _maxDiscountDbps The maximum discount basis points
   * @param _discountPerEpoch The discount basis points per epoch
   */
  function _validDbpsSetup(
    uint24 _maxDiscountDbps,
    uint24 _discountPerEpoch
  ) internal pure {
    if (_maxDiscountDbps > Constants.DBPS_DENOMINATOR || _discountPerEpoch > _maxDiscountDbps) {
      revert HubStorage_InvalidDbpsValue();
    }
  }
}
