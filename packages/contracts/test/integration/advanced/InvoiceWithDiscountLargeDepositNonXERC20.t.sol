// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';

import {Vm} from 'forge-std/Vm.sol';
import {console} from 'forge-std/console.sol';

import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';

import {ISettler} from 'interfaces/hub/ISettler.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract Invoice_WithDiscountNonXERC20_Integration is IntegrationBase {
  uint256 _invoiceSize = 10_000 * 1e6;
  uint256 _depositSize = _invoiceSize * 10;

  function test_DepositPurchasePowerCoversInvoiceSize() public {
    // Create big intent in sepolia
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _invoiceSize
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
        _intentAmount: _depositSize
      });
    }

    _processDepositsAndInvoices(keccak256('DAI'));

    // Process settlement for BSC testnet where the initial intent is settled
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // 100% of intent in deposits available for the epoch being settled
    uint256 _amountAfterFees = _invoiceSize - (_invoiceSize * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // 3 epochs elapsed, using _depositsAvailableForEpochSettled instead of _amountAfterFees because it's < than _amountToDiscount
    uint256 _rewardsForDepositors = _amountAfterFees * defaultDiscountPerEpoch * 2 / Common.DBPS_DENOMINATOR;

    uint256 _userSettlementAmount = _amountAfterFees - _rewardsForDepositors;

    assertEq(ERC20(address(bscDAI)).balanceOf(_user), _userSettlementAmount);
  }
}
