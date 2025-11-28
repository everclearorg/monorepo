// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UnsafeUpgrades} from '@upgrades/Upgrades.sol';

import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {ISpokeStorage} from 'interfaces/intent/ISpokeStorage.sol';

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

import {EverclearHub, IEverclearHub} from 'contracts/hub/EverclearHub.sol';
import {HubGateway, IHubGateway} from 'contracts/hub/HubGateway.sol';
import {HubGatewayV3} from 'contracts/hub/HubGatewayV3.sol';

import {HubGateway} from 'contracts/hub/HubGateway.sol';
import {EverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';
import {ISpokeGateway, SpokeGateway} from 'contracts/intent/SpokeGateway.sol';
import {SpokeGatewayV2} from 'contracts/intent/SpokeGatewayV2.sol';
import {ICallExecutor} from 'interfaces/intent/ICallExecutor.sol';

library Deploy {
  // intent contracts
  function EverclearSpokeProxy(
    ISpokeStorage.SpokeInitializationParams memory _init
  ) internal returns (EverclearSpoke _spoke) {
    address _impl = address(new EverclearSpoke());
    _spoke = EverclearSpoke(UnsafeUpgrades.deployUUPSProxy(_impl, abi.encodeCall(EverclearSpoke.initialize, (_init))));
  }

  function SpokeGatewayProxy(
    address _owner,
    address _mailbox,
    address _spoke,
    address _securityModule,
    uint32 _everclearId,
    bytes32 _hubGateway
  ) internal returns (SpokeGateway _gateway) {
    address _impl = address(new SpokeGateway());
    _gateway = SpokeGateway(
      payable(UnsafeUpgrades.deployUUPSProxy(
          _impl,
          abi.encodeCall(
            SpokeGateway.initialize, (_owner, _mailbox, _spoke, _securityModule, _everclearId, _hubGateway)
          )
        ))
    );
  }

  // hub contracts
  function EverclearHubProxy(
    IEverclearHub.HubInitializationParams memory _init
  ) internal returns (EverclearHub _hub) {
    address _impl = address(new EverclearHub());
    _hub = EverclearHub(UnsafeUpgrades.deployUUPSProxy(_impl, abi.encodeCall(EverclearHub.initialize, (_init))));
  }

  function HubGatewayProxy(
    address _owner,
    address _mailbox,
    address _hub,
    address _securityModule
  ) internal returns (HubGateway _gateway) {
    address _impl = address(new HubGateway());
    _gateway = HubGateway(
      payable(UnsafeUpgrades.deployUUPSProxy(
          _impl, abi.encodeCall(HubGateway.initialize, (_owner, _mailbox, _hub, _securityModule))
        ))
    );
  }

  function HubGatewayV3Proxy(
    address _owner,
    address _receiver,
    address _interchainSecurityModule,
    address _polymerProver,
    address _hyperlaneMailbox,
    address _ccipMailbox,
    address _polymerMailbox,
    address[] memory _mailboxes,
    uint32[] memory _chainIds
  ) internal returns (HubGatewayV3 _gateway) {
    address _impl = address(new HubGatewayV3());
    _gateway = HubGatewayV3(
      payable(UnsafeUpgrades.deployUUPSProxy(
          _impl,
          abi.encodeCall(
            HubGatewayV3.initialize,
            (
              _owner,
              _receiver,
              _interchainSecurityModule,
              _polymerProver,
              _hyperlaneMailbox,
              _ccipMailbox,
              _polymerMailbox,
              _mailboxes,
              _chainIds
            )
          )
        ))
    );
  }

  function SpokeGatewayV2Proxy(
    address _owner,
    address _receiver,
    address _interchainSecurityModule,
    uint32 _everclearId,
    bytes32 _hubGateway,
    address _polymerProver,
    address _hyperlaneMailbox,
    address _ccipMailbox,
    address _polymerMailbox
  ) internal returns (SpokeGatewayV2 _gateway) {
    address _impl = address(new SpokeGatewayV2());
    _gateway = SpokeGatewayV2(
      payable(UnsafeUpgrades.deployUUPSProxy(
          _impl,
          abi.encodeCall(
            SpokeGatewayV2.initialize,
            (
              _owner,
              _receiver,
              _interchainSecurityModule,
              _everclearId,
              _hubGateway,
              _polymerProver,
              _hyperlaneMailbox,
              _ccipMailbox,
              _polymerMailbox
            )
          )
        ))
    );
  }
}
