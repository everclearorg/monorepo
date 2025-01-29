// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TestExtended} from '../../utils/TestExtended.sol';

import {IUsersManager, UsersManager} from 'contracts/hub/modules/managers/UsersManager.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

contract TestUsersManager is UsersManager {
  using TypeCasts for address;

  function mockMinSolverSupportedDomains(
    uint8 _minSolverSupportedDomains
  ) public {
    minSolverSupportedDomains = _minSolverSupportedDomains;
  }

  function mockDomainSuppport(
    uint32 _domain
  ) public {
    Uint32Set.add(_supportedDomains, _domain);
  }

  function mockUserSupportedDomain(uint32 _domain, address _user) public {
    Uint32Set.add(_usersSupportedDomains[_user.toBytes32()], _domain);
  }

  function mockExistingDomains(uint32[] memory _existingDomains, address _user) public {
    Uint32Set.Set storage _userSupportedDomains = _usersSupportedDomains[_user.toBytes32()];

    for (uint256 _i; _i < _existingDomains.length; _i++) {
      Uint32Set.add(_userSupportedDomains, _existingDomains[_i]);
    }
  }
}

contract BaseTest is TestExtended {
  TestUsersManager internal usersManager;

  function setUp() public {
    usersManager = new TestUsersManager();
  }
}

contract Unit_UserSupportedDomains is BaseTest {
  using TypeCasts for address;

  event SolverConfigUpdated(bytes32 indexed _user, uint32[] _supportedDomains);

  /**
   * @notice Tests the setUserSupportedDomains function
   * @param _minSolverSupportedDomains The minimum number of supported domains
   * @param _supportedDomains The supported domains
   * @param _user The user address
   */
  function test_SetUserSuppportedDomains(
    uint8 _minSolverSupportedDomains,
    uint32[] memory _supportedDomains,
    address _user
  ) public {
    vm.assume(_supportedDomains.length > 0);
    vm.assume(_supportedDomains.length > _minSolverSupportedDomains);

    usersManager.mockMinSolverSupportedDomains(_minSolverSupportedDomains);

    uint32[] memory _uniqueDomains = new uint32[](_supportedDomains.length);

    // Hash each element with a unique nonce to ensure uniqueness
    for (uint256 _i; _i < _supportedDomains.length; _i++) {
      // Simple hash function combining the element with its index
      _uniqueDomains[_i] = uint32(uint256(keccak256(abi.encodePacked(_supportedDomains[_i], _i))));
    }

    for (uint256 _i; _i < _supportedDomains.length; _i++) {
      usersManager.mockDomainSuppport(_uniqueDomains[_i]);
    }

    vm.expectEmit(address(usersManager));
    emit SolverConfigUpdated(_user.toBytes32(), _uniqueDomains);

    vm.prank(_user);
    usersManager.setUserSupportedDomains(_uniqueDomains);
  }

  /**
   * @notice Tests the setUserSupportedDomains function with existing domains
   * @param _minSolverSupportedDomains The minimum number of supported domains
   * @param _supportedDomains The supported domains
   * @param _existingDomains The existing domains
   * @param _user The user address
   */
  function test_SetUserSuppportedDomains_WithExistingDomains(
    uint8 _minSolverSupportedDomains,
    uint32[] memory _supportedDomains,
    uint32[] memory _existingDomains,
    address _user
  ) public {
    vm.assume(_supportedDomains.length > 0);
    vm.assume(_supportedDomains.length > _minSolverSupportedDomains);

    usersManager.mockMinSolverSupportedDomains(_minSolverSupportedDomains);
    usersManager.mockExistingDomains(_existingDomains, _user);

    uint32[] memory _uniqueDomains = new uint32[](_supportedDomains.length);

    // Hash each element with a unique nonce to ensure uniqueness
    for (uint256 _i; _i < _supportedDomains.length; _i++) {
      // Simple hash function combining the element with its index
      _uniqueDomains[_i] = uint32(uint256(keccak256(abi.encodePacked(_supportedDomains[_i], _i))));
    }

    for (uint256 _i; _i < _supportedDomains.length; _i++) {
      usersManager.mockDomainSuppport(_uniqueDomains[_i]);
    }

    vm.expectEmit(address(usersManager));
    emit SolverConfigUpdated(_user.toBytes32(), _uniqueDomains);

    vm.prank(_user);
    usersManager.setUserSupportedDomains(_uniqueDomains);
  }

  /**
   * @notice Tests the setUserSupportedDomains function with the minimum supported domains not met
   * @param _minSolverSupportedDomains The minimum number of supported domains
   * @param _supportedDomains The supported domains
   * @param _user The user address
   */
  function test_Revert_SetUserSuppportedDomains_MinimumSupportedDomainsNotMet(
    uint8 _minSolverSupportedDomains,
    uint32[] memory _supportedDomains,
    address _user
  ) public {
    vm.assume(_supportedDomains.length < _minSolverSupportedDomains);

    usersManager.mockMinSolverSupportedDomains(_minSolverSupportedDomains);

    vm.expectRevert(
      abi.encodeWithSelector(
        IUsersManager.UsersManager_SetUser_MinimumSupportedDomainsNotMet.selector,
        _minSolverSupportedDomains,
        _supportedDomains.length
      )
    );

    vm.prank(_user);
    usersManager.setUserSupportedDomains(_supportedDomains);
  }

  /**
   * @notice Tests the setUserSupportedDomains function with a domain not supported
   * @param _minSolverSupportedDomains The minimum number of supported domains
   * @param _supportedDomains The supported domains
   * @param _user The user address
   */
  function test_Revert_SetUserSuppportedDomains_DomainNotSupported(
    uint8 _minSolverSupportedDomains,
    uint32[] memory _supportedDomains,
    address _user
  ) public {
    vm.assume(_supportedDomains.length > 0);
    vm.assume(_supportedDomains.length > _minSolverSupportedDomains);

    usersManager.mockMinSolverSupportedDomains(_minSolverSupportedDomains);

    vm.expectRevert(
      abi.encodeWithSelector(IUsersManager.UsersManager_SetUser_DomainNotSupported.selector, _supportedDomains[0])
    );

    vm.prank(_user);
    usersManager.setUserSupportedDomains(_supportedDomains);
  }

  /**
   * @notice Tests the setUserSupportedDomains function with a duplicated supported domain
   * @param _minSolverSupportedDomains The minimum number of supported domains
   * @param _supportedDomains The supported domains
   * @param _user The user address
   */
  function test_Revert_SetUserSuppportedDomains_DuplicatedSupportedDomain(
    uint8 _minSolverSupportedDomains,
    uint32[] memory _supportedDomains,
    address _user
  ) public {
    vm.assume(_supportedDomains.length > 0 && _supportedDomains.length < 30);
    vm.assume(_supportedDomains.length > _minSolverSupportedDomains);
    vm.assume(_minSolverSupportedDomains > 1);

    usersManager.mockMinSolverSupportedDomains(_minSolverSupportedDomains);
    uint32[] memory _uniqueDomains = new uint32[](_supportedDomains.length);

    // Hash each element with a unique nonce to ensure uniqueness
    for (uint256 _i; _i < _supportedDomains.length; _i++) {
      _uniqueDomains[_i] = uint32(uint256(keccak256(abi.encodePacked(_supportedDomains[_i], _i))));
    }

    for (uint256 _i; _i < _supportedDomains.length; _i++) {
      usersManager.mockDomainSuppport(_uniqueDomains[_i]);
    }

    uint32[] memory _userSupportedDomains = new uint32[](_minSolverSupportedDomains);
    _userSupportedDomains[0] = _uniqueDomains[0];
    _userSupportedDomains[1] = _uniqueDomains[0];

    vm.expectRevert(
      abi.encodeWithSelector(IUsersManager.UsersManager_SetUser_DuplicatedSupportedDomain.selector, _uniqueDomains[0])
    );

    vm.prank(_user);
    usersManager.setUserSupportedDomains(_userSupportedDomains);
  }
}

contract Unit_UpdateVirutalBalance is BaseTest {
  using TypeCasts for address;

  event IncreaseVirtualBalanceSet(bytes32 indexed _userAddress, bool _status);

  /**
   * @notice Tests the setUpdateVirtualBalance function
   * @param _status The status to set
   * @param _user The user address
   */
  function test_SetUpdateVirtualBalance(bool _status, address _user) public {
    vm.expectEmit(address(usersManager));
    emit IncreaseVirtualBalanceSet(_user.toBytes32(), _status);

    vm.prank(_user);
    usersManager.setUpdateVirtualBalance(_status);

    assertEq(usersManager.updateVirtualBalance(_user.toBytes32()), _status);
  }
}
