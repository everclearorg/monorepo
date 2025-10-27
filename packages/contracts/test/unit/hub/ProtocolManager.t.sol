// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';

import {TestExtended} from '../../utils/TestExtended.sol';
import {StdStorage, stdStorage} from 'test/utils/TestExtended.sol';

import {Constants} from 'test/utils/Constants.sol';

import {MessageLib} from 'contracts/common/MessageLib.sol';
import {IProtocolManager, ProtocolManager} from 'contracts/hub/modules/managers/ProtocolManager.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {HubGateway, IHubGateway} from 'contracts/hub/HubGateway.sol';
import {IGateway} from 'interfaces/common/IGateway.sol';

import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {Deploy} from 'utils/Deploy.sol';

contract TestProtocolManager is ProtocolManager {
  constructor(address __owner, address __admin, address __hubGateway, address __lighthouse) {
    // Set the internal state vars for tests, these are set in the constructor of the HubStorage originally
    owner = __owner;
    roles[__admin] = IHubStorage.Role.ADMIN;
    hubGateway = IHubGateway(__hubGateway);
    lighthouse = __lighthouse;
  }

  function maxDiscountDbps(
    bytes32 _tickerHash
  ) external view returns (uint24 _maxDiscountDbps) {
    return _tokenConfigs[_tickerHash].maxDiscountDbps;
  }

  function mockEpochLength(
    uint48 _epochLength
  ) external {
    epochLength = _epochLength;
  }
}

contract BaseTest is TestExtended {
  using stdStorage for StdStorage;

  TestProtocolManager internal protocolManager;
  IHubGateway internal hubGateway;

  address immutable DEPLOYER = makeAddr('DEPLOYER');
  address immutable OWNER = makeAddr('OWNER');
  address immutable ADMIN = makeAddr('ADMIN');
  address immutable ASSET_MANAGER = makeAddr('ASSET_MANAGER');

  address immutable HUB_MAILBOX = makeAddr('HUB_MAILBOX');
  address immutable INTERCHAIN_SECURITY_MODULE = makeAddr('INTERCHAIN_SECURITY_MODULE');
  address immutable LIGHTHOUSE = makeAddr('LIGHTHOUSE');

  bytes metadata;

  function setUp() public {
    vm.startPrank(DEPLOYER);

    address _predictedHubGateway = _addressFrom(DEPLOYER, 2);
    protocolManager = new TestProtocolManager(OWNER, ADMIN, _predictedHubGateway, LIGHTHOUSE); // 0 -> 1

    hubGateway = Deploy.HubGatewayProxy(OWNER, HUB_MAILBOX, address(protocolManager), INTERCHAIN_SECURITY_MODULE); // 1 -> 3

    vm.stopPrank();
    assertEq(_predictedHubGateway, address(hubGateway));

    metadata = StandardHookMetadata.formatMetadata(0, 50_000, address(hubGateway), '');
  }

  function assignAssetManagerRole() internal {
    vm.prank(ADMIN);
    protocolManager.assignRole(ASSET_MANAGER, IHubStorage.Role.ASSET_MANAGER);
  }

  function _mockAcceptanceDelay(
    uint256 _delay
  ) internal {
    stdstore.target(address(protocolManager)).sig(IHubStorage.acceptanceDelay.selector).checked_write(_delay);
  }

  function _addSupportedDomains(
    IHubStorage.DomainSetup[] memory _domains
  ) internal returns (uint32[] memory _uniqueIds) {
    _uniqueIds = new uint32[](_domains.length);
    // Hash each element with a unique nonce to ensure uniqueness
    for (uint256 _i; _i < _domains.length; _i++) {
      // Simple hash function combining the element with its index
      _domains[_i].id = uint32(uint256(keccak256(abi.encodePacked(_domains[_i].id, _i))));
      _uniqueIds[_i] = _domains[_i].id;
    }

    vm.prank(OWNER);
    protocolManager.addSupportedDomains(_domains);
  }
}

contract Unit_OwnershipFunctions is BaseTest {
  event OwnershipProposed(address indexed _proposedOwner, uint256 _timestamp);

  event OwnershipTransferred(address indexed _oldOwner, address indexed _newOwner);

  /**
   * @notice Test the proposeOwner function
   * @param _newOwner The address of the new owner
   */
  function test_ProposeOwner(
    address _newOwner
  ) public {
    vm.assume(_newOwner != address(0) && _newOwner != OWNER);

    _expectEmit(address(protocolManager));
    emit OwnershipProposed(_newOwner, block.timestamp);

    vm.prank(OWNER);
    protocolManager.proposeOwner(_newOwner);

    uint256 _currentTimestamp = block.timestamp;
    assertEq(protocolManager.proposedOwner(), _newOwner);
    assertEq(protocolManager.proposedOwnershipTimestamp(), _currentTimestamp);
  }

  /**
   * @notice Test the proposeOwner function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _newOwner The address of the new owner
   */
  function test_Revert_ProposeOwnerNotOwner(address _caller, address _newOwner) public {
    vm.assume(_newOwner != address(0) && _newOwner != OWNER);
    vm.assume(_caller != OWNER);
    vm.prank(_caller);
    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);
    protocolManager.proposeOwner(_newOwner);
  }

  /**
   * @notice Test the accept ownership function
   * @param _timestamp The timestamp to warp to
   * @param _delay The acceptance delay
   * @param _newOwner The address of the new owner
   */
  function test_AcceptOwnership(uint256 _timestamp, uint256 _delay, address _newOwner) public {
    vm.assume(_newOwner != address(0) && _newOwner != OWNER);
    vm.assume(type(uint256).max - _timestamp > _delay);
    _mockAcceptanceDelay(_delay);

    vm.warp(_timestamp);

    _expectEmit(address(protocolManager));
    emit OwnershipProposed(_newOwner, _timestamp);

    vm.prank(OWNER);
    protocolManager.proposeOwner(_newOwner);

    vm.warp(block.timestamp + protocolManager.acceptanceDelay() + 1);

    _expectEmit(address(protocolManager));
    emit OwnershipTransferred(OWNER, _newOwner);

    vm.prank(_newOwner);
    protocolManager.acceptOwnership();

    assertEq(protocolManager.owner(), _newOwner);
  }

  /**
   * @notice Test the accept ownership function reverts when the caller is not the proposed owner
   * @param _caller The address of the caller
   * @param _newOwner The address of the new owner
   */
  function test_Revert_AcceptOwnershipNotProposedOwner(address _caller, address _newOwner) public {
    vm.assume(_newOwner != address(0) && _newOwner != OWNER);
    vm.assume(_caller != _newOwner);
    vm.prank(OWNER);
    protocolManager.proposeOwner(_newOwner);

    vm.prank(_caller);
    vm.expectRevert(IProtocolManager.ProtocolManager_AcceptOwnership_NotProposedOwner.selector);
    protocolManager.acceptOwnership();
  }

  /**
   * @notice Test the accept ownership function reverts when the acceptance delay has not elapsed
   * @param _timestamp The timestamp to warp to
   * @param _delay The acceptance delay
   * @param _timeElapsed The time elapsed
   * @param _newOwner The address of the new owner
   */
  function test_Revert_AcceptOwnershipDelayNotElapsed(
    uint256 _timestamp,
    uint256 _delay,
    uint256 _timeElapsed,
    address _newOwner
  ) public {
    vm.assume(_newOwner != address(0) && _newOwner != OWNER);
    vm.assume(type(uint256).max - _timestamp >= _delay);
    vm.assume(_timeElapsed <= _delay);

    _mockAcceptanceDelay(_delay);

    vm.warp(_timestamp);

    vm.prank(OWNER);
    protocolManager.proposeOwner(_newOwner);

    vm.warp(_timestamp + _timeElapsed);

    vm.prank(_newOwner);
    vm.expectRevert(IProtocolManager.ProtocolManager_AcceptOwnership_DelayNotElapsed.selector);
    protocolManager.acceptOwnership();
  }
}

contract Unit_RoleManagementFunctions is BaseTest {
  event RoleAssigned(address indexed _account, IHubStorage.Role _role);

  /**
   * @notice Test the assignRole function
   * @param _account The address of the account
   * @param _roleIndex The index of the role
   */
  function test_AssignRole(address _account, uint256 _roleIndex) public {
    vm.assume(_account != address(0) && _account != ADMIN);
    IHubStorage.Role _role = IHubStorage.Role(bound(_roleIndex, 0, 1));

    _expectEmit(address(protocolManager));
    emit RoleAssigned(_account, _role);

    vm.prank(ADMIN);
    protocolManager.assignRole(_account, _role);

    assertEq(uint256(protocolManager.roles(_account)), uint256(_role));
  }

  /**
   * @notice Test the assignRole function reverts when the caller is not the admin
   * @param _caller The address of the caller
   */
  function test_Revert_AssignRoleNotAdmin(
    address _caller
  ) public {
    vm.assume(_caller != address(0) && _caller != ADMIN && _caller != OWNER);
    vm.prank(_caller);
    vm.expectRevert(IProtocolManager.ProtocolManager_Unauthorized.selector);
    protocolManager.assignRole(ASSET_MANAGER, IHubStorage.Role.ASSET_MANAGER);
  }
}

contract Unit_PauseAndUnpauseFunctions is BaseTest {
  event Paused();

  event Unpaused();

  /**
   * @notice Test the pause function
   */
  function test_Pause() public {
    _expectEmit(address(protocolManager));
    emit Paused();

    vm.prank(OWNER);
    protocolManager.pause();

    assertTrue(protocolManager.paused());
  }

  /**
   * @notice Test the unpause function
   */
  function test_Unpause() public {
    vm.startPrank(OWNER);

    _expectEmit(address(protocolManager));
    emit Paused();
    protocolManager.pause();

    _expectEmit(address(protocolManager));
    emit Unpaused();
    protocolManager.unpause();

    vm.stopPrank();

    assertFalse(protocolManager.paused());
  }

  /**
   * @notice Test the pause function reverts when the caller is not the owner
   * @param _caller The address of the caller
   */
  function test_Revert_PauseNotAuthorized(
    address _caller
  ) public {
    vm.assume(_caller != OWNER && _caller != address(0) && _caller != LIGHTHOUSE);
    vm.prank(_caller);
    vm.expectRevert(IHubStorage.HubStorage_Pause_NotAuthorized.selector);
    protocolManager.pause();
  }

  /**
   * @notice Test the unpause function reverts when the caller is not the owner
   * @param _caller The address of the caller
   */
  function test_Revert_UnpauseNotAuthorized(
    address _caller
  ) public {
    vm.assume(_caller != OWNER && _caller != address(0) && _caller != LIGHTHOUSE);
    vm.prank(OWNER);
    protocolManager.pause();

    vm.prank(_caller);
    vm.expectRevert(IHubStorage.HubStorage_Pause_NotAuthorized.selector);
    protocolManager.unpause();
  }
}

contract Unit_FeeAndDomainFunctions is BaseTest {
  event LighthouseUpdated(address _oldLighthouse, address _newLighthouse, bytes32[] _messageIds);
  event ManagerUpdated(address _oldManager, address _newManager);
  event SettlerUpdated(address _oldSettler, address _newSettler);
  event AcceptanceDelayUpdated(uint256 _oldAcceptanceDelay, uint256 _newAcceptanceDelay);
  event SupportedDomainsAdded(IHubStorage.DomainSetup[] _domains);
  event SupportedDomainsRemoved(uint32[] _domains);
  event MinSolverSupportedDomainsUpdated(uint8 _oldMinSolverSupportedDomains, uint8 _newMinSolverSupportedDomains);
  event ExpiryTimeBufferUpdated(uint48 _oldExpiryTimeBuffer, uint48 _newExpiryTimeBuffer);
  event DiscountPerEpochUpdated(uint24 _oldDiscountPerEpoch, uint24 _newDiscountPerEpoch);
  event EpochLengthUpdated(uint48 _oldEpochLength, uint48 _newEpochLength);
  event MaxDiscountDbpsSet(bytes32 _tickerHash, uint24 _oldMaxDiscountDbps, uint24 _newMaxDiscountDbps);

  mapping(uint32 => bool) internal _seen;

  /**
   * @notice Test the updateAcceptanceDelay function
   * @param _newDelay The new acceptance delay
   */
  function test_UpdateAcceptanceDelay(
    uint256 _newDelay
  ) public {
    _expectEmit(address(protocolManager));
    emit AcceptanceDelayUpdated(protocolManager.acceptanceDelay(), _newDelay);

    vm.prank(OWNER);
    protocolManager.updateAcceptanceDelay(_newDelay);

    assertEq(protocolManager.acceptanceDelay(), _newDelay);
  }

  /**
   * @notice Test the updateAcceptanceDelay function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _newDelay The new acceptance delay
   */
  function test_Revert_UpdateAcceptanceDelayNotOwnerOrAdmin(address _caller, uint256 _newDelay) public {
    vm.assume(_caller != OWNER && _caller != ADMIN && _caller != address(0));

    vm.prank(_caller);
    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);
    protocolManager.updateAcceptanceDelay(_newDelay);
  }

  /**
   * @notice Test the updateMinSolverSupportedDomains function
   * @param _newMinDomains The new minimum number of supported domains
   */
  function test_UpdateMinSolverSupportedDomains(
    uint8 _newMinDomains
  ) public {
    _expectEmit(address(protocolManager));
    emit MinSolverSupportedDomainsUpdated(protocolManager.minSolverSupportedDomains(), _newMinDomains);

    vm.prank(OWNER);
    protocolManager.updateMinSolverSupportedDomains(_newMinDomains);

    assertEq(protocolManager.minSolverSupportedDomains(), _newMinDomains);
  }

  /**
   * @notice Test the updateMinSolverSupportedDomains function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _newMinDomains The new minimum number of supported domains
   */
  function test_Revert_UpdateMinSolverSupportedDomainsNotOwnerOrAdmin(address _caller, uint8 _newMinDomains) public {
    vm.assume(_caller != OWNER && _caller != ADMIN);

    vm.prank(_caller);
    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);
    protocolManager.updateMinSolverSupportedDomains(_newMinDomains);
  }

  /**
   * @notice Test the addSupportedDomains function
   * @param _domains The domains to add
   */
  function test_AddSupportedDomains(
    IHubStorage.DomainSetup[] memory _domains
  ) public {
    vm.assume(_domains.length > 0);

    // Hash each element with a unique nonce to ensure uniqueness
    for (uint256 _i; _i < _domains.length; _i++) {
      // Simple hash function combining the element with its index
      _domains[_i].id = uint32(uint256(keccak256(abi.encodePacked(_domains[_i].id, _i))));
    }

    _expectEmit(address(protocolManager));
    emit SupportedDomainsAdded(_domains);

    vm.prank(OWNER);
    protocolManager.addSupportedDomains(_domains);

    uint32[] memory _supportedDomains = protocolManager.supportedDomains();

    for (uint256 _i; _i < _domains.length; _i++) {
      assertEq(_domains[_i].id, _supportedDomains[_i]);
    }
  }

  /**
   * @notice Test the addSupportedDomains function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _domains The domains to add
   */
  function test_Revert_AddSupportedDomainsNotOwnerOrAdmin(
    address _caller,
    IHubStorage.DomainSetup[] memory _domains
  ) public {
    vm.assume(_caller != OWNER && _caller != ADMIN);

    for (uint256 _i; _i < _domains.length; _i++) {
      _domains[_i].id = uint32(uint256(keccak256(abi.encodePacked(_domains[_i].id, _i))));
    }

    vm.prank(_caller);
    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);
    protocolManager.addSupportedDomains(_domains);
  }

  /**
   * @notice Test the addSupportedDomains function reverts when a domain is already added
   * @param _domains The domains to add
   */
  function test_Revert_AddSupportedDomainsAlreadyAdded(
    IHubStorage.DomainSetup[] memory _domains
  ) public {
    uint256 _arrayLength = _domains.length;
    vm.assume(_arrayLength > 1);

    uint32 _firstDuplicate;
    bool _duplicateFound = false;

    // Iterate over the array to find the first duplicate
    for (uint256 _i; _i < _arrayLength; _i++) {
      if (_seen[_domains[_i].id]) {
        _firstDuplicate = _domains[_i].id;
        _duplicateFound = true;
        break;
      }
      _seen[_domains[_i].id] = true;
    }

    // Introduce a duplicate deliberately if no duplicate is found
    if (!_duplicateFound) {
      uint256 _randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp))) % _arrayLength;
      uint256 _targetIndex = (_randomIndex + 1) % _arrayLength; // Ensure it's a different index

      // Make sure we're not duplicating the same index
      while (_targetIndex == _randomIndex) {
        _targetIndex = (_targetIndex + 1) % _arrayLength;
      }

      _domains[_targetIndex].id = _domains[_randomIndex].id;
      _firstDuplicate = _domains[_randomIndex].id;
    }

    vm.prank(OWNER);
    vm.expectRevert(
      abi.encodeWithSelector(
        IProtocolManager.ProtocolManager_AddSupportedDomains_SupportedDomainAlreadyAdded.selector, _firstDuplicate
      )
    );

    protocolManager.addSupportedDomains(_domains);
  }

  /**
   * @notice Test the removeSupportedDomains function
   * @param _domains The domains to remove
   */
  function test_RemoveSupportedDomains(
    IHubStorage.DomainSetup[] memory _domains
  ) public {
    vm.assume(_domains.length > 0);
    uint32[] memory _domainIds = new uint32[](_domains.length);
    for (uint256 _i; _i < _domains.length; _i++) {
      _domains[_i].id = uint32(uint256(keccak256(abi.encodePacked(_domains[_i].id, _i))));
      _domainIds[_i] = _domains[_i].id;
    }

    vm.prank(OWNER);
    protocolManager.addSupportedDomains(_domains);

    _expectEmit(address(protocolManager));
    emit SupportedDomainsRemoved(_domainIds);

    vm.prank(OWNER);
    protocolManager.removeSupportedDomains(_domainIds);

    assertEq(protocolManager.supportedDomains().length, 0);
  }

  /**
   * @notice Test the removeSupportedDomains function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _domains The domains to remove
   */
  function test_Revert_RemoveSupportedDomains_NotOwnerOrAdmin(address _caller, uint32[] memory _domains) public {
    vm.assume(_caller != OWNER && _caller != ADMIN);

    for (uint256 _i; _i < _domains.length; _i++) {
      _domains[_i] = uint32(uint256(keccak256(abi.encodePacked(_domains[_i], _i))));
    }

    vm.prank(_caller);
    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);
    protocolManager.removeSupportedDomains(_domains);
  }

  /**
   * @notice Test the removeSupportedDomains function reverts when a domain is not found
   * @param _domains The domains to remove
   */
  function test_Revert_RemoveSupportedDomains_DomainNotFound(
    uint32[] memory _domains
  ) public {
    vm.assume(_domains.length > 0);

    for (uint256 _i; _i < _domains.length; _i++) {
      _domains[_i] = uint32(uint256(keccak256(abi.encodePacked(_domains[_i], _i))));
    }

    vm.expectRevert(
      abi.encodeWithSelector(
        IProtocolManager.ProtocolManager_RemoveSupportedDomains_SupportedDomainNotFound.selector, _domains[0]
      )
    );

    vm.prank(OWNER);
    protocolManager.removeSupportedDomains(_domains);
  }

  /**
   * @notice Test the updateExpiryTimeBuffer function
   * @param _newBuffer The new expiry time buffer
   */
  function test_UpdateExpiryTimeBuffer(
    uint48 _newBuffer
  ) public {
    _expectEmit(address(protocolManager));
    emit ExpiryTimeBufferUpdated(protocolManager.expiryTimeBuffer(), _newBuffer);

    vm.prank(OWNER);
    protocolManager.updateExpiryTimeBuffer(_newBuffer);

    assertEq(protocolManager.expiryTimeBuffer(), _newBuffer);
  }

  /**
   * @notice Test the updateExpiryTimeBuffer function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _newBuffer The new expiry time buffer
   */
  function test_Revert_UpdateExpiryTimeBufferNotOwnerOrAdmin(address _caller, uint48 _newBuffer) public {
    vm.assume(_caller != OWNER && _caller != ADMIN);

    vm.prank(_caller);
    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);
    protocolManager.updateExpiryTimeBuffer(_newBuffer);
  }

  /**
   * @notice Test the updateEpochLength function
   * @param _previousEpochLength The previous epoch length
   * @param _newEpochLength The new epoch length
   */
  function test_UpdateEpochLength(uint48 _previousEpochLength, uint48 _newEpochLength) public {
    vm.assume(_newEpochLength != 0 && _previousEpochLength != 0 && _newEpochLength != _previousEpochLength);
    protocolManager.mockEpochLength(_previousEpochLength);
    _expectEmit(address(protocolManager));
    emit EpochLengthUpdated(protocolManager.epochLength(), _newEpochLength);

    vm.prank(OWNER);
    protocolManager.updateEpochLength(_newEpochLength);

    assertEq(protocolManager.epochLength(), _newEpochLength);
  }

  /**
   * @notice Test the updateEpochLength function to a greater value
   * @param _previousEpochLength The previous epoch length
   * @param _newEpochLength The new epoch length
   */
  function test_UpdateEpochLength_GreaterValue(
    uint48 _blockNumber,
    uint48 _previousEpochLength,
    uint48 _newEpochLength
  ) public {
    vm.assume(_newEpochLength != 0 && _previousEpochLength != 0 && _newEpochLength > _previousEpochLength);
    protocolManager.mockEpochLength(_previousEpochLength);
    vm.roll(_blockNumber);

    uint48 _previousCurrentEpoch = protocolManager.getCurrentEpoch();

    _expectEmit(address(protocolManager));
    emit EpochLengthUpdated(protocolManager.epochLength(), _newEpochLength);

    vm.prank(OWNER);
    protocolManager.updateEpochLength(_newEpochLength);

    uint48 _currentEpoch = protocolManager.getCurrentEpoch();

    assertEq(protocolManager.epochLength(), _newEpochLength);
    assertEq(_currentEpoch, _previousCurrentEpoch, 'Current epoch should be greater than or equal to the previous');
  }

  /**
   * @notice Test the updateEpochLength function to a lesser value
   * @param _previousEpochLength The previous epoch length
   * @param _newEpochLength The new epoch length
   */
  function test_UpdateEpochLength_LesserValue(
    uint48 _blockNumber,
    uint48 _previousEpochLength,
    uint48 _newEpochLength
  ) public {
    vm.assume(_newEpochLength != 0 && _previousEpochLength != 0 && _newEpochLength < _previousEpochLength);
    protocolManager.mockEpochLength(_previousEpochLength);
    vm.roll(_blockNumber);

    uint48 _previousCurrentEpoch = protocolManager.getCurrentEpoch();

    _expectEmit(address(protocolManager));
    emit EpochLengthUpdated(protocolManager.epochLength(), _newEpochLength);

    vm.prank(OWNER);
    protocolManager.updateEpochLength(_newEpochLength);

    uint48 _currentEpoch = protocolManager.getCurrentEpoch();

    assertEq(protocolManager.epochLength(), _newEpochLength);
    assertEq(_currentEpoch, _previousCurrentEpoch, 'Current epoch should be greater than or equal to the previous');
  }

  /**
   * @notice Test the updateEpochLength function to a greater value and then to a lesser value
   * @param _previousEpochLength The previous epoch length
   * @param _newEpochLength The new epoch length
   */
  function test_UpdateEpochLength_Double_GreaterValueLesserValue(
    uint48 _blockNumber,
    uint48 _previousEpochLength,
    uint48 _newEpochLength,
    uint48 _blocksElapsed
  ) public {
    vm.assume(_newEpochLength != 0 && _previousEpochLength != 0 && _newEpochLength > _previousEpochLength);
    vm.assume(_blocksElapsed > _blockNumber);
    vm.assume(type(uint48).max - _blockNumber > _blocksElapsed);
    protocolManager.mockEpochLength(_previousEpochLength);
    vm.roll(_blockNumber);

    uint48 _previousCurrentEpoch = protocolManager.getCurrentEpoch();

    _expectEmit(address(protocolManager));
    emit EpochLengthUpdated(protocolManager.epochLength(), _newEpochLength);

    vm.prank(OWNER);
    protocolManager.updateEpochLength(_newEpochLength);

    uint48 _currentEpoch = protocolManager.getCurrentEpoch();

    assertEq(protocolManager.epochLength(), _newEpochLength);
    assertEq(_currentEpoch, _previousCurrentEpoch, 'Current epoch should be greater than or equal to the previous');

    vm.roll(uint256(_blocksElapsed) + _blockNumber);

    // Double update
    _previousCurrentEpoch = protocolManager.getCurrentEpoch();

    _expectEmit(address(protocolManager));
    emit EpochLengthUpdated(protocolManager.epochLength(), _previousEpochLength);

    vm.prank(OWNER);
    protocolManager.updateEpochLength(_previousEpochLength);

    _currentEpoch = protocolManager.getCurrentEpoch();

    assertEq(protocolManager.epochLength(), _previousEpochLength);
    assertEq(
      _currentEpoch,
      _previousCurrentEpoch,
      'Second update, current epoch should be greater than or equal to the previous'
    );
  }

  /**
   * @notice Test the updateEpochLength function to a lesser value and then to a greater value
   * @param _greaterEpochLength The greater epoch length
   * @param _lesserEpochLength The lesser epoch length
   */
  function test_UpdateEpochLength_Double_LesserValueGreaterValue(
    uint48 _blockNumber,
    uint48 _greaterEpochLength,
    uint48 _lesserEpochLength,
    uint48 _blocksElapsed
  ) public {
    vm.assume(_greaterEpochLength != 0 && _lesserEpochLength != 0 && _greaterEpochLength > _lesserEpochLength);
    vm.assume(_blocksElapsed > _blockNumber);
    vm.assume(type(uint48).max - _blockNumber > _blocksElapsed);
    protocolManager.mockEpochLength(_greaterEpochLength);
    vm.roll(_blockNumber);

    uint48 _previousCurrentEpoch = protocolManager.getCurrentEpoch();

    _expectEmit(address(protocolManager));
    emit EpochLengthUpdated(protocolManager.epochLength(), _lesserEpochLength);

    vm.prank(OWNER);
    protocolManager.updateEpochLength(_lesserEpochLength);

    uint48 _currentEpoch = protocolManager.getCurrentEpoch();

    assertEq(protocolManager.epochLength(), _lesserEpochLength);
    assertEq(_currentEpoch, _previousCurrentEpoch, 'Current epoch should be greater than or equal to the previous');

    vm.roll(uint256(_blocksElapsed) + _blockNumber);

    // Double update
    _previousCurrentEpoch = protocolManager.getCurrentEpoch();

    _expectEmit(address(protocolManager));
    emit EpochLengthUpdated(protocolManager.epochLength(), _greaterEpochLength);

    vm.prank(OWNER);
    protocolManager.updateEpochLength(_greaterEpochLength);

    _currentEpoch = protocolManager.getCurrentEpoch();

    assertEq(protocolManager.epochLength(), _greaterEpochLength);
    assertEq(
      _currentEpoch,
      _previousCurrentEpoch,
      'Second update, current epoch should be greater than or equal to the previous'
    );
  }

  /**
   * @notice Test the updateEpochLength function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _newEpochLength The new epoch length
   */
  function test_Revert_UpdateEpochLengthNotOwnerOrAdmin(address _caller, uint48 _newEpochLength) public {
    vm.assume(_caller != OWNER && _caller != ADMIN);

    vm.prank(_caller);
    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);
    protocolManager.updateEpochLength(_newEpochLength);
  }

  /**
   * @notice Test the updateEpochLength function reverts when the epoch length is invalid
   */
  function test_Revert_UpdateEpochLength_InvalidEpochLength() public {
    vm.expectRevert(IProtocolManager.ProtocolManager_UpdateEpochLength_InvalidEpochLength.selector);

    vm.prank(OWNER);
    protocolManager.updateEpochLength(0);
  }

  /**
   * @notice Test the setMaxDiscountDbps function
   * @param _tickerHash The hash of the ticker
   * @param _newMaxDiscountDbps The new max discount dbps
   */
  function test_SetMaxDiscountDbps(bytes32 _tickerHash, uint24 _newMaxDiscountDbps) public {
    _newMaxDiscountDbps = _newMaxDiscountDbps % Constants.DBPS_DENOMINATOR;

    _expectEmit(address(protocolManager));
    emit MaxDiscountDbpsSet(_tickerHash, protocolManager.maxDiscountDbps(_tickerHash), _newMaxDiscountDbps);

    vm.prank(OWNER);
    protocolManager.setMaxDiscountDbps(_tickerHash, _newMaxDiscountDbps);

    assertEq(protocolManager.maxDiscountDbps(_tickerHash), _newMaxDiscountDbps);
  }

  /**
   * @notice Test the setMaxDiscountDbps function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker
   * @param _newMaxDiscountDbps The new max discount dbps
   */
  function test_Revert_SetMaxDiscountDbps_NotOwnerOrAdmin(
    address _caller,
    bytes32 _tickerHash,
    uint24 _newMaxDiscountDbps
  ) public {
    vm.assume(_caller != OWNER && _caller != ADMIN);

    vm.prank(_caller);
    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);
    protocolManager.setMaxDiscountDbps(_tickerHash, _newMaxDiscountDbps);
  }

  /**
   * @notice Test the setMaxDiscountDbps function reverts when the discount is invalid
   * @param _tickerHash The hash of the ticker
   * @param _newMaxDiscountDbps The new max discount dbps
   */
  function test_Revert_SetMaxDiscountDbps_InvalidDiscount(bytes32 _tickerHash, uint24 _newMaxDiscountDbps) public {
    vm.assume(_newMaxDiscountDbps > Constants.DBPS_DENOMINATOR);

    vm.expectRevert(IProtocolManager.ProtocolManager_SetMaxDiscountDbps_InvalidDiscount.selector);

    vm.prank(OWNER);
    protocolManager.setMaxDiscountDbps(_tickerHash, _newMaxDiscountDbps);
  }
}

contract Unit_UpdateGatewayStorage is BaseTest {
  using TypeCasts for bytes32;

  /**
   * @notice Test the updateMailbox function
   * @param _newMailbox The new mailbox address
   */
  function test_UpdateMailbox(
    address _newMailbox
  ) public validAddress(_newMailbox) {
    vm.prank(OWNER);

    vm.expectCall(address(hubGateway), abi.encodeWithSignature('updateMailbox(address)', _newMailbox));
    protocolManager.updateMailbox(_newMailbox);
  }

  /**
   * @notice Test the updateMailbox function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _newMailbox The new mailbox address
   */
  function test_Revert_UpdateMailboxNonOwner(address _caller, address _newMailbox) public validAddress(_newMailbox) {
    vm.assume(_caller != OWNER);
    vm.prank(_caller);

    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);
    protocolManager.updateMailbox(_newMailbox);
  }

  /**
   * @notice Test the updateMailbox function reverts when the mailbox address is zero
   */
  function test_Revert_UpdateMailboxZeroAddress() public {
    vm.prank(OWNER);

    vm.expectRevert(IGateway.Gateway_ZeroAddress.selector);
    protocolManager.updateMailbox(address(0));
  }

  /**
   * @notice Test the updateSecurityModule function
   * @param _newSecurityModule The new security module address
   */
  function test_UpdateSecurityModule(
    address _newSecurityModule
  ) public validAddress(_newSecurityModule) {
    vm.prank(OWNER);

    vm.expectCall(address(hubGateway), abi.encodeWithSignature('updateSecurityModule(address)', _newSecurityModule));
    protocolManager.updateSecurityModule(_newSecurityModule);
  }

  /**
   * @notice Test the updateSecurityModule function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _newSecurityModule The new security module address
   */
  function test_Revert_UpdateSecurityModuleNonOwner(
    address _caller,
    address _newSecurityModule
  ) public validAddress(_newSecurityModule) {
    vm.assume(_caller != OWNER);
    vm.prank(_caller);

    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);
    protocolManager.updateSecurityModule(_newSecurityModule);
  }

  /**
   * @notice Test the updateSecurityModule function reverts when the security module address is zero
   */
  function test_Revert_UpdateSecurityModuleZeroAddress() public {
    vm.prank(OWNER);

    vm.expectRevert(IGateway.Gateway_ZeroAddress.selector);
    protocolManager.updateSecurityModule(address(0));
  }

  /**
   * @notice Test the updateChainGateway function
   * @param _chainId The chain ID
   * @param _gateway The gateway address
   */
  function test_UpdateChainGateway(uint32 _chainId, bytes32 _gateway) public validAddress(_gateway.toAddress()) {
    vm.prank(OWNER);

    vm.expectCall(address(hubGateway), abi.encodeWithSignature('setChainGateway(uint32,bytes32)', _chainId, _gateway));
    protocolManager.updateChainGateway(_chainId, _gateway);
  }

  /**
   * @notice Test the updateChainGateway function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _chainId The chain ID
   * @param _gateway The gateway address
   */
  function test_Revert_UpdateChainGatewayNonOwner(
    address _caller,
    uint32 _chainId,
    bytes32 _gateway
  ) public validAddress(_gateway.toAddress()) {
    vm.assume(_caller != OWNER);
    vm.prank(_caller);

    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);
    protocolManager.updateChainGateway(_chainId, _gateway);
  }

  /**
   * @notice Test the updateChainGateway function reverts when the gateway address is zero
   * @param _chainId The chain ID
   */
  function test_Revert_UpdateChainGatewayZeroAddress(
    uint32 _chainId
  ) public {
    vm.prank(OWNER);

    vm.expectRevert(IGateway.Gateway_ZeroAddress.selector);
    protocolManager.updateChainGateway(_chainId, bytes32(0));
  }

  /**
   * @notice Test the removeChainGateway function
   * @param _chainId The chain ID
   * @param _gateway The gateway address
   */
  function test_RemoveChainGateway(uint32 _chainId, bytes32 _gateway) public validAddress(_gateway.toAddress()) {
    vm.startPrank(OWNER);
    vm.expectCall(address(hubGateway), abi.encodeWithSignature('setChainGateway(uint32,bytes32)', _chainId, _gateway));
    protocolManager.updateChainGateway(_chainId, _gateway);

    vm.expectCall(address(hubGateway), abi.encodeWithSignature('removeChainGateway(uint32)', _chainId));
    protocolManager.removeChainGateway(_chainId);
    vm.stopPrank();
  }

  /**
   * @notice Test the removeChainGateway function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _chainId The chain ID
   */
  function test_Revert_RemoveChainGatewayNonOwner(address _caller, uint32 _chainId) public {
    vm.assume(_caller != OWNER);
    vm.prank(_caller);

    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);
    protocolManager.removeChainGateway(_chainId);
  }

  /**
   * @notice Test the removeChainGateway function reverts when the chain gateway is already removed
   * @param _chainId The chain ID
   */
  function test_Revert_RemoveChainGatewayAlreadyRemoved(
    uint32 _chainId
  ) public {
    vm.prank(OWNER);

    vm.expectRevert(
      abi.encodeWithSelector(IHubGateway.HubGateway_RemoveGateway_GatewayAlreadyRemoved.selector, _chainId)
    );
    protocolManager.removeChainGateway(_chainId);
  }
}

contract Unit_CrossChainUpdates is BaseTest {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  event MailboxUpdated(address _mailbox, uint32[] _domains, bytes32[] _messageIds);
  event LighthouseUpdated(address _oldLighthouse, address _newLighthouse, bytes32[] _messageIds);
  event WatchtowerUpdated(address _oldWatchtower, address _newWatchtower, bytes32[] _messageIds);
  event MaxSolversFeeUpdated(uint24 _oldMaxSolversFee, uint24 _newMaxSolversFee, bytes32[] _messageIds);
  event IntentTTLUpdated(uint256 _oldIntentTTL, uint256 _newIntentTTL, bytes32[] _messageIds);

  /**
   * @notice Test the updateLighthouse function
   * @param _chainGateway The chain gateway address
   * @param _lighthouse The lighthouse address
   */
  function test_UpdateLighthouse(
    address _chainGateway,
    address _lighthouse,
    IHubStorage.DomainSetup[] memory _domains
  ) public validAddress(_lighthouse) validAddress(_chainGateway) {
    vm.assume(_domains.length > 0);
    uint256 _length = _domains.length;
    bytes memory _message =
      MessageLib.formatAddressUpdateMessage(keccak256(abi.encode('LIGHTHOUSE')), _lighthouse.toBytes32());
    uint32[] memory _uniqueDomains = new uint32[](_length);
    _uniqueDomains = _addSupportedDomains(_domains);
    bytes32[] memory _messageIds = new bytes32[](_length);
    // Mock the dispatchHub function for each domain
    for (uint256 _i; _i < _length; _i++) {
      vm.prank(address(protocolManager));
      hubGateway.setChainGateway(_uniqueDomains[_i], _chainGateway.toBytes32());
      _messageIds[_i] = _mockDispatchHub(
        address(HUB_MAILBOX), address(hubGateway), _uniqueDomains[_i], _chainGateway, _message, metadata
      );
      vm.expectCall(
        address(HUB_MAILBOX),
        abi.encodeWithSignature(
          'dispatch(uint32,bytes32,bytes,bytes)', _uniqueDomains[_i], _chainGateway.toBytes32(), _message, metadata
        )
      );
    }

    _expectEmit(address(protocolManager));
    emit LighthouseUpdated(protocolManager.lighthouse(), _lighthouse, _messageIds);
    vm.prank(OWNER);

    protocolManager.updateLighthouse(_lighthouse);

    assertEq(protocolManager.lighthouse(), _lighthouse);
  }

  /**
   * @notice Test the updateLighthouse function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _lighthouse The lighthouse address
   */
  function test_Revert_UpdateLighthouse_NotOwner(address _caller, address _lighthouse) public {
    vm.assume(_caller != OWNER && _caller != address(0));
    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);
    protocolManager.updateLighthouse(_lighthouse);
  }

  /**
   * @notice Test the updateLighthouse function reverts when the lighthouse address is zero
   */
  function test_Revert_UpdateLighthouse_ZeroAddress() public {
    vm.prank(OWNER);
    vm.expectRevert(IHubStorage.HubStorage_InvalidAddress.selector);
    protocolManager.updateLighthouse(address(0));
  }

  /**
   * @notice Test the updateWatchtower function
   * @param _chainGateway The chain gateway address
   * @param _watchtower The watchtower address
   */
  function test_UpdateWatchtower(
    address _chainGateway,
    address _watchtower,
    IHubStorage.DomainSetup[] memory _domains
  ) public validAddress(_watchtower) validAddress(_chainGateway) {
    vm.assume(_domains.length > 0);
    bytes memory _message =
      MessageLib.formatAddressUpdateMessage(keccak256(abi.encode('WATCHTOWER')), _watchtower.toBytes32());
    uint32[] memory _uniqueDomains = new uint32[](_domains.length);
    _uniqueDomains = _addSupportedDomains(_domains);
    uint256 _length = _domains.length;
    bytes32[] memory _messageIds = new bytes32[](_length);
    // Mock the dispatchHub function for each domain
    for (uint256 _i; _i < _length; _i++) {
      vm.prank(address(protocolManager));
      hubGateway.setChainGateway(_uniqueDomains[_i], _chainGateway.toBytes32());
      _messageIds[_i] = _mockDispatchHub(
        address(HUB_MAILBOX), address(hubGateway), _uniqueDomains[_i], _chainGateway, _message, metadata
      );
      vm.expectCall(
        address(HUB_MAILBOX),
        abi.encodeWithSignature(
          'dispatch(uint32,bytes32,bytes,bytes)', _uniqueDomains[_i], _chainGateway.toBytes32(), _message, metadata
        )
      );
    }
    _expectEmit(address(protocolManager));
    emit WatchtowerUpdated(protocolManager.watchtower(), _watchtower, _messageIds);

    vm.prank(OWNER);

    protocolManager.updateWatchtower(_watchtower);

    assertEq(protocolManager.watchtower(), _watchtower);
  }

  /**
   * @notice Test the updateWatchtower function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _watchtower The watchtower address
   */
  function test_Revert_UpdateWatchtower_NotOwner(address _caller, address _watchtower) public {
    vm.assume(_caller != OWNER && _caller != address(0));
    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);
    protocolManager.updateWatchtower(_watchtower);
  }

  /**
   * @notice Test the updateWatchtower function reverts when the watchtower address is zero
   */
  function test_Revert_UpdateWatchtower_ZeroAddress() public {
    vm.prank(OWNER);
    vm.expectRevert(IHubStorage.HubStorage_InvalidAddress.selector);
    protocolManager.updateWatchtower(address(0));
  }
}

contract Unit_DomainSpecificUpdates is BaseTest {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  event MailboxUpdated(bytes32 _mailbox, uint32[] _domains, bytes32[] _messageIds);
  event GatewayUpdated(bytes32 _gateway, uint32[] _domains, bytes32[] _messageIds);
  event SecurityModuleUpdated(address _securityModule, uint32[] _domains, bytes32[] _messageIds);

  /**
   * @notice Test the updateMailbox function
   * @param _chainGateway The chain gateway address
   * @param _mailbox The mailbox address
   * @param _domains The domains to update
   */
  function test_UpdateDomainMailbox(
    address _chainGateway,
    bytes32 _mailbox,
    uint32[] calldata _domains
  ) public validAddress(_chainGateway) validAddress(_mailbox.toAddress()) {
    vm.assume(_domains.length > 0);
    bytes memory _message = MessageLib.formatAddressUpdateMessage(keccak256(abi.encode('MAILBOX')), _mailbox);
    uint256 _length = _domains.length;
    bytes32[] memory _messageIds = new bytes32[](_length);
    // Mock the dispatchHub function for each domain
    for (uint256 _i; _i < _length; _i++) {
      vm.prank(address(protocolManager));
      hubGateway.setChainGateway(_domains[_i], _chainGateway.toBytes32());
      _messageIds[_i] =
        _mockDispatchHub(address(HUB_MAILBOX), address(hubGateway), _domains[_i], _chainGateway, _message, metadata);
      vm.expectCall(
        address(HUB_MAILBOX),
        abi.encodeWithSignature(
          'dispatch(uint32,bytes32,bytes,bytes)', _domains[_i], _chainGateway.toBytes32(), _message, metadata
        )
      );
    }
    _expectEmit(address(protocolManager));
    emit MailboxUpdated(_mailbox, _domains, _messageIds);

    vm.prank(OWNER);
    protocolManager.updateMailbox(_mailbox, _domains);
  }

  /**
   * @notice Test the updateMailbox function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _mailbox The mailbox address
   * @param _domains The domains to update
   */
  function test_Revert_UpdateDomainMailbox_NonOwner(
    address _caller,
    bytes32 _mailbox,
    uint32[] calldata _domains
  ) public {
    vm.assume(_caller != OWNER);
    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);
    vm.prank(_caller);
    protocolManager.updateMailbox(_mailbox, _domains);
  }

  /**
   * @notice Test the updateMailbox function reverts when the mailbox address is zero
   * @param _domains The domains to update
   */
  function test_Revert_UpdateDomainMailbox_ZeroAddress(
    uint32[] calldata _domains
  ) public {
    vm.prank(OWNER);
    vm.expectRevert(IHubStorage.HubStorage_InvalidAddress.selector);
    protocolManager.updateMailbox(address(0).toBytes32(), _domains);
  }

  /**
   * @notice Test the updateGateway function
   * @param _chainGateway The chain gateway address
   * @param _gateway The gateway address
   * @param _domains The domains to update
   */
  function test_UpdateDomainGateway(
    address _chainGateway,
    bytes32 _gateway,
    uint32[] calldata _domains
  ) public validAddress(_chainGateway) validAddress(_gateway.toAddress()) {
    vm.assume(_domains.length > 0);
    bytes memory _message = MessageLib.formatAddressUpdateMessage(keccak256(abi.encode('GATEWAY')), _gateway);
    uint256 _length = _domains.length;
    bytes32[] memory _messageIds = new bytes32[](_length);
    for (uint256 _i; _i < _length; _i++) {
      vm.prank(address(protocolManager));
      hubGateway.setChainGateway(_domains[_i], _chainGateway.toBytes32());
      _messageIds[_i] =
        _mockDispatchHub(address(HUB_MAILBOX), address(hubGateway), _domains[_i], _chainGateway, _message, metadata);
      vm.expectCall(
        address(HUB_MAILBOX),
        abi.encodeWithSignature(
          'dispatch(uint32,bytes32,bytes,bytes)', _domains[_i], _chainGateway.toBytes32(), _message, metadata
        )
      );
    }
    _expectEmit(address(protocolManager));
    emit GatewayUpdated(_gateway, _domains, _messageIds);

    vm.prank(OWNER);

    protocolManager.updateGateway(_gateway, _domains);
  }

  /**
   * @notice Test the updateGateway function reverts when the caller is not the owner
   * @param _caller The address of the caller
   * @param _gateway The gateway address
   * @param _domains The domains to update
   */
  function test_Revert_UpdateDomainGateway_NonOwner(
    address _caller,
    bytes32 _gateway,
    uint32[] calldata _domains
  ) public {
    vm.assume(_caller != OWNER);
    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);
    vm.prank(_caller);
    protocolManager.updateGateway(_gateway, _domains);
  }

  /**
   * @notice Test the updateGateway function reverts when the gateway address is zero
   * @param _domains The domains to update
   */
  function test_Revert_UpdateDomainGateway_ZeroAddress(
    uint32[] calldata _domains
  ) public {
    vm.prank(OWNER);
    vm.expectRevert(IHubStorage.HubStorage_InvalidAddress.selector);
    protocolManager.updateGateway(address(0).toBytes32(), _domains);
  }
}

contract Unit_UpdateGateway is BaseTest {
  event GatewayUpdated(address _oldGateway, address _newGateway);

  /**
   * @notice Test the update of the gateway address
   * @param _oldGateway The old gateway address
   * @param _newGateway The new gateway address
   */
  function test_UpdateGateway(
    address _oldGateway,
    address _newGateway
  ) public validAddress(_oldGateway) validAddress(_newGateway) {
    vm.prank(OWNER);
    protocolManager.updateGateway(_oldGateway);

    _expectEmit(address(protocolManager));
    emit GatewayUpdated(_oldGateway, _newGateway);

    vm.prank(OWNER);
    protocolManager.updateGateway(_newGateway);

    assertEq(address(protocolManager.hubGateway()), _newGateway, 'Gateway not updated');
  }

  /**
   * @notice Test the revert of the update of the gateway address when the caller is not the owner
   * @param _nonOwner The address of the caller
   * @param _newGateway The new mailbox address
   */
  function test_Revert_UpdateGateway_OnlyOwner(address _nonOwner, address _newGateway) public {
    vm.assume(_nonOwner != OWNER);

    vm.expectRevert(IHubStorage.HubStorage_OnlyOwner.selector);

    vm.prank(_nonOwner);
    protocolManager.updateGateway(_newGateway);
  }

  /**
   * @notice Test the revert of the update of the gateway address when the new gateway address is zero
   */
  function test_Revert_UpdateGateway_InvalidAddress() public {
    vm.prank(OWNER);

    vm.expectRevert(IHubStorage.HubStorage_InvalidAddress.selector);
    protocolManager.updateGateway(address(0));
  }
}

contract Unit_UpdateGasConfig is BaseTest {
  event GasConfigUpdated(IHubStorage.GasConfig _oldGasConfig, IHubStorage.GasConfig _newGasConfig);

  /**
   * @notice Test the update of the gas config
   * @param _newGasConfig The new gas config
   */
  function test_UpdateGasConfig(
    IHubStorage.GasConfig calldata _newGasConfig
  ) public {
    vm.assume(_newGasConfig.bufferDBPS < Constants.DBPS_DENOMINATOR);
    IHubStorage.GasConfig memory _oldGasConfig = IHubStorage.GasConfig(0, 0, 0);
    _expectEmit(address(protocolManager));
    emit GasConfigUpdated(_oldGasConfig, _newGasConfig);

    vm.prank(OWNER);
    protocolManager.updateGasConfig(_newGasConfig);

    (uint256 _settlementBaseGasUnits, uint256 _averageGasUnitsPerSettlement, uint256 _bufferDBPS) =
      protocolManager.gasConfig();

    assertEq(_newGasConfig.settlementBaseGasUnits, _settlementBaseGasUnits, 'Settlement base gas units not updated');
    assertEq(
      _newGasConfig.averageGasUnitsPerSettlement,
      _averageGasUnitsPerSettlement,
      'Average gas units per settlement not updated'
    );
    assertEq(_newGasConfig.bufferDBPS, _bufferDBPS, 'Buffer DBPS not updated');
  }

  /**
   * @notice Test the revert of the update of the gas config when the caller is not the owner
   * @param _nonOwner The address of the caller
   * @param _newGasConfig The new gas config
   */
  function test_Revert_Unauthorized(address _nonOwner, IHubStorage.GasConfig calldata _newGasConfig) public {
    vm.assume(_nonOwner != OWNER && _nonOwner != ADMIN);

    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);

    vm.prank(_nonOwner);
    protocolManager.updateGasConfig(_newGasConfig);
  }

  /**
   * @notice Test the revert of the update of the gas config when the buffer DBPS is greater than the denominator
   * @param _newGasConfig The new gas config
   */
  function test_Revert_InvalidBufferDbps(
    IHubStorage.GasConfig calldata _newGasConfig
  ) public {
    vm.assume(_newGasConfig.bufferDBPS > Constants.DBPS_DENOMINATOR);

    vm.expectRevert(IHubStorage.HubStorage_InvalidDbpsValue.selector);

    vm.prank(OWNER);
    protocolManager.updateGasConfig(_newGasConfig);
  }
}
