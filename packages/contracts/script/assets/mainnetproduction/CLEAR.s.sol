// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {AddAssetBase} from '../AddAsset.s.sol';

import {MainnetProductionEnvironment} from '../../MainnetProduction.sol';

contract CLEAR is AddAssetBase, MainnetProductionEnvironment {
  using TypeCasts for address;

  function _fetchTokenSetup()
    internal
    override(AddAssetBase)
    returns (string memory _symbol, IHubStorage.TokenSetup memory _setup)
  {
    /*///////////////////////////////////////////////////////////////
                             TICKER HASH
    //////////////////////////////////////////////////////////////*/

    _symbol = 'xCLEAR';
    bytes32 _tickerHash = keccak256(bytes(_symbol));

    /*///////////////////////////////////////////////////////////////
                              TOKEN FEES 
    //////////////////////////////////////////////////////////////*/

    IHubStorage.Fee[] memory _fees = new IHubStorage.Fee[](0);
    // _fees[0] = IHubStorage.Fee({recipient: FEE_RECIPIENT, fee: 0}); // 0 BPS

    /*///////////////////////////////////////////////////////////////
                         ADOPTED CONFIGURATION  
    //////////////////////////////////////////////////////////////*/

    IHubStorage.AssetConfig[] memory _assetConfigs = new IHubStorage.AssetConfig[](6);

    ///// Ethereum
    _assetConfigs[0] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ETHEREUM_CLEAR.toBytes32(),
      domain: ETHEREUM,
      approval: true,
      strategy: IEverclear.Strategy.XERC20
    });

    ///// Arbitrum
    _assetConfigs[1] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ARBITRUM_CLEAR.toBytes32(),
      domain: ARBITRUM_ONE,
      approval: true,
      strategy: IEverclear.Strategy.XERC20
    });

    ///// Optimism
    _assetConfigs[2] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: OPTIMISM_CLEAR.toBytes32(),
      domain: OPTIMISM,
      approval: true,
      strategy: IEverclear.Strategy.XERC20
    });

    ///// BNB
    _assetConfigs[3] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: BNB_CLEAR.toBytes32(),
      domain: BNB,
      approval: true,
      strategy: IEverclear.Strategy.XERC20
    });

    ///// Polygon
    _assetConfigs[4] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: POLYGON_CLEAR.toBytes32(),
      domain: POLYGON,
      approval: true,
      strategy: IEverclear.Strategy.XERC20
    });

    ///// Gnosis
    _assetConfigs[5] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: GNOSIS_CLEAR.toBytes32(),
      domain: GNOSIS,
      approval: true,
      strategy: IEverclear.Strategy.XERC20
    });

    /*///////////////////////////////////////////////////////////////
                          TOKEN SETUP 
    //////////////////////////////////////////////////////////////*/

    _setup = IHubStorage.TokenSetup({
      tickerHash: _tickerHash,
      initLastClosedEpochProcessed: false,
      prioritizedStrategy: IEverclear.Strategy.XERC20,
      maxDiscountDbps: 0,
      discountPerEpoch: 0,
      fees: _fees,
      adoptedForAssets: _assetConfigs
    });
  }
}

contract CLEARDashboard is CLEAR {
  function run(
    address _hub
  ) public {
    _logTokenSetup(_hub);
  }
}
