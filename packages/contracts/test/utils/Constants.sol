// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library Constants {
  uint32 constant EVERCLEAR_ID = 1122;
  uint32 constant MOCK_SPOKE_CHAIN_ID = 534_351;
  uint256 constant MAILBOX_MOCK_NONCE = 0;
  bytes32 constant EVERCLEAR_GATEWAY = bytes32(keccak256('hub_gateway'));
  address constant HL_VERSION = address(0x456);

  uint256 public constant EXECUTE_CALLDATA_RESERVE_GAS = 10_000;
  uint256 public constant MAX_CALLDATA_SIZE = 50_000;
  uint256 public constant EXPIRY_TIME_BUFFER = 1 hours;
  uint24 public constant DBPS_DENOMINATOR = 100_000;
  uint24 public constant MAX_FEE = 500;
  uint16 public constant DEFAULT_COPY_BYTES = 256;
  bytes32 public constant EMPTY_HASH = keccak256('');
  uint256 public constant MAX_PK =
    115_792_089_237_316_195_423_570_985_008_687_907_852_837_564_279_074_904_382_605_163_141_518_161_494_337;

  bytes32 public constant GATEWAY_HASH = keccak256(abi.encode('GATEWAY'));
  bytes32 public constant MAILBOX_HASH = keccak256(abi.encode('MAILBOX'));
  bytes32 public constant SECURITY_MODULE_HASH = keccak256(abi.encode('SECURITY_MODULE'));
  bytes32 public constant LIGHTHOUSE_HASH = keccak256(abi.encode('LIGHTHOUSE'));
  bytes32 public constant WATCHTOWER_HASH = keccak256(abi.encode('WATCHTOWER'));
  bytes32 public constant MAX_FEE_HASH = keccak256(abi.encode('MAX_FEE'));
  bytes32 public constant INTENT_TTL_HASH = keccak256(abi.encode('INTENT_TTL'));

  address constant PERMIT2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
}
