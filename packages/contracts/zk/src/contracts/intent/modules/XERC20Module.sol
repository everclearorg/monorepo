// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';
import {IXERC20} from 'interfaces/common/IXERC20.sol';
import {IXERC20Module} from 'interfaces/intent/modules/IXERC20Module.sol';

/**
 * @title XERC20Module
 * @notice Module for handling minting and burning through XERC20 specific methods
 */
contract XERC20Module is IXERC20Module {
  /// @inheritdoc IXERC20Module
  mapping(address _user => mapping(address _asset => uint256 _amount)) public mintable;

  /// @inheritdoc IXERC20Module
  address public spoke;

  /**
   * @notice Check that the function is called by the local `EverclearSpoke`
   */
  modifier onlySpoke() {
    if (msg.sender != spoke) revert XERC20Module_HandleStrategy_OnlySpoke();
    _;
  }

  constructor(
    address _spoke
  ) {
    spoke = _spoke;
  }

  /// @inheritdoc ISettlementModule
  function handleMintStrategy(
    address _asset,
    address _recipient,
    address _fallbackRecipient,
    uint256 _amount,
    bytes calldata
  ) external onlySpoke returns (bool _success) {
    uint256 _limit = IXERC20(_asset).mintingCurrentLimitOf(address(this));
    if (_amount <= _limit) {
      try IXERC20(_asset).mint(_recipient, _amount) {
        _success = true;
      } catch {}
    }
    if (!_success) {
      mintable[_fallbackRecipient][_asset] += _amount;
      emit HandleMintStrategyFailed(_asset, _recipient, _amount);
    }
  }

  /// @inheritdoc ISettlementModule
  function handleBurnStrategy(address _asset, address _user, uint256 _amount, bytes calldata) external onlySpoke {
    uint256 _limit = IXERC20(_asset).burningMaxLimitOf(address(this));
    if (_limit < _amount) revert XERC20Module_HandleBurnStrategy_InsufficientBurningLimit(_asset, _limit, _amount);

    IXERC20(_asset).burn(_user, _amount);
  }

  /// @inheritdoc IXERC20Module
  function mintDebt(address _asset, address _recipient, uint256 _amount) external {
    uint256 _limit = IXERC20(_asset).mintingMaxLimitOf(address(this));

    if (_limit < _amount) revert XERC20Module_MintDebt_InsufficientMintingLimit(_asset, _limit, _amount);

    mintable[_recipient][_asset] -= _amount;
    IXERC20(_asset).mint(_recipient, _amount);

    emit DebtMinted(_asset, _recipient, _amount);
  }
}
