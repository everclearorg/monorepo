// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

import {TestDAI} from 'test/utils/TestDAI.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';

import {Constants} from 'test/utils/Constants.sol';

contract DecimalsTests_Integration is IntegrationBase {
  function test_NonXERC20_12_DecimalsOrigin_6_DecimalsDestination_TTLZero() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    TestDAI(address(sepoliaDAI)).mockDecimals(12);

    _switchFork(BSC_TESTNET_FORK);
    TestDAI(address(bscDAI)).mockDecimals(6);

    // create intent amount in origin with the value of 1000 thousand dollars in sepolia
    uint256 _daiAmountSepolia = 1000 * 1e12;
    uint256 _daiAmountAfterFeesSepolia =
      _daiAmountSepolia - (_daiAmountSepolia * totalProtocolFees / Common.DBPS_DENOMINATOR);

    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _daiAmountSepolia
    });

    // create intent amount in destination with the value of 1000 dollars in bsc
    uint256 _daiAmountBsc = 1000 * 1e6;
    uint256 _daiAmountAfterFeesBsc = _daiAmountBsc - (_daiAmountBsc * totalProtocolFees / Common.DBPS_DENOMINATOR);

    _createIntentAndReceiveInHub({
      _user: _user2,
      _assetOrigin: bscDAI,
      _assetDestination: sepoliaDAI,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _daiAmountBsc
    });

    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // invoice queue should be empty
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlements for BSC testnet
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // check balance of user in bsc
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscDAI)), _daiAmountAfterFeesBsc);

    // Process settlements for Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // check balance of user in sepolia
    assertEq(_getTokenBalanceInSepolia(_user2, address(sepoliaDAI)), _daiAmountAfterFeesSepolia);
  }

  function test_NonXERC20_6_DecimalsOrigin_12_DecimalsDestination_TTLZero() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    XERC20(address(sepoliaDAI)).mockDecimals(6);

    _switchFork(BSC_TESTNET_FORK);
    XERC20(address(bscDAI)).mockDecimals(12);

    // create intent amount in origin with the value of 1000 thousand dollars in sepolia
    uint256 _daiAmountSepolia = 1000 * 1e6;
    uint256 _daiAmountAfterFeesSepolia =
      _daiAmountSepolia - (_daiAmountSepolia * totalProtocolFees / Common.DBPS_DENOMINATOR);

    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _daiAmountSepolia
    });

    // create intent amount in destination with the value of 1000 dollars in bsc
    uint256 _daiAmountBsc = 1000 * 1e12;
    uint256 _daiAmountAfterFeesBsc = _daiAmountBsc - (_daiAmountBsc * totalProtocolFees / Common.DBPS_DENOMINATOR);

    _createIntentAndReceiveInHub({
      _user: _user2,
      _assetOrigin: bscDAI,
      _assetDestination: sepoliaDAI,
      _origin: BSC_TESTNET_ID,
      _destination: ETHEREUM_SEPOLIA_ID,
      _intentAmount: _daiAmountBsc
    });

    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // invoice queue should be empty
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlements for BSC testnet
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // check balance of user in bsc
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscDAI)), _daiAmountAfterFeesBsc);

    // Process settlements for Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // check balance of user in sepolia
    assertEq(_getTokenBalanceInSepolia(_user2, address(sepoliaDAI)), _daiAmountAfterFeesSepolia);
  }

  function test_XERC20_12_DecimalsOrigin_6_DecimalsDestination_TTLZero() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    TestDAI(address(sepoliaXToken)).mockDecimals(12);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    _switchFork(BSC_TESTNET_FORK);
    TestDAI(address(bscXToken)).mockDecimals(6);

    // create intent amount in origin with the value of 1000 thousand dollars in sepolia
    uint256 _xAmountSepolia = 1000 * 1e12;

    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _xAmountSepolia
    });

    // create intent amount in destination with the value of 1000 dollars in bsc
    uint256 _xAmountBsc = 1000 * 1e6;
    uint256 _xAmountAfterFeesBsc = _xAmountBsc - (_xAmountBsc * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // invoice queue should be empty
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlements for BSC testnet
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // check balance of user in bsc
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscXToken)), _xAmountAfterFeesBsc);
  }

  function test_XERC20_6_DecimalsOrigin_1_DecimalsDestination_TTLZero() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    TestDAI(address(sepoliaXToken)).mockDecimals(6);

    // approve tokens
    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    _switchFork(BSC_TESTNET_FORK);
    TestDAI(address(bscXToken)).mockDecimals(12);

    // create intent amount in origin with the value of 1000 thousand dollars in sepolia
    uint256 _xAmountSepolia = 1000 * 1e6;

    _createIntentAndReceiveInHub({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _xAmountSepolia
    });

    // create intent amount in destination with the value of 1000 dollars in bsc
    uint256 _xAmountBsc = 1000 * 1e12;
    uint256 _xAmountAfterFeesBsc = _xAmountBsc - (_xAmountBsc * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // invoice queue should be empty
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // Process settlements for BSC testnet
    bytes memory _settlementMessageBodyBsc = _processSettlementQueue(BSC_TESTNET_ID, 1);
    _processSettlementMessage({_destination: BSC_TESTNET_ID, _settlementMessageBody: _settlementMessageBodyBsc});

    // check balance of user in bsc
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscXToken)), _xAmountAfterFeesBsc);
  }

  function test_NonXERC20_12_DecimalsOrigin_6_DecimalsDestination_TTLNotZero() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    TestDAI(address(sepoliaDAI)).mockDecimals(12);

    _switchFork(BSC_TESTNET_FORK);
    TestDAI(address(bscDAI)).mockDecimals(6);

    // create intent amount in origin with the value of 1000 thousand dollars in sepolia
    uint256 _daiAmountSepolia = 1000 * 1e12;
    uint256 _daiAmountAfterFeesSepolia =
      _daiAmountSepolia - (_daiAmountSepolia * totalProtocolFees / Common.DBPS_DENOMINATOR);

    (bytes32 _intentId, IEverclear.Intent memory _intent) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _daiAmountSepolia,
      _ttl: 48 hours
    });

    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // create intent amount in destination with the value of 1000 dollars in bsc
    uint256 _daiAmountBsc = 1000 * 1e6;
    uint256 _daiAmountAfterFeesBsc = _daiAmountBsc - (_daiAmountBsc * Constants.MAX_FEE / Common.DBPS_DENOMINATOR);

    _fillIntentAndReceiveInHub({
      _intentId: _intentId,
      _intent: _intent,
      _assetDestination: bscDAI,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _daiAmountBsc,
      _solver: _solver
    });

    // invoice queue should be empty
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // check user balance of user in bsc
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscDAI)), _daiAmountAfterFeesBsc);

    // Process settlements for Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // check balance of settled solver in sepolia
    assertEq(_getTokenBalanceInSepolia(_solver, address(sepoliaDAI)), _daiAmountAfterFeesSepolia);
  }

  function test_NonXERC20_6_DecimalsOrigin_12_DecimalsDestination_TTLNotZero() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    TestDAI(address(sepoliaDAI)).mockDecimals(6);

    _switchFork(BSC_TESTNET_FORK);
    TestDAI(address(bscDAI)).mockDecimals(12);

    // create intent amount in origin with the value of 1000 thousand dollars in sepolia
    uint256 _daiAmountSepolia = 1000 * 1e6;
    uint256 _daiAmountAfterFeesSepolia =
      _daiAmountSepolia - (_daiAmountSepolia * totalProtocolFees / Common.DBPS_DENOMINATOR);

    (bytes32 _intentId, IEverclear.Intent memory _intent) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _daiAmountSepolia,
      _ttl: 48 hours
    });

    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // create intent amount in destination with the value of 1000 dollars in bsc
    uint256 _daiAmountBsc = 1000 * 1e12;
    uint256 _daiAmountAfterFeesBsc = _daiAmountBsc - (_daiAmountBsc * Constants.MAX_FEE / Common.DBPS_DENOMINATOR);

    _fillIntentAndReceiveInHub({
      _intentId: _intentId,
      _intent: _intent,
      _assetDestination: bscDAI,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _daiAmountBsc,
      _solver: _solver
    });

    // invoice queue should be empty
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // check user balance of user in bsc
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscDAI)), _daiAmountAfterFeesBsc);

    // Process settlements for Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // check balance of settled solver in sepolia
    assertEq(_getTokenBalanceInSepolia(_solver, address(sepoliaDAI)), _daiAmountAfterFeesSepolia);
  }

  function test_XERC20_12_DecimalsOrigin_6_DecimalsDestination_TTLNotZero() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    TestDAI(address(sepoliaXToken)).mockDecimals(12);

    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    _switchFork(BSC_TESTNET_FORK);
    TestDAI(address(bscXToken)).mockDecimals(6);

    // create intent amount in origin with the value of 1000 thousand dollars in sepolia
    uint256 _xAmountSepolia = 1000 * 1e12;
    uint256 _xAmountAfterFeesSepolia = _xAmountSepolia - (_xAmountSepolia * totalProtocolFees / Common.DBPS_DENOMINATOR);

    (bytes32 _intentId, IEverclear.Intent memory _intent) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _xAmountSepolia,
      _ttl: 48 hours
    });

    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // create intent amount in destination with the value of 1000 dollars in bsc
    uint256 _xAmountBsc = 1000 * 1e6;
    uint256 _xAmountAfterFeesBsc = _xAmountBsc - (_xAmountBsc * Constants.MAX_FEE / Common.DBPS_DENOMINATOR);

    _fillIntentAndReceiveInHub({
      _intentId: _intentId,
      _intent: _intent,
      _assetDestination: IERC20(address(bscXToken)),
      _destination: BSC_TESTNET_ID,
      _intentAmount: _xAmountBsc,
      _solver: _solver
    });

    // invoice queue should be empty
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // check user balance of user in bsc
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscXToken)), _xAmountAfterFeesBsc);

    // Process settlements for Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // check balance of settled solver in sepolia
    assertEq(_getTokenBalanceInSepolia(_solver, address(sepoliaXToken)), _xAmountAfterFeesSepolia);
  }

  function test_XERC20_6_DecimalsOrigin_12_DecimalsDestination_TTLNotZero() public {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    TestDAI(address(sepoliaXToken)).mockDecimals(6);

    vm.prank(_user);
    ERC20(address(sepoliaXToken)).approve(address(sepoliaXERC20Module), type(uint256).max);

    _switchFork(BSC_TESTNET_FORK);
    TestDAI(address(bscXToken)).mockDecimals(12);

    // create intent amount in origin with the value of 1000 thousand dollars in sepolia
    uint256 _xAmountSepolia = 1000 * 1e6;
    uint256 _xAmountAfterFeesSepolia = _xAmountSepolia - (_xAmountSepolia * totalProtocolFees / Common.DBPS_DENOMINATOR);

    (bytes32 _intentId, IEverclear.Intent memory _intent) = _createIntentAndReceiveInHubWithTTL({
      _user: _user,
      _assetOrigin: IERC20(address(sepoliaXToken)),
      _assetDestination: IERC20(address(bscXToken)),
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _xAmountSepolia,
      _ttl: 48 hours
    });

    _closeEpochAndProcessDepositsAndInvoices(keccak256('DAI'));

    // create intent amount in destination with the value of 1000 dollars in bsc
    uint256 _xAmountBsc = 1000 * 1e12;
    uint256 _xAmountAfterFeesBsc = _xAmountBsc - (_xAmountBsc * Constants.MAX_FEE / Common.DBPS_DENOMINATOR);

    _fillIntentAndReceiveInHub({
      _intentId: _intentId,
      _intent: _intent,
      _assetDestination: IERC20(address(bscXToken)),
      _destination: BSC_TESTNET_ID,
      _intentAmount: _xAmountBsc,
      _solver: _solver
    });

    // invoice queue should be empty
    (,,, uint256 _length) = _getInvoicesForAsset(keccak256('DAI'));
    assertEq(_length, 0, 'invalid length');

    // check user balance of user in bsc
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscXToken)), _xAmountAfterFeesBsc);

    // Process settlements for Sepolia
    bytes memory _settlementMessageBodySepolia = _processSettlementQueue(ETHEREUM_SEPOLIA_ID, 1);
    _processSettlementMessage({_destination: ETHEREUM_SEPOLIA_ID, _settlementMessageBody: _settlementMessageBodySepolia});

    // check balance of settled solver in sepolia
    assertEq(_getTokenBalanceInSepolia(_solver, address(sepoliaXToken)), _xAmountAfterFeesSepolia);
  }
}
