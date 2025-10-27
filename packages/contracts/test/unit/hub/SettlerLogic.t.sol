// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestExtended} from '../../utils/TestExtended.sol';

import {EverclearHub, IEverclearHub} from 'contracts/hub/EverclearHub.sol';
import {InvoiceListLib} from 'contracts/hub/lib/InvoiceListLib.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {HubStorage, IHubStorage} from 'contracts/hub/HubStorage.sol';
import {SettlerLogic} from 'contracts/hub/modules/SettlerLogic.sol';

import {StdStorage, stdStorage} from 'test/utils/TestExtended.sol';

contract SettlerLogicForTest is SettlerLogic {
  using Uint32Set for Uint32Set.Set;
  using InvoiceListLib for InvoiceListLib.InvoiceList;

  function getDestinations(
    bytes32 _tickerHash,
    bytes32 _intentId,
    bytes32 _user
  ) public view returns (uint32[] memory _destinations) {
    return _getDestinations(_tickerHash, _intentId, _user);
  }

  function getTokenDomains(
    bytes32 _tickerHash
  ) public view returns (uint32[] memory _domains) {
    return _tokenConfigs[_tickerHash].domains.memValues();
  }

  function getUserDomains(
    bytes32 _user
  ) public view returns (uint32[] memory _domains) {
    return _usersSupportedDomains[_user].memValues();
  }

  function getPendingRewards(
    bytes32 _intentId
  ) public view returns (uint256) {
    return _contexts[_intentId].pendingRewards;
  }

  function createInvoice(bytes32 _tickerHash, bytes32 _intentId, uint256 _amount, bytes32 _owner) public {
    _createInvoice(_tickerHash, _intentId, _amount, _owner);
  }

  function findDestinationXerc20Strategy(
    bytes32 _tickerHash,
    uint32[] memory _destinations
  ) public view returns (uint32 _selectedDestination) {
    return _findDestinationXerc20Strategy(_tickerHash, _destinations);
  }

  function findDestinationDefaultStrategy(
    bytes32 _tickerHash,
    uint256 _amountAndRewards,
    uint32[] memory _destinations
  ) public view returns (uint32 _selectedDestination) {
    return _findDestinationDefaultStrategy(_tickerHash, _amountAndRewards, _destinations);
  }

  function createSettlement(
    bytes32 _intentId,
    bytes32 _tickerHash,
    uint256 _amount,
    uint32 _destination,
    bytes32 _recipient
  ) public {
    _createSettlement(_intentId, _tickerHash, _amount, _destination, _recipient);
  }

  function createSettlementOrInvoice(bytes32 _intentId, bytes32 _tickerHash, bytes32 _recipient) public {
    _createSettlementOrInvoice(_intentId, _tickerHash, _recipient);
  }

  function findDestinationWithStrategies(
    bytes32 _tickerHash,
    uint256 _amountAndRewards,
    uint32[] memory _destinations
  ) public view returns (uint32 _selectedDestination) {
    return _findDestinationWithStrategies(_tickerHash, _amountAndRewards, _destinations);
  }

  function getInvoice(bytes32 _tickerHash, bytes32 _id) public view returns (IEverclearHub.Invoice memory) {
    return invoices[_tickerHash].at(_id).invoice;
  }

  function getSettlement(uint32 _destination, uint256 _position) public view returns (IEverclearHub.Settlement memory) {
    return settlements[_destination].queue[_position];
  }

  function mockTokenConfigAssetHash(bytes32 _tickerHash, uint32 _destination, bytes32 _assetHash) public {
    _tokenConfigs[_tickerHash].assetHashes[_destination] = _assetHash;
    _adoptedForAssets[_assetHash].adopted = _assetHash;
  }

  function mockTokenDomain(bytes32 _tickerHash, uint32 _tokenDomain) public {
    _tokenConfigs[_tickerHash].domains.add(_tokenDomain);
  }

  function mockCustodiedAssets(bytes32 _assetHash, uint256 _amount) public {
    custodiedAssets[_assetHash] = _amount;
  }

  function mockUpdateVirtualBalance(bytes32 _user, bool _update) public {
    updateVirtualBalance[_user] = _update;
  }

  function mockAdoptedForAsset(bytes32 _assetHash, bytes32 _adopted) public {
    _adoptedForAssets[_assetHash].adopted = _adopted;
  }

  function mockContextDestinations(bytes32 _intentId, uint32[] memory _destinations) public {
    _contexts[_intentId].intent.destinations = _destinations;
  }

  function mockTokenSupportedDomains(bytes32 _tickerHash, uint32[] memory _tokenSupportedDomains) public {
    for (uint256 _i; _i < _tokenSupportedDomains.length; _i++) {
      _tokenConfigs[_tickerHash].domains.add(_tokenSupportedDomains[_i]);
    }
  }

  function mockUserSupportedDomains(bytes32 _user, uint32[] memory _userSupportedDomains) public {
    for (uint256 _i; _i < _userSupportedDomains.length; _i++) {
      _usersSupportedDomains[_user].add(_userSupportedDomains[_i]);
    }
  }

  function mockAmountAfterFees(bytes32 _intentId, uint256 _amount) public {
    _contexts[_intentId].amountAfterFees = _amount;
  }

  function mockPendingRewards(bytes32 _intentId, uint256 _amount) public {
    _contexts[_intentId].pendingRewards = _amount;
  }

  function mockEpochLength(
    uint48 _epochLength
  ) public {
    epochLength = _epochLength;
  }

  function mockAssetHashStrategy(bytes32 _assetHash, IEverclear.Strategy _strategy) public {
    _adoptedForAssets[_assetHash].strategy = _strategy;
  }

  function mockAssetPrioritizedStrategy(bytes32 _tickerHash, IEverclear.Strategy _strategy) public {
    _tokenConfigs[_tickerHash].prioritizedStrategy = _strategy;
  }
}

contract BaseTest is TestExtended {
  using stdStorage for StdStorage;

  SettlerLogicForTest settlerLogic;

  function setUp() public {
    settlerLogic = new SettlerLogicForTest();
  }

  function _mockEpockLength(
    uint48 _epochLength
  ) internal {
    //stdstore.target(address(settlerLogic)).sig(IHubStorage.epochLength.selector).checked_write(_epochLength);
    settlerLogic.mockEpochLength(_epochLength);
  }

  event SettlementEnqueued(
    bytes32 indexed _intentId,
    uint32 indexed _domain,
    uint48 indexed _entryEpoch,
    bytes32 _asset,
    uint256 _amount,
    bool _updateVirtualBalance,
    bytes32 _owner
  );

  event InvoiceEnqueued(
    bytes32 indexed _intentId, bytes32 indexed _tickerHash, uint48 indexed _entryEpoch, uint256 _amount, bytes32 _owner
  );
}

contract Unit_CurrentEpoch is BaseTest {
  /**
   * @notice Test the current epoch
   * @param _epochLength The epoch length
   * @param _blocknumber The block number
   */
  function test_CurrentEpoch(uint48 _epochLength, uint256 _blocknumber) public {
    vm.assume(_epochLength > 0);
    vm.roll(_blocknumber);
    _mockEpockLength(_epochLength);
    uint48 epoch = settlerLogic.getCurrentEpoch();
    uint48 expectedEpoch = uint48(_blocknumber / _epochLength);
    assertEq(epoch, expectedEpoch, 'Invalid epoch');
  }
}

contract Unit_GetDestinations is BaseTest {
  /**
   * @notice Test the get destinations when the user supported domains are empty and the intent destinations are not empty
   * @param _tickerHash The hash of the ticker symbol
   * @param _intentId The intent id
   * @param _user The user
   * @param _destinations The destinations
   */
  function test_UserSupportedDomainsEmptyAndIntentDestinationsNotEmpty(
    bytes32 _tickerHash,
    bytes32 _intentId,
    bytes32 _user,
    uint32[] memory _destinations
  ) public {
    vm.assume(_destinations.length > 0);
    settlerLogic.mockContextDestinations(_intentId, _destinations);
    uint32[] memory _destinationsResult = settlerLogic.getDestinations(_tickerHash, _intentId, _user);

    assertEq(_destinationsResult.length, _destinations.length, 'Invalid destinations length');
    for (uint256 _i; _i < _destinations.length; _i++) {
      assertEq(_destinationsResult[_i], _destinations[_i], 'Invalid destination');
    }
  }

  /**
   * @notice Test the get destinations when the user supported domains are empty and the intent destinations are empty
   * @param _tickerHash The hash of the ticker symbol
   * @param _intentId The intent id
   * @param _user The user
   * @param _tokenSupportedDomains The token supported domains
   */
  function test_UserSupportedDomainsEmptyAndIntentDestinationsIsEmpty(
    bytes32 _tickerHash,
    bytes32 _intentId,
    bytes32 _user,
    uint32[] memory _tokenSupportedDomains
  ) public {
    vm.assume(_tokenSupportedDomains.length > 0);
    settlerLogic.mockTokenSupportedDomains(_tickerHash, _tokenSupportedDomains);
    uint32[] memory _destinationsResult = settlerLogic.getDestinations(_tickerHash, _intentId, _user);

    uint32[] memory _tokenDomains = settlerLogic.getTokenDomains(_tickerHash);
    assertEq(_destinationsResult.length, _tokenDomains.length, 'Invalid destinations length');

    for (uint256 _i; _i < _tokenDomains.length; _i++) {
      assertEq(_destinationsResult[_i], _tokenDomains[_i], 'Invalid destination');
    }
  }

  /**
   * @notice Test the get destinations when the user supported domains are not empty
   * @param _tickerHash The hash of the ticker symbol
   * @param _intentId The intent id
   * @param _user The user
   * @param _destinations The destinations
   * @param _userSupportedDomains The user supported domains
   */
  function test_UserSupportedDomainsNotEmpty(
    bytes32 _tickerHash,
    bytes32 _intentId,
    bytes32 _user,
    uint32[] memory _destinations,
    uint32[] memory _userSupportedDomains
  ) public {
    vm.assume(_destinations.length > 0);
    vm.assume(_userSupportedDomains.length > 0);
    settlerLogic.mockContextDestinations(_intentId, _destinations);
    settlerLogic.mockUserSupportedDomains(_user, _userSupportedDomains);
    uint32[] memory _destinationsResult = settlerLogic.getDestinations(_tickerHash, _intentId, _user);
    uint32[] memory _userDomains = settlerLogic.getUserDomains(_user);

    assertEq(_destinationsResult.length, _userDomains.length, 'Invalid destinations length');
    for (uint256 _i; _i < _userDomains.length; _i++) {
      assertEq(_destinationsResult[_i], _userDomains[_i], 'Invalid destination');
    }
  }
}

contract Unit_CreateInvoice is BaseTest {
  /**
   * @notice Test the create invoice method
   * @param _blockNumber The block number
   * @param _epochLength The epoch length
   * @param _tickerHash The hash of the ticker symbol
   * @param _intentId The intent id
   * @param _amount The amount
   * @param _owner The owner
   */
  function test_CreateInvoice(
    uint48 _blockNumber,
    uint48 _epochLength,
    bytes32 _tickerHash,
    bytes32 _intentId,
    uint256 _amount,
    bytes32 _owner
  ) public {
    vm.assume(_epochLength > 0);
    vm.assume(_intentId != 0);
    vm.roll(_blockNumber);
    _mockEpockLength(_epochLength);

    _expectEmit(address(settlerLogic));
    emit InvoiceEnqueued(_intentId, _tickerHash, _blockNumber / _epochLength, _amount, _owner);

    settlerLogic.createInvoice(_tickerHash, _intentId, _amount, _owner);

    IEverclearHub.IntentContext memory _intentContext = settlerLogic.contexts(_intentId);
    (bytes32 _head, bytes32 _tail, uint256 _nonce, uint256 _length) = settlerLogic.invoices(_tickerHash);
    IHubStorage.Invoice memory _invoice = settlerLogic.getInvoice(_tickerHash, _head);

    assertEq(_length, 1, 'Invalid invoice length');
    assertEq(_head, _tail, 'Invalid head and tail');
    assertEq(_nonce, 1, 'Invalid nonce');
    assertEq(_length, 1, 'Invalid length');
    assertTrue(_head != 0, 'Invalid head');

    assertEq(_invoice.intentId, _intentId, 'Invalid intent id');
    assertEq(_invoice.owner, _owner, 'Invalid owner');
    assertEq(_invoice.entryEpoch, uint48(_blockNumber / _epochLength), 'Invalid entry epoch');
    assertEq(_invoice.amount, _amount, 'Invalid amount');
    assertEq(_invoice.entryEpoch, uint48(_blockNumber / _epochLength), 'Invalid entry epoch');

    assertEq(uint8(_intentContext.status), uint8(IEverclear.IntentStatus.INVOICED), 'Invalid intent status');
  }
}

contract Unit_CreateSettlement is BaseTest {
  /**
   * @notice Test the create settlement method
   * @param _intentId The intent id
   * @param _tickerHash The hash of the ticker symbol
   * @param _amount The amount
   * @param _destination The destination
   * @param _recipient The recipient
   */
  function test_CreateSettlement(
    bytes32 _intentId,
    bytes32 _tickerHash,
    bytes32 _assetHash,
    bytes32 _adoptedForAsset,
    uint256 _custodiedAssetsAmount,
    uint256 _amount,
    uint32 _destination,
    bytes32 _recipient,
    bool _updateVirtualBalance
  ) public {
    vm.assume(_custodiedAssetsAmount >= _amount);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settlerLogic.mockCustodiedAssets(_assetHash, _custodiedAssetsAmount);
    settlerLogic.mockUpdateVirtualBalance(_recipient, _updateVirtualBalance);
    settlerLogic.mockAdoptedForAsset(_assetHash, _adoptedForAsset);
    settlerLogic.mockEpochLength(1);

    _expectEmit(address(settlerLogic));
    emit SettlementEnqueued(
      _intentId,
      _destination,
      settlerLogic.getCurrentEpoch(),
      _adoptedForAsset,
      _amount,
      _updateVirtualBalance,
      _recipient
    );
    settlerLogic.createSettlement(_intentId, _tickerHash, _amount, _destination, _recipient);

    IEverclearHub.IntentContext memory _intentContext = settlerLogic.contexts(_intentId);
    uint256 _custodiedAssets = settlerLogic.custodiedAssets(_assetHash);
    (uint256 _first, uint256 _last) = settlerLogic.settlements(_destination);
    IEverclearHub.Settlement memory _settlement = settlerLogic.getSettlement(_destination, _first);

    assertEq(_custodiedAssets, _custodiedAssetsAmount - _amount, 'Invalid custodied assets');
    assertEq(uint8(_intentContext.status), uint8(IEverclear.IntentStatus.SETTLED), 'Invalid intent status');
    assertEq(_first, 1, 'Invalid first');
    assertEq(_last, 1, 'Invalid last');

    assertEq(_settlement.intentId, _intentId, 'Invalid intent id');
    assertEq(_settlement.amount, _amount, 'Invalid amount');
    assertEq(_settlement.asset, _adoptedForAsset, 'Invalid asset');
    assertEq(_settlement.recipient, _recipient, 'Invalid recipient');
    assertEq(_settlement.updateVirtualBalance, _updateVirtualBalance, 'Invalid update virtual balance');
  }
}

contract Unit_CreateSettlementOrInvoice is BaseTest {
  /**
   * @notice Test the create settlement or invoice method when there is no liquidity
   * @param _intentId The intent id
   * @param _tickerHash The hash of the ticker symbol
   * @param _blockNumber The block number
   * @param _epochLength The epoch length
   * @param _amountAfterFees The amount after fees
   * @param _pendingRewards The pending rewards
   * @param _owner The owner of the deposit
   */
  function test_CreateSettlementOrInvoiceNoLiquidity(
    bytes32 _intentId,
    bytes32 _tickerHash,
    uint32 _destination,
    uint48 _blockNumber,
    uint48 _epochLength,
    uint256 _amountAfterFees,
    uint256 _pendingRewards,
    bytes32 _owner
  ) public {
    vm.assume(_epochLength > 0);
    vm.assume(_intentId != 0);
    vm.assume(_destination != 0);
    vm.assume(_amountAfterFees <= type(uint256).max - _pendingRewards);
    vm.roll(_blockNumber);
    _mockEpockLength(_epochLength);
    settlerLogic.mockAmountAfterFees(_intentId, _amountAfterFees);
    settlerLogic.mockPendingRewards(_intentId, _pendingRewards);
    settlerLogic.mockTokenDomain(_tickerHash, _destination);

    _expectEmit(address(settlerLogic));
    emit InvoiceEnqueued(
      _intentId, _tickerHash, settlerLogic.getCurrentEpoch(), _amountAfterFees + _pendingRewards, _owner
    );

    settlerLogic.createSettlementOrInvoice(_intentId, _tickerHash, _owner);

    IEverclearHub.IntentContext memory _intentContext = settlerLogic.contexts(_intentId);
    assertEq(uint8(_intentContext.status), uint8(IEverclear.IntentStatus.INVOICED), 'Invalid intent status');
    assertEq(settlerLogic.getPendingRewards(_intentId), 0, 'Invalid pending rewards');
  }

  /**
   * @notice Test the create settlement or invoice method when there is liquidity available
   * @param _intentId The intent id
   * @param _tickerHash The hash of the ticker symbol
   * @param _assetHash The hash of the asset
   * @param _adoptedForAsset The adopted for asset
   * @param _custodiedAssetsAmount The custodied assets amount
   * @param _amountAfterFees The amount after fees
   * @param _pendingRewards The pending rewards
   * @param _destination The destination
   * @param _recipient The recipient
   * @param _updateVirtualBalance The update virtual balance
   */
  function test_CreateSettlementOrInvoiceLiquidityAvailable(
    bytes32 _intentId,
    bytes32 _tickerHash,
    bytes32 _assetHash,
    bytes32 _adoptedForAsset,
    uint256 _custodiedAssetsAmount,
    uint256 _amountAfterFees,
    uint256 _pendingRewards,
    uint32 _destination,
    bytes32 _recipient,
    bool _updateVirtualBalance
  ) public {
    vm.assume(_amountAfterFees <= type(uint256).max - _pendingRewards);
    uint256 _settlementAmount = _amountAfterFees + _pendingRewards;
    vm.assume(_settlementAmount > 0);
    vm.assume(_custodiedAssetsAmount >= _settlementAmount);
    vm.assume(_destination != 0);

    settlerLogic.mockPendingRewards(_intentId, _pendingRewards);
    settlerLogic.mockAmountAfterFees(_intentId, _amountAfterFees);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settlerLogic.mockCustodiedAssets(_assetHash, _custodiedAssetsAmount);
    settlerLogic.mockUpdateVirtualBalance(_recipient, _updateVirtualBalance);
    settlerLogic.mockAdoptedForAsset(_assetHash, _adoptedForAsset);
    settlerLogic.mockTokenDomain(_tickerHash, _destination);
    settlerLogic.mockEpochLength(1);

    _expectEmit(address(settlerLogic));
    emit SettlementEnqueued(
      _intentId,
      _destination,
      settlerLogic.getCurrentEpoch(),
      _adoptedForAsset,
      _settlementAmount,
      _updateVirtualBalance,
      _recipient
    );
    settlerLogic.createSettlementOrInvoice(_intentId, _tickerHash, _recipient);

    IEverclearHub.IntentContext memory _intentContext = settlerLogic.contexts(_intentId);
    uint256 _custodiedAssets = settlerLogic.custodiedAssets(_assetHash);

    assertEq(_custodiedAssets, _custodiedAssetsAmount - _settlementAmount, 'Invalid custodied assets');
    assertEq(uint8(_intentContext.status), uint8(IEverclear.IntentStatus.SETTLED), 'Invalid intent status');
  }

  /**
   * @notice Test the create settlement or invoice method when the asset is XERC20 supported
   * @param _intentId The intent id
   * @param _tickerHash The hash of the ticker symbol
   * @param _assetHash The hash of the asset
   * @param _adoptedForAsset The adopted for asset
   * @param _custodiedAssetsAmount The custodied assets amount
   * @param _amountAfterFees The amount after fees
   * @param _pendingRewards The pending rewards
   * @param _destination The destination
   * @param _recipient The recipient
   * @param _updateVirtualBalance The update virtual balance
   */
  function test_CreateSettlementOrInvoice_XERC20Supported(
    bytes32 _intentId,
    bytes32 _tickerHash,
    bytes32 _assetHash,
    bytes32 _adoptedForAsset,
    uint256 _custodiedAssetsAmount,
    uint256 _amountAfterFees,
    uint256 _pendingRewards,
    uint32 _destination,
    bytes32 _recipient,
    bool _updateVirtualBalance
  ) public {
    vm.assume(_amountAfterFees <= type(uint256).max - _pendingRewards);
    uint256 _settlementAmount = _amountAfterFees + _pendingRewards;
    vm.assume(_settlementAmount > 0);
    vm.assume(_custodiedAssetsAmount >= _settlementAmount);
    vm.assume(_destination != 0);

    settlerLogic.mockPendingRewards(_intentId, _pendingRewards);
    settlerLogic.mockAmountAfterFees(_intentId, _amountAfterFees);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settlerLogic.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.XERC20);
    settlerLogic.mockUpdateVirtualBalance(_recipient, _updateVirtualBalance);
    settlerLogic.mockAdoptedForAsset(_assetHash, _adoptedForAsset);
    settlerLogic.mockTokenDomain(_tickerHash, _destination);
    settlerLogic.mockEpochLength(1);

    _expectEmit(address(settlerLogic));
    emit SettlementEnqueued(
      _intentId,
      _destination,
      settlerLogic.getCurrentEpoch(),
      _adoptedForAsset,
      _settlementAmount,
      _updateVirtualBalance,
      _recipient
    );
    settlerLogic.createSettlementOrInvoice(_intentId, _tickerHash, _recipient);

    IEverclearHub.IntentContext memory _intentContext = settlerLogic.contexts(_intentId);

    assertEq(uint8(_intentContext.status), uint8(IEverclear.IntentStatus.SETTLED), 'Invalid intent status');
  }
}

contract Unit_FindDestinationsXerc20Strategy is BaseTest {
  /**
   * @notice Test the find destination xerc20 strategy method, it should return the first xerc20 strategy found
   * @param _tickerHash The hash of the ticker symbol
   * @param _destinations The destinations
   */
  function test_FindDestinationXerc20Strategy_XER20StrategyInDestinations(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    bytes32 _secondAssetHash,
    uint32[] memory _destinations,
    uint32 _xErc20Destination,
    uint32 _secondXerc20Destination
  ) public {
    vm.assume(_xErc20Destination > 0 && _xErc20Destination < _destinations.length);
    vm.assume(_secondXerc20Destination > _xErc20Destination);
    vm.assume(_assetHash != 0 && _secondAssetHash != 0 && _assetHash != _secondAssetHash);
    vm.assume(_destinations.length > 0 && _destinations.length < 100);
    for (uint256 _i; _i < _destinations.length; _i++) {
      _destinations[_i] = uint32(_i + 1);
    }
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _xErc20Destination, _assetHash);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _secondXerc20Destination, _secondAssetHash);
    settlerLogic.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.XERC20);
    settlerLogic.mockAssetHashStrategy(_secondAssetHash, IEverclear.Strategy.XERC20);

    uint32 _selectedDestination = settlerLogic.findDestinationXerc20Strategy(_tickerHash, _destinations);

    assertEq(_selectedDestination, _xErc20Destination, 'Wrong destination for xerc20 strategy');
  }

  /**
   * @notice Test the find destination xerc20 strategy method when there are no xerc20 strategies in the destinations
   * @param _tickerHash The hash of the ticker symbol
   * @param _destinations The destinations
   */
  function test_FindDestinationXerc20Strategy_NoXER20StrategyInDestinations(
    bytes32 _tickerHash,
    uint32[] memory _destinations
  ) public {
    vm.assume(_destinations.length > 0 && _destinations.length < 100);
    for (uint256 _i; _i < _destinations.length; _i++) {
      _destinations[_i] = uint32(_i + 1);
    }

    uint32 _selectedDestination = settlerLogic.findDestinationXerc20Strategy(_tickerHash, _destinations);

    assertEq(_selectedDestination, 0, 'Wrong destination for xerc20 strategy');
  }
}

contract Unit_FindDestinationDefaultStrategy is BaseTest {
  /**
   * @notice Test the find destination default strategy method when there is enough liquidity in the destination A and it's the domain with the highest liquidity
   * @param _destinationA The destination A
   * @param _destinationB The destination B
   * @param _liquidityA The liquidity in the destination A
   * @param _liquidityB The liquidity in the destination B
   * @param _tickerHash The hash of the ticker symbol
   * @param _assetHashA The asset hash A
   * @param _assetHashB The asset hash B
   * @param _amountAndRewards The amount and rewards
   */
  function test_FindDestinationADefaultStrategyEnoughLiquidity(
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityA,
    uint256 _liquidityB,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint256 _amountAndRewards
  ) public {
    vm.assume(_amountAndRewards > 0);
    vm.assume(_destinationA != 0 && _destinationB != 0 && _destinationA != _destinationB);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_liquidityA >= _amountAndRewards && _liquidityA >= _liquidityB);

    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);

    settlerLogic.mockCustodiedAssets(_assetHashA, _liquidityA);
    settlerLogic.mockCustodiedAssets(_assetHashB, _liquidityB);

    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = _destinationA;
    _destinations[1] = _destinationB;

    uint32 _selectedDestination =
      settlerLogic.findDestinationDefaultStrategy(_tickerHash, _amountAndRewards, _destinations);

    assertEq(_selectedDestination, _destinationA, 'Invalid destination selected');
  }

  /**
   * @notice Test the find destination default strategy method when there is enough liquidity in the destination B and it's the domain with the highest liquidity
   * @param _destinationA The destination A
   * @param _destinationB The destination B
   * @param _liquidityA The liquidity in the destination A
   * @param _liquidityB The liquidity in the destination B
   * @param _tickerHash The hash of the ticker symbol
   * @param _assetHashA The asset hash A
   * @param _assetHashB The asset hash B
   * @param _amountAndRewards The amount and rewards
   */
  function test_FindDestinationBDefaultStrategyEnoughLiquidity(
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityA,
    uint256 _liquidityB,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint256 _amountAndRewards
  ) public {
    vm.assume(_destinationA != 0 && _destinationB != 0 && _destinationA != _destinationB);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_liquidityB >= _amountAndRewards && _liquidityB > _liquidityA);

    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);

    settlerLogic.mockCustodiedAssets(_assetHashA, _liquidityA);
    settlerLogic.mockCustodiedAssets(_assetHashB, _liquidityB);

    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = _destinationA;
    _destinations[1] = _destinationB;

    uint32 _selectedDestination =
      settlerLogic.findDestinationDefaultStrategy(_tickerHash, _amountAndRewards, _destinations);

    assertEq(_selectedDestination, _destinationB, 'Invalid destination selected');
  }

  /**
   * @notice Test the find destination default strategy method when there is not enough liquidity in the destination A and B
   * @param _destinationA The destination A
   * @param _destinationB The destination B
   * @param _liquidityA The liquidity in the destination A
   * @param _liquidityB The liquidity in the destination B
   * @param _tickerHash The hash of the ticker symbol
   * @param _assetHashA The asset hash A
   * @param _assetHashB The asset hash B
   * @param _amountAndRewards The amount and rewards
   */
  function test_FindDestinationDefaultStrategyNotEnoughLiquidity(
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityA,
    uint256 _liquidityB,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint256 _amountAndRewards
  ) public {
    vm.assume(_amountAndRewards > 0);
    vm.assume(_destinationA != 0 && _destinationB != 0 && _destinationA != _destinationB);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_liquidityA < _amountAndRewards && _liquidityB < _amountAndRewards);

    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);

    settlerLogic.mockCustodiedAssets(_assetHashA, _liquidityA);
    settlerLogic.mockCustodiedAssets(_assetHashB, _liquidityB);

    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = _destinationA;
    _destinations[1] = _destinationB;

    uint32 _selectedDestination =
      settlerLogic.findDestinationDefaultStrategy(_tickerHash, _amountAndRewards, _destinations);

    assertEq(_selectedDestination, 0, 'Invalid destination selected');
  }
}

contract Unit_FindDestinationWithStrategies is BaseTest {
  /**
   * @notice Test the find destination with strategies method when the xerc20 strategy is prioritized
   * @param _tickerHash The hash of the ticker symbol
   * @param _assetHash The asset hash
   * @param _secondAssetHash The second asset hash
   * @param _amountAndRewards The amount and rewards
   * @param _destinations The destinations
   * @param _xErc20Destination The xerc20 destinatio
   */
  function test_xErc20PrioritedStrategy_XERC20inDomains(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    bytes32 _secondAssetHash,
    uint256 _amountAndRewards,
    uint32[] memory _destinations,
    uint32 _xErc20Destination,
    uint32 _secondXerc20Destination
  ) public {
    vm.assume(_assetHash != 0 && _secondAssetHash != 0 && _assetHash != _secondAssetHash);
    vm.assume(_xErc20Destination > 0 && _xErc20Destination < _destinations.length);
    vm.assume(_secondXerc20Destination > _xErc20Destination);
    vm.assume(_destinations.length > 0 && _destinations.length < 100);
    settlerLogic.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.XERC20);

    for (uint256 _i; _i < _destinations.length; _i++) {
      _destinations[_i] = uint32(_i + 1);
    }
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _xErc20Destination, _assetHash);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _secondXerc20Destination, _secondAssetHash);
    settlerLogic.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.XERC20);
    settlerLogic.mockAssetHashStrategy(_secondAssetHash, IEverclear.Strategy.XERC20);

    uint32 _selectedDestination =
      settlerLogic.findDestinationWithStrategies(_tickerHash, _amountAndRewards, _destinations);

    assertEq(_selectedDestination, _xErc20Destination, 'Wrong destination for prioritized xerc20 strategy');
  }

  /**
   * @notice Test the find destination with strategies method when the xerc20 strategy is prioritized and the xerc20 destination is not in the domains
   * @param _tickerHash The hash of the ticker symbol
   * @param _assetHash The asset hash
   * @param _secondAssetHash The second asset hash
   * @param _amountAndRewards The amount and rewards
   * @param _destinations The destinations
   * @param _firstDestination The first destination
   * @param _second20Destination The second destination
   */
  function test_xErc20PrioritedStrategy_XERC20NotInDomains(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    bytes32 _secondAssetHash,
    uint256 _amountAndRewards,
    uint32[] memory _destinations,
    uint32 _firstDestination,
    uint32 _second20Destination
  ) public {
    vm.assume(_assetHash != 0 && _secondAssetHash != 0 && _assetHash != _secondAssetHash);
    vm.assume(_firstDestination > 0 && _firstDestination < _destinations.length);
    vm.assume(_second20Destination > _firstDestination);
    vm.assume(_destinations.length > 0 && _destinations.length < 100);
    settlerLogic.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.XERC20);

    for (uint256 _i; _i < _destinations.length; _i++) {
      _destinations[_i] = uint32(_i + 1);
    }
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _firstDestination, _assetHash);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _second20Destination, _secondAssetHash);
    settlerLogic.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.DEFAULT);
    settlerLogic.mockAssetHashStrategy(_secondAssetHash, IEverclear.Strategy.DEFAULT);

    uint32 _selectedDestination =
      settlerLogic.findDestinationWithStrategies(_tickerHash, _amountAndRewards, _destinations);

    assertEq(_selectedDestination, 0, 'Wrong destination for prioritized xerc20 strategy');
  }

  /**
   * @notice Test the find destination with strategies method when the xerc20 strategy is prioritized and the xerc20 destination is not in the domains but there is enough liquidity
   */
  function test_xErc20PrioritedStrategy_XERC20NotInDomains_EnoughLiquidity(
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityA,
    uint256 _liquidityB,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint256 _amountAndRewards
  ) public {
    vm.assume(_destinationA != 0 && _destinationB != 0 && _destinationA != _destinationB);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_liquidityB >= _amountAndRewards && _liquidityB > _liquidityA);
    settlerLogic.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.XERC20);

    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);

    settlerLogic.mockCustodiedAssets(_assetHashA, _liquidityA);
    settlerLogic.mockCustodiedAssets(_assetHashB, _liquidityB);

    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = _destinationA;
    _destinations[1] = _destinationB;

    uint32 _selectedDestination =
      settlerLogic.findDestinationDefaultStrategy(_tickerHash, _amountAndRewards, _destinations);

    assertEq(_selectedDestination, _destinationB, 'Invalid destination selected');
  }

  /**
   * @notice Test the find destination with strategies method when the default strategy is prioritized and ther is enough liquidity
   */
  function test_DefaultStrategyPrioritized_EnoughLiquidity(
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityB,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint256 _amountAndRewards
  ) public {
    vm.assume(_amountAndRewards > 0);
    vm.assume(_destinationA != 0 && _destinationB != 0 && _destinationA != _destinationB);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_liquidityB >= _amountAndRewards);

    settlerLogic.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.DEFAULT);

    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);

    settlerLogic.mockAssetHashStrategy(_assetHashA, IEverclear.Strategy.XERC20);
    settlerLogic.mockCustodiedAssets(_assetHashB, _liquidityB);

    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = _destinationA;
    _destinations[1] = _destinationB;

    uint32 _selectedDestination =
      settlerLogic.findDestinationWithStrategies(_tickerHash, _amountAndRewards, _destinations);

    assertEq(_selectedDestination, _destinationB, 'Invalid destination selected');
  }

  /**
   * @notice Test the find destination with strategies method when the default strategy is prioritized and ther is not enough liquidity
   */
  function test_DefaultStrategyPrioritized_NotEnoughLiquidity(
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityB,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint256 _amountAndRewards
  ) public {
    vm.assume(_destinationA != 0 && _destinationB != 0 && _destinationA != _destinationB);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_liquidityB < _amountAndRewards);

    settlerLogic.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.DEFAULT);

    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settlerLogic.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);

    settlerLogic.mockAssetHashStrategy(_assetHashA, IEverclear.Strategy.XERC20);
    settlerLogic.mockCustodiedAssets(_assetHashB, _liquidityB);

    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = _destinationA;
    _destinations[1] = _destinationB;

    uint32 _selectedDestination =
      settlerLogic.findDestinationWithStrategies(_tickerHash, _amountAndRewards, _destinations);

    assertEq(_selectedDestination, _destinationA, 'Invalid destination selected');
  }
}
