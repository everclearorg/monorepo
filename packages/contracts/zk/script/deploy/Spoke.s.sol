// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from "../utils/Utils.sol";

import {TypeCasts} from "contracts/common/TypeCasts.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ISpecifiesInterchainSecurityModule} from "@hyperlane/interfaces/IInterchainSecurityModule.sol";

import {CallExecutor, ICallExecutor} from "contracts/intent/CallExecutor.sol";

import {EverclearSpoke} from "contracts/intent/EverclearSpoke.sol";
import {ISpokeGateway, SpokeGateway} from "contracts/intent/SpokeGateway.sol";
import {SpokeMessageReceiver} from "contracts/intent/modules/SpokeMessageReceiver.sol";

import {IMessageReceiver} from "interfaces/common/IMessageReceiver.sol";

import {ISpokeStorage} from "interfaces/intent/ISpokeStorage.sol";

import {MainnetProductionEnvironment} from "../MainnetProduction.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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

    function run() public {
        DeploymentParams memory _params = _deploymentParams[block.chainid];
        if (_params.lighthouse == address(0)) {
            revert WrongChainId();
        }

        vm.startBroadcast();
        // NOTE: Nonce is unused if not predicting addresses
        // address _deployer = msg.sender;
        // uint64 _nonce = vm.getNonce(_deployer);

        // predict gateway address
        // _params.gateway = ISpokeGateway(_addressFrom(_deployer, _nonce + 3));
        // // predict call executor address
        // _params.executor = ICallExecutor(_addressFrom(_deployer, _nonce + 4));
        // // predict message receiver address
        // _params.messageReceiver = _addressFrom(_deployer, _nonce + 5);

        // NOTE: Manual inputs - gateway requires updating as not predicted
        _params.gateway = ISpokeGateway(address(0x123));
        _params.executor = ICallExecutor(0xd2cC1a32430B1b81b0ed6327bc37670a26ca4568);
        _params.messageReceiver = 0x59A282CCa380894C91f57612c1c34F8DF274F78A;

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
        address _spokeImpl = address(new EverclearSpoke());
        _spoke = EverclearSpoke(deployUUPSProxy(_spokeImpl, abi.encodeCall(EverclearSpoke.initialize, (_init))));

        // deploy spoke gateway
        address _gatewayImpl = address(new SpokeGateway());
        _gateway = SpokeGateway(
            payable(
                deployUUPSProxy(
                    _gatewayImpl,
                    abi.encodeCall(
                        SpokeGateway.initialize,
                        (
                            _params.owner,
                            _params.mailbox,
                            address(_spoke),
                            _params.ism,
                            _params.hubDomain,
                            _params.hubGateway.toBytes32()
                        )
                    )
                )
            )
        );

        // if (address(_gateway) != address(_params.gateway)) {
        //     revert GatewayAddressMismatch();
        // }

        // Check mailbox
        if (address(_params.mailbox) != address(_gateway.mailbox())) {
            revert MailboxMismatch();
        }

        // // deploy call executor
        // _executor = new CallExecutor();
        // if (address(_executor) != address(_params.executor)) {
        //     revert ExecutorAddressMismatch();
        // }

        // // deploy message receiver
        // address messageReceiverAddr = address(new SpokeMessageReceiver());
        // _messageReceiver = new SpokeMessageReceiver();
        // if (address(_messageReceiver) != address(_params.messageReceiver)) {
        //     revert MessageReceiverAddressMismatch();
        // }

        vm.stopBroadcast();

        console.log("------------------------------------------------");
        console.log("Everclear Spoke:", address(_spoke));
        console.log("Spoke Gateway:", address(_gateway));
        // console.log("Message Receiver:", address(_messageReceiver));
        // console.log("Message Receiver:", address(messageReceiverAddr));
        // NOTE: Not querying as the ISM is not set
        // console.log(
        //     "ISM:", address(ISpecifiesInterchainSecurityModule(address(_spoke.gateway())).interchainSecurityModule())
        // );
        // console.log("Call Executor:", address(_executor));
        console.log("Chain ID:", block.chainid);
        console.log("------------------------------------------------");
    }

    function deployUUPSProxy(address impl, bytes memory initializerData) internal returns (address) {
        return address(new ERC1967Proxy(impl, initializerData));
    }
}

contract MainnetProduction is DeploySpokeBase, MainnetProductionEnvironment {
    function setUp() public {
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
            owner: 0x223B2BBe9a77db651CE241f33Fd7d7A67887A1e0,
            maxSolversFee: MAX_FEE
        });
    }
}
