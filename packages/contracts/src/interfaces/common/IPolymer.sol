// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IPolymer {
  function validateEvent(
    bytes memory proof
  ) external returns (uint32, address, bytes memory, bytes memory);
}
