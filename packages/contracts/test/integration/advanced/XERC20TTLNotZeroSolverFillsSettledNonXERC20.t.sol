// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.t.sol';
import {Constants} from 'test/utils/Constants.sol';
import {ERC20, IXERC20, XERC20} from 'test/utils/TestXToken.sol';

contract XERC20TTLNotZeroSolverFillsSettledNonXERC20_Integration is IntegrationBase {
  using TypeCasts for address;

  function test_XERC20TTLNotZero_SolverFills_SettledNonXERC20() public {
    _unifyUnixBlocktimestampInChains(10_000);

    // One thousand deposit
    uint256 _intentAmount = 1000 * 1e18;
    uint256 _amountAfterFees = _intentAmount - (_intentAmount * totalProtocolFees / Common.DBPS_DENOMINATOR);

    // provide DAI liquidity to sepolia spoke
    _createIntentAndReceiveInHubWithTTL({
      _user: _user2,
      _assetOrigin: sepoliaDAI,
      _assetDestination: bscDAI,
      _origin: ETHEREUM_SEPOLIA_ID,
      _destination: BSC_TESTNET_ID,
      _intentAmount: _intentAmount * 10,
      _ttl: 24 hours
    });

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

    // Fake DAI token adopted in sepolia non xERC20
    IHubStorage.AssetConfig memory _adoptedForAsset = IHubStorage.AssetConfig({
      tickerHash: keccak256('TXT'),
      adopted: address(sepoliaDAI).toBytes32(),
      domain: ETHEREUM_SEPOLIA_ID,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });
    _setAdpotedForAsset(_adoptedForAsset);

    // override prioritized strategy to default for non-erc20
    _setPrioritizedStrategy(keccak256('TXT'), IEverclear.Strategy.DEFAULT);

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

    // check amount of settlement in sepolia for solver, converting to DAI decimals (DAI: 6, TXT: 18)
    assertEq(_getTokenBalanceInSepolia(_solver, address(sepoliaDAI)), _amountAfterFees / 1e12);

    // check amount of settlement in bsc for user
    assertEq(_getTokenBalanceInBscTestnet(_user, address(bscXToken)), _amountAfterProtocolAndSolverFees);
  }
}
