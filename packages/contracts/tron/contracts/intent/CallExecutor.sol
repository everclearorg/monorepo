// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ICallExecutor} from 'interfaces/intent/ICallExecutor.sol';

/**
 * @title CallExecutor
 * @notice Contract that executes calls to external contracts
 */
contract CallExecutor is ICallExecutor {
  /**
   * @inheritdoc ICallExecutor
   * @dev The main difference between this and a solidity low-level call is
   * that we limit the number of bytes that the callee can cause to be
   * copied to caller memory. This prevents stupid things like malicious
   * contracts returning 10,000,000 bytes causing a local OOG when copying
   * to memory.
   */
  function excessivelySafeCall(
    address _target,
    uint256 _gas,
    uint256 _value,
    uint16 _maxCopy,
    bytes memory _calldata
  ) external returns (bool _success, bytes memory _returnData) {
    // set up for assembly call
    uint256 _toCopy;
    _returnData = new bytes(_maxCopy);
    // dispatch message to recipient
    // by assembly calling "handle" function
    // we call via assembly to avoid memcopying a very large returndata
    // returned by a malicious contract
    assembly {
      _success :=
        call(
          _gas, // gas
          _target, // recipient
          _value, // ether value
          add(_calldata, 0x20), // inloc
          mload(_calldata), // inlen
          0, // outloc
          0 // outlen
        )
      // limit our copy to 256 bytes
      _toCopy := returndatasize()
      if gt(_toCopy, _maxCopy) { _toCopy := _maxCopy }
      // Store the length of the copied bytes
      mstore(_returnData, _toCopy)
      // copy the bytes from returndata[0:_toCopy]
      returndatacopy(add(_returnData, 0x20), 0, _toCopy)
    }
    return (_success, _returnData);
  }
}
