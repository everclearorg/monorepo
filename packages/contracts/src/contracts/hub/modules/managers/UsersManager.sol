// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {IUsersManager} from 'interfaces/hub/IUsersManager.sol';

import {HubStorage} from 'contracts/hub/HubStorage.sol';

/**
 * @title UsersManager
 * @notice Manages the solvers
 */
abstract contract UsersManager is HubStorage, IUsersManager {
  using Uint32Set for Uint32Set.Set;
  using TypeCasts for address;

  /// @inheritdoc IUsersManager
  function setUserSupportedDomains(
    uint32[] calldata __supportedDomains
  ) external {
    if (__supportedDomains.length < minSolverSupportedDomains) {
      revert UsersManager_SetUser_MinimumSupportedDomainsNotMet(minSolverSupportedDomains, __supportedDomains.length);
    }
    bytes32 _user = msg.sender.toBytes32();

    Uint32Set.Set storage _userSupportedDomains = _usersSupportedDomains[_user];

    if (_userSupportedDomains.length() > 0) {
      _userSupportedDomains.flush();
    }

    for (uint256 _i; _i < __supportedDomains.length; _i++) {
      if (!_supportedDomains.contains(__supportedDomains[_i])) {
        revert UsersManager_SetUser_DomainNotSupported(__supportedDomains[_i]);
      }
      if (!_userSupportedDomains.add(__supportedDomains[_i])) {
        revert UsersManager_SetUser_DuplicatedSupportedDomain(__supportedDomains[_i]);
      }
    }

    emit SolverConfigUpdated(_user, __supportedDomains);
  }

  /// @inheritdoc IUsersManager
  function setUpdateVirtualBalance(
    bool _status
  ) external {
    bytes32 _userAddress = msg.sender.toBytes32();
    updateVirtualBalance[_userAddress] = _status;

    emit IncreaseVirtualBalanceSet(_userAddress, _status);
  }
}
