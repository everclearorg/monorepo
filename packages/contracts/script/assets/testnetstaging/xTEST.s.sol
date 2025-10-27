// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {AddAssetBase} from '../AddAsset.s.sol';

import {TestnetStagingEnvironment} from '../../TestnetStaging.sol';

contract XTEST is AddAssetBase, TestnetStagingEnvironment {
  using TypeCasts for address;

  function _fetchTokenSetup()
    internal
    override(AddAssetBase)
    returns (string memory _symbol, IHubStorage.TokenSetup memory _setup)
  {
    /*///////////////////////////////////////////////////////////////
                             TICKER HASH
    //////////////////////////////////////////////////////////////*/

    _symbol = 'xTEST';
    bytes32 _tickerHash = keccak256(bytes(_symbol));

    /*///////////////////////////////////////////////////////////////
                              TOKEN FEES 
    //////////////////////////////////////////////////////////////*/

    IHubStorage.Fee[] memory _fees = new IHubStorage.Fee[](1);
    _fees[0] = IHubStorage.Fee({recipient: OWNER, fee: 10});

    /*///////////////////////////////////////////////////////////////
                         ADOPTED CONFIGURATION  
    //////////////////////////////////////////////////////////////*/

    IHubStorage.AssetConfig[] memory _assetConfigs = new IHubStorage.AssetConfig[](4);

    ///// Ethereum Sepolia
    _assetConfigs[0] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: SEPOLIA_XERC20_TEST_TOKEN.toBytes32(),
      domain: ETHEREUM_SEPOLIA,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// BSC Testnet
    _assetConfigs[1] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: BSC_XERC20_TEST_TOKEN.toBytes32(),
      domain: BSC_TESTNET,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Arbitrum Sepolia
    _assetConfigs[2] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: ARB_SEPOLIA_XERC20_TEST_TOKEN.toBytes32(),
      domain: ARB_SEPOLIA,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    ///// Optimism Sepolia
    _assetConfigs[3] = IHubStorage.AssetConfig({
      tickerHash: _tickerHash,
      adopted: OP_SEPOLIA_XERC20_TEST_TOKEN.toBytes32(),
      domain: OP_SEPOLIA,
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
      maxDiscountDbps: 1000,
      discountPerEpoch: 8,
      fees: _fees,
      adoptedForAssets: _assetConfigs
    });
  }
}
