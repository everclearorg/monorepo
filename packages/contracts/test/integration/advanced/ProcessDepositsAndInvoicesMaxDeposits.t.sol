// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract ProcessDepositsAndInvoicesMaxDeposits_Integration is IntegrationBase {
  function test_ProcessDepositsAndInvoicesMaxDepositsParam() public {
    uint256 _intentAmount = 1000 * 1e6;

    // Create ten intents with different discounts and receive them in the hub
    for (uint256 _i; _i < 10; _i++) {
      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: sepoliaDAI,
        _assetDestination: bscDAI,
        _origin: ETHEREUM_SEPOLIA_ID,
        _destination: BSC_TESTNET_ID,
        _intentAmount: _intentAmount
      });

      // roll one epoch to generate different discounts
      _rollEpochs(1);
    }

    // To convert all previous deposits to invoices
    _processDepositsAndInvoices({_tickerHash: keccak256('DAI'), _maxEpochs: 0, _maxDeposits: 5, _maxInvoices: 0});

    // check that 6 deposits were processed, the first one was instantly processed when arrived to the hub
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 6, 'invalid length');

    // process the rest of deposits and invoices for all epochs
    _processDepositsAndInvoices(keccak256('DAI'));

    // check that all epochs, deposits and invoices were processed
    (,,, _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 10, 'invalid length');
  }
}
