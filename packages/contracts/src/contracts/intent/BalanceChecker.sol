// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract BalanceChecker {
  constructor() {}

  function getTokenBalance(address _token, address _account) external view returns (uint256) {
    return IERC20(_token).balanceOf(_account);
  }

  function getTokenBalance(address[] memory _token, address _account) external view returns (uint256[] memory) {
    uint256[] memory balances = new uint256[](_token.length + 1);
    for (uint256 i = 0; i < _token.length; i++) {
      balances[i] = IERC20(_token[i]).balanceOf(_account);
    }
    balances[_token.length] = _account.balance;
    return balances;
  }
}
