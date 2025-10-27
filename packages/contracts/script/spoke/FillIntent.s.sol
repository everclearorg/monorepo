// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IERC20Metadata} from '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';

import {MainnetProductionEnvironment} from '../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../MainnetStaging.sol';
import {TestnetProductionEnvironment} from '../TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../TestnetStaging.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

contract FillIntentBase is Script, ScriptUtils {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  error InsufficientBalance(address asset, address user, uint256 required, uint256 balance);
  error DepositFailed();

  mapping(uint32 _domain => IEverclearSpoke) public spokes;
  uint256 _userPk;

  function run(IEverclear.Intent memory _intent, uint24 _fee) public {
    vm.startBroadcast(_userPk);

    IEverclearSpoke _spoke = spokes[uint32(block.chainid)];
    address _solver = vm.addr(_userPk);
    address _outputAsset = _intent.outputAsset.toAddress();

    console.log('=== Fill Intent ===');
    console.log('Chain ID:', block.chainid);
    console.log('Spoke address:', address(_spoke));
    console.log('Solver address:', _solver);
    console.log('Output asset:', _outputAsset);

    // Calculate the amount needed (normalized to destination decimals)
    uint256 _decimals = IERC20Metadata(_outputAsset).decimals();
    uint256 _amount = _normalizeAmount(_intent.amount, _decimals);

    // Calculate amount after fee
    uint256 _feeDeduction = (_amount * _fee) / 10_000;
    uint256 _finalAmount = _amount - _feeDeduction;

    console.log('Amount needed (with decimals):', _amount);
    console.log('Fee (DBPS):', _fee);
    console.log('Fee deduction:', _feeDeduction);
    console.log('Final amount to transfer:', _finalAmount);

    // Check deposited balance in spoke contract
    uint256 _depositedBalance = _spoke.balances(_outputAsset.toBytes32(), _solver.toBytes32());
    console.log('Current deposited balance:', _depositedBalance);

    // If insufficient deposited balance, deposit the difference
    if (_depositedBalance < _finalAmount) {
      uint256 _depositAmount = _finalAmount - _depositedBalance;
      console.log('Insufficient deposited balance, need to deposit:', _depositAmount);

      // Check wallet balance
      uint256 _walletBalance = IERC20(_outputAsset).balanceOf(_solver);
      console.log('Wallet balance:', _walletBalance);

      if (_walletBalance < _depositAmount) {
        revert InsufficientBalance(_outputAsset, _solver, _depositAmount, _walletBalance);
      }

      // Approve spoke contract if needed
      uint256 _allowance = IERC20(_outputAsset).allowance(_solver, address(_spoke));
      if (_allowance < _depositAmount) {
        console.log('Approving spoke contract for deposit...');
        bool _approveSuccess = IERC20(_outputAsset).approve(address(_spoke), _depositAmount);
        if (!_approveSuccess) revert DepositFailed();
        console.log('Approval successful');
      }

      // Deposit tokens
      console.log('Depositing tokens to spoke contract...');
      _spoke.deposit(_outputAsset, _depositAmount);
      console.log('Deposit successful');
    } else {
      console.log('Sufficient balance already deposited');
    }

    // Fill the intent
    console.log('\n--- Filling intent ---');
    IEverclear.FillMessage memory _fillMessage = _spoke.fillIntent(_intent, _fee);

    console.log('Intent filled successfully!');
    console.log('Fill Message Intent ID:');
    console.logBytes32(_fillMessage.intentId);
    console.log('Solver:');
    console.logBytes32(_fillMessage.solver);
    console.log('Fee:', _fillMessage.fee);

    vm.stopBroadcast();
  }

  /**
   * @notice Normalize amount from 18 decimals to destination decimals
   * @param _amount Amount in 18 decimals
   * @param _decimals Destination decimals
   */
  function _normalizeAmount(uint256 _amount, uint256 _decimals) internal pure returns (uint256) {
    if (_decimals == 18) {
      return _amount;
    } else if (_decimals < 18) {
      return _amount / (10 ** (18 - _decimals));
    } else {
      return _amount * (10 ** (_decimals - 18));
    }
  }
}

contract MainnetProduction is FillIntentBase, MainnetProductionEnvironment {
  function setUp() public {
    spokes[OPTIMISM] = OPTIMISM_SPOKE;
    spokes[ARBITRUM_ONE] = ARBITRUM_ONE_SPOKE;
    spokes[ETHEREUM] = ETHEREUM_SPOKE;
    spokes[BNB] = BNB_SPOKE;
    spokes[BASE] = BASE_SPOKE;
    _userPk = vm.parseUint(vm.promptSecret('User private key'));
  }
}

contract MainnetStaging is FillIntentBase, MainnetStagingEnvironment {
  function setUp() public {
    spokes[OPTIMISM] = OPTIMISM_SPOKE;
    spokes[ARBITRUM_ONE] = ARBITRUM_ONE_SPOKE;
    spokes[BASE] = BASE_SPOKE;
    _userPk = vm.parseUint(vm.promptSecret('User private key'));
  }
}

contract TestnetProduction is FillIntentBase, TestnetProductionEnvironment {
  function setUp() public {
    spokes[ETHEREUM_SEPOLIA] = ETHEREUM_SEPOLIA_SPOKE;
    spokes[BSC_TESTNET] = BSC_SPOKE;
    spokes[OP_SEPOLIA] = OP_SEPOLIA_SPOKE;
    spokes[ARB_SEPOLIA] = ARB_SEPOLIA_SPOKE;
    _userPk = vm.parseUint(vm.promptSecret('User private key'));
  }
}

contract TestnetStaging is FillIntentBase, TestnetStagingEnvironment {
  function setUp() public {
    spokes[ETHEREUM_SEPOLIA] = ETHEREUM_SEPOLIA_SPOKE;
    spokes[BSC_TESTNET] = BSC_SPOKE;
    _userPk = vm.parseUint(vm.promptSecret('User private key'));
  }
}
