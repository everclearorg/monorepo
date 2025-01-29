// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ScriptUtils} from '../utils/Utils.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';

import {MainnetProductionEnvironment} from '../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../MainnetStaging.sol';
import {TestnetProductionEnvironment} from '../TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../TestnetStaging.sol';

abstract contract SetupDomainsAndGatewaysBase is Script, ScriptUtils {
  function run(string memory _account, address _hub) public virtual {
    revert NotImplemented();

    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);
  }
}

contract SetupDomainsAndGatewaysTestnetProduction is SetupDomainsAndGatewaysBase, TestnetProductionEnvironment {
  function run(string memory _account, address _hub) public override {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IHubStorage.DomainSetup[] memory _domainsSetup =
      new IHubStorage.DomainSetup[](SUPPORTED_DOMAINS_AND_GATEWAYS.length);

    // add supported domains
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      _domainsSetup[_i] = IHubStorage.DomainSetup({
        id: SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId,
        blockGasLimit: SUPPORTED_DOMAINS_AND_GATEWAYS[_i].blockGasLimit
      });
    }
    IEverclearHub(_hub).addSupportedDomains(_domainsSetup);

    // set chain gateways
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      IEverclearHub(_hub).updateChainGateway(
        SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId, SUPPORTED_DOMAINS_AND_GATEWAYS[_i].gateway
      );
    }

    uint32[] memory _supportedDomains = IEverclearHub(_hub).supportedDomains();
    IHubGateway _hubGateway = IEverclearHub(_hub).hubGateway();

    // assertions
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      uint32 _domainId = _supportedDomains[_i];
      uint256 _gasLimit = IEverclearHub(_hub).domainGasLimit(SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      bytes32 _gateway = _hubGateway.chainGateways(SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      assert(_domainId == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      assert(_gasLimit == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].blockGasLimit);
      assert(_gateway == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].gateway);

      console.log('==================== Added Supported Domain ====================');
      console.log('domain:', _domainId);
      console.log('block gas limit:', _gasLimit);
      console.log('gateway:');
      console.logBytes32(_gateway);
      console.log('================================================================================');
    }
  }
}

contract SetupDomainsAndGatewaysTestnetStaging is SetupDomainsAndGatewaysBase, TestnetStagingEnvironment {
  function run(string memory _account, address _hub) public override {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IHubStorage.DomainSetup[] memory _domainsSetup =
      new IHubStorage.DomainSetup[](SUPPORTED_DOMAINS_AND_GATEWAYS.length);

    // add supported domains
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      _domainsSetup[_i] = IHubStorage.DomainSetup({
        id: SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId,
        blockGasLimit: SUPPORTED_DOMAINS_AND_GATEWAYS[_i].blockGasLimit
      });
    }
    IEverclearHub(_hub).addSupportedDomains(_domainsSetup);

    // set chain gateways
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      IEverclearHub(_hub).updateChainGateway(
        SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId, SUPPORTED_DOMAINS_AND_GATEWAYS[_i].gateway
      );
    }

    uint32[] memory _supportedDomains = IEverclearHub(_hub).supportedDomains();
    IHubGateway _hubGateway = IEverclearHub(_hub).hubGateway();

    // assertions
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      uint32 _domainId = _supportedDomains[_i];
      uint256 _gasLimit = IEverclearHub(_hub).domainGasLimit(SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      bytes32 _gateway = _hubGateway.chainGateways(SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      assert(_domainId == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      assert(_gasLimit == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].blockGasLimit);
      assert(_gateway == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].gateway);

      console.log('==================== Added Supported Domain ====================');
      console.log('domain:', _domainId);
      console.log('block gas limit:', _gasLimit);
      console.log('gateway:');
      console.logBytes32(_gateway);
      console.log('================================================================================');
    }
  }
}

contract SetupDomainsAndGatewaysMainnetStaging is SetupDomainsAndGatewaysBase, MainnetStagingEnvironment {
  function run(string memory _account, address _hub) public override {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IHubStorage.DomainSetup[] memory _domainsSetup =
      new IHubStorage.DomainSetup[](SUPPORTED_DOMAINS_AND_GATEWAYS.length);

    // add supported domains
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      _domainsSetup[_i] = IHubStorage.DomainSetup({
        id: SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId,
        blockGasLimit: SUPPORTED_DOMAINS_AND_GATEWAYS[_i].blockGasLimit
      });
    }
    IEverclearHub(_hub).addSupportedDomains(_domainsSetup);

    // set chain gateways
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      IEverclearHub(_hub).updateChainGateway(
        SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId, SUPPORTED_DOMAINS_AND_GATEWAYS[_i].gateway
      );
    }

    uint32[] memory _supportedDomains = IEverclearHub(_hub).supportedDomains();
    IHubGateway _hubGateway = IEverclearHub(_hub).hubGateway();

    // assertions
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      uint32 _domainId = _supportedDomains[_i];
      uint256 _gasLimit = IEverclearHub(_hub).domainGasLimit(SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      bytes32 _gateway = _hubGateway.chainGateways(SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      assert(_domainId == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      assert(_gasLimit == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].blockGasLimit);
      assert(_gateway == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].gateway);

      console.log('==================== Added Supported Domain ====================');
      console.log('domain:', _domainId);
      console.log('block gas limit:', _gasLimit);
      console.log('gateway:');
      console.logBytes32(_gateway);
      console.log('================================================================================');
    }
  }
}

contract SetupDomainsAndGatewaysMainnetProduction is SetupDomainsAndGatewaysBase, MainnetProductionEnvironment {
  function run(string memory _account, address _hub) public override {
    uint256 _accountPk = vm.envUint(_account);
    vm.startBroadcast(_accountPk);

    IHubStorage.DomainSetup[] memory _domainsSetup =
      new IHubStorage.DomainSetup[](SUPPORTED_DOMAINS_AND_GATEWAYS.length);

    // add supported domains
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      _domainsSetup[_i] = IHubStorage.DomainSetup({
        id: SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId,
        blockGasLimit: SUPPORTED_DOMAINS_AND_GATEWAYS[_i].blockGasLimit
      });
    }
    IEverclearHub(_hub).addSupportedDomains(_domainsSetup);

    // set chain gateways
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      IEverclearHub(_hub).updateChainGateway(
        SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId, SUPPORTED_DOMAINS_AND_GATEWAYS[_i].gateway
      );
    }

    uint32[] memory _supportedDomains = IEverclearHub(_hub).supportedDomains();
    IHubGateway _hubGateway = IEverclearHub(_hub).hubGateway();

    // assertions
    for (uint256 _i; _i < SUPPORTED_DOMAINS_AND_GATEWAYS.length; _i++) {
      uint32 _domainId = _supportedDomains[_i];
      uint256 _gasLimit = IEverclearHub(_hub).domainGasLimit(SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      bytes32 _gateway = _hubGateway.chainGateways(SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      assert(_domainId == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].chainId);
      assert(_gasLimit == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].blockGasLimit);
      assert(_gateway == SUPPORTED_DOMAINS_AND_GATEWAYS[_i].gateway);

      console.log('==================== Added Supported Domain ====================');
      console.log('domain:', _domainId);
      console.log('block gas limit:', _gasLimit);
      console.log('gateway:');
      console.logBytes32(_gateway);
      console.log('================================================================================');
    }
  }
}
