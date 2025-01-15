// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {AddAssetBase} from '../AddAsset.s.sol';

import {MainnetProductionEnvironment} from '../../MainnetProduction.sol';

contract USDC is AddAssetBase, MainnetProductionEnvironment {
  using TypeCasts for address;

  function _fetchTokenSetup()
    internal
    override(AddAssetBase)
    returns (string memory _symbol, IHubStorage.TokenSetup memory _setup)
  {
    /*///////////////////////////////////////////////////////////////
                             TICKER HASH
    //////////////////////////////////////////////////////////////*/

    _symbol = 'USDC';
    bytes32 _tickerHash = keccak256(bytes(_symbol));

    /*///////////////////////////////////////////////////////////////
                              TOKEN FEES 
    //////////////////////////////////////////////////////////////*/

    IHubStorage.Fee[] memory _fees = new IHubStorage.Fee[](1);
    _fees[0] = IHubStorage.Fee({recipient: FEE_RECIPIENT, fee: 2}); // 0.2 BPS

    /*///////////////////////////////////////////////////////////////
                         ADOPTED CONFIGURATION  
    //////////////////////////////////////////////////////////////*/

    IHubStorage.AssetConfig[] memory _assetConfigs = new IHubStorage.AssetConfig[](5);

    ///// Optimism
    _assetConfigs[0] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: OPTIMISM_USDC.toBytes32(),
      domain: OPTIMISM,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Arbitrum
    _assetConfigs[1] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ARBITRUM_USDC.toBytes32(),
      domain: ARBITRUM_ONE,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Base
    _assetConfigs[2] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: BASE_USDC.toBytes32(),
      domain: BASE,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Bnb
    _assetConfigs[3] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: BNB_USDC.toBytes32(),
      domain: BNB,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Ethereum
    _assetConfigs[4] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ETHEREUM_USDC.toBytes32(),
      domain: ETHEREUM,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    /*///////////////////////////////////////////////////////////////
                          TOKEN SETUP 
    //////////////////////////////////////////////////////////////*/

    _setup = IHubStorage.TokenSetup({
      tickerHash: _tickerHash,
      initLastClosedEpochProcessed: true,
      prioritizedStrategy: IEverclear.Strategy.XERC20,
      maxDiscountDbps: 12, // 1.2 BPS
      discountPerEpoch: 3, // 0.3 BPS
      fees: _fees,
      adoptedForAssets: _assetConfigs
    });
  }
}

contract USDCDashboard is USDC {
  function run(
    address _hub
  ) public {
    _logTokenSetup(_hub);
  }
}
