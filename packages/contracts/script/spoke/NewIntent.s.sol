// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';
import {Script} from 'forge-std/Script.sol';

import {IERC20Metadata} from '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';

import {MainnetProductionEnvironment} from '../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../MainnetStaging.sol';
import {TestnetProductionEnvironment} from '../TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../TestnetStaging.sol';

import {Constants} from 'test/utils/Constants.sol';

contract NewIntentBase is Script, ScriptUtils {
  error InsufficientBalance(address asset, address user, uint256 amount, uint256 balance);
  error InvalidDestination(uint32 destination);
  error SolversFeeTooHigh(uint24 fee);

  mapping(uint32 _domain => IEverclearSpoke _spoke) internal _spokes;
  uint256 _userPk;
  address _inputAsset;
  address _outputAsset;
  uint256 _amount;
  uint48 _ttl;
  uint32[] _destinations;
  address _sender;
  address _to;
  bytes _data;
  uint256 _runs;

  function _getInputs() internal {
    _userPk = vm.parseUint(vm.promptSecret('User private key'));
    _sender = vm.addr(_userPk);
    console.log('Sender:', _sender);

    // Set default values
    _setDefaults();

    // Get user overrides
    _parseDestinationsFromInput();

    try vm.parseAddress(vm.prompt('To address (on destination)')) returns (address _res) {
      _to = _res;
    } catch (bytes memory) {}

    try vm.parseAddress(vm.prompt('Asset address to deposit')) returns (address _res) {
      _inputAsset = _res;
    } catch (bytes memory) {}

    try vm.parseAddress(vm.prompt('Asset address to receive (on destination)')) returns (address _res) {
      _outputAsset = _res;
    } catch (bytes memory) {}

    uint256 _amountWithoutDecimals;
    try vm.parseUint(vm.prompt('Amount to deposit')) returns (uint256 _res) {
      _amountWithoutDecimals = _res;
    } catch (bytes memory) {}

    try vm.parseUint(vm.prompt('Time to live')) returns (uint256 _res) {
      _ttl = uint48(_res);
    } catch (bytes memory) {}

    try vm.parseUint(vm.prompt('Runs')) returns (uint256 _res) {
      _runs = _res;
    } catch (bytes memory) {}

    // Convert amount to wei
    _amount =
      _amountWithoutDecimals > 0 ? _amountWithoutDecimals * (10 ** IERC20Metadata(_inputAsset).decimals()) : _amount;
  }

  function _setDefaults() internal virtual {}

  function _parseDestinationsFromInput() internal {
    bool _finished = false;
    while (!_finished) {
      uint32 _domain;
      try vm.parseUint(vm.prompt('Destination (press [Enter] to finish)')) returns (uint256 _res) {
        _domain = uint32(_res);
      } catch (bytes memory) {
        _domain = 0;
      }

      if (_domain == 0) {
        _finished = true;
      } else {
        _destinations.push(_domain);
      }
    }
  }

  function _sanityChecks(
    IEverclearSpoke _spoke
  ) internal {
    // user has enough balance of input asset
    uint256 balance = IERC20(_inputAsset).balanceOf(_sender);
    if (balance < _amount) {
      revert InsufficientBalance(_inputAsset, _sender, _amount, balance);
    }

    // destination is not hub domain or existing domain
    uint32 _hub = _spokes[uint32(block.chainid)].EVERCLEAR();
    for (uint256 _i = 0; _i < _destinations.length; _i++) {
      uint32 _destination = _destinations[_i];
      if (_destination == _hub || _destination == uint32(block.chainid)) {
        revert InvalidDestination(uint32(_destination));
      }
    }
  }

  function run() public {
    vm.startBroadcast(_userPk);

    IEverclearSpoke _spoke = _spokes[uint32(block.chainid)];
    _sanityChecks(_spoke);
    console.log('Creating intent:');
    uint256 idx = _destinations.length;
    console.log('- destinations:');
    for (uint256 i = 0; i < idx; i++) {
      console.log('   ', _destinations[i]);
    }
    console.log('- to:', _to);
    console.log('- input asset:', _inputAsset);
    console.log('- output asset:', _outputAsset);
    console.log('- amount:', _amount);
    console.log('- time to live:', _ttl);
    console.log('- data:');
    console.logBytes(_data);

    IERC20(_inputAsset).approve(address(_spoke), _amount * _runs);
    for (uint256 i = 0; i < _runs; i++) {
      console.log('Run:  ', i);
      _spoke.newIntent(_destinations, _to, _inputAsset, _outputAsset, _amount, Constants.MAX_FEE, _ttl, _data);
    }

    vm.stopBroadcast();
  }
}

contract TestnetProduction is NewIntentBase, TestnetProductionEnvironment {
  function setUp() public {
    _spokes[ETHEREUM_SEPOLIA] = ETHEREUM_SEPOLIA_SPOKE;
    _spokes[BSC_TESTNET] = BSC_SPOKE;

    _getInputs();
  }

  /**
   * @notice Default behavior is standard token transfer between bsc and sepolia
   */
  function _setDefaults() internal override {
    // Assumes staging environment uses either Sepolia or BSC Testnet
    _destinations.push(uint32(block.chainid) == BSC_TESTNET ? ETHEREUM_SEPOLIA : BSC_TESTNET);

    _to = _sender;
    _inputAsset = block.chainid == BSC_TESTNET ? BSC_DEFAULT_TEST_TOKEN : SEPOLIA_DEFAULT_TEST_TOKEN;
    _outputAsset = block.chainid == BSC_TESTNET ? SEPOLIA_DEFAULT_TEST_TOKEN : BSC_DEFAULT_TEST_TOKEN;
    _amount = 1 ether;
    _runs = 1;
    // Default of ttl is 0
  }
}

contract TestnetStaging is NewIntentBase, TestnetStagingEnvironment {
  function setUp() public {
    _spokes[ETHEREUM_SEPOLIA] = ETHEREUM_SEPOLIA_SPOKE;
    _spokes[BSC_TESTNET] = BSC_SPOKE;

    _getInputs();
  }

  /**
   * @notice Default behavior is standard token transfer between bsc and sepolia
   */
  function _setDefaults() internal override {
    // Assumes staging environment uses either Sepolia or BSC Testnet
    _destinations.push(uint32(block.chainid) == BSC_TESTNET ? ETHEREUM_SEPOLIA : BSC_TESTNET);

    _to = _sender;
    _inputAsset = block.chainid == BSC_TESTNET ? BSC_DEFAULT_TEST_TOKEN : SEPOLIA_DEFAULT_TEST_TOKEN;
    _outputAsset = block.chainid == BSC_TESTNET ? SEPOLIA_DEFAULT_TEST_TOKEN : BSC_DEFAULT_TEST_TOKEN;
    _amount = 1 ether;
    _runs = 1;
    // Default of ttl is 0
  }
}

contract MainnetProduction is NewIntentBase, MainnetProductionEnvironment {
  function setUp() public {
    _spokes[OPTIMISM] = OPTIMISM_SPOKE;
    _spokes[ARBITRUM_ONE] = ARBITRUM_ONE_SPOKE;
    _spokes[ETHEREUM] = ETHEREUM_SPOKE;
    _spokes[BNB] = BNB_SPOKE;
    _spokes[BASE] = BASE_SPOKE;

    _getInputs();
  }

  /**
   * @notice Default behavior is standard token transfer between bsc and sepolia
   */
  function _setDefaults() internal override {
    // Assumes staging environment uses either Sepolia or BSC Testnet
    _destinations.push(OPTIMISM);

    _to = _sender;
    _inputAsset = ARBITRUM_USDT;
    _outputAsset = OPTIMISM_USDT;
    _amount = 1_000_000;
    _runs = 1;
    // Default of ttl is 0
  }
}

contract MainnetStaging is NewIntentBase, MainnetStagingEnvironment {
  function setUp() public {
    _spokes[OPTIMISM] = OPTIMISM_SPOKE;
    _spokes[ARBITRUM_ONE] = ARBITRUM_ONE_SPOKE;

    _getInputs();
  }

  /**
   * @notice Default behavior is standard token transfer between bsc and sepolia
   */
  function _setDefaults() internal override {
    // Assumes staging environment uses either Sepolia or BSC Testnet
    _destinations.push(OPTIMISM);

    _to = _sender;
    _inputAsset = ARBITRUM_USDT;
    _outputAsset = OPTIMISM_USDT;
    _amount = 1_000_000;
    _runs = 1;
    // Default of ttl is 0
  }
}
