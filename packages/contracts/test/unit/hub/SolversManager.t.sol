// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {TestExtended} from 'test/utils/TestExtended.sol';

import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';
import {StdStorage, stdStorage} from 'test/utils/TestExtended.sol';

import {IHubStorage} from 'contracts/hub/HubStorage.sol';

import {IProtocolManager, ProtocolManager} from 'contracts/hub/modules/managers/ProtocolManager.sol';
import {IUsersManager, UsersManager} from 'contracts/hub/modules/managers/UsersManager.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

contract TestUsersManager is UsersManager, ProtocolManager {
  using Uint32Set for Uint32Set.Set;

  constructor(address _owner, uint8 __minSupportedDomains) {
    minSolverSupportedDomains = __minSupportedDomains;
    owner = _owner;
  }

  function setMinSupportedDomains(
    uint8 __minSupportedDomains
  ) public {
    minSolverSupportedDomains = __minSupportedDomains;
  }

  function userSupportedDomains(
    bytes32 _owner
  ) external view returns (uint32[] memory) {
    return _usersSupportedDomains[_owner].memValues();
  }
}

contract BaseTest is TestExtended {
  using stdStorage for StdStorage;

  TestUsersManager solversManager;

  uint8 public constant MIN_SUPPORTED_DOMAINS = 5;

  address public owner = makeAddr('owner');

  modifier validSupportedDomainsLength(
    uint32[] memory _supportedDomains
  ) {
    vm.assume(_supportedDomains.length >= MIN_SUPPORTED_DOMAINS && _supportedDomains.length <= type(uint32).max);
    _;
  }

  modifier setSupportedDomains(
    uint32[] memory _supportedDomains
  ) {
    IHubStorage.DomainSetup[] memory _domains = new IHubStorage.DomainSetup[](_supportedDomains.length);

    for (uint256 _i; _i < _supportedDomains.length; _i++) {
      _domains[_i] = IHubStorage.DomainSetup({
        id: uint32(uint256(keccak256(abi.encodePacked(_supportedDomains[_i], _i)))),
        blockGasLimit: 1
      });
    }

    _setSupportedDomains(_domains);
    _;
  }

  function setUp() public virtual {
    solversManager = new TestUsersManager(owner, MIN_SUPPORTED_DOMAINS);
  }

  function _mockRole(address _account, IHubStorage.Role _role) internal {
    stdstore.target(address(solversManager)).sig(IHubStorage.roles.selector).with_key(_account).checked_write(
      uint8(_role)
    );
  }

  function _setSupportedDomains(
    IHubStorage.DomainSetup[] memory _domains
  ) internal {
    vm.prank(owner);
    IProtocolManager(address(solversManager)).addSupportedDomains(_domains);
  }

  function _setUserSupportedDomainsConfig(address _account, uint32[] memory _supportedDomains) internal {
    vm.prank(_account);
    solversManager.setUserSupportedDomains(_supportedDomains);
  }
}

contract Unit_SetUser is BaseTest {
  using TypeCasts for address;

  event SolverConfigUpdated(bytes32 indexed _solver, uint32[] _supportedDomains);

  /**
   * @notice Test that the setUserSupportedDomains function emits the SolverConfigUpdated event and sets the solver config correctly
   */
  function test_SetUserHappyPath(
    address _solver,
    uint32[] memory _supportedDomains
  ) public validAddress(_solver) validSupportedDomainsLength(_supportedDomains) setSupportedDomains(_supportedDomains) {
    for (uint256 _i; _i < _supportedDomains.length; _i++) {
      _supportedDomains[_i] = uint32(uint256(keccak256(abi.encodePacked(_supportedDomains[_i], _i))));
    }
    _expectEmit(address(solversManager));

    // Assert emitted event
    emit SolverConfigUpdated(_solver.toBytes32(), _supportedDomains);

    vm.prank(_solver);
    solversManager.setUserSupportedDomains(_supportedDomains);

    uint32[] memory _newSupportedDomains = solversManager.userSupportedDomains(_solver.toBytes32());

    for (uint256 _i; _i < _newSupportedDomains.length; _i++) {
      assertEq(_newSupportedDomains[_i], _supportedDomains[_i], 'Supported domain not set correctly');
    }
  }

  /**
   * @notice Test that the setUserSupportedDomains function reverts when the amount of supported domains is less than the minimum
   */
  function test_Revert_MinimumSupportedDomainsNotMet(
    address _solver,
    uint8 _minSupportedDomains,
    uint8 _notMinSupportedDomains
  ) public {
    vm.assume(_minSupportedDomains > 0);
    vm.assume(_notMinSupportedDomains < _minSupportedDomains);
    TestUsersManager(address(solversManager)).setMinSupportedDomains(_minSupportedDomains);

    uint32[] memory _supportedDomains = new uint32[](_notMinSupportedDomains);

    vm.expectRevert(
      abi.encodeWithSelector(
        IUsersManager.UsersManager_SetUser_MinimumSupportedDomainsNotMet.selector,
        _minSupportedDomains,
        _notMinSupportedDomains
      )
    );

    vm.prank(_solver);
    solversManager.setUserSupportedDomains(_supportedDomains);
  }

  /**
   * @notice Test that the setUserSupportedDomains function reverts when a domain in the list of the solver config is not supported
   */
  function test_Revert_DomainNotSupported(
    address _solver,
    uint32[] memory _supportedDomains,
    uint32 _notSupportedDomain
  ) public validSupportedDomainsLength(_supportedDomains) {
    vm.assume(_notSupportedDomain < _supportedDomains.length);

    IHubStorage.DomainSetup[] memory _domains = new IHubStorage.DomainSetup[](_supportedDomains.length);

    for (uint256 _i; _i < _supportedDomains.length; _i++) {
      uint32 _uniqueId = uint32(uint256(keccak256(abi.encodePacked(_supportedDomains[_i], _i))));
      _supportedDomains[_i] = _uniqueId;
      _domains[_i] = IHubStorage.DomainSetup({id: _uniqueId, blockGasLimit: 1});
    }

    vm.prank(owner);
    IProtocolManager(address(solversManager)).addSupportedDomains(_domains);

    uint32[] memory _notSupportedDomains = new uint32[](1);
    _notSupportedDomains[0] = _domains[_notSupportedDomain].id;

    vm.prank(owner);
    IProtocolManager(address(solversManager)).removeSupportedDomains(_notSupportedDomains);

    vm.expectRevert(
      abi.encodeWithSelector(IUsersManager.UsersManager_SetUser_DomainNotSupported.selector, _notSupportedDomains[0])
    );

    vm.prank(_solver);
    solversManager.setUserSupportedDomains(_supportedDomains);
  }
}
