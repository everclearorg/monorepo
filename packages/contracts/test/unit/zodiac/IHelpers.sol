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

interface ISafe {
  function isModuleEnabled(address module) external view returns (bool);
  function getThreshold() external view returns (uint256 threshold);  
}