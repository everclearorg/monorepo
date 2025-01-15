// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {TestnetProductionEnvironment} from '../TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../TestnetStaging.sol';

contract AddDomainsBase is Script, ScriptUtils {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  IEverclearHub internal _hub;
  uint32[] internal _supportedDomains;
  bytes32[] internal _spokeGateways;

  error GatewayNotFound(uint32 domain);

  function run() public {
    uint256 _ownerPk = vm.envUint('DEPLOYER_PK');
    vm.startBroadcast(_ownerPk);

    IHubStorage.DomainSetup[] memory _domainSetup = new IHubStorage.DomainSetup[](1);
    _domainSetup[0] = IHubStorage.DomainSetup(_supportedDomains[0], 30_000_000);
    // _domainSetup[1] = IHubStorage.DomainSetup(_supportedDomains[1], 120_000_000);

    _hub.addSupportedDomains(_domainSetup);

    for (uint256 _i = 0; _i < _supportedDomains.length; ++_i) {
      _hub.updateChainGateway(_supportedDomains[_i], _spokeGateways[_i]);
    }

    vm.stopBroadcast();

    for (uint256 _i = 0; _i < _supportedDomains.length; ++_i) {
      console.log('Supported domain:', _supportedDomains[_i]);
      console.log('Gateway:', _spokeGateways[_i].toAddress());
    }
  }
}

contract TestnetProduction is AddDomainsBase, TestnetProductionEnvironment {
  using TypeCasts for address;

  function setUp() public {
    // vm.createSelectFork(HUB_RPC);
    _checkValidDomain(EVERCLEAR_DOMAIN);
    _hub = HUB;

    _supportedDomains = SUPPORTED_DOMAINS;

    _spokeGateways = new bytes32[](SUPPORTED_DOMAINS.length);

    // populate gateways
    for (uint256 _i = 0; _i < SUPPORTED_DOMAINS.length; ++_i) {
      uint32 _domain = SUPPORTED_DOMAINS[_i];

      // This needs to be manually subbed out when adding new chains
      address _gateway = _domain == BSC_TESTNET ? address(BSC_SPOKE_GATEWAY) : address(ETHEREUM_SEPOLIA_SPOKE_GATEWAY);
      if (_gateway == address(0)) {
        revert GatewayNotFound(_domain);
      }
      _spokeGateways[_i] = _gateway.toBytes32();
    }
  }
}

contract TestnetStaging is AddDomainsBase, TestnetStagingEnvironment {
  using TypeCasts for address;

  function setUp() public {
    // vm.createSelectFork(HUB_RPC);
    _checkValidDomain(EVERCLEAR_DOMAIN);
    _hub = HUB;

    _supportedDomains = SUPPORTED_DOMAINS;

    _spokeGateways = new bytes32[](SUPPORTED_DOMAINS.length);

    // populate gateways
    for (uint256 _i = 0; _i < SUPPORTED_DOMAINS.length; ++_i) {
      uint32 _domain = SUPPORTED_DOMAINS[_i];

      // This needs to be manually subbed out when adding new chains
      address _gateway = _domain == BSC_TESTNET ? address(BSC_SPOKE_GATEWAY) : address(ETHEREUM_SEPOLIA_SPOKE_GATEWAY);
      if (_gateway == address(0)) {
        revert GatewayNotFound(_domain);
      }
      _spokeGateways[_i] = _gateway.toBytes32();
    }
  }
}
