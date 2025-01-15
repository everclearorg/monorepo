// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {ScriptUtils} from '../utils/Utils.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {TestnetProductionEnv, TestnetStagingEnv} from '../utils/Environment.sol';

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract AddAssetBase is Script, ScriptUtils {
  using TypeCasts for address;

  error InvalidDecimals();
  error InvalidTicker();
  error InvalidAdopted();
  error InvalidApproval();

  string _symbol;
  address[] _adoptedAssets;
  uint32[] _domains;
  uint8[] _strategies;

  uint24 _fee;
  address _feeRecipient;

  address[] _enteredAssets;
  uint32[] _enteredDomains;
  uint8[] _enteredStrategies;

  bytes32 _tickerHash;

  function _checkValidSetup(
    IHubStorage.TokenSetup[] memory _setup
  ) internal {
    for (uint256 _i = 0; _i < _setup.length; _i++) {
      IHubStorage.TokenSetup memory _config = _setup[_i];

      for (uint256 _j = 0; _j < _config.adoptedForAssets.length; _j++) {
        if (_config.adoptedForAssets[_j].domain == 0) revert InvalidDomain(0);
        if (_config.adoptedForAssets[_j].tickerHash == 0) revert InvalidTicker();
        if (_config.adoptedForAssets[_j].adopted == 0) revert InvalidAdopted();
        if (!_config.adoptedForAssets[_j].approval) revert InvalidApproval();
      }
    }
  }

  function _setDefaults() internal virtual {}

  function _logConfig() internal {
    console.log('------------------------------------------------');
    console.log('Registering asset:', _symbol);
    console.log('Ticker hash:');
    console.logBytes32(_tickerHash);
    console.log('Adopted Assets:', _adoptedAssets.length);
    for (uint256 _i = 0; _i < _adoptedAssets.length; _i++) {
      console.log(' - %d: %s. Strategy:', _domains[_i], address(_adoptedAssets[_i]), _strategies[_i]);
    }
    console.log('Fee:', _fee);
    console.log('Fee Recipient:', address(_feeRecipient));
    console.log('Chain ID:', block.chainid);
    console.log('------------------------------------------------');
  }

  function _getInputs() internal {
    // symbol
    try vm.prompt('Token Symbol') returns (string memory _res) {
      if (keccak256(bytes(_res)) != keccak256(bytes(''))) {
        _symbol = _res;
      }
    } catch (bytes memory) {}

    // asset configs
    bool _finished = false;
    while (!_finished) {
      uint32 _adoptedDomain;
      try vm.parseUint(vm.prompt('Asset domain (press [Enter] to finish, limit 10)')) returns (uint256 _res) {
        _adoptedDomain = uint32(_res);
        _enteredDomains.push(_adoptedDomain);
      } catch (bytes memory) {
        _adoptedDomain = 0;
      }

      if (_adoptedDomain == 0) {
        _finished = true;
        continue;
      }

      _enteredAssets.push(vm.parseAddress(vm.prompt('Asset address')));
      _enteredStrategies.push(uint8(vm.parseUint(vm.prompt('Asset strategy'))));
    }

    // Update defaults
    if (_enteredDomains.length > 0) {
      _domains = _enteredDomains;
      _adoptedAssets = _enteredAssets;
      _strategies = _enteredStrategies;
    }

    // fee
    try vm.parseUint(vm.prompt('Fee')) returns (uint256 _res) {
      if (_res > 0) {
        _fee = uint24(_res);
      }
    } catch (bytes memory) {}

    // fee recipient
    try vm.parseAddress(vm.prompt('Fee Recipient')) returns (address _res) {
      if (_res != address(0)) {
        _feeRecipient = _res;
      }
    } catch (bytes memory) {}
  }
}

contract TestnetStaging is AddAssetBase, TestnetStagingEnv {
  using TypeCasts for address;

  function _setDefaults() internal virtual override {
    // Default to standard TEST token (Default strategy, 18 decimals)
    _symbol = 'TEST';
    _tickerHash = keccak256(bytes(_symbol));

    // Establish new asset contexts
    _domains = new uint32[](4);
    _adoptedAssets = new address[](4);
    _strategies = new uint8[](4);

    _domains[0] = SEPOLIA;
    _adoptedAssets[0] = SEPOLIA_DEFAULT_TEST_TOKEN;
    _strategies[0] = uint8(IEverclear.Strategy.DEFAULT);

    _domains[1] = BSC_TESTNET;
    _adoptedAssets[1] = BSC_DEFAULT_TEST_TOKEN;
    _strategies[1] = uint8(IEverclear.Strategy.DEFAULT);

    _domains[2] = OP_SEPOLIA;
    _adoptedAssets[2] = OP_SEPOLIA_DEFAULT_TEST_TOKEN;
    _strategies[2] = uint8(IEverclear.Strategy.DEFAULT);

    _domains[3] = ARB_SEPOLIA;
    _adoptedAssets[3] = ARB_SEPOLIA_DEFAULT_TEST_TOKEN;
    _strategies[3] = uint8(IEverclear.Strategy.DEFAULT);

    // set protocol fees
    _fee = 1;
    _feeRecipient = OWNER;
  }

  function run() public {
    vm.createSelectFork(HUB_RPC);
    _checkValidDomain(EVERCLEAR_DOMAIN);

    // Get default values
    _setDefaults();

    // Get user overrides
    _getInputs();

    // Set ticker hash
    _tickerHash = keccak256(bytes(_symbol));

    // Log configuration
    _logConfig();

    IHubStorage.TokenSetup[] memory _setup = new IHubStorage.TokenSetup[](1);

    ///////////////////// TestToken /////////////////////////
    // set protocol fees
    // NOTE: Improvement would be to capture this from CLI as well.
    IHubStorage.Fee[] memory _testFees = new IHubStorage.Fee[](1);
    _testFees[0] = IHubStorage.Fee({recipient: _feeRecipient, fee: _fee});

    // set configuration for different domains
    uint256 _assetConfigs = _adoptedAssets.length;
    IHubStorage.AssetConfig[] memory _testAssetConfigs = new IHubStorage.AssetConfig[](_assetConfigs);
    for (uint256 _i = 0; _i < _assetConfigs; _i++) {
      _testAssetConfigs[_i] = IHubStorage.AssetConfig({
        tickerHash: _tickerHash,
        adopted: _adoptedAssets[_i].toBytes32(),
        domain: _domains[_i],
        approval: true,
        strategy: IEverclear.Strategy(_strategies[_i])
      });
    }

    _setup[0] = IHubStorage.TokenSetup({
      tickerHash: _tickerHash,
      initLastClosedEpochProcessed: true,
      prioritizedStrategy: IEverclear.Strategy.XERC20,
      maxDiscountDbps: 5000,
      discountPerEpoch: TestnetStagingEnv.DISCOUNT_PER_EPOCH,
      fees: _testFees,
      adoptedForAssets: _testAssetConfigs
    });

    _checkValidSetup(_setup);

    // RUN SCRIPT
    uint256 _adminPk = vm.envUint('DEPLOYER_PK');
    vm.startBroadcast(_adminPk);

    HUB.setTokenConfigs(_setup);

    vm.stopBroadcast();
  }
}

contract TestnetProduction is AddAssetBase, TestnetProductionEnv {
  using TypeCasts for address;

  function run() public {
    vm.createSelectFork(HUB_RPC);
    _checkValidDomain(EVERCLEAR_DOMAIN);

    IHubStorage.TokenSetup[] memory _setup = new IHubStorage.TokenSetup[](1);

    ///////////////////// TestToken /////////////////////////

    // set protocol fees
    IHubStorage.Fee[] memory _testFees = new IHubStorage.Fee[](1);
    _testFees[0] = IHubStorage.Fee({recipient: OWNER, fee: 1});

    // set configuration for different domains
    IHubStorage.AssetConfig[] memory _testAssetConfigs = new IHubStorage.AssetConfig[](2);

    // sepolia
    _testAssetConfigs[0] = IHubStorage.AssetConfig({
      tickerHash: keccak256('TEST'),
      adopted: SEPOLIA_DEFAULT_TEST_TOKEN.toBytes32(), // fill with token address on domain
      domain: 11_155_111, // sepolia id
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });
    // bsc testnet
    _testAssetConfigs[1] = IHubStorage.AssetConfig({
      tickerHash: keccak256('TEST'),
      adopted: BSC_DEFAULT_TEST_TOKEN.toBytes32(), // fill with token address on domain
      domain: 97, // bsc testnet id
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    _setup[0] = IHubStorage.TokenSetup({
      tickerHash: keccak256('TEST'),
      initLastClosedEpochProcessed: true,
      prioritizedStrategy: IEverclear.Strategy.XERC20,
      maxDiscountDbps: 5000,
      discountPerEpoch: TestnetProductionEnv.DISCOUNT_PER_EPOCH,
      fees: _testFees,
      adoptedForAssets: _testAssetConfigs
    });

    _checkValidSetup(_setup);

    // RUN SCRIPT
    uint256 _adminPk = vm.envUint('DEPLOYER_PK');
    vm.startBroadcast(_adminPk);

    HUB.setTokenConfigs(_setup);

    vm.stopBroadcast();
  }
}
