// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TestExtended} from '../../utils/TestExtended.sol';

import {HubQueueLib} from 'contracts/hub/lib/HubQueueLib.sol';
import {InvoiceListLib} from 'contracts/hub/lib/InvoiceListLib.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

import {Constants} from 'contracts/common/Constants.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {EverclearHub, IEverclearHub} from 'contracts/hub/EverclearHub.sol';
import {ISettler, Settler} from 'contracts/hub/modules/Settler.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IGateway} from 'interfaces/common/IGateway.sol';
import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

contract SettlerForTest is Settler {
  using Uint32Set for Uint32Set.Set;
  using HubQueueLib for HubQueueLib.DepositQueue;
  using HubQueueLib for HubQueueLib.SettlementQueue;
  using InvoiceListLib for InvoiceListLib.InvoiceList;

  function getDiscountDbps(
    bytes32 _tickerHash,
    uint48 _epoch,
    uint48 _entryEpoch
  ) public view returns (uint24 _discountDbps) {
    return _getDiscountDbps(_tickerHash, _epoch, _entryEpoch);
  }

  function getDiscountedAmount(
    bytes32 _tickerHash,
    uint24 _discountDbps,
    uint32 _domain,
    uint48 _epoch,
    uint256 _invoiceAmount
  ) public view returns (uint256 _amountAfterDiscount, uint256 _amountToBeDiscounted, uint256 _rewardsForDepositors) {
    return _getDiscountedAmount(_tickerHash, _discountDbps, _domain, _epoch, _invoiceAmount);
  }

  function getDestinations(
    bytes32 _tickerHash,
    bytes32 _intentId,
    bytes32 _user
  ) public view returns (uint32[] memory _destinations) {
    return _getDestinations(_tickerHash, _intentId, _user);
  }

  function findLowestDiscountAndHighestLiquidity(
    FindDomainParams memory _params
  ) public view returns (FindDomainResult memory _result) {
    return _findLowestDiscountAndHighestLiquidity(_params);
  }

  function findDestinationWithStrategiesForInvoice(
    uint48 _epoch,
    bytes32 _tickerHash,
    Invoice memory _invoice
  ) public view returns (FindDomainResult memory _domainResult) {
    return _findDestinationWithStrategiesForInvoice(_epoch, _tickerHash, _invoice);
  }

  function processDeposit(uint48 _epoch, uint32 _domain, bytes32 _tickerHash) public {
    _processDeposit(_epoch, _domain, _tickerHash);
  }

  function processInvoice(uint48 _epoch, bytes32 _tickerHash, Invoice memory _invoice) public returns (bool _settled) {
    return _processInvoice(_epoch, _tickerHash, _invoice);
  }

  function mockAssetMaxDiscountDbps(bytes32 _tickerHash, uint24 _maxDiscountDbps) public {
    _tokenConfigs[_tickerHash].maxDiscountDbps = _maxDiscountDbps;
  }

  function mockDiscountPerEpoch(bytes32 _tickerHash, uint24 _discountPerEpoch) public {
    _tokenConfigs[_tickerHash].discountPerEpoch = _discountPerEpoch;
  }

  function mockCustodiedAssets(bytes32 _assetHash, uint256 _amount) public {
    custodiedAssets[_assetHash] = _amount;
  }

  function mockTokenConfigAssetHash(bytes32 _tickerHash, uint32 _destination, bytes32 _assetHash) public {
    _tokenConfigs[_tickerHash].assetHashes[_destination] = _assetHash;
    _adoptedForAssets[_assetHash].adopted = _assetHash;
  }

  function mockTokenSupportedDomains(bytes32 _tickerHash, uint32[] memory _tokenSupportedDomains) public {
    for (uint256 _i; _i < _tokenSupportedDomains.length; _i++) {
      _tokenConfigs[_tickerHash].domains.add(_tokenSupportedDomains[_i]);
    }
  }

  function mockTokenSupportedDomains(bytes32 _tickerHash, uint32 _tokenSupportedDomain) public {
    _tokenConfigs[_tickerHash].domains.add(_tokenSupportedDomain);
  }

  function mockDepositsAvailableInEpoch(
    uint48 _epoch,
    uint32 _domain,
    bytes32 _tickerHash,
    uint256 _depositsAvailable
  ) public {
    depositsAvailableInEpoch[_epoch][_domain][_tickerHash] = _depositsAvailable;
  }

  function mockAssetPrioritizedStrategy(bytes32 _tickerHash, IEverclear.Strategy _strategy) public {
    _tokenConfigs[_tickerHash].prioritizedStrategy = _strategy;
  }

  function mockAssetHashStrategy(bytes32 _assetHash, IEverclear.Strategy _strategy) public {
    _adoptedForAssets[_assetHash].strategy = _strategy;
  }

  function mockUserSupportedDomains(bytes32 _user, uint32[] memory _domains) public {
    for (uint256 _i; _i < _domains.length; _i++) {
      _usersSupportedDomains[_user].add(_domains[_i]);
    }
  }

  function mockDeposit(uint48 _epoch, uint32 _domain, bytes32 _tickerHash, IHubStorage.Deposit memory _deposit) public {
    deposits[_epoch][_domain][_tickerHash].enqueueDeposit(_deposit);
  }

  function mockIntentContext(bytes32 _intentId, IntentContext memory _context) public {
    _contexts[_intentId] = _context;
  }

  function mockEpochLength(
    uint48 _epochLength
  ) public {
    epochLength = _epochLength;
  }

  function mockInvoice(bytes32 _tickerHash, Invoice memory _invoice) public {
    invoices[_tickerHash].append(_invoice);
  }

  function mockLastEpochProcessed(bytes32 _tickerHash, uint48 _lastEpochProcessed) public {
    lastClosedEpochsProcessed[_tickerHash] = _lastEpochProcessed;
  }

  function mockSupportedDomain(
    uint32 _domain
  ) public {
    _supportedDomains.add(_domain);
  }

  function mockSettlements(uint32 _domain, uint256 _amount) public {
    for (uint256 _i; _i < _amount; _i++) {
      settlements[_domain].enqueueSettlement(
        IEverclear.Settlement({
          intentId: keccak256(abi.encode(_i)),
          amount: 1,
          asset: keccak256(abi.encode(_i)),
          recipient: keccak256(abi.encode(_i)),
          updateVirtualBalance: false
        })
      );
    }
  }

  function mockGateway(
    address _gateway
  ) public {
    hubGateway = IHubGateway(_gateway);
  }

  function mockLighthouse(
    address _lighthouse
  ) public {
    lighthouse = _lighthouse;
  }

  function mockGasConfig(
    IHubStorage.GasConfig memory _gasConfig
  ) public {
    gasConfig = _gasConfig;
  }
}

contract BaseTest is TestExtended {
  SettlerForTest settler;

  event DepositProcessed(
    uint48 indexed _epoch,
    uint32 indexed _domain,
    bytes32 indexed _tickerHash,
    bytes32 _intentId,
    uint256 _amountAndRewards
  );

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

  function setUp() public {
    settler = new SettlerForTest();
  }
}

contract Unit_GetDiscountDbps is BaseTest {
  /**
   * @notice Test the case where the epoch is greater than the entry epoch and the max discount is not exceeded
   * @param _tickerHash The ticker hash
   * @param _epoch The epoch
   * @param _entryEpoch The entry epoch
   * @param _discountPerEpoch The discount per epoch
   * @param _assetMaxDiscountDbps The max discount
   */
  function test_GetDiscountDbps_EpochGreaterThanEntryEpoch_MaxDiscountNotExceeded(
    bytes32 _tickerHash,
    uint48 _epoch,
    uint48 _entryEpoch,
    uint24 _discountPerEpoch,
    uint24 _assetMaxDiscountDbps
  ) public {
    vm.assume(_epoch > _entryEpoch);
    uint48 _interval = _epoch - _entryEpoch;
    vm.assume(type(uint24).max / _interval >= _discountPerEpoch);
    uint24 _expectedDiscountDbps = uint24(_interval * _discountPerEpoch);
    vm.assume(_assetMaxDiscountDbps >= _expectedDiscountDbps);

    settler.mockAssetMaxDiscountDbps(_tickerHash, _assetMaxDiscountDbps);
    settler.getDiscountDbps(_tickerHash, _epoch, _entryEpoch);
    settler.mockDiscountPerEpoch(_tickerHash, _discountPerEpoch);

    uint24 discountDbps = settler.getDiscountDbps(_tickerHash, _epoch, _entryEpoch);

    assertEq(discountDbps, _expectedDiscountDbps, 'invalid discount Bps');
  }

  /**
   * @notice Test the case where the epoch is greater than the entry epoch and the max discount is exceeded
   * @param _tickerHash The ticker hash
   * @param _epoch The epoch
   * @param _entryEpoch The entry epoch
   * @param _discountPerEpoch The discount per epoch
   * @param _assetMaxDiscountDbps The max discount
   */
  function test_GetDiscountDbps_EpochGreaterThanEntryEpoch_MaxDiscountExceeded(
    bytes32 _tickerHash,
    uint48 _epoch,
    uint48 _entryEpoch,
    uint24 _discountPerEpoch,
    uint24 _assetMaxDiscountDbps
  ) public {
    vm.assume(_epoch > _entryEpoch);
    uint48 _interval = _epoch - _entryEpoch;
    vm.assume(type(uint24).max / _interval >= _discountPerEpoch);
    uint24 _discountDbps = uint24(_interval * _discountPerEpoch);
    vm.assume(_assetMaxDiscountDbps < _discountDbps);

    settler.mockAssetMaxDiscountDbps(_tickerHash, _assetMaxDiscountDbps);
    settler.getDiscountDbps(_tickerHash, _epoch, _entryEpoch);
    settler.mockDiscountPerEpoch(_tickerHash, _discountPerEpoch);

    uint24 discountDbps = settler.getDiscountDbps(_tickerHash, _epoch, _entryEpoch);

    assertEq(discountDbps, _assetMaxDiscountDbps, 'invalid discount Bps');
  }

  /**
   * @notice Test the case where the epoch is less than or equal to the entry epoch
   * @param _tickerHash The ticker hash
   * @param _epoch The epoch
   * @param _entryEpoch The entry epoch
   * @param _discountPerEpoch The discount per epoch
   * @param _assetMaxDiscountDbps The max discount
   */
  function test_GetDiscountDbps_EpochLessOrEqualThanEntryEpoch(
    bytes32 _tickerHash,
    uint48 _epoch,
    uint48 _entryEpoch,
    uint24 _discountPerEpoch,
    uint24 _assetMaxDiscountDbps
  ) public {
    vm.assume(_epoch <= _entryEpoch);

    settler.mockAssetMaxDiscountDbps(_tickerHash, _assetMaxDiscountDbps);
    settler.getDiscountDbps(_tickerHash, _epoch, _entryEpoch);
    settler.mockDiscountPerEpoch(_tickerHash, _discountPerEpoch);

    uint24 discountDbps = settler.getDiscountDbps(_tickerHash, _epoch, _entryEpoch);

    assertEq(discountDbps, 0, 'invalid discount Bps');
  }
}

contract Unit_GetDiscountedAmount is BaseTest {
  struct GetDiscountedAmountTestParams {
    bytes32 tickerHash;
    uint24 discountDbps;
    uint32 domain;
    uint48 epoch;
    uint256 depositsAvailable;
    uint256 invoiceAmount;
  }

  /**
   * @notice Test the case where deposits are greater than or equal to the invoice amount
   * @param _params The test parameters
   */
  function test_GetDiscountedAmount_DepoistsGreaterOrEqualInvoiceAmount(
    GetDiscountedAmountTestParams memory _params
  ) public {
    vm.assume(_params.depositsAvailable >= _params.invoiceAmount);
    vm.assume(
      _params.discountDbps == 0
        || (
          _params.discountDbps <= Constants.DBPS_DENOMINATOR
            && type(uint256).max / _params.discountDbps >= _params.invoiceAmount
        )
    );
    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domain, _params.tickerHash, _params.depositsAvailable);

    uint256 _expectedAmountToBeDiscounted = _params.invoiceAmount;
    uint256 _expectedRewardsForDepositors = _params.invoiceAmount * _params.discountDbps / Constants.DBPS_DENOMINATOR;
    uint256 _expectedAmountAfterDiscount = _params.invoiceAmount - _expectedRewardsForDepositors;

    (uint256 _amountAfterDiscount, uint256 _amountToBeDiscounted, uint256 _rewardsForDepositors) = settler
      .getDiscountedAmount(_params.tickerHash, _params.discountDbps, _params.domain, _params.epoch, _params.invoiceAmount);

    assertEq(_amountAfterDiscount, _expectedAmountAfterDiscount, 'invalid amount after discount');
    assertEq(_amountToBeDiscounted, _expectedAmountToBeDiscounted, 'invalid amount to be discounted');
    assertEq(_rewardsForDepositors, _expectedRewardsForDepositors, 'invalid rewards for depositors');
  }

  /**
   * @notice Test the case where deposits are less than the invoice amount
   * @param _params The test parameters
   */
  function test_GetDiscountedAmount_DepoistsLessThanInvoiceAmount(
    GetDiscountedAmountTestParams memory _params
  ) public {
    vm.assume(_params.depositsAvailable < _params.invoiceAmount);
    vm.assume(
      _params.discountDbps == 0
        || (
          _params.discountDbps <= Constants.DBPS_DENOMINATOR
            && type(uint256).max / _params.discountDbps >= _params.invoiceAmount
        )
    );
    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domain, _params.tickerHash, _params.depositsAvailable);

    uint256 _expectedAmountToBeDiscounted = _params.depositsAvailable;
    uint256 _expectedRewardsForDepositors =
      _params.depositsAvailable * _params.discountDbps / Constants.DBPS_DENOMINATOR;
    uint256 _expectedAmountAfterDiscount = _params.invoiceAmount - _expectedRewardsForDepositors;

    (uint256 _amountAfterDiscount, uint256 _amountToBeDiscounted, uint256 _rewardsForDepositors) = settler
      .getDiscountedAmount(_params.tickerHash, _params.discountDbps, _params.domain, _params.epoch, _params.invoiceAmount);

    assertEq(_amountAfterDiscount, _expectedAmountAfterDiscount, 'invalid amount after discount');
    assertEq(_amountToBeDiscounted, _expectedAmountToBeDiscounted, 'invalid amount to be discounted');
    assertEq(_rewardsForDepositors, _expectedRewardsForDepositors, 'invalid rewards for depositors');
  }
}

contract Unit_FindLowestDiscountAndHighestLiquidity is BaseTest {
  struct FindLowestDiscountAndHighestLiquidityTestParams {
    bytes32 tickerHash;
    bytes32 assetHashA;
    bytes32 assetHashB;
    uint24 discountPerEpoch;
    uint32 domainA;
    uint32 domainB;
    IHubStorage.Invoice invoice;
    uint256 liquidityA;
    uint256 liquidityB;
    uint256 depositsAvailableA;
    uint256 depositsAvailableB;
    uint48 epoch;
  }

  /**
   * @notice Test the case where the domain A has the lowest discount and liquidity is enough in both domains
   * @param _params The test parameters
   */
  function test_FindLowestDiscountAndHighestLiquidityLowestDiscountA(
    FindLowestDiscountAndHighestLiquidityTestParams memory _params
  ) public {
    vm.assume(_params.discountPerEpoch > 0);
    vm.assume(_params.domainA != _params.domainB && _params.domainA != 0 && _params.domainB != 0);
    vm.assume(_params.invoice.entryEpoch < _params.epoch);
    vm.assume(_params.depositsAvailableA > 0 && _params.depositsAvailableB > 0);
    vm.assume(_params.assetHashA != 0 && _params.assetHashB != 0 && _params.assetHashA != _params.assetHashB);
    vm.assume(_params.liquidityA >= _params.invoice.amount && _params.liquidityB >= _params.invoice.amount);
    vm.assume(
      _params.depositsAvailableA < _params.invoice.amount && _params.depositsAvailableA < _params.depositsAvailableB
    );
    uint256 _amountToBeDiscounted =
      _params.depositsAvailableB > _params.invoice.amount ? _params.invoice.amount : _params.depositsAvailableB;
    settler.mockDiscountPerEpoch(_params.tickerHash, _params.discountPerEpoch);
    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    uint256 _discountDbps = settler.getDiscountDbps(_params.tickerHash, _params.epoch, _params.invoice.entryEpoch);
    vm.assume(_discountDbps > 0);
    vm.assume(type(uint256).max / _discountDbps >= _amountToBeDiscounted);
    uint256 _rewards = _amountToBeDiscounted * _discountDbps / Constants.DBPS_DENOMINATOR;
    vm.assume(_rewards > 0);

    uint32[] memory domains = new uint32[](2);
    domains[0] = _params.domainA;
    domains[1] = _params.domainB;

    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domainA, _params.assetHashA);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domainB, _params.assetHashB);
    settler.mockCustodiedAssets(_params.assetHashA, _params.liquidityA);
    settler.mockCustodiedAssets(_params.assetHashB, _params.liquidityB);

    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domainA, _params.tickerHash, _params.depositsAvailableA);
    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domainB, _params.tickerHash, _params.depositsAvailableB);

    ISettler.FindDomainParams memory params = ISettler.FindDomainParams({
      tickerHash: _params.tickerHash,
      domains: domains,
      invoice: _params.invoice,
      epoch: _params.epoch
    });

    ISettler.FindDomainResult memory result = settler.findLowestDiscountAndHighestLiquidity(params);
    assertEq(result.selectedDomain, _params.domainA, 'invalid selected domain');
  }

  /**
   * @notice Test the case where the domain B has the lowest discount and liquidity is enough in both domains
   * @param _params The test parameters
   * @dev setting special fuzz runs combination only for this test, since max rejections is exceeded
   */
  /// forge-config: default.fuzz.runs = 100
  function test_FindLowestDiscountAndHighestLiquidityLowestDiscountB(
    FindLowestDiscountAndHighestLiquidityTestParams memory _params
  ) public {
    vm.assume(_params.discountPerEpoch > 0);
    vm.assume(_params.invoice.entryEpoch < _params.epoch);
    vm.assume(_params.depositsAvailableA > 0 && _params.depositsAvailableB > 0);
    vm.assume(_params.assetHashA != 0 && _params.assetHashB != 0 && _params.assetHashA != _params.assetHashB);
    vm.assume(_params.domainA != _params.domainB && _params.domainA != 0 && _params.domainB != 0);
    vm.assume(_params.liquidityA >= _params.invoice.amount && _params.liquidityB >= _params.invoice.amount);
    vm.assume(
      _params.depositsAvailableB < _params.invoice.amount && _params.depositsAvailableB < _params.depositsAvailableA - 1
    );
    vm.assume(_params.invoice.amount - _params.depositsAvailableB > 1e6);
    uint256 _amountToBeDiscounted =
      _params.depositsAvailableA > _params.invoice.amount ? _params.invoice.amount : _params.depositsAvailableA;
    settler.mockDiscountPerEpoch(_params.tickerHash, _params.discountPerEpoch);
    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);

    uint256 _discountDbps = settler.getDiscountDbps(_params.tickerHash, _params.epoch, _params.invoice.entryEpoch);
    vm.assume(_discountDbps > 0);
    vm.assume(type(uint256).max / _discountDbps >= _amountToBeDiscounted);
    uint256 _rewards = _amountToBeDiscounted * _discountDbps / Constants.DBPS_DENOMINATOR;
    vm.assume(_rewards > 0);

    uint32[] memory domains = new uint32[](2);
    domains[0] = _params.domainA;
    domains[1] = _params.domainB;

    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domainA, _params.assetHashA);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domainB, _params.assetHashB);
    settler.mockCustodiedAssets(_params.assetHashA, _params.liquidityA);
    settler.mockCustodiedAssets(_params.assetHashB, _params.liquidityB);

    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domainA, _params.tickerHash, _params.depositsAvailableA);
    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domainB, _params.tickerHash, _params.depositsAvailableB);

    ISettler.FindDomainParams memory params = ISettler.FindDomainParams({
      tickerHash: _params.tickerHash,
      domains: domains,
      invoice: _params.invoice,
      epoch: _params.epoch
    });

    ISettler.FindDomainResult memory result = settler.findLowestDiscountAndHighestLiquidity(params);
    assertEq(result.selectedDomain, _params.domainB, 'invalid selected domain');
  }

  /**
   * @notice Test the case where discount is the same in both domains and liquidity is higher in domain A
   * @param _params The test parameters
   */
  function test_FindLowestDiscountAndHighestLiquidity_SameDiscount_HighestLiquidityA(
    FindLowestDiscountAndHighestLiquidityTestParams memory _params
  ) public {
    vm.assume(_params.discountPerEpoch > 0);
    vm.assume(_params.invoice.amount > 0);
    vm.assume(_params.invoice.entryEpoch < _params.epoch);
    vm.assume(_params.assetHashA != 0 && _params.assetHashB != 0 && _params.assetHashA != _params.assetHashB);
    vm.assume(_params.liquidityA >= _params.invoice.amount && _params.liquidityB >= _params.invoice.amount);
    vm.assume(_params.liquidityA > _params.liquidityB);

    uint256 _amountToBeDiscounted =
      _params.depositsAvailableA > _params.invoice.amount ? _params.invoice.amount : _params.depositsAvailableA;
    settler.mockDiscountPerEpoch(_params.tickerHash, _params.discountPerEpoch);
    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    uint256 _discountDbps = settler.getDiscountDbps(_params.tickerHash, _params.epoch, _params.invoice.entryEpoch);
    vm.assume(_discountDbps > 0);
    vm.assume(type(uint256).max / _discountDbps >= _amountToBeDiscounted);

    uint32[] memory domains = new uint32[](2);
    domains[0] = _params.domainA;
    domains[1] = _params.domainB;

    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockDiscountPerEpoch(_params.tickerHash, _params.discountPerEpoch);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domainA, _params.assetHashA);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domainB, _params.assetHashB);
    settler.mockCustodiedAssets(_params.assetHashA, _params.liquidityA);
    settler.mockCustodiedAssets(_params.assetHashB, _params.liquidityB);

    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domainA, _params.tickerHash, _params.depositsAvailableA);
    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domainB, _params.tickerHash, _params.depositsAvailableA);

    ISettler.FindDomainParams memory params = ISettler.FindDomainParams({
      tickerHash: _params.tickerHash,
      domains: domains,
      invoice: _params.invoice,
      epoch: _params.epoch
    });

    ISettler.FindDomainResult memory result = settler.findLowestDiscountAndHighestLiquidity(params);
    assertEq(result.selectedDomain, _params.domainA, 'invalid selected domain');
  }

  /**
   * @notice Test the case where discount is the same in both domains and liquidity is higher in domain B
   * @param _params The test parameters
   */
  function test_FindLowestDiscountAndHighestLiquidity_SameDiscount_HighestLiquidityB(
    FindLowestDiscountAndHighestLiquidityTestParams memory _params
  ) public {
    vm.assume(_params.discountPerEpoch > 0);
    vm.assume(_params.invoice.amount > 0);
    vm.assume(_params.invoice.entryEpoch < _params.epoch);
    vm.assume(_params.assetHashA != 0 && _params.assetHashB != 0 && _params.assetHashA != _params.assetHashB);
    vm.assume(_params.liquidityA >= _params.invoice.amount && _params.liquidityB >= _params.invoice.amount);
    vm.assume(_params.liquidityB > _params.liquidityA);

    uint256 _amountToBeDiscounted =
      _params.depositsAvailableA > _params.invoice.amount ? _params.invoice.amount : _params.depositsAvailableA;
    settler.mockDiscountPerEpoch(_params.tickerHash, _params.discountPerEpoch);
    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    uint256 _discountDbps = settler.getDiscountDbps(_params.tickerHash, _params.epoch, _params.invoice.entryEpoch);
    vm.assume(_discountDbps > 0);
    vm.assume(type(uint256).max / _discountDbps >= _amountToBeDiscounted);

    uint32[] memory domains = new uint32[](2);
    domains[0] = _params.domainA;
    domains[1] = _params.domainB;

    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockDiscountPerEpoch(_params.tickerHash, _params.discountPerEpoch);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domainA, _params.assetHashA);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domainB, _params.assetHashB);
    settler.mockCustodiedAssets(_params.assetHashA, _params.liquidityA);
    settler.mockCustodiedAssets(_params.assetHashB, _params.liquidityB);

    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domainA, _params.tickerHash, _params.depositsAvailableA);
    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domainB, _params.tickerHash, _params.depositsAvailableA);

    ISettler.FindDomainParams memory params = ISettler.FindDomainParams({
      tickerHash: _params.tickerHash,
      domains: domains,
      invoice: _params.invoice,
      epoch: _params.epoch
    });

    ISettler.FindDomainResult memory result = settler.findLowestDiscountAndHighestLiquidity(params);
    assertEq(result.selectedDomain, _params.domainB, 'invalid selected domain');
  }

  /**
   * @notice Test the case where the liquidity is not enough in both domains
   * @param _params The test parameters
   */
  function test_FindLowestDiscountAndHighest_NoLiquidity(
    FindLowestDiscountAndHighestLiquidityTestParams memory _params
  ) public {
    vm.assume(_params.discountPerEpoch > 0);
    vm.assume(_params.invoice.amount > 0);
    vm.assume(_params.invoice.entryEpoch < _params.epoch);
    vm.assume(_params.assetHashA != 0 && _params.assetHashB != 0 && _params.assetHashA != _params.assetHashB);

    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockDiscountPerEpoch(_params.tickerHash, _params.discountPerEpoch);

    uint24 _discountDbps = settler.getDiscountDbps(_params.tickerHash, _params.epoch, _params.invoice.entryEpoch);
    vm.assume(_discountDbps > 0);

    uint256 _amountToBeDiscountedA =
      _params.invoice.amount > _params.depositsAvailableA ? _params.depositsAvailableA : _params.invoice.amount;
    vm.assume(type(uint256).max / _discountDbps >= _amountToBeDiscountedA);
    uint256 _amountAfterDiscountA =
      _params.invoice.amount - (_amountToBeDiscountedA * _discountDbps / Constants.DBPS_DENOMINATOR);

    uint256 _amountToBeDiscountedB =
      _params.invoice.amount > _params.depositsAvailableB ? _params.depositsAvailableB : _params.invoice.amount;
    vm.assume(type(uint256).max / _discountDbps >= _amountToBeDiscountedB);
    uint256 _amountAfterDiscountB =
      _params.invoice.amount - (_amountToBeDiscountedB * _discountDbps / Constants.DBPS_DENOMINATOR);

    vm.assume(_params.liquidityA < _amountAfterDiscountA && _params.liquidityB < _params.invoice.amount);
    vm.assume(_params.liquidityB < _amountAfterDiscountB && _params.liquidityB < _params.invoice.amount);

    uint32[] memory domains = new uint32[](2);
    domains[0] = _params.domainA;
    domains[1] = _params.domainB;

    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domainA, _params.assetHashA);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domainB, _params.assetHashB);
    settler.mockCustodiedAssets(_params.assetHashA, _params.liquidityA);
    settler.mockCustodiedAssets(_params.assetHashB, _params.liquidityB);

    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domainA, _params.tickerHash, _params.depositsAvailableA);
    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.domainB, _params.tickerHash, _params.depositsAvailableB);

    ISettler.FindDomainParams memory params = ISettler.FindDomainParams({
      tickerHash: _params.tickerHash,
      domains: domains,
      invoice: _params.invoice,
      epoch: _params.epoch
    });

    ISettler.FindDomainResult memory result = settler.findLowestDiscountAndHighestLiquidity(params);
    assertEq(result.selectedDomain, 0, 'invalid selected domain');
  }
}

contract Unit_FindDestinationWithStrategiesForInvoice is BaseTest {
  /**
   * @notice Test the case where the prioritized strategy is XERC20 and the destination A has the XERC20 strategy
   */
  function test_Xerc20PrioritizedStrategy(
    uint48 _epoch,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityB,
    IHubStorage.Invoice memory _invoice
  ) public {
    vm.assume(_liquidityB >= _invoice.amount);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_destinationA != _destinationB && _destinationA != 0 && _destinationB != 0);

    uint32[] memory _domains = new uint32[](2);
    _domains[0] = _destinationA;
    _domains[1] = _destinationB;
    settler.mockUserSupportedDomains(_invoice.owner, _domains);

    settler.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.XERC20);
    settler.mockAssetHashStrategy(_assetHashA, IEverclear.Strategy.XERC20);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);
    settler.mockCustodiedAssets(_assetHashB, _liquidityB);

    ISettler.FindDomainResult memory _result =
      settler.findDestinationWithStrategiesForInvoice(_epoch, _tickerHash, _invoice);
    assertEq(_result.selectedDomain, _destinationA, 'invalid selected domain');
  }

  /**
   * @notice Test the case where the prioritized strategy is XERC20 but there are not destinations with the XERC20 strategy and liquidity is enough
   */
  function test_Xerc20PrioritizedStrategy_NoXERC20Destination(
    uint48 _epoch,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityB,
    IHubStorage.Invoice memory _invoice
  ) public {
    vm.assume(_invoice.amount > 0);
    vm.assume(_liquidityB >= _invoice.amount);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_destinationA != _destinationB && _destinationA != 0 && _destinationB != 0);

    uint32[] memory _domains = new uint32[](2);
    _domains[0] = _destinationA;
    _domains[1] = _destinationB;
    settler.mockUserSupportedDomains(_invoice.owner, _domains);

    settler.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.XERC20);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);
    settler.mockCustodiedAssets(_assetHashB, _liquidityB);

    ISettler.FindDomainResult memory _result =
      settler.findDestinationWithStrategiesForInvoice(_epoch, _tickerHash, _invoice);
    assertEq(_result.selectedDomain, _destinationB, 'invalid selected domain');
  }

  /**
   * @notice Test the case where the prioritized strategy is XERC20 but there are not destinations with the XERC20 strategy and liquidity is not enough
   */
  function test_Xerc20PrioritizedStrategy_NoXERC20Destination_NotEnoughLiqudity(
    uint48 _epoch,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityB,
    IHubStorage.Invoice memory _invoice
  ) public {
    vm.assume(_liquidityB < _invoice.amount);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_destinationA != _destinationB && _destinationA != 0 && _destinationB != 0);

    uint32[] memory _domains = new uint32[](2);
    _domains[0] = _destinationA;
    _domains[1] = _destinationB;
    settler.mockUserSupportedDomains(_invoice.owner, _domains);

    settler.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.XERC20);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);
    settler.mockCustodiedAssets(_assetHashB, _liquidityB);

    ISettler.FindDomainResult memory _result =
      settler.findDestinationWithStrategiesForInvoice(_epoch, _tickerHash, _invoice);
    assertEq(_result.selectedDomain, 0, 'invalid selected domain');
  }

  /**
   * @notice Test the case where the prioritized strategy is DEFAULT and there is enough liquidity in the destination B
   */
  function test_DefaultPrioritizedStrategy(
    uint48 _epoch,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityB,
    IHubStorage.Invoice memory _invoice
  ) public {
    vm.assume(_invoice.amount > 0);
    vm.assume(_liquidityB >= _invoice.amount);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_destinationA != _destinationB && _destinationA != 0 && _destinationB != 0);

    uint32[] memory _domains = new uint32[](2);
    _domains[0] = _destinationA;
    _domains[1] = _destinationB;
    settler.mockUserSupportedDomains(_invoice.owner, _domains);

    settler.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockAssetHashStrategy(_assetHashA, IEverclear.Strategy.XERC20);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);
    settler.mockCustodiedAssets(_assetHashB, _liquidityB);

    ISettler.FindDomainResult memory _result =
      settler.findDestinationWithStrategiesForInvoice(_epoch, _tickerHash, _invoice);
    assertEq(_result.selectedDomain, _destinationB, 'invalid selected domain');
  }

  /**
   * @notice Test the case where the prioritized strategy is DEFAULT and there is not enough liquidity in the destination B, and there is a XERC20 destination
   */
  function test_DefaultPrioritizedStrategy_NotEnoughLiquidity(
    uint48 _epoch,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityB,
    IHubStorage.Invoice memory _invoice
  ) public {
    vm.assume(_liquidityB < _invoice.amount);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_destinationA != _destinationB && _destinationA != 0 && _destinationB != 0);

    uint32[] memory _domains = new uint32[](2);
    _domains[0] = _destinationA;
    _domains[1] = _destinationB;
    settler.mockUserSupportedDomains(_invoice.owner, _domains);

    settler.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockAssetHashStrategy(_assetHashA, IEverclear.Strategy.XERC20);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);
    settler.mockCustodiedAssets(_assetHashB, _liquidityB);

    ISettler.FindDomainResult memory _result =
      settler.findDestinationWithStrategiesForInvoice(_epoch, _tickerHash, _invoice);
    assertEq(_result.selectedDomain, _destinationA, 'invalid selected domain');
  }

  /**
   * @notice Test the case where the prioritized strategy is DEFAULT and there is not enough liquidity in the destination B, and there is not a XERC20 destination
   */
  function test_DefaultPrioritizedStrategy_NotEnoughLiquidity_NoXerc20Destination(
    uint48 _epoch,
    bytes32 _tickerHash,
    bytes32 _assetHashA,
    bytes32 _assetHashB,
    uint32 _destinationA,
    uint32 _destinationB,
    uint256 _liquidityB,
    IHubStorage.Invoice memory _invoice
  ) public {
    vm.assume(_liquidityB < _invoice.amount);
    vm.assume(_assetHashA != 0 && _assetHashB != 0 && _assetHashA != _assetHashB);
    vm.assume(_destinationA != _destinationB && _destinationA != 0 && _destinationB != 0);

    uint32[] memory _domains = new uint32[](2);
    _domains[0] = _destinationA;
    _domains[1] = _destinationB;
    settler.mockUserSupportedDomains(_invoice.owner, _domains);

    settler.mockAssetPrioritizedStrategy(_tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationA, _assetHashA);
    settler.mockTokenConfigAssetHash(_tickerHash, _destinationB, _assetHashB);
    settler.mockCustodiedAssets(_assetHashB, _liquidityB);

    ISettler.FindDomainResult memory _result =
      settler.findDestinationWithStrategiesForInvoice(_epoch, _tickerHash, _invoice);
    assertEq(_result.selectedDomain, 0, 'invalid selected domain');
  }
}

contract Unit_ProcessDeposit is BaseTest {
  struct ProcessDepositTestParams {
    bytes32 intentId;
    bytes32 tickerHash;
    bytes32 assetHash;
    bytes32 owner;
    uint48 epoch;
    uint32 domain;
    uint256 amount;
    uint256 amountAfterFees;
    uint256 rewards;
    uint256 liquidity;
  }

  /**
   * @notice Test the case where the TTL is zero and the prioritized strategy is DEFAULT and there is not enough liquidity
   */
  function test_TTLZero_DefaultStrategy_NotEnoughLiquidity(
    ProcessDepositTestParams memory _params
  ) public {
    vm.assume(_params.amountAfterFees < _params.amount);
    vm.assume(type(uint256).max - _params.amountAfterFees >= _params.rewards);
    uint256 _settleAmount = _params.amountAfterFees + _params.rewards;
    vm.assume(_settleAmount > _params.liquidity);
    vm.assume(_params.domain != 0);

    settler.mockAssetPrioritizedStrategy(_params.tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domain, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockEpochLength(1);

    IHubStorage.Deposit memory deposit =
      IHubStorage.Deposit({intentId: _params.intentId, purchasePower: _params.amount});

    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _params.domain;

    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0,
      receiver: _params.owner,
      inputAsset: 0,
      outputAsset: 0,
      maxFee: 0,
      origin: 0,
      nonce: 0,
      timestamp: 0,
      ttl: 0,
      amount: _params.amount,
      destinations: _destinations,
      data: ''
    });

    IHubStorage.IntentContext memory context = IHubStorage.IntentContext({
      solver: 0,
      fee: 0,
      totalProtocolFee: 0,
      fillTimestamp: 0,
      amountAfterFees: _params.amountAfterFees,
      pendingRewards: _params.rewards,
      status: IEverclear.IntentStatus.ADDED,
      intent: _intent
    });

    settler.mockIntentContext(_params.intentId, context);
    settler.mockDeposit(_params.epoch, _params.domain, _params.tickerHash, deposit);

    // check the deposit is processed
    _expectEmit(address(settler));
    emit DepositProcessed(_params.epoch, _params.domain, _params.tickerHash, _params.intentId, _settleAmount);

    uint48 _currentEpoch = settler.getCurrentEpoch();

    // check the invoice is created and enqueued
    _expectEmit(address(settler));
    emit InvoiceEnqueued(_params.intentId, _params.tickerHash, _currentEpoch, _settleAmount, _params.owner);

    settler.processDeposit(_params.epoch, _params.domain, _params.tickerHash);

    (uint256 _first, uint256 _last,) = settler.deposits(_params.epoch, _params.domain, _params.tickerHash);
    // check the deposit is removed
    assertEq(_first, 2, 'invalid first');
    assertEq(_last, 1, 'invalid last');
  }

  /**
   * @notice Test the case where the TTL is zero and the prioritized strategy is DEFAULT and xerc20 is supported
   */
  function test_TTLZero_DefaultStrategy_NotEnoughLiquidity_XERC20Supported(
    ProcessDepositTestParams memory _params
  ) public {
    vm.assume(_params.amountAfterFees < _params.amount);
    vm.assume(type(uint256).max - _params.amountAfterFees >= _params.rewards);
    uint256 _settleAmount = _params.amountAfterFees + _params.rewards;
    vm.assume(_params.domain != 0);

    settler.mockAssetPrioritizedStrategy(_params.tickerHash, IEverclear.Strategy.XERC20);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domain, _params.assetHash);
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.XERC20);
    settler.mockEpochLength(1);

    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _params.domain;

    IHubStorage.Deposit memory deposit =
      IHubStorage.Deposit({intentId: _params.intentId, purchasePower: _params.amount});

    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0,
      receiver: _params.owner,
      inputAsset: 0,
      outputAsset: 0,
      maxFee: 0,
      origin: 0,
      nonce: 0,
      timestamp: 0,
      ttl: 0,
      amount: _params.amount,
      destinations: _destinations,
      data: ''
    });

    IHubStorage.IntentContext memory context = IHubStorage.IntentContext({
      solver: 0,
      fee: 0,
      totalProtocolFee: 0,
      fillTimestamp: 0,
      amountAfterFees: _params.amountAfterFees,
      pendingRewards: _params.rewards,
      status: IEverclear.IntentStatus.ADDED,
      intent: _intent
    });

    settler.mockIntentContext(_params.intentId, context);
    settler.mockDeposit(_params.epoch, _params.domain, _params.tickerHash, deposit);

    // check the deposit is processed
    _expectEmit(address(settler));
    emit DepositProcessed(_params.epoch, _params.domain, _params.tickerHash, _params.intentId, _settleAmount);

    uint48 _currentEpoch = settler.getCurrentEpoch();

    // check the settlement is created and enqueued
    _expectEmit(address(settler));
    emit SettlementEnqueued(
      _params.intentId, _params.domain, _currentEpoch, _params.assetHash, _settleAmount, false, _params.owner
    );

    settler.processDeposit(_params.epoch, _params.domain, _params.tickerHash);

    (uint256 _first, uint256 _last,) = settler.deposits(_params.epoch, _params.domain, _params.tickerHash);
    // check the deposit is removed
    assertEq(_first, 2, 'invalid first');
    assertEq(_last, 1, 'invalid last');
  }

  /**
   * @notice Test the case where the TTL is zero and the prioritized strategy is DEFAULT and there is enough liquidity
   */
  function test_TTLZero_DefaultStrategy_EnoughLiquidity(
    ProcessDepositTestParams memory _params
  ) public {
    vm.assume(_params.amountAfterFees > 0);
    vm.assume(_params.amountAfterFees < _params.amount);
    vm.assume(type(uint256).max - _params.amountAfterFees >= _params.rewards);
    uint256 _settleAmount = _params.amountAfterFees + _params.rewards;
    vm.assume(_params.liquidity >= _settleAmount);
    vm.assume(_params.domain != 0);

    settler.mockAssetPrioritizedStrategy(_params.tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domain, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockEpochLength(1);

    IHubStorage.Deposit memory deposit =
      IHubStorage.Deposit({intentId: _params.intentId, purchasePower: _params.amount});

    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _params.domain;

    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0,
      receiver: _params.owner,
      inputAsset: 0,
      outputAsset: 0,
      maxFee: 0,
      origin: 0,
      nonce: 0,
      timestamp: 0,
      ttl: 0,
      amount: _params.amount,
      destinations: _destinations,
      data: ''
    });

    IHubStorage.IntentContext memory context = IHubStorage.IntentContext({
      solver: 0,
      fee: 0,
      totalProtocolFee: 0,
      fillTimestamp: 0,
      amountAfterFees: _params.amountAfterFees,
      pendingRewards: _params.rewards,
      status: IEverclear.IntentStatus.ADDED,
      intent: _intent
    });

    settler.mockIntentContext(_params.intentId, context);
    settler.mockDeposit(_params.epoch, _params.domain, _params.tickerHash, deposit);

    // check the deposit is processed
    _expectEmit(address(settler));
    emit DepositProcessed(_params.epoch, _params.domain, _params.tickerHash, _params.intentId, _settleAmount);

    uint48 _currentEpoch = settler.getCurrentEpoch();

    // check the settlement is created and enqueued
    _expectEmit(address(settler));
    emit SettlementEnqueued(
      _params.intentId, _params.domain, _currentEpoch, _params.assetHash, _settleAmount, false, _params.owner
    );

    settler.processDeposit(_params.epoch, _params.domain, _params.tickerHash);

    (uint256 _first, uint256 _last,) = settler.deposits(_params.epoch, _params.domain, _params.tickerHash);
    // check the deposit is removed
    assertEq(_first, 2, 'invalid first');
    assertEq(_last, 1, 'invalid last');
  }

  /**
   * @notice Test the case where the TTL is not zero and a solver filled but there is not enough liquidity
   */
  function test_TTLNotZero_SolverFilled_DefaultStrategy_NotEnoughLiquidity(
    ProcessDepositTestParams memory _params,
    bytes32 _solver,
    uint48 _ttl
  ) public {
    vm.assume(_params.amountAfterFees < _params.amount);
    vm.assume(type(uint256).max - _params.amountAfterFees >= _params.rewards);
    uint256 _settleAmount = _params.amountAfterFees + _params.rewards;
    vm.assume(_settleAmount > _params.liquidity);
    vm.assume(_params.domain != 0);
    vm.assume(_ttl > 0);
    vm.assume(_solver != 0);

    settler.mockAssetPrioritizedStrategy(_params.tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domain, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockEpochLength(1);

    IHubStorage.Deposit memory deposit =
      IHubStorage.Deposit({intentId: _params.intentId, purchasePower: _params.amount});

    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _params.domain;

    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0,
      receiver: _params.owner,
      inputAsset: 0,
      outputAsset: 0,
      maxFee: 0,
      origin: 0,
      nonce: 0,
      timestamp: 0,
      ttl: _ttl,
      amount: _params.amount,
      destinations: _destinations,
      data: ''
    });

    IHubStorage.IntentContext memory context = IHubStorage.IntentContext({
      solver: _solver,
      fee: 0,
      totalProtocolFee: 0,
      fillTimestamp: 0,
      amountAfterFees: _params.amountAfterFees,
      pendingRewards: _params.rewards,
      status: IEverclear.IntentStatus.ADDED,
      intent: _intent
    });

    settler.mockIntentContext(_params.intentId, context);
    settler.mockDeposit(_params.epoch, _params.domain, _params.tickerHash, deposit);

    // check the deposit is processed
    _expectEmit(address(settler));
    emit DepositProcessed(_params.epoch, _params.domain, _params.tickerHash, _params.intentId, _settleAmount);

    uint48 _currentEpoch = settler.getCurrentEpoch();

    // check the invoice is created and enqueued
    _expectEmit(address(settler));
    emit InvoiceEnqueued(_params.intentId, _params.tickerHash, _currentEpoch, _settleAmount, _solver);

    settler.processDeposit(_params.epoch, _params.domain, _params.tickerHash);

    (uint256 _first, uint256 _last,) = settler.deposits(_params.epoch, _params.domain, _params.tickerHash);
    // check the deposit is removed
    assertEq(_first, 2, 'invalid first');
    assertEq(_last, 1, 'invalid last');
  }

  /**
   * @notice Test the case where the TTL is not zero and a solver filled but there is not enough liquidity and xerc20 is supported
   */
  function test_TTLNotZero_SolverFilled_DefaultStrategy_XERC20Supported(
    ProcessDepositTestParams memory _params,
    bytes32 _solver,
    uint48 _ttl
  ) public {
    vm.assume(_params.amountAfterFees < _params.amount);
    vm.assume(type(uint256).max - _params.amountAfterFees >= _params.rewards);
    uint256 _settleAmount = _params.amountAfterFees + _params.rewards;
    vm.assume(_settleAmount <= _params.liquidity);
    vm.assume(_params.domain != 0);
    vm.assume(_ttl > 0);
    vm.assume(_solver != 0);

    settler.mockAssetPrioritizedStrategy(_params.tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.XERC20);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domain, _params.assetHash);
    settler.mockEpochLength(1);

    IHubStorage.Deposit memory deposit =
      IHubStorage.Deposit({intentId: _params.intentId, purchasePower: _params.amount});

    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _params.domain;

    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0,
      receiver: _params.owner,
      inputAsset: 0,
      outputAsset: 0,
      maxFee: 0,
      origin: 0,
      nonce: 0,
      timestamp: 0,
      ttl: _ttl,
      amount: _params.amount,
      destinations: _destinations,
      data: ''
    });

    IHubStorage.IntentContext memory context = IHubStorage.IntentContext({
      solver: _solver,
      fee: 0,
      totalProtocolFee: 0,
      fillTimestamp: 0,
      amountAfterFees: _params.amountAfterFees,
      pendingRewards: _params.rewards,
      status: IEverclear.IntentStatus.ADDED,
      intent: _intent
    });

    settler.mockIntentContext(_params.intentId, context);
    settler.mockDeposit(_params.epoch, _params.domain, _params.tickerHash, deposit);

    // check the deposit is processed
    _expectEmit(address(settler));
    emit DepositProcessed(_params.epoch, _params.domain, _params.tickerHash, _params.intentId, _settleAmount);

    uint48 _currentEpoch = settler.getCurrentEpoch();

    // check the invoice is created and enqueued
    _expectEmit(address(settler));
    emit SettlementEnqueued(
      _params.intentId, _params.domain, _currentEpoch, _params.assetHash, _settleAmount, false, _solver
    );

    settler.processDeposit(_params.epoch, _params.domain, _params.tickerHash);

    (uint256 _first, uint256 _last,) = settler.deposits(_params.epoch, _params.domain, _params.tickerHash);
    // check the deposit is removed
    assertEq(_first, 2, 'invalid first');
    assertEq(_last, 1, 'invalid last');
  }

  /**
   * @notice Test the case where the TTL is not zero and a solver filled and there is not enough liquidity
   */
  function test_TTLNotZero_SolverFilled_DefaultStrategy_EnoughLiquidity(
    ProcessDepositTestParams memory _params,
    bytes32 _solver,
    uint48 _ttl
  ) public {
    vm.assume(_params.amountAfterFees < _params.amount);
    vm.assume(_params.amountAfterFees > 0);
    vm.assume(type(uint256).max - _params.amountAfterFees >= _params.rewards);
    uint256 _settleAmount = _params.amountAfterFees + _params.rewards;
    vm.assume(_settleAmount <= _params.liquidity);
    vm.assume(_params.domain != 0);
    vm.assume(_ttl > 0);
    vm.assume(_solver != 0);

    settler.mockAssetPrioritizedStrategy(_params.tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domain, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockEpochLength(1);

    IHubStorage.Deposit memory deposit =
      IHubStorage.Deposit({intentId: _params.intentId, purchasePower: _params.amount});

    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _params.domain;

    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0,
      receiver: _params.owner,
      inputAsset: 0,
      outputAsset: 0,
      maxFee: 0,
      origin: 0,
      nonce: 0,
      timestamp: 0,
      ttl: _ttl,
      amount: _params.amount,
      destinations: _destinations,
      data: ''
    });

    IHubStorage.IntentContext memory context = IHubStorage.IntentContext({
      solver: _solver,
      fee: 0,
      totalProtocolFee: 0,
      fillTimestamp: 0,
      amountAfterFees: _params.amountAfterFees,
      pendingRewards: _params.rewards,
      status: IEverclear.IntentStatus.ADDED,
      intent: _intent
    });

    settler.mockIntentContext(_params.intentId, context);
    settler.mockDeposit(_params.epoch, _params.domain, _params.tickerHash, deposit);

    // check the deposit is processed
    _expectEmit(address(settler));
    emit DepositProcessed(_params.epoch, _params.domain, _params.tickerHash, _params.intentId, _settleAmount);

    uint48 _currentEpoch = settler.getCurrentEpoch();

    // check the invoice is created and enqueued
    _expectEmit(address(settler));
    emit SettlementEnqueued(
      _params.intentId, _params.domain, _currentEpoch, _params.assetHash, _settleAmount, false, _solver
    );

    settler.processDeposit(_params.epoch, _params.domain, _params.tickerHash);

    (uint256 _first, uint256 _last,) = settler.deposits(_params.epoch, _params.domain, _params.tickerHash);
    // check the deposit is removed
    assertEq(_first, 2, 'invalid first');
    assertEq(_last, 1, 'invalid last');
  }

  /**
   * @notice Test the case where the TTL is not zero and the solver  not filled and the TTL is expired
   */
  function test_TTLNotZero_SolverNotFilled_Expired_DefaultStrategy_NotEnoughLiquidity(
    ProcessDepositTestParams memory _params,
    uint48 _intentTimestamp,
    uint48 _currentTimestamp,
    uint48 _ttl
  ) public {
    vm.assume(_params.amountAfterFees < _params.amount);
    vm.assume(type(uint256).max - _params.amountAfterFees >= _params.rewards);
    uint256 _settleAmount = _params.amountAfterFees + _params.rewards;
    vm.assume(_settleAmount > _params.liquidity);
    vm.assume(_params.domain != 0);
    vm.assume(_ttl > 0 && _ttl < type(uint48).max && type(uint48).max - _intentTimestamp >= _ttl + 1);
    vm.assume(_currentTimestamp > _intentTimestamp + _ttl + settler.expiryTimeBuffer() + 1);
    vm.warp(_currentTimestamp);

    settler.mockAssetPrioritizedStrategy(_params.tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domain, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockEpochLength(1);

    IHubStorage.Deposit memory deposit =
      IHubStorage.Deposit({intentId: _params.intentId, purchasePower: _params.amount});

    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _params.domain;

    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0,
      receiver: _params.owner,
      inputAsset: 0,
      outputAsset: 0,
      maxFee: 0,
      origin: 0,
      nonce: 0,
      timestamp: _intentTimestamp,
      ttl: _ttl,
      amount: _params.amount,
      destinations: _destinations,
      data: ''
    });

    IHubStorage.IntentContext memory context = IHubStorage.IntentContext({
      solver: 0,
      fee: 0,
      totalProtocolFee: 0,
      fillTimestamp: 0,
      amountAfterFees: _params.amountAfterFees,
      pendingRewards: _params.rewards,
      status: IEverclear.IntentStatus.ADDED,
      intent: _intent
    });

    settler.mockIntentContext(_params.intentId, context);
    settler.mockDeposit(_params.epoch, _params.domain, _params.tickerHash, deposit);

    // check the deposit is processed
    _expectEmit(address(settler));
    emit DepositProcessed(_params.epoch, _params.domain, _params.tickerHash, _params.intentId, _settleAmount);

    uint48 _currentEpoch = settler.getCurrentEpoch();

    // check the invoice is created and enqueued
    _expectEmit(address(settler));
    emit InvoiceEnqueued(_params.intentId, _params.tickerHash, _currentEpoch, _settleAmount, _params.owner);

    settler.processDeposit(_params.epoch, _params.domain, _params.tickerHash);

    (uint256 _first, uint256 _last,) = settler.deposits(_params.epoch, _params.domain, _params.tickerHash);
    // check the deposit is removed
    assertEq(_first, 2, 'invalid first');
    assertEq(_last, 1, 'invalid last');
  }

  /**
   * @notice Test the case where the TTL is not zero and the solver  not filled and the TTL is expired and there is enough liquidity
   */
  function test_TTLNotZero_SolverNotFilled_Expired_DefaultStrategy_EnoughLiquidity(
    ProcessDepositTestParams memory _params,
    uint48 _intentTimestamp,
    uint48 _currentTimestamp,
    uint48 _ttl
  ) public {
    vm.assume(_params.amountAfterFees > 0);
    vm.assume(_params.amountAfterFees < _params.amount);
    vm.assume(type(uint256).max - _params.amountAfterFees >= _params.rewards);
    uint256 _settleAmount = _params.amountAfterFees + _params.rewards;
    vm.assume(_settleAmount <= _params.liquidity);
    vm.assume(_params.domain != 0);
    vm.assume(_ttl > 0 && _ttl < type(uint48).max && type(uint48).max - _intentTimestamp >= _ttl + 1);
    vm.assume(_currentTimestamp > _intentTimestamp + _ttl + settler.expiryTimeBuffer() + 1);
    vm.warp(_currentTimestamp);

    settler.mockAssetPrioritizedStrategy(_params.tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domain, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockEpochLength(1);

    IHubStorage.Deposit memory deposit =
      IHubStorage.Deposit({intentId: _params.intentId, purchasePower: _params.amount});

    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _params.domain;

    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0,
      receiver: _params.owner,
      inputAsset: 0,
      outputAsset: 0,
      maxFee: 0,
      origin: 0,
      nonce: 0,
      timestamp: _intentTimestamp,
      ttl: _ttl,
      amount: _params.amount,
      destinations: _destinations,
      data: ''
    });

    IHubStorage.IntentContext memory context = IHubStorage.IntentContext({
      solver: 0,
      fee: 0,
      totalProtocolFee: 0,
      fillTimestamp: 0,
      amountAfterFees: _params.amountAfterFees,
      pendingRewards: _params.rewards,
      status: IEverclear.IntentStatus.ADDED,
      intent: _intent
    });

    settler.mockIntentContext(_params.intentId, context);
    settler.mockDeposit(_params.epoch, _params.domain, _params.tickerHash, deposit);

    // check the deposit is processed
    _expectEmit(address(settler));
    emit DepositProcessed(_params.epoch, _params.domain, _params.tickerHash, _params.intentId, _settleAmount);

    // check the invoice is created and enqueued
    _expectEmit(address(settler));
    emit SettlementEnqueued(
      _params.intentId,
      _params.domain,
      settler.getCurrentEpoch(),
      _params.assetHash,
      _settleAmount,
      false,
      _params.owner
    );

    settler.processDeposit(_params.epoch, _params.domain, _params.tickerHash);

    (uint256 _first, uint256 _last,) = settler.deposits(_params.epoch, _params.domain, _params.tickerHash);
    // check the deposit is removed
    assertEq(_first, 2, 'invalid first');
    assertEq(_last, 1, 'invalid last');
  }

  /**
   * @notice Test the case where the TTL is not zero and the solver  not filled, the TTL is expired and XERC20 is supported
   */
  function test_TTLNotZero_SolverNotFilled_Expired_DefaultStrategy_XERC20Supported(
    ProcessDepositTestParams memory _params,
    uint48 _intentTimestamp,
    uint48 _currentTimestamp,
    uint48 _ttl
  ) public {
    vm.assume(_params.amountAfterFees < _params.amount);
    vm.assume(type(uint256).max - _params.amountAfterFees >= _params.rewards);
    uint256 _settleAmount = _params.amountAfterFees + _params.rewards;
    vm.assume(_settleAmount <= _params.liquidity);
    vm.assume(_params.domain != 0);
    vm.assume(_ttl > 0 && _ttl < type(uint48).max && type(uint48).max - _intentTimestamp >= _ttl + 1);
    vm.assume(_currentTimestamp > _intentTimestamp + _ttl + settler.expiryTimeBuffer() + 1);
    vm.warp(_currentTimestamp);

    settler.mockAssetPrioritizedStrategy(_params.tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domain, _params.assetHash);
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.XERC20);
    settler.mockEpochLength(1);

    IHubStorage.Deposit memory deposit =
      IHubStorage.Deposit({intentId: _params.intentId, purchasePower: _params.amount});

    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _params.domain;

    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0,
      receiver: _params.owner,
      inputAsset: 0,
      outputAsset: 0,
      maxFee: 0,
      origin: 0,
      nonce: 0,
      timestamp: _intentTimestamp,
      ttl: _ttl,
      amount: _params.amount,
      destinations: _destinations,
      data: ''
    });

    IHubStorage.IntentContext memory context = IHubStorage.IntentContext({
      solver: 0,
      fee: 0,
      totalProtocolFee: 0,
      fillTimestamp: 0,
      amountAfterFees: _params.amountAfterFees,
      pendingRewards: _params.rewards,
      status: IEverclear.IntentStatus.ADDED,
      intent: _intent
    });

    settler.mockIntentContext(_params.intentId, context);
    settler.mockDeposit(_params.epoch, _params.domain, _params.tickerHash, deposit);

    // check the deposit is processed
    _expectEmit(address(settler));
    emit DepositProcessed(_params.epoch, _params.domain, _params.tickerHash, _params.intentId, _settleAmount);

    // check the invoice is created and enqueued
    _expectEmit(address(settler));
    emit SettlementEnqueued(
      _params.intentId,
      _params.domain,
      settler.getCurrentEpoch(),
      _params.assetHash,
      _settleAmount,
      false,
      _params.owner
    );

    settler.processDeposit(_params.epoch, _params.domain, _params.tickerHash);

    (uint256 _first, uint256 _last,) = settler.deposits(_params.epoch, _params.domain, _params.tickerHash);
    // check the deposit is removed
    assertEq(_first, 2, 'invalid first');
    assertEq(_last, 1, 'invalid last');
  }

  /**
   * @notice Test the case where the TTL is not zero and the solver  not filled and the TTL is not expired
   */
  function test_TTLNotZero_SolverNotFilled_NotExpired(
    ProcessDepositTestParams memory _params,
    uint48 _intentTimestamp,
    uint48 _currentTimestamp,
    uint48 _ttl
  ) public {
    vm.assume(_params.amountAfterFees < _params.amount);
    vm.assume(type(uint256).max - _params.amountAfterFees >= _params.rewards);
    uint256 _settleAmount = _params.amountAfterFees + _params.rewards;
    vm.assume(_params.domain != 0);
    vm.assume(_ttl > 0 && _ttl < type(uint48).max && type(uint48).max - _intentTimestamp >= _ttl + 1);
    vm.assume(_currentTimestamp < _intentTimestamp + _ttl + settler.expiryTimeBuffer() + 1);
    vm.warp(_currentTimestamp);

    settler.mockAssetPrioritizedStrategy(_params.tickerHash, IEverclear.Strategy.DEFAULT);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.domain, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockEpochLength(1);

    IHubStorage.Deposit memory deposit =
      IHubStorage.Deposit({intentId: _params.intentId, purchasePower: _params.amount});

    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _params.domain;

    IEverclear.Intent memory _intent = IEverclear.Intent({
      initiator: 0,
      receiver: _params.owner,
      inputAsset: 0,
      outputAsset: 0,
      maxFee: 0,
      origin: 0,
      nonce: 0,
      timestamp: _intentTimestamp,
      ttl: _ttl,
      amount: _params.amount,
      destinations: _destinations,
      data: ''
    });

    IHubStorage.IntentContext memory context = IHubStorage.IntentContext({
      solver: 0,
      fee: 0,
      totalProtocolFee: 0,
      fillTimestamp: 0,
      amountAfterFees: _params.amountAfterFees,
      pendingRewards: _params.rewards,
      status: IEverclear.IntentStatus.ADDED,
      intent: _intent
    });

    settler.mockIntentContext(_params.intentId, context);
    settler.mockDeposit(_params.epoch, _params.domain, _params.tickerHash, deposit);

    // check the deposit is processed
    _expectEmit(address(settler));
    emit DepositProcessed(_params.epoch, _params.domain, _params.tickerHash, _params.intentId, _settleAmount);

    settler.processDeposit(_params.epoch, _params.domain, _params.tickerHash);

    (uint256 _first, uint256 _last,) = settler.deposits(_params.epoch, _params.domain, _params.tickerHash);
    IHubStorage.IntentContext memory _context = settler.contexts(_params.intentId);

    // check the deposit is removed
    assertEq(_first, 2, 'invalid first');
    assertEq(_last, 1, 'invalid last');

    // check the deposit is processed status
    assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.DEPOSIT_PROCESSED), 'invalid status');
  }
}

contract Unit_ProcessInvoice is BaseTest {
  struct ProcessInvoiceTestParams {
    uint8 discountPerEpoch;
    uint48 entryEpoch;
    uint48 epoch;
    uint32 destination;
    uint256 amount;
    uint256 liquidity;
    bytes32 tickerHash;
    bytes32 assetHash;
    bytes32 intentId;
    bytes32 owner;
  }

  struct DepositParams {
    bytes32 depositIntentId;
    uint256 depositAvailable;
  }

  event log_named_uint256(string name, uint256 value);

  /**
   * @notice Test the case where there are no deposits and there is enough liquidity
   */
  function test_NoDeposits_EnoughLiquidity(
    ProcessInvoiceTestParams memory _params
  ) public {
    vm.assume(_params.amount > 0);
    vm.assume(_params.destination != 0);
    vm.assume(_params.entryEpoch < _params.epoch);
    vm.assume(_params.liquidity >= _params.amount);
    settler.mockDiscountPerEpoch(_params.tickerHash, 5000);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.destination, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.DEFAULT);
    uint32[] memory _domains = new uint32[](1);
    _domains[0] = _params.destination;
    settler.mockUserSupportedDomains(_params.owner, _domains);

    IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
      intentId: _params.intentId,
      owner: _params.owner,
      entryEpoch: _params.entryEpoch,
      amount: _params.amount
    });

    uint48 _currentEpoch = settler.getCurrentEpoch();

    _expectEmit(address(settler));
    emit SettlementEnqueued(
      _params.intentId, _params.destination, _currentEpoch, _params.assetHash, _params.amount, false, _params.owner
    );

    bool _settled = settler.processInvoice(_params.epoch, _params.tickerHash, _invoice);

    IHubStorage.IntentContext memory _context = settler.contexts(_params.intentId);
    assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED));
    assertEq(_settled, true, 'invalid settled');
  }

  /**
   * @notice Test the case where there are no deposits and there is not enough liquidity
   */
  function test_NoDeposits_NotEnoughLiquidity(
    ProcessInvoiceTestParams memory _params
  ) public {
    vm.assume(_params.amount > 0);
    vm.assume(_params.destination != 0);
    vm.assume(_params.entryEpoch < _params.epoch);
    vm.assume(_params.liquidity < _params.amount);
    settler.mockDiscountPerEpoch(_params.tickerHash, 5000);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.destination, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.DEFAULT);
    uint32[] memory _domains = new uint32[](1);
    _domains[0] = _params.destination;
    settler.mockUserSupportedDomains(_params.owner, _domains);

    IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
      intentId: _params.intentId,
      owner: _params.owner,
      entryEpoch: _params.entryEpoch,
      amount: _params.amount
    });

    bool _settled = settler.processInvoice(_params.epoch, _params.tickerHash, _invoice);

    IHubStorage.IntentContext memory _context = settler.contexts(_params.intentId);
    assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.NONE), 'invalid status');
    assertEq(_settled, false, 'invalid settled');
  }

  /**
   * @notice Test the case where there are no deposits and there is enough liquidity and XERC20 is supported
   */
  function test_NoDeposits_SupportsXERC20(
    ProcessInvoiceTestParams memory _params
  ) public {
    vm.assume(_params.amount > 0);
    vm.assume(_params.destination != 0);
    vm.assume(_params.entryEpoch < _params.epoch);
    settler.mockDiscountPerEpoch(_params.tickerHash, 5000);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.destination, _params.assetHash);
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.XERC20);
    uint32[] memory _domains = new uint32[](1);
    _domains[0] = _params.destination;
    settler.mockUserSupportedDomains(_params.owner, _domains);

    IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
      intentId: _params.intentId,
      owner: _params.owner,
      entryEpoch: _params.entryEpoch,
      amount: _params.amount
    });

    uint48 _currentEpoch = settler.getCurrentEpoch();

    _expectEmit(address(settler));
    emit SettlementEnqueued(
      _params.intentId, _params.destination, _currentEpoch, _params.assetHash, _params.amount, false, _params.owner
    );

    bool _settled = settler.processInvoice(_params.epoch, _params.tickerHash, _invoice);

    IHubStorage.IntentContext memory _context = settler.contexts(_params.intentId);
    assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED));
    assertEq(_settled, true, 'invalid settled');
  }

  /**
   * @notice Test the case where there are deposits and there is enough liquidity
   * @dev setting special fuzz runs combination only for this test, since max rejections is exceeded
   */
  /// forge-config: default.fuzz.runs = 100
  function test_DepositsAvailable_EnoughLiquidity(
    ProcessInvoiceTestParams memory _params,
    bytes32 _depositIntentId,
    uint256 _depositAvailable
  ) public {
    vm.assume(_params.destination != 0);
    vm.assume(_params.entryEpoch < _params.epoch);
    vm.assume(_params.amount > 1e18);
    vm.assume(_params.liquidity >= _params.amount);
    vm.assume(_params.intentId != _depositIntentId);
    vm.assume(_params.discountPerEpoch > 0);
    uint48 _interval = _params.epoch - _params.entryEpoch;
    vm.assume(type(uint24).max / _params.discountPerEpoch >= _interval);
    uint256 _amountToBeDiscounted = _depositAvailable <= _params.amount ? _depositAvailable : _params.amount;
    uint256 _discountDbps = _params.discountPerEpoch * _interval > Constants.DBPS_DENOMINATOR
      ? Constants.DBPS_DENOMINATOR
      : _params.discountPerEpoch * _interval;
    vm.assume(_discountDbps < Constants.DBPS_DENOMINATOR / 10); // max discount of 10%
    vm.assume(_amountToBeDiscounted == 0 || type(uint256).max / _amountToBeDiscounted >= _discountDbps);
    vm.assume(_depositAvailable > 0 && type(uint256).max / _depositAvailable >= _params.amount);
    settler.mockDiscountPerEpoch(_params.tickerHash, _params.discountPerEpoch);
    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.destination, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.DEFAULT);
    settler.mockDepositsAvailableInEpoch(_params.epoch, _params.destination, _params.tickerHash, _depositAvailable);
    settler.mockDeposit(
      _params.epoch,
      _params.destination,
      _params.tickerHash,
      IHubStorage.Deposit({intentId: _depositIntentId, purchasePower: _depositAvailable})
    );
    uint32[] memory _domains = new uint32[](1);
    _domains[0] = _params.destination;
    settler.mockUserSupportedDomains(_params.owner, _domains);
    IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
      intentId: _params.intentId,
      owner: _params.owner,
      entryEpoch: _params.entryEpoch,
      amount: _params.amount
    });

    _runAssertions(_params, _depositIntentId, _depositAvailable, _discountDbps, _interval, _invoice);
  }

  function _runAssertions(
    ProcessInvoiceTestParams memory _params,
    bytes32 _depositIntentId,
    uint256 _depositAvailable,
    uint256 _discountDbps,
    uint256 _interval,
    IHubStorage.Invoice memory _invoice
  ) internal {
    (uint256 _amountAfterDiscount,, uint256 _rewardsForDepositors) = settler.getDiscountedAmount(
      _params.tickerHash, uint24(_discountDbps), _params.destination, _params.epoch, _params.amount
    );

    uint256 _expectedReward = (_depositAvailable > _params.amount ? _params.amount : _depositAvailable)
      * _rewardsForDepositors / _amountAfterDiscount;

    _expectEmit(address(settler));
    emit SettlementEnqueued(
      _params.intentId,
      _params.destination,
      settler.getCurrentEpoch(),
      _params.assetHash,
      _amountAfterDiscount,
      false,
      _params.owner
    );

    bool _settled = settler.processInvoice(_params.epoch, _params.tickerHash, _invoice);

    IHubStorage.IntentContext memory _context = settler.contexts(_params.intentId);
    IHubStorage.IntentContext memory _depositContext = settler.contexts(_depositIntentId);
    assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
    assertEq(_settled, true, 'invalid settled');
    assertApproxEqRel(_amountAfterDiscount + _expectedReward, _params.amount, 0.02e18, 'invalid amount after discount');
    assertTrue(
      _amountAfterDiscount + _depositContext.pendingRewards <= _params.amount,
      'invalid amount after discount + pending rewards drain risk'
    );

    // 10% delta error in deposits rewards in case of rounding errors
    // TODO: check delta and margins, and lose of precision
    assertApproxEqRel(_depositContext.pendingRewards, _expectedReward, 0.1e18, 'invalid pending rewards');

    // Leaving informational logs important for debugging
    emit log_named_uint256('invoice amount', _params.amount);
    emit log_named_uint256('deposits available', _depositAvailable);
    emit log_named_uint256('amountAfterDiscount', _amountAfterDiscount);
    emit log_named_uint256('rewardsForDepositors', _rewardsForDepositors);
    emit log_named_uint256('pendingRewards', _depositContext.pendingRewards);
    emit log_named_uint256('amount', _params.amount);
    emit log_named_uint256('discountDbps', _discountDbps);
    emit log_named_uint256('interval', _interval);
  }
}

contract Unit_ProcessDepositsAndInvoices is BaseTest {
  event ClosedEpochsProcessed(bytes32 indexed _tickerHash, uint48 _lastClosedEpochProcessed);

  function test_Emit_ClosedEpochsProcessed(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    uint32 _destination,
    uint8 _currentEpoch,
    uint256 _liquidity,
    uint8 _invoicesNumber
  ) public {
    vm.assume(_invoicesNumber > 0 && _invoicesNumber <= 250);
    vm.assume(_currentEpoch > 1);
    vm.assume(_liquidity >= _invoicesNumber);
    vm.assume(_destination != 0);
    vm.assume(_tickerHash != 0);

    settler.mockTokenSupportedDomains(_tickerHash, _destination);
    settler.mockDiscountPerEpoch(_tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settler.mockCustodiedAssets(_assetHash, _liquidity);
    settler.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.DEFAULT);
    // mock currentEpoch
    vm.roll(_currentEpoch);

    _expectEmit(address(settler));
    emit ClosedEpochsProcessed(_tickerHash, _currentEpoch - 1);

    settler.processDepositsAndInvoices(_tickerHash, 0, 0, 0);
  }

  /**
   * @notice Test the case where there are no deposits and there is enough liquidity
   */
  function test_NoDeposits_EnoughLiquidity(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    uint32 _destination,
    uint256 _liquidity,
    uint8 _invoicesNumber
  ) public {
    vm.assume(_invoicesNumber > 0 && _invoicesNumber <= 250);
    vm.assume(_liquidity >= _invoicesNumber);
    vm.assume(_destination != 0);
    vm.assume(_tickerHash != 0);
    uint256 _invoiceAmount = _liquidity / _invoicesNumber;

    settler.mockTokenSupportedDomains(_tickerHash, _destination);
    settler.mockDiscountPerEpoch(_tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settler.mockCustodiedAssets(_assetHash, _liquidity);
    settler.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.DEFAULT);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i)),
        owner: keccak256(abi.encode(vm.addr(_i))),
        entryEpoch: 0,
        amount: _invoiceAmount
      });
      settler.mockInvoice(_tickerHash, _invoice);
    }

    uint48 _currentEpoch = settler.getCurrentEpoch();

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      _expectEmit(address(settler));
      emit SettlementEnqueued(
        keccak256(abi.encode(_i)),
        _destination,
        _currentEpoch,
        _assetHash,
        _invoiceAmount,
        false,
        keccak256(abi.encode(vm.addr(_i)))
      );
    }

    settler.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i)));
      assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
    }

    (bytes32 _head, bytes32 _tail,, uint256 _length) = settler.invoices(_tickerHash);
    assertEq(_head, 0, 'invalid head');
    assertEq(_tail, 0, 'invalid tail');
    assertEq(_length, 0, 'invalid length');
  }

  /**
   * @notice Test the case where there are no deposits and there is not enough liquidity
   */
  function test_NoDeposits_NotEnoughLiquidity(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    uint32 _destination,
    uint256 _invoiceAmount,
    uint8 _invoicesNumber
  ) public {
    vm.assume(_invoicesNumber > 0 && _invoicesNumber <= 250);
    vm.assume(_destination != 0);
    vm.assume(_tickerHash != 0);

    settler.mockTokenSupportedDomains(_tickerHash, _destination);
    settler.mockDiscountPerEpoch(_tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settler.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.DEFAULT);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i)),
        owner: keccak256(abi.encode(vm.addr(_i))),
        entryEpoch: 0,
        amount: _invoiceAmount
      });
      settler.mockInvoice(_tickerHash, _invoice);
    }

    (bytes32 _previousHead, bytes32 _previoustail, uint256 _previousNonce, uint256 _previouslength) =
      settler.invoices(_tickerHash);

    settler.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i)));
      // check that the status is the previous one
      assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.NONE), 'invalid status');
    }

    (bytes32 _head, bytes32 _tail, uint256 _nonce, uint256 _length) = settler.invoices(_tickerHash);
    assertEq(_head, _previousHead, 'invalid head');
    assertEq(_tail, _previoustail, 'invalid tail');
    assertEq(_nonce, _previousNonce, 'invalid nonce');
    assertEq(_length, _previouslength, 'invalid length');
  }

  /**
   * @notice Test the case where there are no deposits and there is not enough liquidity and XERC20 is supported
   */
  function test_NoDeposits_NotEnoughLiquidity_XERC20Supported(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    uint32 _destination,
    uint256 _invoiceAmount,
    uint8 _invoicesNumber
  ) public {
    vm.assume(_invoicesNumber > 0 && _invoicesNumber <= 250);
    vm.assume(_destination != 0);
    vm.assume(_tickerHash != 0);

    settler.mockTokenSupportedDomains(_tickerHash, _destination);
    settler.mockDiscountPerEpoch(_tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settler.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.XERC20);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i)),
        owner: keccak256(abi.encode(vm.addr(_i))),
        entryEpoch: 0,
        amount: _invoiceAmount
      });
      settler.mockInvoice(_tickerHash, _invoice);
    }

    uint48 _currentEpoch = settler.getCurrentEpoch();

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      _expectEmit(address(settler));
      emit SettlementEnqueued(
        keccak256(abi.encode(_i)),
        _destination,
        _currentEpoch,
        _assetHash,
        _invoiceAmount,
        false,
        keccak256(abi.encode(vm.addr(_i)))
      );
    }

    settler.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i)));
      // check that the status is the previous one
      assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
    }

    (bytes32 _head, bytes32 _tail,, uint256 _length) = settler.invoices(_tickerHash);
    assertEq(_head, 0, 'invalid head');
    assertEq(_tail, 0, 'invalid tail');
    assertEq(_length, 0, 'invalid length');
  }

  /**
   * @notice Test the case where there are no deposits and there is half of the liquidity required to fill invoices
   */
  function test_NoDeposits_HalfLiquidity(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    uint32 _destination,
    uint256 _liquidity,
    uint8 _invoicesNumber
  ) public {
    vm.assume(_invoicesNumber >= 2 && _invoicesNumber <= 250 && _invoicesNumber % 2 == 0);
    vm.assume(_liquidity >= _invoicesNumber && _liquidity % 2 == 0);
    vm.assume(_destination != 0);
    vm.assume(_tickerHash != 0);
    uint256 _invoiceAmount = _liquidity / _invoicesNumber;

    settler.mockTokenSupportedDomains(_tickerHash, _destination);
    settler.mockDiscountPerEpoch(_tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settler.mockCustodiedAssets(_assetHash, _liquidity / 2);
    settler.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.DEFAULT);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i)),
        owner: keccak256(abi.encode(vm.addr(_i))),
        entryEpoch: 0,
        amount: _invoiceAmount
      });
      settler.mockInvoice(_tickerHash, _invoice);
    }

    uint48 _currentEpoch = settler.getCurrentEpoch();

    for (uint256 _i = 1; _i <= _invoicesNumber / 2; _i++) {
      _expectEmit(address(settler));
      emit SettlementEnqueued(
        keccak256(abi.encode(_i)),
        _destination,
        _currentEpoch,
        _assetHash,
        _invoiceAmount,
        false,
        keccak256(abi.encode(vm.addr(_i)))
      );
    }

    settler.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _invoicesNumber / 2; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i)));
      assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
    }

    (bytes32 _head, bytes32 _tail,, uint256 _length) = settler.invoices(_tickerHash);
    assertTrue(_length <= _invoicesNumber / 2, 'invalid length');
  }

  /**
   * @notice Test the case where there are no deposits and even invoices are settled
   */
  function test_NoDeposits_IntercalatedEvenInvoicesSettled(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    uint32 _destination,
    uint256 _liquidity,
    uint8 _invoicesNumber
  ) public {
    vm.assume(_invoicesNumber >= 2 && _invoicesNumber <= 250 && _invoicesNumber % 2 == 0);
    vm.assume(_liquidity >= _invoicesNumber);
    vm.assume(_destination != 0);
    vm.assume(_tickerHash != 0);
    uint256 _invoiceAmount = _liquidity / _invoicesNumber;

    settler.mockTokenSupportedDomains(_tickerHash, _destination);
    settler.mockDiscountPerEpoch(_tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settler.mockCustodiedAssets(_assetHash, _liquidity / 2);
    settler.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.DEFAULT);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i)),
        owner: keccak256(abi.encode(vm.addr(_i))),
        entryEpoch: 0,
        amount: _i % 2 == 0 ? _invoiceAmount : type(uint256).max
      });
      settler.mockInvoice(_tickerHash, _invoice);
    }

    uint48 _currentEpoch = settler.getCurrentEpoch();

    for (uint256 _i = 1; _i <= _invoicesNumber / 2; _i++) {
      if (_i % 2 == 0) {
        _expectEmit(address(settler));
        emit SettlementEnqueued(
          keccak256(abi.encode(_i)),
          _destination,
          _currentEpoch,
          _assetHash,
          _invoiceAmount,
          false,
          keccak256(abi.encode(vm.addr(_i)))
        );
      }
    }

    settler.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _invoicesNumber / 2; _i++) {
      if (_i % 2 == 0) {
        IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i)));
        assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
      }
    }

    (bytes32 _head, bytes32 _tail,, uint256 _length) = settler.invoices(_tickerHash);
    assertTrue(_length <= _invoicesNumber / 2, 'invalid length');
  }

  /**
   * @notice Test the case where there are no deposits and odd invoices are settled
   */
  function test_NoDeposits_IntercalatedOddInvoicesSettled(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    uint32 _destination,
    uint256 _liquidity,
    uint8 _invoicesNumber
  ) public {
    vm.assume(_invoicesNumber >= 2 && _invoicesNumber <= 250 && _invoicesNumber % 2 == 0);
    vm.assume(_liquidity >= _invoicesNumber);
    vm.assume(_destination != 0);
    vm.assume(_tickerHash != 0);
    uint256 _invoiceAmount = _liquidity / _invoicesNumber;

    settler.mockTokenSupportedDomains(_tickerHash, _destination);
    settler.mockDiscountPerEpoch(_tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settler.mockCustodiedAssets(_assetHash, _liquidity / 2);
    settler.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.DEFAULT);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i)),
        owner: keccak256(abi.encode(vm.addr(_i))),
        entryEpoch: 0,
        amount: _i % 2 == 0 ? type(uint256).max : _invoiceAmount
      });
      settler.mockInvoice(_tickerHash, _invoice);
    }

    uint48 _currentEpoch = settler.getCurrentEpoch();

    for (uint256 _i = 1; _i <= _invoicesNumber / 2; _i++) {
      if (_i % 2 != 0) {
        _expectEmit(address(settler));
        emit SettlementEnqueued(
          keccak256(abi.encode(_i)),
          _destination,
          _currentEpoch,
          _assetHash,
          _invoiceAmount,
          false,
          keccak256(abi.encode(vm.addr(_i)))
        );
      }
    }

    settler.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _invoicesNumber / 2; _i++) {
      if (_i % 2 != 0) {
        IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i)));
        assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
      }
    }

    (bytes32 _head, bytes32 _tail,, uint256 _length) = settler.invoices(_tickerHash);
    assertTrue(_length <= _invoicesNumber / 2, 'invalid length');
  }

  /**
   * @notice Test the case where there are deposits and there is enough liquidity and no discount is applied
   */
  function test_DepositsAvailable_EnoughLiquidity_NoDiscount(
    bytes32 _tickerHash,
    bytes32 _assetHash,
    uint32 _destination,
    uint256 _liquidity,
    uint8 _invoicesNumber
  ) public {
    vm.assume(_invoicesNumber > 0 && _invoicesNumber <= 250);
    vm.assume(_liquidity >= _invoicesNumber);
    vm.assume(_destination != 0);
    vm.assume(_tickerHash != 0);
    uint256 _invoiceAmount = _liquidity / _invoicesNumber;
    vm.assume(type(uint256).max / _invoiceAmount >= Constants.DBPS_DENOMINATOR);

    settler.mockTokenSupportedDomains(_tickerHash, _destination);
    settler.mockDiscountPerEpoch(_tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_tickerHash, _destination, _assetHash);
    settler.mockCustodiedAssets(_assetHash, _liquidity);
    settler.mockDepositsAvailableInEpoch(settler.getCurrentEpoch(), _destination, _tickerHash, _liquidity);
    settler.mockAssetHashStrategy(_assetHash, IEverclear.Strategy.DEFAULT);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i, 'invoice')),
        owner: keccak256(abi.encode(vm.addr(_i))),
        entryEpoch: 1,
        amount: _invoiceAmount
      });
      settler.mockInvoice(_tickerHash, _invoice);
    }

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.Deposit memory _deposit =
        IHubStorage.Deposit({intentId: keccak256(abi.encode(_i, 'deposit')), purchasePower: _invoiceAmount});
      settler.mockDeposit(settler.getCurrentEpoch(), _destination, _tickerHash, _deposit);
    }

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      _expectEmit(address(settler));
      emit SettlementEnqueued(
        keccak256(abi.encode(_i, 'invoice')),
        _destination,
        settler.getCurrentEpoch(),
        _assetHash,
        _invoiceAmount,
        false,
        keccak256(abi.encode(vm.addr(_i)))
      );
    }

    settler.processDepositsAndInvoices(_tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _invoicesNumber; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i, 'invoice')));
      assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
    }

    (bytes32 _head, bytes32 _tail,, uint256 _length) = settler.invoices(_tickerHash);
    assertEq(_head, 0, 'invalid head');
    assertEq(_tail, 0, 'invalid tail');
    assertEq(_length, 0, 'invalid length');

    (uint256 _first, uint256 _last, uint256 _firstDepositWithPurchasePower) =
      settler.deposits(settler.getCurrentEpoch(), _destination, _tickerHash);
    assertEq(_first, 1, 'invalid first');
    assertEq(_last, _invoicesNumber, 'invalid last');
    assertEq(_firstDepositWithPurchasePower, _invoicesNumber + 1, 'invalid first deposit with purchase power');
  }

  struct ProcessDepositsAndInvoicesTestParams {
    bytes32 tickerHash;
    bytes32 assetHash;
    uint32 destination;
    uint64 liquidity;
    uint8 invoicesNumber;
  }

  /**
   * @notice Test the case where there are deposits and there is enough liquidity and discount is applied
   */
  function test_DepositsAvailable_EnoughLiquidity_DiscountOfOneEpoch(
    ProcessDepositsAndInvoicesTestParams memory _params
  ) public {
    vm.assume(_params.invoicesNumber > 0 && _params.invoicesNumber <= 250);
    vm.assume(_params.liquidity >= _params.invoicesNumber);
    vm.assume(_params.destination != 0);
    vm.assume(_params.tickerHash != 0);
    uint256 _invoiceAmount = _params.liquidity / _params.invoicesNumber;
    vm.assume(type(uint256).max / _invoiceAmount >= Constants.DBPS_DENOMINATOR);

    settler.mockTokenSupportedDomains(_params.tickerHash, _params.destination);
    settler.mockDiscountPerEpoch(_params.tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.destination, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockDepositsAvailableInEpoch(
      settler.getCurrentEpoch(), _params.destination, _params.tickerHash, _params.liquidity
    );
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.DEFAULT);

    (uint256 _amountAfterDiscount, uint256 _amountToBeDiscounted,) = settler.getDiscountedAmount(
      _params.tickerHash, 5000, _params.destination, settler.getCurrentEpoch(), _invoiceAmount
    );

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i, 'invoice')),
        owner: keccak256(abi.encode(vm.addr(_i))),
        entryEpoch: 0,
        amount: _invoiceAmount
      });
      settler.mockInvoice(_params.tickerHash, _invoice);
    }

    uint48 _currentEpoch = settler.getCurrentEpoch();

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      IHubStorage.Deposit memory _deposit =
        IHubStorage.Deposit({intentId: keccak256(abi.encode(_i, 'deposit')), purchasePower: _invoiceAmount});
      settler.mockDeposit(_currentEpoch, _params.destination, _params.tickerHash, _deposit);
    }

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      _expectEmit(address(settler));
      emit SettlementEnqueued(
        keccak256(abi.encode(_i, 'invoice')),
        _params.destination,
        _currentEpoch,
        _params.assetHash,
        _amountAfterDiscount,
        false,
        keccak256(abi.encode(vm.addr(_i)))
      );
    }

    settler.processDepositsAndInvoices(_params.tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i, 'invoice')));
      assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
    }

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i, 'deposit')));
      // loss of precision here if the amounts are too small or even odd numbers
      assertTrue(_context.pendingRewards <= _amountToBeDiscounted, 'invalid pending rewards');
    }

    (bytes32 _head, bytes32 _tail,, uint256 _length) = settler.invoices(_params.tickerHash);
    assertEq(_head, 0, 'invalid head');
    assertEq(_tail, 0, 'invalid tail');
    assertEq(_length, 0, 'invalid length');

    (uint256 _first, uint256 _last, uint256 _firstDepositWithPurchasePower) =
      settler.deposits(settler.getCurrentEpoch(), _params.destination, _params.tickerHash);
    assertEq(_first, 1, 'invalid first');
    assertEq(_last, _params.invoicesNumber, 'invalid last');
    uint256 _liquidityUsed = _params.invoicesNumber * _amountAfterDiscount;
    assertEq(settler.custodiedAssets(_params.assetHash), _params.liquidity - _liquidityUsed, 'invalid custodied assets');
    uint256 _depositsUsed = _liquidityUsed / _invoiceAmount;
    assertEq(_firstDepositWithPurchasePower, _depositsUsed + 1, 'invalid first deposit with purchase power');
  }

  /**
   * @notice Test the case where there are deposits and there is half liquidity to settle half of invoices and discount is applied
   */
  function test_DepositsAvailable_HalfDepositsLiquidity_DiscountOfOneEpoch(
    ProcessDepositsAndInvoicesTestParams memory _params
  ) public {
    vm.assume(_params.invoicesNumber > 0 && _params.invoicesNumber <= 250 && _params.invoicesNumber % 2 == 0);
    vm.assume(_params.liquidity >= _params.invoicesNumber);
    vm.assume(_params.destination != 0);
    vm.assume(_params.tickerHash != 0);
    uint256 _invoiceAmount = _params.liquidity / _params.invoicesNumber;
    vm.assume(type(uint256).max / _invoiceAmount >= Constants.DBPS_DENOMINATOR);

    settler.mockTokenSupportedDomains(_params.tickerHash, _params.destination);
    settler.mockDiscountPerEpoch(_params.tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.destination, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockDepositsAvailableInEpoch(
      settler.getCurrentEpoch(), _params.destination, _params.tickerHash, _params.liquidity
    );
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.DEFAULT);

    (uint256 _amountAfterDiscount, uint256 _amountToBeDiscounted,) = settler.getDiscountedAmount(
      _params.tickerHash, 5000, _params.destination, settler.getCurrentEpoch(), _invoiceAmount
    );

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i, 'invoice')),
        owner: keccak256(abi.encode(vm.addr(_i))),
        entryEpoch: 0,
        amount: _invoiceAmount
      });
      settler.mockInvoice(_params.tickerHash, _invoice);
    }

    for (uint256 _i = 1; _i <= _params.invoicesNumber / 2; _i++) {
      IHubStorage.Deposit memory _deposit =
        IHubStorage.Deposit({intentId: keccak256(abi.encode(_i, 'deposit')), purchasePower: _invoiceAmount});
      settler.mockDeposit(settler.getCurrentEpoch(), _params.destination, _params.tickerHash, _deposit);
    }

    uint48 _currentEpoch = settler.getCurrentEpoch();

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      _expectEmit(address(settler));
      emit SettlementEnqueued(
        keccak256(abi.encode(_i, 'invoice')),
        _params.destination,
        _currentEpoch,
        _params.assetHash,
        _amountAfterDiscount,
        false,
        keccak256(abi.encode(vm.addr(_i)))
      );
    }

    settler.processDepositsAndInvoices(_params.tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i, 'invoice')));
      assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
    }

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i, 'deposit')));
      // loss of precision here if the amounts are too small or even odd numbers
      assertTrue(_context.pendingRewards <= _amountToBeDiscounted, 'invalid pending rewards');
    }

    (bytes32 _head, bytes32 _tail,, uint256 _length) = settler.invoices(_params.tickerHash);
    assertEq(_head, 0, 'invalid head');
    assertEq(_tail, 0, 'invalid tail');
    assertEq(_length, 0, 'invalid length');

    (uint256 _first, uint256 _last,) =
      settler.deposits(settler.getCurrentEpoch(), _params.destination, _params.tickerHash);
    assertEq(_first, 1, 'invalid first');
    assertEq(_last, _params.invoicesNumber / 2, 'invalid last');

    // TODO: complete the assertions
    /*
    uint256 _liquidityUsed =_params.invoicesNumber /2 * _amountAfterDiscount + (_params.invoicesNumber / 2 * _invoiceAmount);
    assertEq(settler.custodiedAssets(_params.assetHash), _params.liquidity - _liquidityUsed, 'invalid custodied assets');
    uint256 _depositsUsed = _liquidityUsed / _invoiceAmount;
    assertEq(_firstDepositWithPurchasePower, _depositsUsed + 1, 'invalid first deposit with purchase power');*/
  }

  /**
   * @notice Test the case where there are deposits and there is enough liquidity and discount is applied, and deposits fill partially
   */
  function test_DepositsAvailable_PartialFill_EnoughLiquidity_DiscountOfOneEpoch(
    ProcessDepositsAndInvoicesTestParams memory _params
  ) public {
    vm.assume(_params.invoicesNumber > 0 && _params.invoicesNumber <= 250);
    vm.assume(_params.liquidity >= _params.invoicesNumber);
    vm.assume(_params.destination != 0);
    vm.assume(_params.tickerHash != 0);
    uint256 _invoiceAmount = _params.liquidity / _params.invoicesNumber;
    vm.assume(type(uint256).max / _invoiceAmount >= Constants.DBPS_DENOMINATOR && _invoiceAmount % 2 == 0);
    uint256 _depositsNumber = uint256(_params.invoicesNumber) * 2;

    uint256 _amountDiscounted = _invoiceAmount * 5000 / Constants.DBPS_DENOMINATOR;
    uint256 _amountAfterDiscount = _invoiceAmount - _amountDiscounted;

    settler.mockTokenSupportedDomains(_params.tickerHash, _params.destination);
    settler.mockDiscountPerEpoch(_params.tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.destination, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockDepositsAvailableInEpoch(
      settler.getCurrentEpoch(), _params.destination, _params.tickerHash, _params.liquidity
    );
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.DEFAULT);

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      IHubStorage.Invoice memory _invoice = IHubStorage.Invoice({
        intentId: keccak256(abi.encode(_i, 'invoice')),
        owner: keccak256(abi.encode(vm.addr(_i))),
        entryEpoch: 0,
        amount: _invoiceAmount
      });
      settler.mockInvoice(_params.tickerHash, _invoice);
    }

    for (uint256 _i = 1; _i <= _depositsNumber; _i++) {
      IHubStorage.Deposit memory _deposit =
        IHubStorage.Deposit({intentId: keccak256(abi.encode(_i, 'deposit')), purchasePower: _invoiceAmount / 2});
      settler.mockDeposit(settler.getCurrentEpoch(), _params.destination, _params.tickerHash, _deposit);
    }

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      _expectEmit(address(settler));
      emit SettlementEnqueued(
        keccak256(abi.encode(_i, 'invoice')),
        _params.destination,
        settler.getCurrentEpoch(),
        _params.assetHash,
        _amountAfterDiscount,
        false,
        keccak256(abi.encode(vm.addr(_i)))
      );
    }

    settler.processDepositsAndInvoices(_params.tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i, 'invoice')));
      assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
    }

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      IHubStorage.IntentContext memory _context = settler.contexts(keccak256(abi.encode(_i, 'deposit')));
      // loss of precision here if the amounts are too small or even odd numbers
      assertTrue(_context.pendingRewards <= _amountDiscounted, 'invalid pending rewards');
    }

    (bytes32 _head, bytes32 _tail,, uint256 _length) = settler.invoices(_params.tickerHash);
    assertEq(_head, 0, 'invalid head');
    assertEq(_tail, 0, 'invalid tail');
    assertEq(_length, 0, 'invalid length');

    (uint256 _first, uint256 _last, uint256 _firstDepositWithPurchasePower) =
      settler.deposits(settler.getCurrentEpoch(), _params.destination, _params.tickerHash);
    assertEq(_first, 1, 'invalid first');
    assertEq(_last, _depositsNumber, 'invalid last');
    uint256 _liquidityUsed = _params.invoicesNumber * _amountAfterDiscount;
    assertEq(settler.custodiedAssets(_params.assetHash), _params.liquidity - _liquidityUsed, 'invalid custodied assets');
    uint256 _depositsUsed = _liquidityUsed / _invoiceAmount * 2;
    assertTrue(
      _firstDepositWithPurchasePower == _depositsUsed + 1 || _firstDepositWithPurchasePower == _depositsUsed + 2,
      'invalid first deposit with purchase power'
    );
  }

  /**
   * Test case where deposits are cleaned up and there is enough liquidity to settle all deposits
   */
  function test_DepositsCleanUp_EnoughLiquidity(
    ProcessDepositsAndInvoicesTestParams memory _params,
    uint8 _epoch,
    uint8 _epochsElapsed
  ) public {
    vm.assume(_params.invoicesNumber > 2 && _params.invoicesNumber <= 250);
    vm.assume(_params.liquidity >= _params.invoicesNumber);
    vm.assume(_params.destination != 0);
    vm.assume(_params.tickerHash != 0);
    vm.assume(_epochsElapsed > 0 && _epochsElapsed <= 10);
    vm.roll(uint256(_epoch) + _epochsElapsed);
    uint256 _invoiceAmount = _params.liquidity / _params.invoicesNumber;

    settler.mockTokenSupportedDomains(_params.tickerHash, _params.destination);
    settler.mockDiscountPerEpoch(_params.tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.destination, _params.assetHash);
    settler.mockCustodiedAssets(_params.assetHash, _params.liquidity);
    settler.mockDepositsAvailableInEpoch(
      settler.getCurrentEpoch(), _params.destination, _params.tickerHash, _params.liquidity
    );
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.DEFAULT);

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      bytes32 _intentId = keccak256(abi.encode(_i, 'deposit'));
      IHubStorage.Deposit memory _deposit = IHubStorage.Deposit({intentId: _intentId, purchasePower: _invoiceAmount});
      settler.mockDeposit(_epoch, _params.destination, _params.tickerHash, _deposit);
    }

    uint48 _currentEpoch = settler.getCurrentEpoch();
    emit log_named_uint('currentEpoch', _currentEpoch);

    settler.processDepositsAndInvoices(_params.tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      bytes32 _intentId = keccak256(abi.encode(_i, 'deposit'));
      IHubStorage.IntentContext memory _context = settler.contexts(_intentId);
      assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.SETTLED), 'invalid status');
    }

    (uint256 _first, uint256 _last, uint256 _firstDepositWithPurchasePower) =
      settler.deposits(_epoch, _params.destination, _params.tickerHash);
    assertEq(_first, _last + 1, 'Deposits queue not empty');
    assertEq(
      settler.lastClosedEpochsProcessed(_params.tickerHash), _currentEpoch - 1, 'invalid last closed epoch processed'
    );
  }

  /**
   * Test case where deposits are cleaned up and there is not enough liquidity to settle all deposits
   */
  function test_DepositsCleanUp_NotEnoughLiquidity(
    ProcessDepositsAndInvoicesTestParams memory _params,
    uint8 _epoch,
    uint8 _epochsElapsed
  ) public {
    vm.assume(_params.invoicesNumber > 2 && _params.invoicesNumber <= 250);
    vm.assume(_params.destination != 0);
    vm.assume(_params.tickerHash != 0);
    vm.assume(_epochsElapsed > 0 && _epochsElapsed <= 10);
    vm.roll(uint256(_epoch) + _epochsElapsed);
    uint256 _invoiceAmount = _params.liquidity / _params.invoicesNumber;

    settler.mockTokenSupportedDomains(_params.tickerHash, _params.destination);
    settler.mockDiscountPerEpoch(_params.tickerHash, 5000);
    settler.mockAssetMaxDiscountDbps(_params.tickerHash, Constants.DBPS_DENOMINATOR);
    settler.mockEpochLength(1);
    settler.mockTokenConfigAssetHash(_params.tickerHash, _params.destination, _params.assetHash);
    settler.mockDepositsAvailableInEpoch(
      settler.getCurrentEpoch(), _params.destination, _params.tickerHash, _params.liquidity
    );
    settler.mockAssetHashStrategy(_params.assetHash, IEverclear.Strategy.DEFAULT);

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      bytes32 _intentId = keccak256(abi.encode(_i, 'deposit'));
      IHubStorage.Deposit memory _deposit = IHubStorage.Deposit({intentId: _intentId, purchasePower: _invoiceAmount});
      settler.mockDeposit(_epoch, _params.destination, _params.tickerHash, _deposit);
    }

    uint48 _currentEpoch = settler.getCurrentEpoch();

    settler.processDepositsAndInvoices(_params.tickerHash, 0, 0, 0);

    for (uint256 _i = 1; _i <= _params.invoicesNumber; _i++) {
      bytes32 _intentId = keccak256(abi.encode(_i, 'deposit'));
      IHubStorage.IntentContext memory _context = settler.contexts(_intentId);
      assertEq(uint8(_context.status), uint8(IEverclear.IntentStatus.INVOICED), 'invalid status');
    }

    (uint256 _first, uint256 _last, uint256 _firstDepositWithPurchasePower) =
      settler.deposits(_epoch, _params.destination, _params.tickerHash);
    assertEq(_first, _last + 1, 'Deposits queue not empty');
    assertEq(
      settler.lastClosedEpochsProcessed(_params.tickerHash), _currentEpoch - 1, 'invalid last closed epoch processed'
    );
  }
}

contract Unit_ProcessSettlementQueue is BaseTest {
  bytes32 constant _typehash = keccak256(
    'function processQueueViaRelayer(uint32 _domain, uint32 _amount, address _relayer, uint256 _ttl, uint256 _nonce, uint256 _bufferDBPS, bytes calldata _signature)'
  );

  event SettlementQueueProcessed(bytes32 _messageId, uint32 _domain, uint32 _amount, uint256 _quote);

  struct ViaRelayerParams {
    address relayer;
    uint256 ttl;
    uint256 bufferDBPS;
  }

  /**
   * @notice Test the case where the settlement queue is processed
   */
  function test_ProcessSettlementQueue(
    uint32 _domain,
    uint32 _amount,
    address _gateway,
    bytes32 _messageId,
    uint256 _feeSpent
  ) public {
    vm.assume(_amount > 0 && _amount <= 1000);
    settler.mockSupportedDomain(_domain);
    settler.mockSettlements(_domain, _amount);
    settler.mockGateway(_gateway);
    vm.mockCall(
      _gateway, abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)'), abi.encode(_messageId, _feeSpent)
    );

    _expectEmit(address(settler));
    emit SettlementQueueProcessed(_messageId, _domain, _amount, _feeSpent);

    settler.processSettlementQueue(_domain, _amount);
  }

  /**
   * @notice Test the case where the settlement queue is processed and the domain is not supported
   */
  function test_Revert_ProcessSettlementQueue_DomainNotSupported(uint32 _domain, uint32 _amount) public {
    vm.expectRevert(ISettler.Settler_DomainNotSupported.selector);

    settler.processSettlementQueue(_domain, _amount);
  }

  /**
   * @notice Test the case where the settlement queue is processed and there are insufficient settlements
   */
  function test_Revert_ProcessSettlementQueue_InsufficientSettlements(uint32 _domain, uint32 _amount) public {
    // TODO: check why 1 doesn't trigger revert
    vm.assume(_amount > 1);
    settler.mockSupportedDomain(_domain);

    vm.expectRevert(ISettler.Settler_InsufficientSettlements.selector);

    settler.processSettlementQueue(_domain, _amount);
  }

  /**
   * @notice Test the case where the settlement queue is processed and the block gas limit is exceeded
   */
  function test_Revert_ProcessSettlementQueue_BlockGasLimitExceeded(uint32 _domain, uint32 _amount) public {
    vm.assume(_amount > 0 && _amount <= 1000);
    settler.mockSupportedDomain(_domain);
    settler.mockSettlements(_domain, _amount);
    settler.mockGasConfig(
      IHubStorage.GasConfig({settlementBaseGasUnits: 1, averageGasUnitsPerSettlement: 1, bufferDBPS: 1})
    );

    vm.expectRevert(abi.encodeWithSelector(ISettler.Settler_DomainBlockGasLimitReached.selector, 0, 1 + _amount));

    settler.processSettlementQueue(_domain, _amount);
  }

  /**
   * @notice Test the case where the settlement queue is processed via relayer
   */
  function test_ProcessSettlementQueueViaRelayer(
    uint32 _domain,
    uint32 _amount,
    address _gateway,
    bytes32 _messageId,
    uint256 _feeSpent,
    ViaRelayerParams memory _params
  ) public {
    assumeNotPrecompile(_params.relayer);
    assumeNotPrecompile(_gateway);
    vm.assume(_amount > 0 && _amount <= 1000);

    (address _lighthouse, uint256 _lighthouseKey) = makeAddrAndKey('LIGHTHOUSE');
    bytes memory _data = abi.encode(_typehash, _domain, _amount, _params.relayer, _params.ttl, 0, _params.bufferDBPS);
    (bytes memory _signature,) = _createSignature(_lighthouseKey, keccak256(_data));

    settler.mockSupportedDomain(_domain);
    settler.mockSettlements(_domain, _amount);
    settler.mockGateway(_gateway);
    settler.mockLighthouse(_lighthouse);

    vm.mockCall(_gateway, abi.encodeWithSignature('quoteMessage(uint32,bytes,uint256)'), abi.encode(1));
    vm.mockCall(
      _gateway, abi.encodeWithSignature('sendMessage(uint32,bytes,uint256,uint256)'), abi.encode(_messageId, _feeSpent)
    );

    _expectEmit(address(settler));
    emit SettlementQueueProcessed(_messageId, _domain, _amount, _feeSpent);

    settler.processSettlementQueueViaRelayer(
      _domain, _amount, _params.relayer, _params.ttl, 0, _params.bufferDBPS, _signature
    );
  }

  /**
   * @notice Test the case where the settlement queue is processed via relayer and the domain is not supported
   */
  function test_Revert_ProcessSettlementQueueViaRelayer_InvalidSignature(
    uint32 _domain,
    uint32 _amount,
    address _gateway,
    bytes32 _messageId,
    uint256 _feeSpent,
    ViaRelayerParams memory _params
  ) public {
    vm.assume(_amount > 0 && _amount <= 1000);
    (address _lighthouse, uint256 _lighthouseKey) = makeAddrAndKey('LIGHTHOUSE');
    bytes memory _data = abi.encode(_typehash, _domain, _amount, _lighthouse, _params.ttl, 0, _params.bufferDBPS);
    (bytes memory _signature,) = _createSignature(_lighthouseKey, keccak256(_data));
    settler.mockSupportedDomain(_domain);
    settler.mockSettlements(_domain, _amount);
    settler.mockGateway(_gateway);
    settler.mockLighthouse(_lighthouse);
    vm.mockCall(_gateway, abi.encodeWithSignature('sendMessage(uint32,bytes)'), abi.encode(_messageId, _feeSpent));

    vm.expectRevert(IHubStorage.HubStorage_InvalidSignature.selector);

    settler.processSettlementQueueViaRelayer(
      _domain, _amount, _params.relayer, _params.ttl, 0, _params.bufferDBPS, _signature
    );
  }
}
