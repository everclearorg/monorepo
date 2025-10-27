// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract ChangeUserPreferredDomainForSettle_Integration is IntegrationBase {
  using TypeCasts for address;

  function test_InvoiceWithDiscount_UserChangesHisPreferredDomainToBeSettled() public {
    // 10k DAI intent amount
    uint256 _intentAmount = 10_000 * 1e6;
    uint256 _amountAfterProtocolFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // Create intent in sepolia
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount
    });

    // elapse epochs to generate big discount
    _rollEpochs(10);

    // Fake xToken adopted in sepolia as it was another domain with xERC20 strategy which user not yet prefers
    IHubStorage.AssetConfig memory _adoptedForAsset = IHubStorage.AssetConfig({
      tickerHash: keccak256('DAI'),
      adopted: address(sepoliaXToken).toBytes32(),
      domain: ETHEREUM_SEPOLIA_ID,
      approval: true,
      strategy: IEverclear.Strategy.XERC20
    });
    _setAdpotedForAsset(_adoptedForAsset);

    // call to process deposits and invoices just to test that invoice cannot be settled because of lack of liquidity
    _processDepositsAndInvoices(keccak256('DAI'));

    // check that invoice is not settled
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 1, 'invalid length');

    // User changes his preferred domain to be settled
    uint32[] memory _preferredDomains = new uint32[](2);
    _preferredDomains[0] = ETHEREUM_SEPOLIA_ID;
    _preferredDomains[1] = BSC_TESTNET_ID;
    _setUserSupportedDomains(_user, _preferredDomains);

    // now that the user supports a domain with xERC20 strategy, the invoice can be settled since no liquidity is required and the asset is minted in destination with no discount
    _processDepositsAndInvoices(keccak256('DAI'));

    // check that invoice was settled
    (,,, _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlements for SEPOLIA testnet
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // Check that no discount was applied and only protocol fees were charged, with the decimals of sepolia x tokens
    assertEq(
      _getTokenBalanceInSepolia(_user, address(sepoliaXToken)), _amountAfterProtocolFees * 1e12, 'invalid balance'
    );
  }
}
