// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ScriptUtils} from '../utils/Utils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {EverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';
import {SpokeGateway} from 'contracts/intent/SpokeGateway.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearHub} from 'interfaces/hub/IEverclearHub.sol';
import {IEverclearSpoke} from 'interfaces/intent/IEverclearSpoke.sol';

import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

contract Dashboard is Script, ScriptUtils {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  struct GatewayData {
    address owner;
    address mailbox;
    address receiver;
    address ism;
  }

  function run(
    address _spoke
  ) public view {
    IEverclearSpoke _everclearSpoke = IEverclearSpoke(_spoke);

    address _permit2 = address(_everclearSpoke.PERMIT2());
    uint32 _everclearChainId = _everclearSpoke.EVERCLEAR();
    address _owner = EverclearSpoke(address(_everclearSpoke)).owner();
    address _lighthouse = _everclearSpoke.lighthouse();
    address _watchtower = _everclearSpoke.watchtower();
    address _messageReceiver = address(_everclearSpoke.messageReceiver());
    SpokeGateway _gateway = SpokeGateway(payable(address(_everclearSpoke.gateway())));
    address _callExecutor = address(_everclearSpoke.callExecutor());
    bool _paused = _everclearSpoke.paused();
    uint256 _nonce = _everclearSpoke.nonce();
    uint256 _messageGasLimit = _everclearSpoke.messageGasLimit();
    address _xerc20Module = address(_everclearSpoke.modules(IEverclear.Strategy.XERC20));
    address _defaultModule = address(_everclearSpoke.modules(IEverclear.Strategy.DEFAULT));

    GatewayData memory _gatewayData = _getGatewayData(_gateway);

    console.log('================================== Spoke Dashboard ==================================');

    console.log('Everclear Chain ID:                      ', _everclearChainId);
    console.log('Permit2:                                 ', _permit2);
    console.log('Owner:                                   ', address(_owner));
    console.log('Lighthouse:                              ', _lighthouse);
    console.log('Watchtower:                              ', _watchtower);
    console.log('Message Receiver:                        ', _messageReceiver);
    console.log('Gateway:                                 ', address(_gateway));
    console.log('Call Executor:                           ', _callExecutor);
    console.log('Paused:                                  ', _paused);
    console.log('Nonce:                                   ', _nonce);
    console.log('Message Gas Limit:                       ', _messageGasLimit);
    console.log('XERC20 Module:                           ', _xerc20Module);
    console.log('Default Module:                          ', _defaultModule);
    console.log('Gateway Owner:                           ', _gatewayData.owner);
    console.log('Gateway Mailbox:                         ', _gatewayData.mailbox);
    console.log('Gateway Receiver:                        ', _gatewayData.receiver);
    console.log('Gateway ISM:                             ', _gatewayData.ism);

    console.log('================================== Spoke Dashboard ==================================');
  }

  function _getGatewayData(
    SpokeGateway _gateway
  ) internal view returns (GatewayData memory _data) {
    address _owner = _gateway.owner();
    address _mailbox = address(_gateway.mailbox());
    address _receiver = address(_gateway.receiver());
    address _ism = address(_gateway.interchainSecurityModule());

    _data = GatewayData({owner: _owner, mailbox: _mailbox, receiver: _receiver, ism: _ism});
  }
}
