// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ICREATE3 {
  function deploy(bytes32 _salt, bytes calldata _creation) external returns (address);
}
