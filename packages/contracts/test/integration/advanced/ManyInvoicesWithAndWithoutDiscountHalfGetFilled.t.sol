// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract ManyInvoicesWithAndWithoutDiscountHalfGetFilled_Integration is IntegrationBase {
  uint256 _bigIntentAmount = 100_000 * 1e6;
  uint256 _bigIntentTenth = _bigIntentAmount / 10;

  function test_ManyInvoices_WithAndWithoutDiscount_HalfGetFilled() public {
    // Create ten intents with different discounts and receive them in the hub
    for (uint256 _i; _i < 5; _i++) {
      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: sepoliaDAI,
        _assetDestination: bscDAI,
        _origin: ETHEREUM_SEPOLIA_ID,
        _destination: BSC_TESTNET_ID,
        _intentAmount: _bigIntentTenth
      });

      // roll one epoch to generate different discounts
      _rollEpochs(1);

      // To convert all previous deposits to invoices
      _processDepositsAndInvoices(keccak256('DAI'));
    }

    // Create another 5 intents without discount
    for (uint256 _i; _i < 5; _i++) {
      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: sepoliaDAI,
        _assetDestination: bscDAI,
        _origin: ETHEREUM_SEPOLIA_ID,
        _destination: BSC_TESTNET_ID,
        _intentAmount: _bigIntentTenth
      });
    }

    // only 5 deposits because the previous 5 belongs to the current epoch
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 5, 'invalid length');

    // Create 5 deposits in the opposite direction
    for (uint256 _i; _i < 5; _i++) {
      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: bscDAI,
        _assetDestination: sepoliaDAI,
        _origin: BSC_TESTNET_ID,
        _destination: ETHEREUM_SEPOLIA_ID,
        _intentAmount: _bigIntentTenth
      });
    }

    _processDepositsAndInvoices(keccak256('DAI'));

    // the queue should have 0 invoices because epoch for the previous 10 was not closed
    (,,, _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlements for BSC testnet
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 5);
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // closing epoch to convert deposit to invoices
    _rollEpochs(1);
    _processDepositsAndInvoices(keccak256('DAI'));

    // the queue should have 5 invoices
    (,,, _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 5, 'invalid length');

    // Process settlements for SEPOLIA testnet
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 5);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});
  }
}
