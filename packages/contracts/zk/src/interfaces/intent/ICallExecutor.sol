// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title ICallExecutor
 * @notice Interface for the CallExecutor contract, executes calls to external contracts
 */
interface ICallExecutor {
  /**
   * @notice Safely call a target contract, use when you _really_ really _really_ don't trust the called
   * contract. This prevents the called contract from causing reversion of the caller in as many ways as we can.
   * @param _target The address to call
   * @param _gas The amount of gas to forward to the remote contract
   * @param _value The value in wei to send to the remote contract
   * @param _maxCopy The maximum number of bytes of returndata to copy to memory
   * @param _calldata The data to send to the remote contract
   * @return _success Whether the call was successful
   * @return _returnData Returndata as `.call()`. Returndata is capped to `_maxCopy` bytes.
   */
  function excessivelySafeCall(
    address _target,
    uint256 _gas,
    uint256 _value,
    uint16 _maxCopy,
    bytes memory _calldata
  ) external returns (bool _success, bytes memory _returnData);
}
