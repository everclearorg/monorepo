// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract OneBigDepositFillsHalfOfInvoicesWithDiscount_Integration is IntegrationBase {
  function test_OneBigDepositFillsHalfOfInvoicesWithDiscount() public {
    // 100 DAI intent amount
    uint256 _intentAmount = 1000 * 1e6;
    for (uint256 _i = 1; _i <= 6; _i++) {
      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: sepoliaDAI,
        _assetDestination: bscDAI,
        _origin: ETHEREUM_SEPOLIA_ID,
        _destination: BSC_TESTNET_ID,
        _intentAmount: _intentAmount
      });
    }

    // close epoch to process deposits and invoices to generate discounts
    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    uint256 _depositsValueAfterFees =
      (_intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR)) * 3;
    uint256 _depositsValueAfterDiscount =
      _depositsValueAfterFees - (_depositsValueAfterFees * defaultDiscountPerEpoch / Common.DBPS_DENOMINATOR);

    // roll epoch to generate disconunt
    _rollEpochs(1);

    // user generates 1 deposit to cover the 3 invoices with discount with minimum amount of DAI to cover them after the discounts
    _createIntentAndReceiveInHub({
      _user: _generateAddress(),
      _assetOrigin: bscDAI,
      _assetDestination: sepoliaDAI,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _depositsValueAfterDiscount
    });

    _processDepositsAndInvoices(keccak256('DAI'));

    // the queue should have 3 invoices because half were filled
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 3, 'invalid length');

    // close epoch to process the last deposit
    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // the queue should still have 3 invoices because there were liquidity for the last deposit
    (,,, _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 3, 'invalid length');

    // Process settlements for BSC testnet
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 3);
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // Process settlements for Ethereum Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});
  }
}
