// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestWETH is ERC20 {
  bool private _failTransfer;
  bool private _revertTransfer;

  error TestWETH_RevertTransfer();

  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

  function decimals() public pure override returns (uint8) {
    return 18;
  }

  function transfer(address to, uint256 value) public virtual override returns (bool) {
    if (_failTransfer) {
      return false;
    } else if (_revertTransfer) {
      revert TestWETH_RevertTransfer();
    } else {
      return super.transfer(to, value);
    }
  }

  function mockFailTransfer(
    bool _fail
  ) public {
    _failTransfer = _fail;
  }

  function mockRevertTransfer(
    bool _revert
  ) public {
    _revertTransfer = _revert;
  }
}
