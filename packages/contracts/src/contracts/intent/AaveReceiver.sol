// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IAaveV3Pool} from '../../interfaces/external/IAaveV3Pool.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract AaveReceiver {
  using SafeERC20 for IERC20;
  IAaveV3Pool public immutable aaveV3;

  constructor(
    IAaveV3Pool _aaveV3
  ) {
    aaveV3 = IAaveV3Pool(_aaveV3);
  }

  /*///////////////////////////////////////////////////////////////
                       SPOKE FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /// @dev assuming TTL will be infinite for fill path intents (i.e. funds will be used in an atomic tx and no excess balance held)
  function supply(
    address _asset,
    uint256 _amount,
    address _onBehalfOf,
    uint16 _referralCode
  ) external {
    IERC20 _token = IERC20(_asset);

    // Approving and supplying
    _token.forceApprove(address(aaveV3), _amount);
    aaveV3.supply(_asset, _amount, _onBehalfOf, _referralCode);
  }
}
