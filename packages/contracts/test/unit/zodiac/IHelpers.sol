// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IRoleModule {
  function execTransactionWithRole(
    address to,
    uint256 value,
    bytes memory data,
    uint8 operation,
    bytes32 roleKey,
    bool shouldRevert
  ) external;

  function owner() external view returns (address);
  function avatar() external view returns (address);
  function target() external view returns (address);
}

interface IWETH {
  function deposit() external payable;
  function withdraw(uint256 wad) external;
}

interface ISafe {
  function isModuleEnabled(
    address module
  ) external view returns (bool);
  function getThreshold() external view returns (uint256 threshold);
}

interface IAcrossSpokePool {
  function depositV3(
    address depositor,
    address recipient,
    address inputToken,
    address outputToken,
    uint256 inputAmount,
    uint256 outputAmount,
    uint256 destinationChainId,
    address exclusiveRelayer,
    uint32 quoteTimestamp,
    uint32 fillDeadline,
    uint32 exclusivityDeadline,
    bytes calldata message
  ) external payable;
}

interface IStargatePool {
  struct SendParams {
    uint32 dstEid;
    bytes32 to;
    uint256 amountLD;
    uint256 minAmountLD;
    bytes extraOptions;
    bytes composeMsg;
    bytes oftCmd;
  }

  struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
  }

  function send(SendParams memory _sendParam, MessagingFee memory _fee, address _refundAddress) external;
}
