// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {AaveReceiver} from 'contracts/intent/AaveReceiver.sol';
import {Test} from 'forge-std/Test.sol';
import {console2} from 'forge-std/console2.sol';
import {IAaveV3Pool} from 'interfaces/external/IAaveV3Pool.sol';

contract AaveReceiverTest is Test {
  using SafeERC20 for IERC20;

  AaveReceiver receiver;
  IAaveV3Pool constant AAVE_POOL = IAaveV3Pool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
  IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
  IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  IERC20 constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  address constant STAGING_DEPLOYMENT = 0x92e28dAc2fDf062Faa3Ac85647ad679e95c59557;
  address constant WALLET_WITH_USDT = 0xBc8988C7a4b77c1d6df7546bd876Ea4D42DF0837;

  address owner = makeAddr('owner');
  address spoke = makeAddr('spoke');

  function setUp() public {
    // Fork mainnet
    vm.createSelectFork(vm.envString('MAINNET_RPC'));

    // Deploy receiver with real Aave pool
    receiver = new AaveReceiver(AAVE_POOL);
  }

  /*///////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
  //////////////////////////////////////////////////////////////*/

  function testConstructor() public {
    assertEq(address(receiver.aaveV3()), address(AAVE_POOL), 'aave');
  }

  /*///////////////////////////////////////////////////////////////
                          SUPPLY TESTS
  //////////////////////////////////////////////////////////////*/
  function test_supply_usdt() public {
    uint256 supplyAmount = 1e6; // USDT has 6 decimals
    address user = address(0xBc8988C7a4b77c1d6df7546bd876Ea4D42DF0837);

    // Deal USDT (works fine with deal)
    deal(address(USDT), address(receiver), supplyAmount);

    // Verify the receiver has the tokens
    uint256 receiverUSDTBalance = USDT.balanceOf(address(receiver));
    assertEq(receiverUSDTBalance, supplyAmount, 'receiver USDT balance');

    // Call supply on receiver
    receiver.supply(address(USDT), supplyAmount, user, 0);

    // Aserting balance reduction
    uint256 receiverUSDTBalanceAfter = USDT.balanceOf(address(receiver));
    assertEq(receiverUSDTBalanceAfter, 0, 'receiver USDT balance after');
  }

  function test_supply_usdc() public {
    uint256 supplyAmount = 1000e6; // USDC also has 6 decimals
    address user = address(0x123);

    // Deal USDC (works fine with deal)
    deal(address(USDC), address(receiver), supplyAmount);

    // Verify the receiver has the tokens
    uint256 receiverUSDCBalance = USDC.balanceOf(address(receiver));
    assertEq(receiverUSDCBalance, supplyAmount, 'receiver USDC balance');

    // Call supply on receiver
    receiver.supply(address(USDC), supplyAmount, user, 0);

    // Aserting balance reduction
    uint256 receiverUSDCBalanceAfter = USDC.balanceOf(address(receiver));
    assertEq(receiverUSDCBalanceAfter, 0, 'receiver USDC balance after');
  }

  function test_supply_dai() public {
    uint256 supplyAmount = 10e18; // DAI has 18 decimals
    address user = address(0x123);

    // Deal DAI (works fine with deal)
    deal(address(DAI), address(receiver), supplyAmount);

    // Verify the receiver has the tokens
    uint256 receiverDAIBalance = DAI.balanceOf(address(receiver));
    assertEq(receiverDAIBalance, supplyAmount, 'receiver DAI balance');

    // Call supply on receiver
    receiver.supply(address(DAI), supplyAmount, user, 0);

    // Aserting balance reduction
    uint256 receiverDAIBalanceAfter = DAI.balanceOf(address(receiver));
    assertEq(receiverDAIBalanceAfter, 0, 'receiver DAI balance after');
  }

  function test_supply_wbtc() public {
    uint256 supplyAmount = 1e7; // WBTC has 8 decimals
    address user = address(0x123);

    // Deal WBTC (works fine with deal)
    deal(address(WBTC), address(receiver), supplyAmount);

    // Verify the receiver has the tokens
    uint256 receiverWBTCBalance = WBTC.balanceOf(address(receiver));
    assertEq(receiverWBTCBalance, supplyAmount, 'receiver WBTC balance');

    // Call supply on receiver
    receiver.supply(address(WBTC), supplyAmount, user, 0);

    // Aserting balance reduction
    uint256 receiverWBTCBalanceAfter = WBTC.balanceOf(address(receiver));
    assertEq(receiverWBTCBalanceAfter, 0, 'receiver WBTC balance after');
  }

  /*///////////////////////////////////////////////////////////////
                          DEPLOYMENT TESTS
  //////////////////////////////////////////////////////////////*/

  function test_supplyViaDeployment_usdt() public {
    AaveReceiver deployedReceiver = AaveReceiver(STAGING_DEPLOYMENT);
    address user = address(0x456);
    uint256 supplyAmount = 999_870; // USDT

    // Dealing to the deployment from wallet
    vm.prank(WALLET_WITH_USDT);
    USDT.safeTransfer(address(deployedReceiver), supplyAmount);

    // Asserting the USDT balance of the deployed contract
    uint256 deployedReceiverUSDTBalance = USDT.balanceOf(address(deployedReceiver));
    assertEq(deployedReceiverUSDTBalance, supplyAmount, 'deployed receiver USDT balance');

    // Checking approval
    uint256 allowance = USDT.allowance(address(deployedReceiver), address(AAVE_POOL));
    assertEq(allowance, 0, 'deployed receiver USDT allowance is not zero');

    deployedReceiver.supply(address(USDT), supplyAmount, user, 0);
  }

  function test_supplyViaDeployment_usdc() public {
    AaveReceiver deployedReceiver = AaveReceiver(STAGING_DEPLOYMENT);
    address user = address(0x456);
    uint256 supplyAmount = 1000e6; // USDC
    deal(address(USDC), address(deployedReceiver), supplyAmount);

    // Asserting the USDT balance of the deployed contract
    uint256 deployedReceiverUSDCBalance = USDC.balanceOf(address(deployedReceiver));
    assertEq(deployedReceiverUSDCBalance, supplyAmount, 'deployed receiver USDC balance');

    // Checking approval
    uint256 allowance = USDC.allowance(address(deployedReceiver), address(AAVE_POOL));
    assertEq(allowance, 0, 'deployed receiver USDC allowance is not zero');

    deployedReceiver.supply(address(USDC), supplyAmount, user, 0);
  }

  function test_supplyViaDeployment_dai() public {
    AaveReceiver deployedReceiver = AaveReceiver(STAGING_DEPLOYMENT);
    address user = address(0x456);
    uint256 supplyAmount = 10e18; // DAI
    deal(address(DAI), address(deployedReceiver), supplyAmount);

    // Asserting the DAI balance of the deployed contract
    uint256 deployedReceiverDAIBalance = DAI.balanceOf(address(deployedReceiver));
    assertEq(deployedReceiverDAIBalance, supplyAmount, 'deployed receiver DAI balance');

    // Checking approval
    uint256 allowance = DAI.allowance(address(deployedReceiver), address(AAVE_POOL));
    assertEq(allowance, 0, 'deployed receiver DAI allowance is not zero');

    deployedReceiver.supply(address(DAI), supplyAmount, user, 0);
  }

  function test_supplyViaDeployment_wbtc() public {
    AaveReceiver deployedReceiver = AaveReceiver(STAGING_DEPLOYMENT);
    address user = address(0x456);
    uint256 supplyAmount = 1e7; // WBTC
    deal(address(WBTC), address(deployedReceiver), supplyAmount);

    // Asserting the WBTC balance of the deployed contract
    uint256 deployedReceiverWBTCBalance = WBTC.balanceOf(address(deployedReceiver));
    assertEq(deployedReceiverWBTCBalance, supplyAmount, 'deployed receiver WBTC balance');

    // Checking approval
    uint256 allowance = WBTC.allowance(address(deployedReceiver), address(AAVE_POOL));
    assertEq(allowance, 0, 'deployed receiver WBTC allowance is not zero');

    deployedReceiver.supply(address(WBTC), supplyAmount, user, 0);
  }

  /*///////////////////////////////////////////////////////////////
                       DIRECT TESTS
  //////////////////////////////////////////////////////////////*/
  function test_supplyDirect_usdt() public {
    uint256 supplyAmount = 1e6; // USDT has 6 decimals
    address user = address(WALLET_WITH_USDT);

    // Asserting user has enough USDT
    uint256 userUSDTBalanceBefore = USDT.balanceOf(address(user));
    assertGe(userUSDTBalanceBefore, supplyAmount, 'user USDT balance before');

    vm.startPrank(user);
    USDT.forceApprove(address(AAVE_POOL), 0);
    USDT.forceApprove(address(AAVE_POOL), supplyAmount);

    // Call supply on Aave
    console2.log('Supplying USDT directly to Aave from user...');
    IAaveV3Pool(AAVE_POOL).supply(address(USDT), supplyAmount, user, 0);

    // Check that supply worked (balance should decrease by supplyAmount)
    uint256 userUSDTBalanceAfter = USDT.balanceOf(address(user));
    assertEq(userUSDTBalanceAfter, userUSDTBalanceBefore - supplyAmount, 'user USDT balance after');
    vm.stopPrank();
  }

  function test_supplyDirect_usdc() public {
    uint256 supplyAmount = 1000e6; // USDC has 6 decimals
    address user = address(0x123);

    // Deal USDC (works fine with deal)
    vm.startPrank(user);
    deal(address(USDC), address(user), supplyAmount);
    USDC.approve(address(AAVE_POOL), supplyAmount);

    // Verify the user has the tokens
    uint256 userUSDCBalance = USDC.balanceOf(address(user));
    assertEq(userUSDCBalance, supplyAmount, 'user USDC balance');

    // Call supply on receiver
    IAaveV3Pool(AAVE_POOL).supply(address(USDC), supplyAmount, user, 0);

    // Aserting balance reduction
    uint256 userUSDCBalanceAfter = USDC.balanceOf(address(user));
    assertEq(userUSDCBalanceAfter, 0, 'user USDC balance after');
    vm.stopPrank();
  }

  function test_supplyDirect_dai() public {
    uint256 supplyAmount = 1e18; // DAI has 18 decimals
    address user = address(0x123);

    // Deal DAI (works fine with deal)
    vm.startPrank(user);
    deal(address(DAI), address(user), supplyAmount);
    DAI.approve(address(AAVE_POOL), supplyAmount);

    // Verify the user has the tokens
    uint256 userDAIBalance = DAI.balanceOf(address(user));
    assertEq(userDAIBalance, supplyAmount, 'user DAI balance');

    // Call supply on receiver
    IAaveV3Pool(AAVE_POOL).supply(address(DAI), supplyAmount, user, 0);

    // Aserting balance reduction
    uint256 userDAIBalanceAfter = DAI.balanceOf(address(user));
    assertEq(userDAIBalanceAfter, 0, 'user DAI balance after');
    vm.stopPrank();
  }

  function test_supplyDirect_wbtc() public {
    uint256 supplyAmount = 1e7; // WBTC has 8 decimals
    address user = address(0x123);

    // Deal WBTC (works fine with deal)
    vm.startPrank(user);
    deal(address(WBTC), address(user), supplyAmount);
    WBTC.approve(address(AAVE_POOL), supplyAmount);

    // Verify the user has the tokens
    uint256 userWBTCBalance = WBTC.balanceOf(address(user));
    assertEq(userWBTCBalance, supplyAmount, 'user WBTC balance');

    // Call supply on receiver
    IAaveV3Pool(AAVE_POOL).supply(address(WBTC), supplyAmount, user, 0);

    // Aserting balance reduction
    uint256 userWBTCBalanceAfter = WBTC.balanceOf(address(user));
    assertEq(userWBTCBalanceAfter, 0, 'user WBTC balance after');
    vm.stopPrank();
  }
}
