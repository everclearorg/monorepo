// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ERC20 } from 'test/utils/TestXToken.sol';
import { Constants as Common } from 'contracts/common/Constants.sol';
import { IntegrationBase } from 'test/integration/IntegrationBase.t.sol';

contract InvoiceViaFeeAdapter_WithDiscountAndRewardsTTLZeroNonXERC20_Integration is IntegrationBase {
  // Big intent amount 100k dai
  uint256 internal _bigIntentAmount = 100_000 * 1e6;
  uint256 internal _bigIntentTenth = _bigIntentAmount / 10;

  // 1 % fee
  uint256 internal _bigFeeAmount = (_bigIntentAmount * 99_000) / 100_000;
  uint256 internal _bigFeeTenth = _bigFeeAmount / 10;

  function test_InvoiceViaFeeAdapterWithDiscountAndRewards_NonXERC20_FeeInTransacting() public {
    // Create new intent via fee adapter
    _createIntentWithFeeAdapterAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _bigIntentAmount,
      _tokenFee: _bigFeeAmount,
      _ethFee: 0
    });

    // Roll two epochs
    _rollEpochs(2);

    // Create 3 intent that fills 30% of the intent
    for (uint256 i; i < 3; i++) {
      _createIntentWithFeeAdapterAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: bscDAI,
        _assetDestination: sepoliaDAI,
        _origin: BSC_TESTNET_ID,
        _destination: ETHEREUM_SEPOLIA_ID,
        _intentAmount: _bigIntentTenth,
        _tokenFee: _bigFeeTenth,
        _ethFee: 0
      });
    }

    // Roll one more epoch
    _rollEpochs(1);

    // Create 7 small intents that fill the remaining 70% of the intent
    for (uint256 i; i < 7; i++) {
      _createIntentWithFeeAdapterAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: bscDAI,
        _assetDestination: sepoliaDAI,
        _origin: BSC_TESTNET_ID,
        _destination: ETHEREUM_SEPOLIA_ID,
        _intentAmount: _bigIntentTenth,
        _tokenFee: _bigFeeTenth,
        _ethFee: 0
      });
    }

    _processDepositsAndInvoices(keccak256('DAI'));

    // Process settlement queue and settlement message for the destination chain
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    _processSettlementMessage({ _destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc });

    // 70% of big intent in deposits available for the epoch being settled
    uint256 _depositsAvailableForEpochSettled = _bigIntentTenth * 7;
    uint256 _amountAfterFees = _bigIntentAmount - ((_bigIntentAmount * totalProtocolFees) / Common.DBPS_DENOMINATOR);

    // 3 epochs elapsed, using _depositsAvailableForEpochSettled instead of _amountAfterFees because it's < than _amountToDiscount
    uint256 _rewardsForDepositors = (_depositsAvailableForEpochSettled * defaultDiscountPerEpoch * 3) /
      Common.DBPS_DENOMINATOR;

    uint256 _userSettlementAmount = _amountAfterFees - _rewardsForDepositors;

    assertEq(ERC20(address(bscDAI)).balanceOf(_user), _userSettlementAmount);

    // Process settlement for Sepolia testnet where the small intents are being settled
    _rollEpochs(1);
    _processDepositsAndInvoices(keccak256('DAI'));

    uint256 _depositorsIndividualRewards = _rewardsForDepositors / 7;
    uint256 _intentTenthAfterFees = _bigIntentTenth - ((_bigIntentTenth * totalProtocolFees) / Common.DBPS_DENOMINATOR);

    // we know that the first 3 intents in bsc testnet are settled
    uint256 _intentsWithRewardsThatCanBeSettled = (_bigIntentAmount - (3 * _intentTenthAfterFees)) /
      (_intentTenthAfterFees + _depositorsIndividualRewards);

    // zero sum check
    assertEq(_intentsWithRewardsThatCanBeSettled, 7, 'invalid intents with rewards that can be settled');

    (, , , uint256 _length) = hub.invoices(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlement for SEPOLIA testnet where the small intents are being settled
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 10);

    // deliver the settlement message to SEPOLIA
    _processSettlementMessage({
      _destination: ETHEREUM_SEPOLIA_ID,
      _settlementMessageBody: _settlementMessageBodySepolia
    });

    // Check the settlement of the small intents with rewards minus fees
    // We check the settlements of the small intents with rewards
    for (uint256 _i = 4; _i <= 10; _i++) {
      assertApproxEqRel(
        ERC20(address(sepoliaDAI)).balanceOf(vm.addr(_i)),
        _intentTenthAfterFees + _depositorsIndividualRewards,
        0.01e18
      );
    }

    // We know _bigFeeAmount would be applied on BSC and should be in fee recipient (across 1x large intent)
    _switchFork(BSC_TESTNET_FORK);
    assertEq(ERC20(address(bscDAI)).balanceOf(bscFeeAdapter.feeRecipient()), _bigFeeAmount);

    // We know _bigFeeAmount should be applied on Sepolia and should be in fee recipient (across 10x small intents)
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    assertEq(ERC20(address(sepoliaDAI)).balanceOf(sepoliaFeeAdapter.feeRecipient()), _bigFeeAmount);
  }

  function test_InvoiceViaFeeAdapterWithDiscountAndRewards_NonXERC20_FeeInEth() public {
    // Create new intent via fee adapter
    _createIntentWithFeeAdapterAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _bigIntentAmount,
      _tokenFee: 0,
      _ethFee: _bigFeeAmount
    });

    // Roll two epochs
    _rollEpochs(2);

    // Create 3 intent that fills 30% of the intent
    for (uint256 i; i < 3; i++) {
      _createIntentWithFeeAdapterAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: bscDAI,
        _assetDestination: sepoliaDAI,
        _origin: BSC_TESTNET_ID,
        _destination: ETHEREUM_SEPOLIA_ID,
        _intentAmount: _bigIntentTenth,
        _tokenFee: 0,
        _ethFee: _bigFeeTenth
      });
    }

    // Roll one more epoch
    _rollEpochs(1);

    // Create 7 small intents that fill the remaining 70% of the intent
    for (uint256 i; i < 7; i++) {
      _createIntentWithFeeAdapterAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: bscDAI,
        _assetDestination: sepoliaDAI,
        _origin: BSC_TESTNET_ID,
        _destination: ETHEREUM_SEPOLIA_ID,
        _intentAmount: _bigIntentTenth,
        _tokenFee: 0,
        _ethFee: _bigFeeTenth
      });
    }

    _processDepositsAndInvoices(keccak256('DAI'));

    // Process settlement queue and settlement message for the destination chain
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    _processSettlementMessage({ _destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc });

    // 70% of big intent in deposits available for the epoch being settled
    uint256 _depositsAvailableForEpochSettled = _bigIntentTenth * 7;
    uint256 _amountAfterFees = _bigIntentAmount - ((_bigIntentAmount * totalProtocolFees) / Common.DBPS_DENOMINATOR);

    // 3 epochs elapsed, using _depositsAvailableForEpochSettled instead of _amountAfterFees because it's < than _amountToDiscount
    uint256 _rewardsForDepositors = (_depositsAvailableForEpochSettled * defaultDiscountPerEpoch * 3) /
      Common.DBPS_DENOMINATOR;

    uint256 _userSettlementAmount = _amountAfterFees - _rewardsForDepositors;

    assertEq(ERC20(address(bscDAI)).balanceOf(_user), _userSettlementAmount);

    // Process settlement for Sepolia testnet where the small intents are being settled
    _rollEpochs(1);
    _processDepositsAndInvoices(keccak256('DAI'));

    uint256 _depositorsIndividualRewards = _rewardsForDepositors / 7;
    uint256 _intentTenthAfterFees = _bigIntentTenth - ((_bigIntentTenth * totalProtocolFees) / Common.DBPS_DENOMINATOR);

    // we know that the first 3 intents in bsc testnet are settled
    uint256 _intentsWithRewardsThatCanBeSettled = (_bigIntentAmount - (3 * _intentTenthAfterFees)) /
      (_intentTenthAfterFees + _depositorsIndividualRewards);

    // zero sum check
    assertEq(_intentsWithRewardsThatCanBeSettled, 7, 'invalid intents with rewards that can be settled');

    (, , , uint256 _length) = hub.invoices(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlement for SEPOLIA testnet where the small intents are being settled
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 10);

    // deliver the settlement message to SEPOLIA
    _processSettlementMessage({
      _destination: ETHEREUM_SEPOLIA_ID,
      _settlementMessageBody: _settlementMessageBodySepolia
    });

    // Check the settlement of the small intents with rewards minus fees
    // We check the settlements of the small intents with rewards
    for (uint256 _i = 4; _i <= 10; _i++) {
      assertApproxEqRel(
        ERC20(address(sepoliaDAI)).balanceOf(vm.addr(_i)),
        _intentTenthAfterFees + _depositorsIndividualRewards,
        0.01e18
      );
    }

    // We know _bigFeeAmount would be sent in ETH on BSC
    _switchFork(BSC_TESTNET_FORK);
    assertEq(bscFeeAdapter.feeRecipient().balance, _bigFeeAmount);

    // We know _bigFeeAmount should be sent in ETH on Sepolia
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    assertEq(sepoliaFeeAdapter.feeRecipient().balance, _bigFeeAmount);
  }

  function test_InvoiceViaFeeAdapterWithDiscountAndRewards_NonXERC20_FeeInTransactingAndEth() public {
    // Create new intent via fee adapter
    _createIntentWithFeeAdapterAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _bigIntentAmount,
      _tokenFee: _bigFeeAmount,
      _ethFee: _bigFeeAmount
    });

    // Roll two epochs
    _rollEpochs(2);

    // Create 3 intent that fills 30% of the intent
    for (uint256 i; i < 3; i++) {
      _createIntentWithFeeAdapterAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: bscDAI,
        _assetDestination: sepoliaDAI,
        _origin: BSC_TESTNET_ID,
        _destination: ETHEREUM_SEPOLIA_ID,
        _intentAmount: _bigIntentTenth,
        _tokenFee: _bigFeeTenth,
        _ethFee: _bigFeeTenth
      });
    }

    // Roll one more epoch
    _rollEpochs(1);

    // Create 7 small intents that fill the remaining 70% of the intent
    for (uint256 i; i < 7; i++) {
      _createIntentWithFeeAdapterAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: bscDAI,
        _assetDestination: sepoliaDAI,
        _origin: BSC_TESTNET_ID,
        _destination: ETHEREUM_SEPOLIA_ID,
        _intentAmount: _bigIntentTenth,
        _tokenFee: _bigFeeTenth,
        _ethFee: _bigFeeTenth
      });
    }

    _processDepositsAndInvoices(keccak256('DAI'));

    // Process settlement queue and settlement message for the destination chain
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    _processSettlementMessage({ _destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc });

    // 70% of big intent in deposits available for the epoch being settled
    uint256 _depositsAvailableForEpochSettled = _bigIntentTenth * 7;
    uint256 _amountAfterFees = _bigIntentAmount - ((_bigIntentAmount * totalProtocolFees) / Common.DBPS_DENOMINATOR);

    // 3 epochs elapsed, using _depositsAvailableForEpochSettled instead of _amountAfterFees because it's < than _amountToDiscount
    uint256 _rewardsForDepositors = (_depositsAvailableForEpochSettled * defaultDiscountPerEpoch * 3) /
      Common.DBPS_DENOMINATOR;

    uint256 _userSettlementAmount = _amountAfterFees - _rewardsForDepositors;

    assertEq(ERC20(address(bscDAI)).balanceOf(_user), _userSettlementAmount);

    // Process settlement for Sepolia testnet where the small intents are being settled
    _rollEpochs(1);
    _processDepositsAndInvoices(keccak256('DAI'));

    uint256 _depositorsIndividualRewards = _rewardsForDepositors / 7;
    uint256 _intentTenthAfterFees = _bigIntentTenth - ((_bigIntentTenth * totalProtocolFees) / Common.DBPS_DENOMINATOR);

    // we know that the first 3 intents in bsc testnet are settled
    uint256 _intentsWithRewardsThatCanBeSettled = (_bigIntentAmount - (3 * _intentTenthAfterFees)) /
      (_intentTenthAfterFees + _depositorsIndividualRewards);

    // zero sum check
    assertEq(_intentsWithRewardsThatCanBeSettled, 7, 'invalid intents with rewards that can be settled');

    (, , , uint256 _length) = hub.invoices(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlement for SEPOLIA testnet where the small intents are being settled
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 10);

    // deliver the settlement message to SEPOLIA
    _processSettlementMessage({
      _destination: ETHEREUM_SEPOLIA_ID,
      _settlementMessageBody: _settlementMessageBodySepolia
    });

    // Check the settlement of the small intents with rewards minus fees
    // We check the settlements of the small intents with rewards
    for (uint256 _i = 4; _i <= 10; _i++) {
      assertApproxEqRel(
        ERC20(address(sepoliaDAI)).balanceOf(vm.addr(_i)),
        _intentTenthAfterFees + _depositorsIndividualRewards,
        0.01e18
      );
    }

    // We know _bigFeeAmount would be applied on BSC and should be in fee recipient (across 1x large intent)
    _switchFork(BSC_TESTNET_FORK);
    assertEq(ERC20(address(bscDAI)).balanceOf(bscFeeAdapter.feeRecipient()), _bigFeeAmount);
    assertEq(bscFeeAdapter.feeRecipient().balance, _bigFeeAmount);

    // We know _bigFeeAmount should be applied on Sepolia and should be in fee recipient (across 10x small intents)
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    assertEq(ERC20(address(sepoliaDAI)).balanceOf(sepoliaFeeAdapter.feeRecipient()), _bigFeeAmount);
    assertEq(sepoliaFeeAdapter.feeRecipient().balance, _bigFeeAmount);
  }
}
