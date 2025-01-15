// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title AssetUtils
 * @notice Library for asset utility functions
 */
library AssetUtils {
  /**
   * @notice This function translates the _amount in _in decimals
   * to _out decimals
   *
   * @param _in The decimals of the asset in / amount in
   * @param _out The decimals of the target asset
   * @param _amount The value to normalize to the `_out` decimals
   * @return _normalized Normalized decimals.
   */
  function normalizeDecimals(uint8 _in, uint8 _out, uint256 _amount) internal pure returns (uint256 _normalized) {
    if (_in == _out) {
      return _amount;
    }
    // Convert this value to the same decimals as _out
    if (_in < _out) {
      _normalized = _amount * (10 ** (_out - _in));
    } else {
      _normalized = _amount / (10 ** (_in - _out));
    }
  }

  /**
   * @notice Get the hash of an asset
   * @param _asset The address of the asset
   * @param _domain The domain of the asset
   * @return _assetHash The hash of the asset
   */
  function getAssetHash(bytes32 _asset, uint32 _domain) internal pure returns (bytes32 _assetHash) {
    return keccak256(abi.encode(_asset, _domain));
  }
}
