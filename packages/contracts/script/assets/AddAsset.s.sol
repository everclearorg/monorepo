// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ScriptUtils} from '../utils/Utils.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

abstract contract AddAssetBase is Script, ScriptUtils {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  error InvalidDecimals();
  error InvalidTicker();
  error InvalidAdopted();
  error InvalidApproval();

  function run(string memory _account, address _hub) public {
    // Get token setup information
    (string memory _symbol, IHubStorage.TokenSetup memory _setup) = _fetchTokenSetup();
    _checkValidSetup(_setup);

    IHubStorage.TokenSetup[] memory _tokenSetup = new IHubStorage.TokenSetup[](1);
    _tokenSetup[0] = _setup;

    // Broadcast as `account`
    uint256 _accountPk = vm.envUint(_account);

    vm.startBroadcast(_accountPk);

    IEverclearHub(_hub).setTokenConfigs(_tokenSetup);

    vm.stopBroadcast();

    // Log configuration
    _logConfig(_symbol, _setup);
  }

  function _checkValidSetup(
    IHubStorage.TokenSetup memory _setup
  ) internal {
    for (uint256 _j = 0; _j < _setup.adoptedForAssets.length; _j++) {
      if (_setup.adoptedForAssets[_j].domain == 0) revert InvalidDomain(0);
      if (_setup.adoptedForAssets[_j].tickerHash == 0) revert InvalidTicker();
      if (_setup.adoptedForAssets[_j].adopted == 0) revert InvalidAdopted();
      if (!_setup.adoptedForAssets[_j].approval) revert InvalidApproval();
    }
  }

  function _logConfig(string memory _symbol, IHubStorage.TokenSetup memory _setup) internal {
    console.log('------------------------------------------------');
    console.log('Asset:', _symbol);
    console.log('Prioritized strategy: ', uint256(_setup.prioritizedStrategy));
    console.log('Max Discount: ', _setup.maxDiscountDbps);
    console.log('Discount per epoch: ', _setup.discountPerEpoch);
    console.log('Protocol fees amount: ', _setup.fees.length);
    console.log('Adopted assets amount: ', _setup.adoptedForAssets.length);
    console.log('Ticker hash: ');
    console.logBytes32(_setup.adoptedForAssets[0].tickerHash);
    console.log('------------------------------------------------');
    for (uint256 _i = 0; _i < _setup.adoptedForAssets.length; _i++) {
      console.log('Domain: ', _setup.adoptedForAssets[_i].domain);
    }
    console.log('------------------------------------------------');
    for (uint256 _i = 0; _i < _setup.fees.length; _i++) {
      console.log('Fee: ', _setup.fees[_i].recipient, _setup.fees[_i].fee);
    }
  }

  function _fetchTokenSetup() internal virtual returns (string memory _symbol, IHubStorage.TokenSetup memory _setup);

  function _logTokenSetup(
    address _hub
  ) internal virtual {
    // Get token setup information
    (string memory _symbol, IHubStorage.TokenSetup memory _setup) = _fetchTokenSetup();

    // Get config from chain
    (uint24 _maxDiscount, uint24 _discountPerEpoch, IEverclear.Strategy _prioritizedStrategy) =
      IHubStorage(_hub).tokenConfigs(_setup.tickerHash);

    // Get fees from chain
    IHubStorage.Fee[] memory _fees = IHubStorage(_hub).tokenFees(_setup.tickerHash);

    // Log token information
    console.log('================================== Asset Dashboard ==================================');
    console.log('Symbol                                 ', _symbol);
    console.log('Init last closed epoch processed       ', _setup.initLastClosedEpochProcessed);
    console.log('Prioritized Strategy                   ', uint8(_prioritizedStrategy));
    console.log(
      '   Matches config?                     ', uint8(_prioritizedStrategy) == uint8(_setup.prioritizedStrategy)
    );
    console.log('Max Discount                           ', _maxDiscount);
    console.log('   Matches config?                     ', _maxDiscount == _setup.maxDiscountDbps);
    console.log('Discount Per Epoch                     ', _discountPerEpoch);
    console.log('   Matches config?                     ', _discountPerEpoch == _setup.discountPerEpoch);
    console.log('');
    console.log('Fees                                   ');
    for (uint256 i = 0; i < _fees.length; i++) {
      console.log('[', i, '] Recipient                        ', _fees[i].recipient);
      console.log('   Matches config?                     ', _setup.fees[i].recipient == _fees[i].recipient);
      console.log('[', i, '] Fee                              ', _fees[i].fee);
      console.log('   Matches config?                     ', _fees[i].fee == _setup.fees[i].fee);
      console.log('');
    }
    console.log('Assets                                 ');
    for (uint256 i = 0; i < _setup.adoptedForAssets.length; i++) {
      bytes32 _assetHash =
        IHubStorage(_hub).assetHash(_setup.adoptedForAssets[i].tickerHash, _setup.adoptedForAssets[i].domain);
      IHubStorage.AssetConfig memory _assetConfig = IHubStorage(_hub).adoptedForAssets(_assetHash);
      console.log('[', i, '] Adopted                          ', _assetConfig.adopted.toAddress());
      console.log('   Matches config?                     ', _assetConfig.adopted == _setup.adoptedForAssets[i].adopted);
      console.log('[', i, '] Domain                           ', _assetConfig.domain);
      console.log('   Matches config?                     ', _assetConfig.domain == _setup.adoptedForAssets[i].domain);
      console.log('[', i, '] Approval                         ', _assetConfig.approval);
      console.log(
        '   Matches config?                     ', _assetConfig.approval == _setup.adoptedForAssets[i].approval
      );
      console.log('[', i, '] Strategy                         ', uint8(_assetConfig.strategy));
      console.log(
        '   Matches config?                     ', _assetConfig.strategy == _setup.adoptedForAssets[i].strategy
      );
      console.log('');
    }
    console.log('Ticker hash                            ');
    console.logBytes32(_setup.tickerHash);
    console.log('================================== Asset Dashboard ==================================');
  }
}
