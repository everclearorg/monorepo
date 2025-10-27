// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract FeeVaultClaims_Integration is IntegrationBase {
  function test_FeeVaultClaims() public {
    uint256 _intentAmount = 1000 * 1e6;
    for (uint256 _i; _i < 10; _i++) {
      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: sepoliaDAI,
        _assetDestination: bscDAI,
        _origin: ETHEREUM_SEPOLIA_ID,
        _destination: BSC_TESTNET_ID,
        _intentAmount: _intentAmount
      });

      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: bscDAI,
        _assetDestination: sepoliaDAI,
        _origin: BSC_TESTNET_ID,
        _destination: ETHEREUM_SEPOLIA_ID,
        _intentAmount: _intentAmount
      });
    }

    _processDepositsAndInvoices(keccak256('DAI'));

    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));

    assertEq(_length, 0);

    uint32[] memory _claimFeesDestinations1 = new uint32[](1);
    _claimFeesDestinations1[0] = ETHEREUM_SEPOLIA_ID;

    // dai has 6 decimals, in the hub all amounts are in 1e18, so to get the fees we need to multiply by 1e12
    uint256 _feesRecipient1TotalFees = _intentAmount * 20 * 1000 * 1e12 / Constants.DBPS_DENOMINATOR;

    _withdrawFees({
      _tickerHash: keccak256('DAI'),
      _withdrawer: _feeRecipient,
      _recipient: _feeRecipient,
      _amount: _feesRecipient1TotalFees,
      _destinations: _claimFeesDestinations1
    });

    // Process settlements for SEPOLIA testnet
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // amount is denormalized to 6 decimals again dividing by 1e12
    assertEq(
      _getTokenBalanceInSepolia(_feeRecipient, address(sepoliaDAI)), _feesRecipient1TotalFees / 1e12, 'invalid balance'
    );

    // dai has 6 decimals, in the hub all amounts are in 1e18, so to get the fees we need to multiply by 1e12
    uint256 _feesRecipient2TotalFees = _intentAmount * 20 * 2000 * 1e12 / Constants.DBPS_DENOMINATOR;

    uint32[] memory _claimFeesDestinations2 = new uint32[](1);
    _claimFeesDestinations2[0] = BSC_TESTNET_ID;

    _withdrawFees({
      _tickerHash: keccak256('DAI'),
      _withdrawer: _feeRecipient2,
      _recipient: _feeRecipient2,
      _amount: _feesRecipient2TotalFees,
      _destinations: _claimFeesDestinations2
    });

    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 2);
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // amount is denormalized to 6 decimals again dividing by 1e12
    assertEq(
      _getTokenBalanceInBscTestnet(_feeRecipient2, address(bscDAI)), _feesRecipient2TotalFees / 1e12, 'invalid balance'
    );
  }
}
