// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Constants} from 'contracts/common/Constants.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';

import {TestExtended} from '../../utils/TestExtended.sol';
import {StdStorage, stdStorage} from 'test/utils/TestExtended.sol';

import {AssetManager, IAssetManager} from 'contracts/hub/modules/managers/AssetManager.sol';
import {IProtocolManager, ProtocolManager} from 'contracts/hub/modules/managers/ProtocolManager.sol';

import {HubGateway, IHubGateway} from 'contracts/hub/HubGateway.sol';

import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {Deploy} from 'utils/Deploy.sol';

contract TestAssetManager is AssetManager, ProtocolManager {
  constructor(address __owner, address __admin, address __hubGateway, address __lighthouse) {
    // Set the internal state vars for tests, these are set in the constructor of the HubStorage originally
    owner = __owner;
    roles[__admin] = IHubStorage.Role.ADMIN;
    hubGateway = IHubGateway(__hubGateway);
    lighthouse = __lighthouse;
  }

  function prioritizedStrategy(
    bytes32 _tickerHash
  ) external view returns (IEverclear.Strategy _prioritizedStrategy) {
    return _tokenConfigs[_tickerHash].prioritizedStrategy;
  }

  function _mockTokenMaxDiscountDbps(bytes32 _tickerHash, uint24 _maxDiscountDbps) external {
    _tokenConfigs[_tickerHash].maxDiscountDbps = _maxDiscountDbps;
  }
}

contract BaseTest is TestExtended {
  using stdStorage for StdStorage;

  TestAssetManager internal assetManager;
  IHubGateway internal hubGateway;

  address immutable DEPLOYER = makeAddr('DEPLOYER');
  address immutable OWNER = makeAddr('OWNER');
  address immutable ADMIN = makeAddr('ADMIN');

  address immutable HUB_MAILBOX = makeAddr('HUB_MAILBOX');
  address immutable INTERCHAIN_SECURITY_MODULE = makeAddr('INTERCHAIN_SECURITY_MODULE');
  address immutable LIGHTHOUSE = makeAddr('LIGHTHOUSE');

  function setUp() public {
    vm.startPrank(DEPLOYER);

    address _predictedHubGateway = _addressFrom(DEPLOYER, 2);
    assetManager = new TestAssetManager(OWNER, ADMIN, _predictedHubGateway, LIGHTHOUSE);

    hubGateway = Deploy.HubGatewayProxy(OWNER, HUB_MAILBOX, address(assetManager), INTERCHAIN_SECURITY_MODULE);
    vm.stopPrank();

    assertEq(_predictedHubGateway, address(hubGateway));
  }

  function _mockRole(address _account, IHubStorage.Role _role) internal {
    stdstore.target(address(assetManager)).sig(IHubStorage.roles.selector).with_key(_account).checked_write(
      uint8(_role)
    );
  }

  function _mockMaxDiscountDbps(bytes32 _tickerHash, uint24 _maxDiscountDbps) internal {
    TestAssetManager(address(assetManager))._mockTokenMaxDiscountDbps(_tickerHash, _maxDiscountDbps);
  }
}

contract Unit_SetAssetConfig is BaseTest {
  event AssetConfigSet(IHubStorage.AssetConfig _config);

  /**
   * @notice Test set asset config
   */
  function test_SetAssetConfig(
    address _caller,
    bytes32 _tickerHash,
    bytes32 _adopted,
    uint32 _domain,
    bool _approval,
    uint8 _strategySeed
  ) public {
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    IEverclear.Strategy _strategy = IEverclear.Strategy(bound(_strategySeed, 0, uint256(type(IEverclear.Strategy).max)));

    IHubStorage.AssetConfig memory _newAssetConfig =
      IHubStorage.AssetConfig(_tickerHash, _adopted, _domain, _approval, _strategy);

    bytes32 _assetHash = keccak256(abi.encode(_newAssetConfig.adopted, _newAssetConfig.domain));

    _expectEmit(address(assetManager));
    emit AssetConfigSet(_newAssetConfig);

    vm.prank(_caller);
    assetManager.setAdoptedForAsset(_newAssetConfig);

    IHubStorage.AssetConfig memory _config = assetManager.adoptedForAssets(_assetHash);

    assertEq(_config.tickerHash, _newAssetConfig.tickerHash, 'ticker hash not set correctly');
    assertEq(_config.adopted, _newAssetConfig.adopted, 'adopted not set correctly');
    assertEq(_config.domain, _newAssetConfig.domain, 'domain not set correctly');
    assertEq(_config.approval, _newAssetConfig.approval, 'approval not set correctly');
  }

  /**
   * @notice Test set asset config and overwrite previous config and set the new config
   */
  function test_SetAssetConfig_OverwritePreviousConfig(
    address _caller,
    bytes32 _tickerHash,
    bytes32 _adopted,
    uint32 _domain,
    bool _approval,
    uint8 _strategySeed,
    bytes32 _tickerHash2,
    bytes32 _adopted2,
    uint32 _domain2,
    bool _approval2,
    uint8 _strategySeed2
  ) public {
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    IHubStorage.AssetConfig memory _previousAssetConfig = IHubStorage.AssetConfig(
      _tickerHash,
      _adopted,
      _domain,
      _approval,
      IEverclear.Strategy(bound(_strategySeed, 0, uint256(type(IEverclear.Strategy).max)))
    );

    IHubStorage.AssetConfig memory _newAssetConfig = IHubStorage.AssetConfig(
      _tickerHash2,
      _adopted2,
      _domain2,
      _approval2,
      IEverclear.Strategy(bound(_strategySeed2, 0, uint256(type(IEverclear.Strategy).max)))
    );

    bytes32 _assetHash = keccak256(abi.encode(_newAssetConfig.adopted, _newAssetConfig.domain));

    vm.prank(_caller);
    assetManager.setAdoptedForAsset(_previousAssetConfig);

    _expectEmit(address(assetManager));
    emit AssetConfigSet(_newAssetConfig);

    vm.prank(_caller);
    assetManager.setAdoptedForAsset(_newAssetConfig);

    IHubStorage.AssetConfig memory _config = assetManager.adoptedForAssets(_assetHash);

    assertEq(_config.tickerHash, _newAssetConfig.tickerHash, 'ticker hash not set correctly');
    assertEq(_config.adopted, _newAssetConfig.adopted, 'adopted not set correctly');
    assertEq(_config.domain, _newAssetConfig.domain, 'domain not set correctly');
    assertEq(_config.approval, _newAssetConfig.approval, 'approval not set correctly');
  }

  /**
   * @notice Test that when setting the asset config it reverts if the caller is not the asset manager
   */
  function test_Revert_SetAssetConfigNotAssetManager(
    address _caller,
    bytes32 _tickerHash,
    bytes32 _adopted,
    uint32 _domain,
    bool _approval,
    uint8 _strategySeed
  ) public {
    vm.assume(_caller != assetManager.owner());
    IEverclear.Strategy _strategy = IEverclear.Strategy(bound(_strategySeed, 0, uint256(type(IEverclear.Strategy).max)));

    IHubStorage.AssetConfig memory _newAssetConfig =
      IHubStorage.AssetConfig(_tickerHash, _adopted, _domain, _approval, _strategy);

    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);

    vm.prank(_caller);
    assetManager.setAdoptedForAsset(_newAssetConfig);
  }
}

contract Unit_SetTokenConfigs is BaseTest {
  using TypeCasts for address;

  event TokenConfigsSet(IHubStorage.TokenSetup[] _configs);

  function _generateConfigs(
    IHubStorage.TokenSetup[] memory _configs,
    uint8 _adoptedForAssetsNumber,
    uint8 _feesNumber
  ) internal {
    for (uint8 _i; _i < _configs.length; _i++) {
      _configs[_i].tickerHash = keccak256(abi.encode(1));
      _configs[_i].fees = new IHubStorage.Fee[](_feesNumber);
      _configs[_i].adoptedForAssets = new IHubStorage.AssetConfig[](_adoptedForAssetsNumber);

      for (uint8 _j; _j < _feesNumber; _j++) {
        _configs[_i].fees[_j] = IHubStorage.Fee({recipient: vm.addr(_j + 1), fee: _j + 2});
      }

      for (uint8 _j; _j < _adoptedForAssetsNumber; _j++) {
        _configs[_i].adoptedForAssets[_j] = IHubStorage.AssetConfig({
          tickerHash: _configs[_i].tickerHash,
          adopted: vm.addr(_j + 1).toBytes32(),
          domain: _j,
          approval: _j % 2 == 0,
          strategy: IEverclear.Strategy.DEFAULT
        });
      }
    }
  }

  /**
   * @notice Test set token configs for multiple tokens with multiple asset configs and fees
   */
  function test_SetTokenConfigs(
    address _caller,
    uint8 _configsNumber,
    uint8 _adoptedForAssetsNumber,
    uint8 _feesNumber
  ) public {
    _configsNumber = uint8(bound(uint256(_configsNumber), 1, MAX_FUZZED_ARRAY_LENGTH));
    _adoptedForAssetsNumber = uint8(bound(uint256(_configsNumber), 1, MAX_FUZZED_ARRAY_LENGTH));
    _feesNumber = uint8(bound(uint256(_configsNumber), 1, MAX_FUZZED_ARRAY_LENGTH));
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    IHubStorage.TokenSetup[] memory _configs = new IHubStorage.TokenSetup[](_configsNumber);
    _generateConfigs(_configs, _adoptedForAssetsNumber, _feesNumber);

    _expectEmit(address(assetManager));
    emit TokenConfigsSet(_configs);

    vm.prank(_caller);
    assetManager.setTokenConfigs(_configs);

    for (uint8 _i; _i < _configsNumber; _i++) {
      bytes32 _tickerHash = _configs[_i].tickerHash;
      IHubStorage.Fee[] memory _fees = assetManager.tokenFees(_tickerHash);

      assertEq(_fees.length, _feesNumber, 'fees length not set correctly');

      for (uint8 _j; _j < _feesNumber; _j++) {
        assertEq(_fees[_j].recipient, _configs[_i].fees[_j].recipient, 'recipient not set correctly');
        assertEq(_fees[_j].fee, _configs[_i].fees[_j].fee, 'fee not set correctly');
      }

      IHubStorage.AssetConfig[] memory _adoptedForAssets = _configs[_i].adoptedForAssets;
      for (uint8 _j; _j < _adoptedForAssets.length; _j++) {
        bytes32 _assetHash =
          keccak256(abi.encode(_configs[_i].adoptedForAssets[_j].adopted, _configs[_i].adoptedForAssets[_j].domain));

        assertEq(
          assetManager.assetHash(_tickerHash, _configs[_i].adoptedForAssets[_j].domain),
          _assetHash,
          'asset hash not set correctly'
        );
        IHubStorage.AssetConfig memory _assetConfig = assetManager.adoptedForAssets(_assetHash);

        assertEq(_assetConfig.tickerHash, _tickerHash, 'ticker hash not set correctly');
        assertEq(_assetConfig.adopted, _adoptedForAssets[_j].adopted, 'adopted not set correctly');
        assertEq(_assetConfig.domain, _adoptedForAssets[_j].domain, 'domain not set correctly');
        assertEq(_assetConfig.approval, _adoptedForAssets[_j].approval, 'approval not set correctly');
        assertEq(uint256(_assetConfig.strategy), uint256(_adoptedForAssets[_j].strategy), 'strategy not set correctly');
      }
    }
  }

  /**
   * @notice Test set token configs fields with the default strategy
   * @dev The default strategy is the strategy with the value 0
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker symbol
   * @param _maxDiscountDbps The maximum discount in basis points
   * @param _discountPerEpoch The discount per epoch in basis points
   */
  function test_SetTokenConfigFieldsDefaultStrategy(
    address _caller,
    bytes32 _tickerHash,
    uint24 _maxDiscountDbps,
    uint24 _discountPerEpoch
  ) public {
    vm.assume(_maxDiscountDbps <= Constants.DBPS_DENOMINATOR && _discountPerEpoch <= _maxDiscountDbps);
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);
    IHubStorage.TokenSetup[] memory _configs = new IHubStorage.TokenSetup[](1);
    _configs[0].tickerHash = _tickerHash;
    _configs[0].prioritizedStrategy = IEverclear.Strategy.DEFAULT;
    _configs[0].maxDiscountDbps = _maxDiscountDbps;
    _configs[0].discountPerEpoch = _discountPerEpoch;

    _expectEmit(address(assetManager));
    emit TokenConfigsSet(_configs);

    vm.prank(_caller);
    assetManager.setTokenConfigs(_configs);
    (uint24 _retMaxDiscountDbps, uint24 _retDiscountPerEpoch, IEverclear.Strategy _retPrioritizedStrategy) =
      assetManager.tokenConfigs(_tickerHash);
    assertEq(_retMaxDiscountDbps, _maxDiscountDbps, 'max discount dbps not set correctly');
    assertEq(_retDiscountPerEpoch, _discountPerEpoch, 'discount per epoch not set correctly');
    assertEq(
      uint8(_retPrioritizedStrategy), uint8(IEverclear.Strategy.DEFAULT), 'prioritized strategy not set correctly'
    );
  }

  /**
   * @notice Test set token configs fields with the xerc20 strategy
   * @dev The default strategy is the strategy with the value 0
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker symbol
   * @param _maxDiscountDbps The maximum discount in basis points
   * @param _discountPerEpoch The discount per epoch in basis points
   */
  function test_SetTokenConfigFieldsXERC20Strategy(
    address _caller,
    bytes32 _tickerHash,
    uint24 _maxDiscountDbps,
    uint24 _discountPerEpoch
  ) public {
    vm.assume(_maxDiscountDbps <= Constants.DBPS_DENOMINATOR && _discountPerEpoch <= _maxDiscountDbps);
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);
    IHubStorage.TokenSetup[] memory _configs = new IHubStorage.TokenSetup[](1);
    _configs[0].tickerHash = _tickerHash;
    _configs[0].prioritizedStrategy = IEverclear.Strategy.XERC20;
    _configs[0].maxDiscountDbps = _maxDiscountDbps;
    _configs[0].discountPerEpoch = _discountPerEpoch;

    _expectEmit(address(assetManager));
    emit TokenConfigsSet(_configs);

    vm.prank(_caller);
    assetManager.setTokenConfigs(_configs);
    (uint24 _retMaxDiscountDbps, uint24 _retDiscountPerEpoch, IEverclear.Strategy _retPrioritizedStrategy) =
      assetManager.tokenConfigs(_tickerHash);
    assertEq(_retMaxDiscountDbps, _maxDiscountDbps, 'max discount dbps not set correctly');
    assertEq(_retDiscountPerEpoch, _discountPerEpoch, 'discount per epoch not set correctly');
    assertEq(
      uint8(_retPrioritizedStrategy), uint8(IEverclear.Strategy.XERC20), 'prioritized strategy not set correctly'
    );
  }

  /**
   * @notice Test set token configs reverts if the caller is not the asset manager
   */
  function test_Revert_SetTokenConfigsNotAssetManager(address _caller, uint8 _configsNumber) public {
    vm.assume(_caller != assetManager.owner());
    IHubStorage.TokenSetup[] memory _configs = new IHubStorage.TokenSetup[](_configsNumber);

    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);

    vm.prank(_caller);
    assetManager.setTokenConfigs(_configs);
  }

  /**
   * @notice Test set token configs reverts if the ticker hash has a mismatch
   */
  function test_Revert_SetTokenConfigs_TickerHashMismatch(
    address _caller
  ) public {
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    IHubStorage.TokenSetup[] memory _configs = new IHubStorage.TokenSetup[](1);
    _generateConfigs(_configs, 1, 1);

    _configs[0].adoptedForAssets[0].tickerHash = keccak256(abi.encode(2));

    vm.expectRevert(IAssetManager.AssetManager_SetTokenConfigs_TickerHashMismatch.selector);

    vm.prank(_caller);
    assetManager.setTokenConfigs(_configs);
  }

  /**
   * @notice Test set token configs reverts if discount per epoch is greater than max discount dbps
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker symbol
   * @param _maxDiscountDbps The maximum discount in basis points
   * @param _discountPerEpoch The discount per epoch in basis points
   */
  function test_Revert_DiscountPerEpochGreaterThanMaxDiscountDbps(
    address _caller,
    bytes32 _tickerHash,
    uint24 _maxDiscountDbps,
    uint24 _discountPerEpoch
  ) public {
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    vm.assume(_maxDiscountDbps <= Constants.DBPS_DENOMINATOR && _discountPerEpoch > _maxDiscountDbps);
    IHubStorage.TokenSetup[] memory _config = new IHubStorage.TokenSetup[](1);
    _config[0].tickerHash = _tickerHash;
    _config[0].prioritizedStrategy = IEverclear.Strategy.DEFAULT;
    _config[0].maxDiscountDbps = _maxDiscountDbps;
    _config[0].discountPerEpoch = _discountPerEpoch;

    vm.expectRevert(IHubStorage.HubStorage_InvalidDbpsValue.selector);

    vm.prank(_caller);
    assetManager.setTokenConfigs(_config);
  }

  /**
   * @notice Test set token configs reverts if max discount dbps is greater than the denominator
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker symbol
   * @param _maxDiscountDbps The maximum discount in basis points
   * @param _discountPerEpoch The discount per epoch in basis points
   */
  function test_Revert_MaxDiscountGreaterThanDenominator(
    address _caller,
    bytes32 _tickerHash,
    uint24 _maxDiscountDbps,
    uint24 _discountPerEpoch
  ) public {
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    vm.assume(_maxDiscountDbps > Constants.DBPS_DENOMINATOR);
    IHubStorage.TokenSetup[] memory _config = new IHubStorage.TokenSetup[](1);
    _config[0].tickerHash = _tickerHash;
    _config[0].prioritizedStrategy = IEverclear.Strategy.DEFAULT;
    _config[0].maxDiscountDbps = _maxDiscountDbps;
    _config[0].discountPerEpoch = _discountPerEpoch;

    vm.expectRevert(IHubStorage.HubStorage_InvalidDbpsValue.selector);

    vm.prank(_caller);
    assetManager.setTokenConfigs(_config);
  }

  /**
   * @notice Test set token configs reverts if the total protocol fees exceed the denominator
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker symbol
   * @param _totalProtocolFees The total protocol fees
   */
  function test_Revert_TotalProtocolFeesExceedsDenominator(
    address _caller,
    bytes32 _tickerHash,
    uint24 _totalProtocolFees
  ) public {
    vm.assume(_totalProtocolFees > Constants.DBPS_DENOMINATOR);
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    IHubStorage.TokenSetup[] memory _config = new IHubStorage.TokenSetup[](1);
    IHubStorage.Fee[] memory _fees = new IHubStorage.Fee[](1);
    _fees[0] = IHubStorage.Fee({recipient: vm.addr(1), fee: _totalProtocolFees});
    _config[0].tickerHash = _tickerHash;
    _config[0].prioritizedStrategy = IEverclear.Strategy.DEFAULT;
    _config[0].fees = _fees;

    vm.expectRevert(IAssetManager.AssetManager_SetTokenConfigs_FeesExceedsDenominator.selector);

    vm.prank(_caller);
    assetManager.setTokenConfigs(_config);
  }
}

contract Unit_SetDiscountPerEpoch is BaseTest {
  event DiscountPerEpochSet(bytes32 _tickerHash, uint24 _oldDiscountPerEpoch, uint24 _newDiscountPerEpoch);

  /**
   * @notice Test set discount per epoch
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker symbol
   * @param _newDiscountPerEpoch The new discount per epoch
   */
  function test_SetDiscountPerEpoch(
    address _caller,
    bytes32 _tickerHash,
    uint24 _maxDiscountDbps,
    uint24 _newDiscountPerEpoch
  ) public {
    vm.assume(_maxDiscountDbps <= Constants.DBPS_DENOMINATOR && _newDiscountPerEpoch <= _maxDiscountDbps);
    _mockMaxDiscountDbps(_tickerHash, _maxDiscountDbps);
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    vm.prank(_caller);

    _expectEmit(address(assetManager));
    emit DiscountPerEpochSet(_tickerHash, 0, _newDiscountPerEpoch);
    assetManager.setDiscountPerEpoch(_tickerHash, _newDiscountPerEpoch);

    uint24 _discountPerEpoch = assetManager.discountPerEpoch(_tickerHash);
    assertEq(_discountPerEpoch, _newDiscountPerEpoch, 'discount per epoch not set correctly');
  }

  /**
   * @notice Test set discount per epoch reverts if the caller is not the asset manager
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker symbol
   * @param _newDiscountPerEpoch The new discount per epoch
   */
  function test_Revert_DiscountPerEpochGreaterThanMaxDiscountDbps(
    address _caller,
    bytes32 _tickerHash,
    uint24 _maxDiscountDbps,
    uint24 _newDiscountPerEpoch
  ) public {
    vm.assume(_maxDiscountDbps <= Constants.DBPS_DENOMINATOR && _newDiscountPerEpoch > _maxDiscountDbps);
    _mockMaxDiscountDbps(_tickerHash, _maxDiscountDbps);
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    vm.expectRevert(IHubStorage.HubStorage_InvalidDbpsValue.selector);

    vm.prank(_caller);
    assetManager.setDiscountPerEpoch(_tickerHash, _newDiscountPerEpoch);
  }

  /**
   * @notice Test set discount per epoch reverts if max discount dbps is greater than the denominator
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker symbol
   * @param _maxDiscountDbps The maximum discount in basis points
   * @param _newDiscountPerEpoch The new discount per epoch
   */
  function test_Revert_MaxDiscountDbpsGreaterThanDenominator(
    address _caller,
    bytes32 _tickerHash,
    uint24 _maxDiscountDbps,
    uint24 _newDiscountPerEpoch
  ) public {
    vm.assume(_maxDiscountDbps > Constants.DBPS_DENOMINATOR);
    _mockMaxDiscountDbps(_tickerHash, _maxDiscountDbps);
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    vm.expectRevert(IHubStorage.HubStorage_InvalidDbpsValue.selector);

    vm.prank(_caller);
    assetManager.setDiscountPerEpoch(_tickerHash, _newDiscountPerEpoch);
  }
}

contract Unit_SetPrioritizedStrategy is BaseTest {
  event PrioritizedStrategySet(bytes32 _tickerHash, IEverclear.Strategy _strategy);

  /**
   * @notice Test set prioritized strategy
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker symbol
   * @param _strategySeed The seed for the strategy
   */
  function test_SetPrioritizedStrategy(address _caller, bytes32 _tickerHash, uint8 _strategySeed) public {
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    IEverclear.Strategy _strategy = IEverclear.Strategy(bound(_strategySeed, 0, uint256(type(IEverclear.Strategy).max)));

    _expectEmit(address(assetManager));
    emit PrioritizedStrategySet(_tickerHash, _strategy);

    vm.prank(_caller);
    assetManager.setPrioritizedStrategy(_tickerHash, _strategy);

    IEverclear.Strategy _prioritizedStrategy = assetManager.prioritizedStrategy(_tickerHash);
    assertEq(uint8(_prioritizedStrategy), uint8(_strategy), 'prioritized strategy not set correctly');
  }

  /**
   * @notice Test set prioritized strategy reverts if the caller is not the asset manager
   * @param _caller The address of the caller
   * @param _tickerHash The hash of the ticker symbol
   * @param _strategySeed The seed for the strategy
   */
  function test_Revert_SetPrioritizedStrategy_NotAssetManager(
    address _caller,
    bytes32 _tickerHash,
    uint8 _strategySeed
  ) public {
    vm.assume(_caller != assetManager.owner());
    IEverclear.Strategy _strategy = IEverclear.Strategy(bound(_strategySeed, 0, uint256(type(IEverclear.Strategy).max)));

    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);

    vm.prank(_caller);
    assetManager.setPrioritizedStrategy(_tickerHash, _strategy);
  }
}

contract Unit_SetLastClosedEpochProcessed is BaseTest {
  event LastEpochProcessedSet(IAssetManager.SetLastClosedEpochProcessedParams _params);

  /**
   * @notice Test set last closed epoch processed
   * @param _caller The address of the caller
   * @param _params The parameters for setting the last epoch processed
   */
  function test_SetLastClosedEpochProcessed(
    address _caller,
    IAssetManager.SetLastClosedEpochProcessedParams memory _params
  ) public {
    _mockRole(_caller, IHubStorage.Role.ASSET_MANAGER);

    _expectEmit(address(assetManager));
    emit LastEpochProcessedSet(_params);

    vm.prank(_caller);
    assetManager.setLastClosedEpochProcessed(_params);

    for (uint256 _i; _i < _params.tickerHashes.length; _i++) {
      bytes32 _tickerHash = _params.tickerHashes[_i];
      uint48 _lastEpochProcessed = assetManager.lastClosedEpochsProcessed(_tickerHash);
      assertEq(_lastEpochProcessed, _params.lastEpochProcessed, 'last epoch processed not set correctly');
    }
  }

  /**
   * @notice Test set last closed epoch processed reverts if the caller is not the asset manager
   * @param _caller The address of the caller
   * @param _params The parameters for setting the last epoch processed
   */
  function test_Revert_SetLastClosedEpochProcessedNotAssetManager(
    address _caller,
    IAssetManager.SetLastClosedEpochProcessedParams memory _params
  ) public {
    vm.assume(_caller != assetManager.owner());

    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);

    vm.prank(_caller);
    assetManager.setLastClosedEpochProcessed(_params);
  }
}
