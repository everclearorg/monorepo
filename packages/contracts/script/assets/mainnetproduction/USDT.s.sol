// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {AddAssetBase} from '../AddAsset.s.sol';

import {MainnetProductionEnvironment} from '../../MainnetProduction.sol';

contract USDT is AddAssetBase, MainnetProductionEnvironment {
  using TypeCasts for address;

  function _fetchTokenSetup()
    internal
    override(AddAssetBase)
    returns (string memory _symbol, IHubStorage.TokenSetup memory _setup)
  {
    /*///////////////////////////////////////////////////////////////
                             TICKER HASH
    //////////////////////////////////////////////////////////////*/

    _symbol = 'USDT';
    bytes32 _tickerHash = keccak256(bytes(_symbol));

    /*///////////////////////////////////////////////////////////////
                              TOKEN FEES 
    //////////////////////////////////////////////////////////////*/

    IHubStorage.Fee[] memory _fees = new IHubStorage.Fee[](1);
    _fees[0] = IHubStorage.Fee({recipient: FEE_RECIPIENT, fee: 2}); // 0.2 BPS

    /*///////////////////////////////////////////////////////////////
                         ADOPTED CONFIGURATION  
    //////////////////////////////////////////////////////////////*/

    IHubStorage.AssetConfig[] memory _assetConfigs = new IHubStorage.AssetConfig[](9);

    ///// Optimism
    _assetConfigs[0] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: OPTIMISM_USDT.toBytes32(),
      domain: OPTIMISM,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Arbitrum
    _assetConfigs[1] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ARBITRUM_USDT.toBytes32(),
      domain: ARBITRUM_ONE,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Bnb
    _assetConfigs[2] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: BNB_USDT.toBytes32(),
      domain: BNB,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Ethereum
    _assetConfigs[3] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ETHEREUM_USDT.toBytes32(),
      domain: ETHEREUM,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Linea
    _assetConfigs[4] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: LINEA_USDT.toBytes32(),
      domain: LINEA,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Polygon
    _assetConfigs[5] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: POLYGON_USDT.toBytes32(),
      domain: POLYGON,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Avalanche
    _assetConfigs[6] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: AVALANCHE_USDT.toBytes32(),
      domain: AVALANCHE,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Scroll
    _assetConfigs[7] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: SCROLL_USDT.toBytes32(),
      domain: SCROLL,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Taiko
    _assetConfigs[8] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: TAIKO_USDT.toBytes32(),
      domain: TAIKO,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    /*///////////////////////////////////////////////////////////////
                          TOKEN SETUP 
    //////////////////////////////////////////////////////////////*/

    _setup = IHubStorage.TokenSetup({
      tickerHash: _tickerHash,
      initLastClosedEpochProcessed: false,
      prioritizedStrategy: IEverclear.Strategy.XERC20,
      maxDiscountDbps: 12, // 1.2 BPS
      discountPerEpoch: 3, // 0.3 BPS
      fees: _fees,
      adoptedForAssets: _assetConfigs
    });
  }
}

contract USDTDashboard is USDT {
  function run(
    address _hub
  ) public {
    _logTokenSetup(_hub);
  }
}
