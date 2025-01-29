// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract InvoiceWithDiscountAndRewardsTTLZero_Integration is IntegrationBase {
  // Big intent amount 100k dai
  uint256 _bigIntentAmount = 100_000 * 1e6;
  uint256 _bigIntentTenth = _bigIntentAmount / 10;

  function test_InvoiceWithDiscountAndRewards_TTLZero() public {
    // Create big intent in sepolia
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _bigIntentAmount
    });

    // roll two epochs
    _rollEpochs(2);

    // create 3 small intents in bsc testnet equal to 30% of big intent
    for (uint256 i; i < 3; i++) {
      _createIntentAndReceiveInHub({
        _user: _generateAddress(),
        _assetOrigin: bscDAI,
        _assetDestination: sepoliaDAI,
        _origin: BSC_TESTNET_ID,
        _destination: ETHEREUM_SEPOLIA_ID,
        _intentAmount: _bigIntentTenth
      });
    }

    // elapse one more epoch
    _rollEpochs(1);

    // create 7 small intents in bsc testnet equal to 70% of big intent
    for (uint256 i; i < 7; i++) {
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

    // Process settlement for BSC testnet where the big intent is settled
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // 70% of big intent in deposits available for the epoch being settled
    uint256 _depositsAvailableForEpochSettled = _bigIntentTenth * 7;
    uint256 _amountAfterFees = _bigIntentAmount - (_bigIntentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // 3 epochs elapsed, using _depositsAvailableForEpochSettled instead of _amountAfterFees because it's < than _amountToDiscount
    uint256 _rewardsForDepositors =
      _depositsAvailableForEpochSettled * defaultDiscountPerEpoch * 3 / Common.DBPS_DENOMINATOR;

    uint256 _userSettlementAmount = _amountAfterFees - _rewardsForDepositors;

    assertEq(ERC20(address(bscDAI)).balanceOf(_user), _userSettlementAmount);

    // Process settlement for SEPOLIA testnet where the small intents are being settled
    // close epoch
    _rollEpochs(1);
    _processDepositsAndInvoices(keccak256('DAI'));

    uint256 _depositorsIndividualRewards = _rewardsForDepositors / 7;
    uint256 _intentTenthAfterFees = _bigIntentTenth - (_bigIntentTenth * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // we know that the first 3 intents in bsc testnet are settled
    uint256 _intentsWithRewardsThatCanBeSettled =
      (_bigIntentAmount - (3 * _intentTenthAfterFees)) / (_intentTenthAfterFees + _depositorsIndividualRewards);

    // zero sum check
    assertEq(_intentsWithRewardsThatCanBeSettled, 7, 'invalid intents with rewards that can be settled');

    (bytes32 _head, bytes32 _tail, uint256 _nonce, uint256 _length) = hub.invoices(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlement for SEPOLIA testnet where the small intents are being settled
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 10);

    // deliver the settlement message to SEPOLIA
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // We chech the settlements of the small intents with and without rewards
    for (uint256 _i = 1; _i <= 3; _i++) {
      assertEq(ERC20(address(sepoliaDAI)).balanceOf(vm.addr(_i)), _intentTenthAfterFees);
    }

    // We check the settlements of the small intents with rewards
    for (uint256 _i = 4; _i <= 10; _i++) {
      assertApproxEqRel(
        ERC20(address(sepoliaDAI)).balanceOf(vm.addr(_i)), _intentTenthAfterFees + _depositorsIndividualRewards, 0.01e18
      );
    }
  }
}
