// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.25;

/**
 * @title TypeCasts
 * @notice Library for type casts
 */
library TypeCasts {
  // alignment preserving cast
  /**
   * @notice Cast an address to a bytes32
   * @param _addr The address to cast
   */
  function toBytes32(
    address _addr
  ) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(_addr)));
  }

  // alignment preserving cast
  /**
   * @notice Cast a bytes32 to an address
   * @param _buf The bytes32 to cast
   */
  function toAddress(
    bytes32 _buf
  ) internal pure returns (address) {
    return address(uint160(uint256(_buf)));
  }
}
