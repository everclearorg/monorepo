// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {AddAssetBase} from '../AddAsset.s.sol';

import {MainnetStagingEnvironment} from '../../MainnetStaging.sol';

contract WETH is AddAssetBase, MainnetStagingEnvironment {
  using TypeCasts for address;

  function _fetchTokenSetup()
    internal
    override(AddAssetBase)
    returns (string memory _symbol, IHubStorage.TokenSetup memory _setup)
  {
    /*///////////////////////////////////////////////////////////////
                             TICKER HASH
    //////////////////////////////////////////////////////////////*/

    _symbol = 'WETH';
    bytes32 _tickerHash = keccak256(bytes(_symbol));

    /*///////////////////////////////////////////////////////////////
                              TOKEN FEES
    //////////////////////////////////////////////////////////////*/

    IHubStorage.Fee[] memory _fees = new IHubStorage.Fee[](0);
    // _fees[0] = IHubStorage.Fee({recipient: OWNER, fee: 100}); // 10 BPS

    /*///////////////////////////////////////////////////////////////
                         ADOPTED CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    IHubStorage.AssetConfig[] memory _assetConfigs = new IHubStorage.AssetConfig[](6);

    ///// Optimism
    _assetConfigs[0] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: OPTIMISM_WETH.toBytes32(),
      domain: OPTIMISM,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Arbitrum
    _assetConfigs[1] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ARBITRUM_WETH.toBytes32(),
      domain: ARBITRUM_ONE,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Ethereum
    _assetConfigs[2] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ETHEREUM_WETH.toBytes32(),
      domain: ETHEREUM,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    //// Mantle
    _assetConfigs[3] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: MANTLE_WETH.toBytes32(),
      domain: MANTLE,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    //// Base
    _assetConfigs[4] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: BASE_WETH.toBytes32(),
      domain: BASE,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    //// Solana
    _assetConfigs[5] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: SOLANA_WETH,
      domain: SOLANA,
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
      maxDiscountDbps: 0,
      discountPerEpoch: 0,
      fees: _fees,
      adoptedForAssets: _assetConfigs
    });
  }
}
