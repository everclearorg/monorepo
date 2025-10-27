// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {AddAssetBase} from '../AddAsset.s.sol';

import {MainnetProductionEnvironment} from '../../MainnetProduction.sol';

contract CBBTC is AddAssetBase, MainnetProductionEnvironment {
  using TypeCasts for address;

  function _fetchTokenSetup()
    internal
    override(AddAssetBase)
    returns (string memory _symbol, IHubStorage.TokenSetup memory _setup)
  {
    /*///////////////////////////////////////////////////////////////
                             TICKER HASH
    //////////////////////////////////////////////////////////////*/

    _symbol = 'cbBTC';
    bytes32 _tickerHash = keccak256(bytes(_symbol));

    /*///////////////////////////////////////////////////////////////
                              TOKEN FEES
    //////////////////////////////////////////////////////////////*/

    IHubStorage.Fee[] memory _fees = new IHubStorage.Fee[](0);
    // _fees[0] = IHubStorage.Fee({recipient: FEE_RECIPIENT, fee: 0}); // 0 BPS

    /*///////////////////////////////////////////////////////////////
                         ADOPTED CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    IHubStorage.AssetConfig[] memory _assetConfigs = new IHubStorage.AssetConfig[](3);

    ///// Ethereum
    _assetConfigs[0] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ETHEREUM_CBBTC.toBytes32(),
      domain: ETHEREUM,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Arbitrum
    _assetConfigs[1] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ARBITRUM_CBBTC.toBytes32(),
      domain: ARBITRUM_ONE,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Base
    _assetConfigs[2] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: BASE_CBBTC.toBytes32(),
      domain: BASE,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    /*///////////////////////////////////////////////////////////////
                          TOKEN SETUP
    //////////////////////////////////////////////////////////////*/

    _setup = IHubStorage.TokenSetup({
      tickerHash: _tickerHash,
      initLastClosedEpochProcessed: false,
      prioritizedStrategy: IEverclear.Strategy.DEFAULT,
      maxDiscountDbps: 0,
      discountPerEpoch: 0,
      fees: _fees,
      adoptedForAssets: _assetConfigs
    });
  }
}

contract CBBTCDashboard is CBBTC {
  function run(
    address _hub
  ) public {
    _logTokenSetup(_hub);
  }
}
