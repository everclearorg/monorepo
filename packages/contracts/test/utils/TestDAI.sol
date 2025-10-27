// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestDAI is ERC20 {
  /**
   * @notice updatable decimals for testing purposes
   */
  uint8 private _fakeDecimals = 6;

  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

  function decimals() public view override returns (uint8) {
    return _fakeDecimals;
  }

  /**
   * @notice Testing method to set the decimals for testing purposes
   * @dev Should be use just for TESTING PURPOSES
   */
  function mockDecimals(
    uint8 _decimals
  ) external {
    _fakeDecimals = _decimals;
  }
}
