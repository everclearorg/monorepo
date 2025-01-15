// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

import {EverclearHub, IEverclearHub} from 'contracts/hub/EverclearHub.sol';
import {HubGateway, IHubGateway} from 'contracts/hub/HubGateway.sol';

import {Handler} from 'contracts/hub/modules/Handler.sol';

import {HubMessageReceiver} from 'contracts/hub/modules/HubMessageReceiver.sol';
import {Manager} from 'contracts/hub/modules/Manager.sol';
import {Settler} from 'contracts/hub/modules/Settler.sol';

import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

import {MainnetProductionEnvironment} from '../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../MainnetStaging.sol';

import {TestnetProductionEnvironment} from '../TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../TestnetStaging.sol';

import {Deploy} from 'utils/Deploy.sol';

contract DeployHubBase is Script, ScriptUtils {
  error InvalidChainID(uint256 chainId, uint32 expected);

  IEverclearHub.HubInitializationParams internal _params;

  IMailbox internal _mailbox;
  EverclearHub internal _hub;
  HubGateway internal _gateway;
  address internal _ism;
  address internal _watchtower;

  error GatewayAddressMismatch();
  error ManagerAddressMismatch();
  error SettlerAddressMismatch();
  error HandlerAddressMismatch();
  error MessageReceiverAddressMismatch();
  error ISMAddressMismatch();
  error MailboxMismatch();
  error WatchtowerMismatch();

  function run(
    string memory _account
  ) public {
    uint256 _deployerPk = vm.envUint(_account);
    address _deployer = vm.addr(_deployerPk);
    uint64 _nonce = vm.getNonce(_deployer);

    vm.startBroadcast(_deployerPk);

    // predict manager address
    _params.manager = _addressFrom(_deployer, _nonce + 2);
    // predict settler address
    _params.settler = _addressFrom(_deployer, _nonce + 3);
    // predict handler address
    _params.handler = _addressFrom(_deployer, _nonce + 4);
    // predict message receiver address
    _params.messageReceiver = _addressFrom(_deployer, _nonce + 5);
    // predict gateway address
    _params.hubGateway = IHubGateway(_addressFrom(_deployer, _nonce + 7));
    // predict mock ism address
    // _params.ism = _addressFrom(_deployer, _nonce + 8);

    _hub = Deploy.EverclearHubProxy(_params);

    // deploy manager module
    Manager _manager = new Manager();
    if (address(_manager) != _params.manager) {
      revert ManagerAddressMismatch();
    }

    // deploy settler module
    Settler _settler = new Settler();
    if (address(_settler) != _params.settler) {
      revert SettlerAddressMismatch();
    }

    // deploy handler module
    Handler _handler = new Handler();
    if (address(_handler) != _params.handler) {
      revert HandlerAddressMismatch();
    }

    // deploy message receiver module
    HubMessageReceiver _messageReceiver = new HubMessageReceiver();
    if (address(_messageReceiver) != _params.messageReceiver) {
      revert MessageReceiverAddressMismatch();
    }

    // deploy hub gateway
    _gateway = Deploy.HubGatewayProxy(_params.owner, address(_mailbox), address(_hub), _ism);
    if (address(_gateway) != address(_params.hubGateway)) {
      revert GatewayAddressMismatch();
    }

    // check mailbox
    if (address(_mailbox) != address(_gateway.mailbox())) {
      revert MailboxMismatch();
    }

    // // set watchtower
    // _hub.updateWatchtower(address(_watchtower));
    // if (address(_watchtower) != _hub.watchtower()) {
    //   revert WatchtowerMismatch();
    // }

    vm.stopBroadcast();

    console.log('------------------------------------------------');
    console.log('Hub Core:', address(_hub));
    console.log('Hub Manager:', address(_manager));
    console.log('Hub Settler:', address(_settler));
    console.log('Hub Handler:', address(_handler));
    console.log('Hub Message Receiver:', address(_messageReceiver));
    console.log('Hub Gateway:', address(_gateway));
    console.log('ISM:', address(_ism));
    console.log('Hub Watchtower:', _hub.watchtower());
    console.log('Chain ID:', block.chainid);
    console.log('------------------------------------------------');
  }
}

contract TestnetProduction is DeployHubBase, TestnetProductionEnvironment {
  function setUp() public {
    if (block.chainid != EVERCLEAR_DOMAIN) {
      revert InvalidChainID(block.chainid, EVERCLEAR_DOMAIN);
    }

    _params = hubParams;
    _mailbox = EVERCLEAR_SEPOLIA_MAILBOX;
    _ism = EVERCLEAR_SEPOLIA_ISM;
    _watchtower = WATCHTOWER;
  }
}

contract TestnetStaging is DeployHubBase, TestnetStagingEnvironment {
  function setUp() public {
    if (block.chainid != EVERCLEAR_DOMAIN) {
      revert InvalidChainID(block.chainid, EVERCLEAR_DOMAIN);
    }

    _params = hubParams;
    _mailbox = EVERCLEAR_SEPOLIA_MAILBOX;
    _ism = EVERCLEAR_SEPOLIA_ISM;
    _watchtower = WATCHTOWER;
  }
}

contract MainnetStaging is DeployHubBase, MainnetStagingEnvironment {
  function setUp() public {
    if (block.chainid != EVERCLEAR_DOMAIN) {
      revert InvalidChainID(block.chainid, EVERCLEAR_DOMAIN);
    }

    _params = hubParams;
    _mailbox = EVERCLEAR_MAILBOX;
    _watchtower = WATCHTOWER;
  }
}

contract MainnetProduction is DeployHubBase, MainnetProductionEnvironment {
  function setUp() public {
    if (block.chainid != EVERCLEAR_DOMAIN) {
      revert InvalidChainID(block.chainid, EVERCLEAR_DOMAIN);
    }

    _params = hubParams;
    _mailbox = EVERCLEAR_MAILBOX;
    _watchtower = WATCHTOWER;
  }
}
