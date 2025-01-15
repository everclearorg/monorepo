// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {TestWETH} from 'test/utils/TestWETH.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract TransferFail_Integration is IntegrationBase {
  function test_NonXERC20_TransferFails() public {
    // 10 weth deposit
    uint256 _intentAmount = 10 * 1e18;

    // Create an intent with the smallest amount in sepolia
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaWETH,
      _assetDestination: bscWETH,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount
    });

    // Create an intent with the smallest amount in bsc
    _createIntentAndReceiveInHub({
      _user: _user2,
      _assetOrigin: bscWETH,
      _assetDestination: sepoliaWETH,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _intentAmount
    });

    // In hub process deposits and invoices and the first intent is settled
    _processDepositsAndInvoices(keccak256('WETH'));

    // roll 1 epoch to close epoch and convert second deposit into settlement
    _rollEpochs(1);

    // In hub process deposits and invoices and the second intent is settled
    _processDepositsAndInvoices(keccak256('WETH'));

    // process settlement messages for sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);

    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // mock transfer failure in sepolia
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    TestWETH(address(sepoliaWETH)).mockFailTransfer(true);

    // deliver the settlement message to SEPOLIA
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // assert balance is 0
    assertEq(_getTokenBalanceInSepolia(_user2, address(sepoliaWETH)), 0);

    // assert virtual balance is incremented
    assertEq(_getTokenVirtualBalanceInSepolia(_user2, address(sepoliaWETH)), _amountAfterFees);

    // mock transfer failure in sepolia
    _switchFork(BSC_TESTNET_FORK);
    TestWETH(address(bscWETH)).mockFailTransfer(true);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // assert balance is 0
    assertEq(ERC20(address(bscWETH)).balanceOf(_user), 0);

    // assert virtual balance is incremented
    assertEq(_getTokenVirtualBalanceInBscTestnet(_user, address(bscWETH)), _amountAfterFees);
  }

  function test_NonXERC20_TransferReverts() public {
    // 10 weth deposit
    uint256 _intentAmount = 10 * 1e18;

    // Create an intent with the smallest amount in sepolia
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaWETH,
      _assetDestination: bscWETH,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount
    });

    // Create an intent with the smallest amount in bsc
    _createIntentAndReceiveInHub({
      _user: _user2,
      _assetOrigin: bscWETH,
      _assetDestination: sepoliaWETH,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _intentAmount
    });

    // In hub process deposits and invoices and the first intent is settled
    _processDepositsAndInvoices(keccak256('WETH'));

    // roll 1 epoch to close epoch and convert second deposit into settlement
    _rollEpochs(1);

    // In hub process deposits and invoices and the second intent is settled
    _processDepositsAndInvoices(keccak256('WETH'));

    // process settlement messages for sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);

    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // mock transfer failure in sepolia
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    TestWETH(address(sepoliaWETH)).mockRevertTransfer(true);

    // deliver the settlement message to SEPOLIA
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // assert balance is 0
    assertEq(_getTokenBalanceInSepolia(_user2, address(sepoliaWETH)), 0);

    // assert virtual balance is incremented
    assertEq(_getTokenVirtualBalanceInSepolia(_user2, address(sepoliaWETH)), _amountAfterFees);

    // mock transfer failure in sepolia
    _switchFork(BSC_TESTNET_FORK);
    TestWETH(address(bscWETH)).mockRevertTransfer(true);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // assert balance is 0
    assertEq(ERC20(address(bscWETH)).balanceOf(_user), 0);

    // assert virtual balance is incremented
    assertEq(_getTokenVirtualBalanceInBscTestnet(_user, address(bscWETH)), _amountAfterFees);
  }
}
