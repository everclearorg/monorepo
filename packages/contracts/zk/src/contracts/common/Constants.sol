// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library Constants {
  // Default normalized decimals for tokens
  uint8 public constant DEFAULT_NORMALIZED_DECIMALS = 18;
  // 1/10 of a basis point denominator
  uint24 public constant DBPS_DENOMINATOR = 100_000;

  // Precomputed hashes (reduce gas costs)
  bytes32 public constant GATEWAY_HASH = keccak256(abi.encode('GATEWAY'));
  bytes32 public constant MAILBOX_HASH = keccak256(abi.encode('MAILBOX'));
  bytes32 public constant LIGHTHOUSE_HASH = keccak256(abi.encode('LIGHTHOUSE'));
  bytes32 public constant WATCHTOWER_HASH = keccak256(abi.encode('WATCHTOWER'));
  bytes32 public constant MAX_FEE_HASH = keccak256(abi.encode('MAX_FEE'));
  bytes32 public constant INTENT_TTL_HASH = keccak256(abi.encode('INTENT_TTL'));

  // Default gas limit for external calls
  uint256 public constant DEFAULT_GAS_LIMIT = 50_000;
  // Maximum calldata size for external calls
  uint256 public constant MAX_CALLDATA_SIZE = 50_000;
}
