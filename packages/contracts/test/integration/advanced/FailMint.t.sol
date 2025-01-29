// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract FailMint_Integration is IntegrationBase {
  function test_XERC20_MintReverts() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);

    // 10 weth deposit
    uint256 _intentAmount = 10 * 1e18;
    XERC20(address(sepoliaXToken)).mockMint(_user, _intentAmount);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    // Create an intent with the smallest amount in sepolia
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount
    });

    // In hub process deposits and invoices and the second intent is settled
    _processDepositsAndInvoices(keccak256('TXT'));

    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // mock transfer failure in sepolia
    _switchFork(BSC_TESTNET_FORK);
    XERC20(address(bscXToken)).mockRevertMint(true);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // assert balance is 0
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), 0);

    // assert virtual balance of xerc20 module is incremented
    assertEq(_getTokenMintableByUserInBscTestnet(_user, address(bscXToken)), _amountAfterFees);
  }

  function test_XERC20_MintNotReverts() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);

    // 10 weth deposit
    uint256 _intentAmount = 10 * 1e18;
    XERC20(address(sepoliaXToken)).mockMint(_user, _intentAmount);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    // Create an intent with the smallest amount in sepolia
    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount
    });

    // In hub process deposits and invoices and the second intent is settled
    _processDepositsAndInvoices(keccak256('TXT'));

    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // mock transfer failure in sepolia
    _switchFork(BSC_TESTNET_FORK);
    XERC20(address(bscXToken)).mockRevertMint(false);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // assert balance is 0
    assertEq(ERC20(address(bscXToken)).balanceOf(_user), _amountAfterFees);

    // assert virtual balance of xerc20 module is incremented
    assertEq(_getTokenMintableByUserInBscTestnet(_user, address(bscXToken)), 0);
  }
}
