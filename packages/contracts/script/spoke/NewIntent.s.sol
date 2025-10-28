// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';
import {Script} from 'forge-std/Script.sol';

import {IERC20Metadata} from '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';
import {IFeeAdapter} from 'interfaces/intent/IFeeAdapter.sol';

import {MainnetProductionEnvironment} from '../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../MainnetStaging.sol';
import {TestnetProductionEnvironment} from '../TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../TestnetStaging.sol';

import {Constants} from 'test/utils/Constants.sol';

contract NewIntentBase is Script, ScriptUtils {
  error InsufficientBalance(address asset, address user, uint256 amount, uint256 balance);
  error InvalidDestination(uint32 destination);
  error SolversFeeTooHigh(uint24 fee);

  mapping(uint32 _domain => IEverclearSpoke) public spokes;
  mapping(uint32 _domain => IFeeAdapter) public feeAdapter;
  uint256 _userPk;

  function _sanityChecks(
    uint256 _amount,
    address _sender,
    address _inputAsset
  ) internal {
    // user has enough balance of input asset
    uint256 balance = IERC20(_inputAsset).balanceOf(_sender);
    if (balance < _amount) {
      revert InsufficientBalance(_inputAsset, _sender, _amount, balance);
    }
  }

  function run(
    address _inputAsset,
    address _outputAsset,
    uint256 _amount,
    uint48 _ttl,
    uint32[] memory _destinations,
    address _sender,
    address _to,
    IFeeAdapter.FeeParams memory _params
  ) public {
    vm.startBroadcast(_userPk);

    IFeeAdapter _feeAdapter = feeAdapter[uint32(block.chainid)];
    console.log('Chain ID:', block.chainid);
    console.log('FeeAdapter address:', address(_feeAdapter));
    console.log('Sender address:', _sender);

    // Sanity checks
    _sanityChecks(_amount, _sender, _inputAsset);

    // Log all inputs
    console.log('=== Creating intent ===');
    console.log('- Destinations count:', _destinations.length);
    for (uint256 i = 0; i < _destinations.length; i++) {
      console.log('  Destination[', i, ']:', _destinations[i]);
    }
    console.log('- To:', _to);
    console.log('- Input asset:', _inputAsset);
    console.log('- Output asset:', _outputAsset);
    console.log('- Amount:', _amount);
    console.log('- Time to live:', _ttl);
    console.log('- Data (hex):');
    console.logBytes('');
    console.log('- FeeParams.fee:', _params.fee);
    console.log('- FeeParams.deadline:', _params.deadline);
    console.log('- FeeParams.sig (hex):');
    console.logBytes(_params.sig);

    // Approving
    bool approveSuccess = IERC20(_inputAsset).approve(address(_feeAdapter), _amount);
    console.log('Approve success:', approveSuccess);

    // Try to create intent and catch errors
    try _feeAdapter.newIntent(
      _destinations, _to, _inputAsset, _outputAsset, _amount, Constants.MAX_FEE, _ttl, '', _params
    ) returns (
      bytes32 intentId, IEverclear.Intent memory intent
    ) {
      console.log('Intent created successfully!');
      console.logBytes32(intentId);
      // Optionally log intent fields if needed
    } catch Error(string memory reason) {
      console.log('Error (string):', reason);
    } catch (bytes memory lowLevelData) {
      console.log('Error (low-level):');
      console.logBytes(lowLevelData);
    }

    // Log user balance after
    uint256 balanceAfter = IERC20(_inputAsset).balanceOf(_sender);
    console.log('User balance after:', balanceAfter);

    vm.stopBroadcast();
  }
}

contract MainnetProduction is NewIntentBase, MainnetProductionEnvironment {
  function setUp() public {
    spokes[OPTIMISM] = OPTIMISM_SPOKE;
    spokes[ARBITRUM_ONE] = ARBITRUM_ONE_SPOKE;
    spokes[ETHEREUM] = ETHEREUM_SPOKE;
    spokes[BNB] = BNB_SPOKE;
    spokes[BASE] = BASE_SPOKE;
    feeAdapter[OPTIMISM] = IFeeAdapter(OPTIMISM_FEE_ADAPTER);
    feeAdapter[ARBITRUM_ONE] = IFeeAdapter(ARBITRUM_FEE_ADAPTER);
    feeAdapter[ETHEREUM] = IFeeAdapter(ETHEREUM_FEE_ADAPTER);
    feeAdapter[BNB] = IFeeAdapter(BNB_FEE_ADAPTER);
    feeAdapter[BASE] = IFeeAdapter(BASE_FEE_ADAPTER);
  }
}

contract MainnetStaging is NewIntentBase, MainnetStagingEnvironment {
  function setUp() public {
    spokes[OPTIMISM] = OPTIMISM_SPOKE;
    spokes[BASE] = BASE_SPOKE;
    feeAdapter[OPTIMISM] = IFeeAdapter(OPTIMISM_FEE_ADAPTER);
    feeAdapter[BASE] = IFeeAdapter(BASE_FEE_ADAPTER);
  }
}
