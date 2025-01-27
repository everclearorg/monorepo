// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {
  IInterchainSecurityModule,
  ISpecifiesInterchainSecurityModule
} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

import {CallExecutor, ICallExecutor} from 'contracts/intent/CallExecutor.sol';

import {EverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';
import {ISpokeGateway, SpokeGateway} from 'contracts/intent/SpokeGateway.sol';
import {SpokeMessageReceiver} from 'contracts/intent/modules/SpokeMessageReceiver.sol';

import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

import {ISpokeStorage} from 'interfaces/intent/ISpokeStorage.sol';

import {MainnetProductionEnvironment} from '../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../MainnetStaging.sol';
import {TestnetProductionEnvironment} from '../TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../TestnetStaging.sol';

import {Deploy} from 'utils/Deploy.sol';

contract DeploySpokeBase is Script, ScriptUtils {
  using TypeCasts for address;

  struct DeploymentParams {
    ISpokeGateway gateway;
    ICallExecutor executor;
    address messageReceiver;
    address lighthouse;
    address watchtower;
    address ism;
    address mailbox;
    uint32 hubDomain;
    address hubGateway;
    address owner;
    uint24 maxSolversFee;
  }

  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  EverclearSpoke internal _spoke;
  SpokeMessageReceiver internal _messageReceiver;
  SpokeGateway internal _gateway;
  CallExecutor internal _executor;

  error WrongChainId();
  error GatewayAddressMismatch();
  error ISMAddressMismatch();
  error ExecutorAddressMismatch();
  error MessageReceiverAddressMismatch();
  error MailboxMismatch();

  function run(
    string memory _account
  ) public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];
    if (_params.lighthouse == address(0)) {
      revert WrongChainId();
    }

    uint256 _deployerPk = vm.envUint(_account);
    address _deployer = vm.addr(_deployerPk);
    uint64 _nonce = vm.getNonce(_deployer);

    vm.startBroadcast(_deployerPk);

    // predict gateway address
    _params.gateway = ISpokeGateway(_addressFrom(_deployer, _nonce + 3));
    // predict call executor address
    _params.executor = ICallExecutor(_addressFrom(_deployer, _nonce + 4));
    // predict message receiver address
    _params.messageReceiver = _addressFrom(_deployer, _nonce + 5);

    // deploy Everclear spoke
    ISpokeStorage.SpokeInitializationParams memory _init = ISpokeStorage.SpokeInitializationParams(
      _params.gateway,
      _params.executor,
      _params.messageReceiver,
      _params.lighthouse,
      _params.watchtower,
      _params.hubDomain,
      _params.owner
    );
    _spoke = Deploy.EverclearSpokeProxy(_init);

    // deploy spoke gateway
    _gateway = Deploy.SpokeGatewayProxy(
      _params.owner, _params.mailbox, address(_spoke), _params.ism, _params.hubDomain, _params.hubGateway.toBytes32()
    );
    if (address(_gateway) != address(_params.gateway)) {
      revert GatewayAddressMismatch();
    }

    // Check mailbox
    if (address(_params.mailbox) != address(_gateway.mailbox())) {
      revert MailboxMismatch();
    }

    // deploy call executor
    _executor = new CallExecutor();
    if (address(_executor) != address(_params.executor)) {
      revert ExecutorAddressMismatch();
    }

    // deploy message receiver
    _messageReceiver = new SpokeMessageReceiver();
    if (address(_messageReceiver) != address(_params.messageReceiver)) {
      revert MessageReceiverAddressMismatch();
    }

    vm.stopBroadcast();

    console.log('------------------------------------------------');
    console.log('Everclear Spoke:', address(_spoke));
    console.log('Spoke Gateway:', address(_gateway));
    console.log('Message Receiver:', address(_messageReceiver));
    console.log(
      'ISM:', address(ISpecifiesInterchainSecurityModule(address(_spoke.gateway())).interchainSecurityModule())
    );
    console.log('Call Executor:', address(_executor));
    console.log('Chain ID:', block.chainid);
    console.log('------------------------------------------------');
  }
}

contract TestnetProduction is DeploySpokeBase, TestnetProductionEnvironment {
  function setUp() public {
    _deploymentParams[ETHEREUM_SEPOLIA] = DeploymentParams({
      gateway: ISpokeGateway(address(0)), // to be computed
      executor: ICallExecutor(address(0)), // to be computed
      messageReceiver: address(0), // message receiver to be computed
      lighthouse: LIGHTHOUSE, // lighthouse
      watchtower: WATCHTOWER, // watchtower
      ism: address(0), // default ism
      mailbox: address(ETHEREUM_SEPOLIA_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN, // Everclear chain id
      hubGateway: address(HUB_GATEWAY), // hub gateway
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    _deploymentParams[BSC_TESTNET] = DeploymentParams({
      gateway: ISpokeGateway(address(0)), // to be computed
      executor: ICallExecutor(address(0)), // to be computed
      messageReceiver: address(0), // message receiver to be computed
      lighthouse: LIGHTHOUSE, // lighthouse
      watchtower: WATCHTOWER, // watchtower
      ism: address(0), // default ism
      mailbox: address(BSC_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN, // Everclear chain id
      hubGateway: address(HUB_GATEWAY), // hub gateway
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    _deploymentParams[OP_SEPOLIA] = DeploymentParams({
      gateway: ISpokeGateway(address(0)), // to be computed
      executor: ICallExecutor(address(0)), // to be computed
      messageReceiver: address(0), // message receiver to be computed
      lighthouse: LIGHTHOUSE, // lighthouse
      watchtower: WATCHTOWER, // watchtower
      ism: address(0), // default ism
      mailbox: address(OP_SEPOLIA_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN, // Everclear chain id
      hubGateway: address(HUB_GATEWAY), // hub gateway
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    _deploymentParams[ARB_SEPOLIA] = DeploymentParams({
      gateway: ISpokeGateway(address(0)), // to be computed
      executor: ICallExecutor(address(0)), // to be computed
      messageReceiver: address(0), // message receiver to be computed
      lighthouse: LIGHTHOUSE, // lighthouse
      watchtower: WATCHTOWER, // watchtower
      ism: address(0), // default ism
      mailbox: address(ARB_SEPOLIA_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN, // Everclear chain id
      hubGateway: address(HUB_GATEWAY), // hub gateway
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });
  }
}

contract TestnetStaging is DeploySpokeBase, TestnetStagingEnvironment {
  function setUp() public {
    _deploymentParams[ETHEREUM_SEPOLIA] = DeploymentParams({
      gateway: ISpokeGateway(address(0)), // to be computed
      executor: ICallExecutor(address(0)), // to be computed
      messageReceiver: address(0), // message receiver to be computed
      lighthouse: LIGHTHOUSE, // lighthouse
      watchtower: WATCHTOWER, // watchtower
      ism: address(0), // default ism
      mailbox: address(ETHEREUM_SEPOLIA_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN, // Everclear chain id
      hubGateway: address(HUB_GATEWAY), // hub gateway
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    _deploymentParams[BSC_TESTNET] = DeploymentParams({
      gateway: ISpokeGateway(address(0)), // to be computed
      executor: ICallExecutor(address(0)), // to be computed
      messageReceiver: address(0), // message receiver to be computed
      lighthouse: LIGHTHOUSE, // lighthouse
      watchtower: WATCHTOWER, // watchtower
      ism: address(0), // default ism
      mailbox: address(BSC_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN, // Everclear chain id
      hubGateway: address(HUB_GATEWAY), // hub gateway
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    _deploymentParams[OP_SEPOLIA] = DeploymentParams({
      gateway: ISpokeGateway(address(0)), // to be computed
      executor: ICallExecutor(address(0)), // to be computed
      messageReceiver: address(0), // message receiver to be computed
      lighthouse: LIGHTHOUSE, // lighthouse
      watchtower: WATCHTOWER, // watchtower
      ism: address(0), // default ism
      mailbox: address(OP_SEPOLIA_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN, // Everclear chain id
      hubGateway: address(HUB_GATEWAY), // hub gateway
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    _deploymentParams[ARB_SEPOLIA] = DeploymentParams({
      gateway: ISpokeGateway(address(0)), // to be computed
      executor: ICallExecutor(address(0)), // to be computed
      messageReceiver: address(0), // message receiver to be computed
      lighthouse: LIGHTHOUSE, // lighthouse
      watchtower: WATCHTOWER, // watchtower
      ism: address(0), // default ism
      mailbox: address(ARB_SEPOLIA_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN, // Everclear chain id
      hubGateway: address(HUB_GATEWAY), // hub gateway
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });
  }
}

contract MainnetStaging is DeploySpokeBase, MainnetStagingEnvironment {
  function setUp() public {
    //// Arbitrum One
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(ARBITRUM_ONE_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(OPTIMISM_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    //// Zircuit
    _deploymentParams[ZIRCUIT] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(ZIRCUIT_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    //// Blast
    _deploymentParams[BLAST] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(BLAST_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });
  }
}

contract MainnetProduction is DeploySpokeBase, MainnetProductionEnvironment {
  function setUp() public {
    //// Arbitrum One
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(ARBITRUM_ONE_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(OPTIMISM_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    //// Base
    _deploymentParams[BASE] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(BASE_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    //// Bnb
    _deploymentParams[BNB] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(BNB_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    //// Ethereum
    _deploymentParams[ETHEREUM] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(ETHEREUM_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    //// Zircuit
    _deploymentParams[ZIRCUIT] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(ZIRCUIT_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    //// Blast
    _deploymentParams[BLAST] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(BLAST_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    /// Linea
    _deploymentParams[LINEA] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(LINEA_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    /// Polygon
    _deploymentParams[POLYGON] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(POLYGON_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    /// Avalanche
    _deploymentParams[AVALANCHE] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(AVALANCHE_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });

    /// zkSync
    _deploymentParams[ZKSYNC] = DeploymentParams({ // set domain id as mapping key
      gateway: ISpokeGateway(address(0)),
      executor: ICallExecutor(address(0)),
      messageReceiver: address(0),
      lighthouse: LIGHTHOUSE,
      watchtower: WATCHTOWER,
      ism: address(0), // using the default ism
      mailbox: address(ZKSYNC_MAILBOX), // domain mailbox
      hubDomain: EVERCLEAR_DOMAIN,
      hubGateway: address(HUB_GATEWAY),
      owner: OWNER,
      maxSolversFee: MAX_FEE
    });
  }
}
