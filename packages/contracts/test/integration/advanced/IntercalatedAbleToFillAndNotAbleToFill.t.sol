// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract IntercalatedAbleToFillAndNotAbleToFill_Integration is IntegrationBase {
  function test_Intercalated_AbleToFill_And_NotAbleToFill() public {
    // One thousand DAI intent amount
    uint256 _abeToFillAmount = 1000 * 1e6;

    // 100M DAI intent amount
    uint256 _notAbleToFillAmount = 100_000_000 * 1e6;

    // create intercalated deposits that can and can't be filled
    for (uint256 _i = 1; _i <= 6; _i++) {
      uint256 _amount = _i % 2 == 0 ? _abeToFillAmount : _notAbleToFillAmount;

      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: sepoliaDAI,
        _assetDestination: bscDAI,
        _origin: ETHEREUM_SEPOLIA_ID,
        _destination: BSC_TESTNET_ID,
        _intentAmount: _amount
      });
    }

    // close epoch to process deposits and invoices
    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // the queue should have 6 invoices
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 6, 'invalid length');

    uint256 _amountToFillEvenDeposits =
      _abeToFillAmount - (_abeToFillAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // 3 invoices are created to fill the even deposits
    for (uint256 _i = 1; _i <= 3; _i++) {
      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: bscDAI,
        _assetDestination: sepoliaDAI,
        _origin: BSC_TESTNET_ID,
        _destination: ETHEREUM_SEPOLIA_ID,
        _intentAmount: _amountToFillEvenDeposits
      });
    }

    // close epoch to and process deposits and invoices to avoid discount being filled in a different epoch of the deposit
    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // the queue should have 3 invoices, the 3 left are the ones of 100M DAI from whales
    (,,, _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 3, 'invalid length');

    // Process settlements for BSC testnet
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 3);
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // Process settlements for Ethereum Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 3);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});
  }
}
