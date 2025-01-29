// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library Constants {
  // Reserved gas required after the calldata execution
  uint256 public constant EXECUTE_CALLDATA_RESERVE_GAS = 10_000;
  // Bytes to copy from the calldata
  uint16 public constant DEFAULT_COPY_BYTES = 256;
  // The empty hash
  bytes32 public constant EMPTY_HASH = keccak256('');
}
