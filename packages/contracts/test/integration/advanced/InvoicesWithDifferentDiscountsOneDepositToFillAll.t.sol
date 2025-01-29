// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract InvoicesWithDifferentDiscountsOneDepositToFillAll_Integration is IntegrationBase {
  uint256 _bigIntentAmount = 100_000 * 1e6;
  uint256 _bigIntentTenth = _bigIntentAmount / 10;

  function test_InvoicesWithDifferentDiscounts_OneDepositToFillAll() public {
    // Create ten intents with different discounts and receive them in the hub
    for (uint256 _i; _i < 10; _i++) {
      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: sepoliaDAI,
        _assetDestination: bscDAI,
        _origin: ETHEREUM_SEPOLIA_ID,
        _destination: BSC_TESTNET_ID,
        _intentAmount: _bigIntentTenth
      });

      // To convert all previous deposits to invoices
      _processDepositsAndInvoices(keccak256('DAI'));

      // roll one epoch to generate different discounts
      _rollEpochs(1);
    }

    uint256 _liquidityNeededToCoverAllInvoices;
    uint256 _protocolFeesPerIntent = _bigIntentTenth * totalProtocolFees / Common.DBPS_DENOMINATOR;
    uint256 _invoiceAmountWithoutDiscount = _bigIntentTenth - _protocolFeesPerIntent;

    // Checking max liquidity efficiency creating a big intent to cover all invoices with the minimum amount of DAI to cover them after the discounts
    for (uint256 _i; _i < 10; _i++) {
      uint256 _discountDbps = defaultDiscountPerEpoch * _i;
      uint256 _discount = _invoiceAmountWithoutDiscount * _discountDbps / Common.DBPS_DENOMINATOR;
      uint256 _amountAfterDiscount = _invoiceAmountWithoutDiscount - _discount;
      _liquidityNeededToCoverAllInvoices += _amountAfterDiscount;
    }

    // Arbitrageur creates a big intent to cover all the invoices with the minimum amount of DAI to cover them after the discounts
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: bscDAI,
      _assetDestination: sepoliaDAI,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _liquidityNeededToCoverAllInvoices
    });

    _processDepositsAndInvoices(keccak256('DAI'));

    // Process settlement for BSC testnet where the big intent is settled
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 10);

    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    uint256 _accumulatedRewards;
    for (uint256 _i = 1; _i <= 10; _i++) {
      uint256 _discountDbps = _i == 1 ? defaultDiscountPerEpoch * 10 : defaultDiscountPerEpoch * (10 - _i);
      uint256 _amountAfterDiscount =
        _invoiceAmountWithoutDiscount - (_invoiceAmountWithoutDiscount * _discountDbps / Common.DBPS_DENOMINATOR);
      uint256 _reward = _invoiceAmountWithoutDiscount * _discountDbps / Common.DBPS_DENOMINATOR;
      _accumulatedRewards += _reward;

      assertEq(ERC20(address(bscDAI)).balanceOf(vm.addr(_i)), _amountAfterDiscount, 'invalid settlement amount');
    }

    // close epoch
    _rollEpochs(1);

    // Process big deposit with bsc testnet origin
    _processDepositsAndInvoices(keccak256('DAI'));

    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlement for SEPOLIA testnet where the small intents are being settled
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);

    // deliver the settlement message to SEPOLIA
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    uint256 _expectedUserBalance = _liquidityNeededToCoverAllInvoices
      - (_liquidityNeededToCoverAllInvoices * totalProtocolFees / Common.DBPS_DENOMINATOR) + _accumulatedRewards;

    // check arbitrageour user settlement balance should reflect the amount after fees + rewards
    uint256 _balanceOfUser = _getTokenBalanceInSepolia(address(_user), address(sepoliaDAI));
    assertEq(_balanceOfUser, _expectedUserBalance, 'invalid user balance');
  }
}
