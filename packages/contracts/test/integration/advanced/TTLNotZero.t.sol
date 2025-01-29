// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';
import {Constants} from 'test/utils/Constants.sol';
import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

contract TTLNotZero_Integration is IntegrationBase {
  function test_ExpiredInvoiced() public {
    _unifyUnixBlocktimestampInChains(10_000);

    // One thousand DAI deposit
    uint256 _intentAmount = 1000 * 1e6;

    // User creates intent to be filled by solver
    (bytes32 _intentId,) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount,
      _ttl: 24 hours
    });

    // close epoch
    _rollEpochs(1);
    _processDepositsAndInvoices(keccak256('DAI'));

    // No solver filled and intent expired
    _elapseTimeInChains(24 hours + hub.expiryTimeBuffer() + 1);

    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = _intentId;

    // expired intent is called
    hub.handleExpiredIntents(_intentIds);

    // check that invoice is created
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 1);
  }

  function test_ExpiredAndSettledWithSlowPath() public {
    _unifyUnixBlocktimestampInChains(10_000);

    // One thousand DAI deposit
    uint256 _intentAmount = 1000 * 1e6;
    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // Guarantee liquidity in bsc
    _createIntentAndReceiveInHub({
      _user: _user2,
      _assetOrigin: bscDAI,
      _assetDestination: sepoliaDAI,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _amountAfterFees
    });

    // User creates intent to be filled by solver
    (bytes32 _intentId,) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount,
      _ttl: 24 hours
    });

    // close epoch
    _rollEpochs(1);
    _processDepositsAndInvoices(keccak256('DAI'));

    // No solver filled and intent expired
    _elapseTimeInChains(24 hours + hub.expiryTimeBuffer() + 1);

    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = _intentId;

    // expired intent is called
    hub.handleExpiredIntents(_intentIds);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    // deliver the settlement message to BSC
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // check amount of settlement in bsc
    assertEq(ERC20(address(bscDAI)).balanceOf(_user), _amountAfterFees);
  }

  function test_WithRewardsExpiredAndSettledWithSlowPath_ProcessBeforeExpired() public {
    _unifyUnixBlocktimestampInChains(10_000);

    // One thousand DAI deposit
    uint256 _intentAmount = 1000 * 1e6;
    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // Guarantee liquidity in bsc
    _createIntentAndReceiveInHub({
      _user: _user2,
      _assetOrigin: bscDAI,
      _assetDestination: sepoliaDAI,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _intentAmount
    });

    // elapse epoch to generate discount and process invoices
    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // User creates intent to be filled by solver, amount is to cover just the first deposit
    _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _amountAfterFees,
      _ttl: 24 hours
    });

    // buy invoice and generates rewards
    _processDepositsAndInvoices(keccak256('DAI'));

    // No solver filled and intent expired, after process
    _elapseTimeInChains(24 hours + hub.expiryTimeBuffer() + 1);

    // close epoch and convert last deposit to settlement, not necessary to call handle expired intents
    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // Process settlements for Ethereum Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    uint256 _discount = _amountAfterFees * defaultDiscountPerEpoch / Common.DBPS_DENOMINATOR;

    // check amount of settlement in sepolia
    assertEq(_getTokenBalanceInSepolia(_user2, address(sepoliaDAI)), _amountAfterFees - _discount);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    uint256 _amountAfterFeesDeposit2 =
      _amountAfterFees - (_amountAfterFees * totalProtocolFees / Common.DBPS_DENOMINATOR);

    uint256 _amountAndRewards =
      _amountAfterFeesDeposit2 + (_amountAfterFees * defaultDiscountPerEpoch / Common.DBPS_DENOMINATOR);

    // deliver the settlement message to BSC where the
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // check balance of user in bsc
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscDAI)), _amountAndRewards);
  }

  function test_WithRewardsExpiredAndSettledWithSlowPath_ProcessAfterExpired() public {
    _unifyUnixBlocktimestampInChains(10_000);

    // One thousand DAI deposit
    uint256 _intentAmount = 1000 * 1e6;
    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // Guarantee liquidity in bsc
    _createIntentAndReceiveInHub({
      _user: _user2,
      _assetOrigin: bscDAI,
      _assetDestination: sepoliaDAI,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _intentAmount
    });

    // elapse epoch to generate discount and process invoices
    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // User creates intent to be filled by solver, amount is to cover just the first deposit
    _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _amountAfterFees,
      _ttl: 24 hours
    });

    // No solver filled and intent expired, before process
    _elapseTimeInChains(24 hours + hub.expiryTimeBuffer() + 1);

    // buy invoice and generates rewards, process after expired
    _processDepositsAndInvoices(keccak256('DAI'));

    // close epoch and convert last deposit to settlement, not necessary to call handle expired intents
    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // call handle expired intents not needed

    // Process settlements for Ethereum Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    uint256 _discount = _amountAfterFees * defaultDiscountPerEpoch / Common.DBPS_DENOMINATOR;

    // check amount of settlement in sepolia
    assertEq(_getTokenBalanceInSepolia(_user2, address(sepoliaDAI)), _amountAfterFees - _discount);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    uint256 _amountAfterFeesDeposit2 =
      _amountAfterFees - (_amountAfterFees * totalProtocolFees / Common.DBPS_DENOMINATOR);

    uint256 _amountAndRewards =
      _amountAfterFeesDeposit2 + (_amountAfterFees * defaultDiscountPerEpoch / Common.DBPS_DENOMINATOR);

    // deliver the settlement message to BSC where the
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // check balance of user in bsc
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscDAI)), _amountAndRewards);
  }

  function test_WithRewardsExpiredAndInvoiced() public {
    _unifyUnixBlocktimestampInChains(10_000);

    // One thousand DAI deposit
    uint256 _intentAmount = 1000 * 1e6;
    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // Guarantee liquidity in bsc
    _createIntentAndReceiveInHub({
      _user: _user2,
      _assetOrigin: bscDAI,
      _assetDestination: sepoliaDAI,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _intentAmount
    });

    // elapse epoch to generate discount and process invoices
    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // User creates intent to be filled by solver, amount is to cover just the first deposit
    _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount * 10,
      _ttl: 24 hours
    });

    // buy invoice and generates rewards
    _processDepositsAndInvoices(keccak256('DAI'));

    // No solver filled and intent expired, after process
    _elapseTimeInChains(24 hours + hub.expiryTimeBuffer() + 1);

    // close epoch and convert last deposit to settlement, not necessary to call handle expired intents
    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // Process settlements for Ethereum Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    uint256 _discount = _amountAfterFees * defaultDiscountPerEpoch / Common.DBPS_DENOMINATOR;

    // check amount of settlement in sepolia
    assertEq(_getTokenBalanceInSepolia(_user2, address(sepoliaDAI)), _amountAfterFees - _discount);

    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));

    // check that invoice is created
    assertEq(_length, 1);
  }

  function test_xERC20_SolverFills() public {
    _unifyUnixBlocktimestampInChains(10_000);

    // One thousand DAI deposit
    uint256 _intentAmount = 1000 * 1e6;
    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    _mockMintAndApprove({
      _token: address(sepoliaXToken),
      _account: _user,
      _chainId: ETHEREUM_SEPOLIA_ID,
      _amount: _intentAmount
    });

    // User creates intent to be filled by solver, amount is to cover just the first deposit
    (bytes32 _intentId, IEverclear.Intent memory _intent) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount,
      _ttl: 24 hours
    });

    uint256 _amountAfterProtocolAndSolverFees =
      _intentAmount - (_intentAmount * _intent.maxFee / Common.DBPS_DENOMINATOR);

    _fillIntentAndReceiveInHub({
      _intentId: _intentId,
      _intent: _intent,
      _assetDestination: IERC20(address(bscXToken)),
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount,
      _solver: _solver
    });

    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // check amount of settlement in sepolia for solver
    assertEq(_getTokenBalanceInSepolia(_solver, address(sepoliaXToken)), _amountAfterFees);

    // check amount of settlement in bsc for user
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscXToken)), _amountAfterProtocolAndSolverFees);
  }

  function test_xERC20_ExpiresAndGetSlowPathSettled() public {
    _unifyUnixBlocktimestampInChains(10_000);

    // One thousand DAI deposit
    uint256 _intentAmount = 1000 * 1e6;
    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    _mockMintAndApprove({
      _token: address(sepoliaXToken),
      _account: _user,
      _chainId: ETHEREUM_SEPOLIA_ID,
      _amount: _intentAmount
    });

    // User creates intent to be filled by solver, amount is to cover just the first deposit
    (bytes32 _intentId,) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount,
      _ttl: 24 hours
    });

    _elapseTimeInChains(24 hours + hub.expiryTimeBuffer() + 1);

    bytes32[] memory _intentIds = new bytes32[](1);
    _intentIds[0] = _intentId;
    _switchHubFork();
    hub.handleExpiredIntents(_intentIds);

    // process settlement messages for bsc
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);

    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // check amount of settlement in bsc for user
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscXToken)), _amountAfterFees);
  }
}
