// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';
import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

contract InvoiceViaFeeAdapter_XERC20 is IntegrationBase {
  function test_InvoiceViaFeeAdapterWithoutDiscountXERC20_TTLZero_TransferZeroAfterDecimalConversion_FeeInTransacting()
    public
  {
    _switchFork(ETHEREUM_SEPOLIA_FORK);

    // Smallest intent amount 1 weth (1e-18)
    uint256 _smallestIntentAmount = 1;

    // Fee amount 1 weth (1e-18)
    uint256 _feeAmount = 1;

    uint256 _totalAmount = _smallestIntentAmount + _feeAmount;
    XERC20(address(sepoliaXToken)).mockMint(_user, _totalAmount);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaFeeAdapter), type(uint256).max);

    // Create an intent with the smallest amount in sepolia
    _createIntentWithFeeAdapterAndReceiveInHub({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _smallestIntentAmount,
      _tokenFee: _feeAmount,
      _ethFee: 0
    });

    // In hub process deposits and invoices and the first intent is settled
    _processDepositsAndInvoices(keccak256('TXT'));

    uint256 _amountAfterFees =
      _smallestIntentAmount - ((_smallestIntentAmount * totalProtocolFees) / Common.DBPS_DENOMINATOR);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // after decimal conversion 1e18 to 1e18 the amount to transfer end up being 1
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), 1);

    // Checking fee sent to fee adapter
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(sepoliaFeeAdapter.feeRecipient()), _feeAmount);
  }

  function test_InvoiceViaFeeAdapterWithoutDiscountXERC20_TTLZero_TransferNotZeroAfterDecimalConversion_FeeInTransacting(
  ) public {
    _switchFork(BSC_TESTNET_FORK);

    // reduce decimals to 6
    XERC20(address(bscXToken)).mockDecimals(6);

    _switchFork(ETHEREUM_SEPOLIA_FORK);

    // reduce decimals to 6
    XERC20(address(sepoliaXToken)).mockDecimals(6);

    // Smallest intent amount 1 weth (1e-18)
    uint256 _smallestIntentAmount = 1;

    // Fee amount 1 weth (1e-18)
    uint256 _feeAmount = 1;

    uint256 _totalAmount = _smallestIntentAmount + _feeAmount;
    XERC20(address(sepoliaXToken)).mockMint(_user, _totalAmount);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    // Create an intent with the smallest amount in sepolia
    _createIntentWithFeeAdapterAndReceiveInHub({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _smallestIntentAmount,
      _tokenFee: _feeAmount,
      _ethFee: 0
    });

    // In hub process deposits and invoices and the first intent is settled
    _processDepositsAndInvoices(keccak256('TXT'));

    uint256 _amountAfterFees =
      _smallestIntentAmount - ((_smallestIntentAmount * totalProtocolFees) / Common.DBPS_DENOMINATOR);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // after decimal conversion 1e18 to 1e18 the amount to transfer end up being 1
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), 0);

    // Checking fee sent to fee adapter
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    assertEq(ERC20(address(sepoliaXToken)).balanceOf(sepoliaFeeAdapter.feeRecipient()), _feeAmount);
  }

  function test_InvoiceViaFeeAdapterWithoutDiscountXERC20_TTLZero_TransferZeroAfterDecimalConversion_FeeInEth() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);

    // Smallest intent amount 1 weth (1e-18)
    uint256 _smallestIntentAmount = 1;

    // Fee amount 1 weth (1e-18)
    uint256 _feeAmount = 1;

    uint256 _totalAmount = _smallestIntentAmount;
    XERC20(address(sepoliaXToken)).mockMint(_user, _totalAmount);
    vm.deal(_user, _feeAmount);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaFeeAdapter), type(uint256).max);

    // Create an intent with the smallest amount in sepolia
    _createIntentWithFeeAdapterAndReceiveInHub({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _smallestIntentAmount,
      _tokenFee: 0,
      _ethFee: _feeAmount
    });

    // In hub process deposits and invoices and the first intent is settled
    _processDepositsAndInvoices(keccak256('TXT'));

    uint256 _amountAfterFees =
      _smallestIntentAmount - ((_smallestIntentAmount * totalProtocolFees) / Common.DBPS_DENOMINATOR);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // after decimal conversion 1e18 to 1e18 the amount to transfer end up being 1
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), 1);

    // Checking fee sent to fee adapter
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    assertEq(sepoliaFeeAdapter.feeRecipient().balance, _feeAmount);
  }

  function test_InvoiceViaFeeAdapterWithoutDiscountXERC20_TTLZero_TransferNotZeroAfterDecimalConversion_FeeInEth()
    public
  {
    _switchFork(BSC_TESTNET_FORK);

    // reduce decimals to 6
    XERC20(address(bscXToken)).mockDecimals(6);

    _switchFork(ETHEREUM_SEPOLIA_FORK);

    // reduce decimals to 6
    XERC20(address(sepoliaXToken)).mockDecimals(6);

    // Smallest intent amount 1 weth (1e-18)
    uint256 _smallestIntentAmount = 1;

    // Fee amount 1 weth (1e-18)
    uint256 _feeAmount = 1;

    uint256 _totalAmount = _smallestIntentAmount;
    XERC20(address(sepoliaXToken)).mockMint(_user, _totalAmount);
    vm.deal(_user, _feeAmount);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    // Create an intent with the smallest amount in sepolia
    _createIntentWithFeeAdapterAndReceiveInHub({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _smallestIntentAmount,
      _tokenFee: 0,
      _ethFee: _feeAmount
    });

    // In hub process deposits and invoices and the first intent is settled
    _processDepositsAndInvoices(keccak256('TXT'));

    uint256 _amountAfterFees =
      _smallestIntentAmount - ((_smallestIntentAmount * totalProtocolFees) / Common.DBPS_DENOMINATOR);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // after decimal conversion 1e18 to 1e18 the amount to transfer end up being 1
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), 0);

    // Checking fee sent to fee adapter
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    assertEq(sepoliaFeeAdapter.feeRecipient().balance, _feeAmount);
  }
}
