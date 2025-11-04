// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract Invoice_WithoutDiscountNonXERC20_Integration is IntegrationBase {
  function test_InvoiceWithoutDiscount_TTLZero_TransferZeroAfterDecimalConversion() public {
    // Smallest intent amount 1 dai
    uint256 _smallestIntentAmount = 1;

    // Create an intent with the smallest amount in sepolia
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _smallestIntentAmount
    });

    // Create an intent with the smallest amount in bsc
    _createIntentAndReceiveInHub({
      _user: _user2,
      _assetOrigin: bscDAI,
      _assetDestination: sepoliaDAI,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _smallestIntentAmount
    });

    // In hub process deposits and invoices and the first intent is settled
    _processDepositsAndInvoices(keccak256('DAI'));

    // roll 1 epoch to close epoch and convert second deposit into settlement
    _rollEpochs(1);

    // In hub process deposits and invoices and the second intent is settled
    _processDepositsAndInvoices(keccak256('DAI'));

    // process settlement messages for sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);

    uint256 _amountAfterFees =
      _smallestIntentAmount - (_smallestIntentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // deliver the settlement message to SEPOLIA
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // after decimal conversion 1e18 to 1e6 the amount to transfer end up being 0
    assertEq(ERC20(address(sepoliaDAI)).balanceOf(_user2), 0);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // after decimal conversion 1e18 to 1e6 the amount to transfer end up being 0
    assertEq(ERC20(address(bscDAI)).balanceOf(_user), 0);
  }

  function test_InvoiceWithoutDiscount_TTLZero_TransferNotZeroAfterDecimalConversion() public {
    // Smallest intent amount 1 weth (1e-18)
    uint256 _smallestIntentAmount = 1;

    // Create an intent with the smallest amount in sepolia
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaWETH,
      _assetDestination: bscWETH,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _smallestIntentAmount
    });

    // Create an intent with the smallest amount in bsc
    _createIntentAndReceiveInHub({
      _user: _user2,
      _assetOrigin: bscWETH,
      _assetDestination: sepoliaWETH,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _smallestIntentAmount
    });

    // In hub process deposits and invoices and the first intent is settled
    _processDepositsAndInvoices(keccak256('WETH'));

    // roll 1 epoch to close epoch and convert second deposit into settlement
    _rollEpochs(1);

    // In hub process deposits and invoices and the second intent is settled
    _processDepositsAndInvoices(keccak256('WETH'));

    // process settlement messages for sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);

    uint256 _amountAfterFees =
      _smallestIntentAmount - (_smallestIntentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // deliver the settlement message to SEPOLIA
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // after decimal conversion 1e18 to 1e18 the amount to transfer end up being 1
    assertEq(ERC20(address(sepoliaWETH)).balanceOf(_user2), 1);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // after decimal conversion 1e18 to 1e18 the amount to transfer end up being 1
    assertEq(ERC20(address(bscWETH)).balanceOf(_user), 1);
  }
}
