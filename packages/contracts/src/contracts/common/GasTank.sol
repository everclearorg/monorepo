// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.23;

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IGasTank} from 'interfaces/common/IGasTank.sol';

/**
 * @title GasTank
 * @notice Contract for receiving gas
 */
contract GasTank is Initializable, OwnableUpgradeable, IGasTank {
  /**
   * @notice Mapping of authorized gas receivers
   */
  mapping(address _account => bool _isAuthorized) internal _authorizedGasReceiver;

  /**
   * @notice Checks that the caller is authorized
   */
  modifier isAuthorized() {
    if (!_authorizedGasReceiver[msg.sender]) {
      revert GasTank_NotAuthorized();
    }
    _;
  }

  /**
   * @notice receive function routes calls to depositGas
   */
  receive() external payable {
    emit GasTankDeposited(msg.sender, msg.value);
  }

  /**
   * @inheritdoc IGasTank
   */
  function withdrawGas(
    uint256 _amount
  ) external override isAuthorized {
    if (_amount > address(this).balance) {
      revert GasTank_InsufficientFunds();
    }

    (bool success,) = msg.sender.call{value: _amount}('');

    if (!success) {
      revert GasTank_CallFailed();
    }

    emit GasTankWithdrawn(msg.sender, _amount);
  }

  /**
   * @inheritdoc IGasTank
   */
  function authorizeGasReceiver(address _receiver, bool _authorized) external onlyOwner {
    _authorizedGasReceiver[_receiver] = _authorized;
    emit GasReceiverAuthorized(_receiver, _authorized);
  }

  /**
   * @inheritdoc IGasTank
   */
  function isAuthorizedGasReceiver(
    address _address
  ) external view returns (bool) {
    return _authorizedGasReceiver[_address];
  }

  /**
   * @notice Initializes the GasTank contract
   * @param _owner The owner of the contract
   */
  function __initializeGasTank(
    address _owner
  ) internal initializer {
    __Ownable_init(_owner);
    _authorizedGasReceiver[_owner] = true;
  }
}
