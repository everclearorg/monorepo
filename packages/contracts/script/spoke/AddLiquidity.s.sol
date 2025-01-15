// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Script} from 'forge-std/Script.sol';

import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';

import {TestnetProductionEnvironment} from '../TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../TestnetStaging.sol';

contract AddLiquidityBase is Script, ScriptUtils {
  mapping(uint32 _domain => IEverclearSpoke _spoke) internal _spokes;
  uint256 _userPk;
  address _asset;
  uint256 _amount;

  function _getInputs() internal {
    _userPk = vm.parseUint(vm.promptSecret('User private key'));
    _asset = vm.parseAddress(vm.prompt('Asset address to deposit'));

    uint8 _decimals = uint8(vm.parseUint(vm.prompt('Decimals')));

    uint256 _amountWithoutDecimals = vm.parseUint(vm.prompt('Amount to deposit'));

    _amount = _amountWithoutDecimals * (10 ** _decimals);
  }

  function run() public {
    vm.startBroadcast(_userPk);

    IEverclearSpoke _spoke = _spokes[uint32(block.chainid)];

    IERC20(_asset).approve(address(_spoke), _amount);
    _spoke.deposit(_asset, _amount);

    vm.stopBroadcast();
  }
}

contract TestnetProduction is AddLiquidityBase, TestnetProductionEnvironment {
  function setUp() public {
    _spokes[ETHEREUM_SEPOLIA] = ETHEREUM_SEPOLIA_SPOKE;
    _spokes[BSC_TESTNET] = BSC_SPOKE;
    _spokes[OP_SEPOLIA] = OP_SEPOLIA_SPOKE;
    _spokes[ARB_SEPOLIA] = ARB_SEPOLIA_SPOKE;

    _getInputs();
  }
}

contract TestnetStaging is AddLiquidityBase, TestnetStagingEnvironment {
  function setUp() public {
    _spokes[ETHEREUM_SEPOLIA] = ETHEREUM_SEPOLIA_SPOKE;
    _spokes[BSC_TESTNET] = BSC_SPOKE;

    _getInputs();
  }
}
