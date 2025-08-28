// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {EverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';
import {EverclearSpokeV3} from 'contracts/intent/EverclearSpokeV3.sol';
import {EverclearSpokeV4} from 'contracts/intent/EverclearSpokeV4.sol';
import {EverclearSpokeV5} from 'contracts/intent/EverclearSpokeV5.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';

import {IHubStorageV2} from 'interfaces/hub/IHubStorageV2.sol';
import {SafeTxBuilder} from 'test/utils/SafeTxBuilder.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {EverclearHubV2, IEverclearHubV2} from 'contracts/hub/EverclearHubV2.sol';
import {HandlerV2, IHandlerV2} from 'contracts/hub/modules/HandlerV2.sol';
import {HubMessageReceiverV2, IHubMessageReceiverV2} from 'contracts/hub/modules/HubMessageReceiverV2.sol';

import {IManagerV2, ManagerV2} from 'contracts/hub/modules/ManagerV2.sol';
import {ISettlerV2, SettlerV2} from 'contracts/hub/modules/SettlerV2.sol';

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

interface ICREATE3 {
  function deploy(bytes32 _salt, bytes calldata _creationCode) external payable returns (address _deployed);
}

contract TestEverclearSpokeV5 is EverclearSpokeV5 {
  function processQueueChecks(uint32 _domain, address _relayer, uint256 _ttl) external view {
    return _processQueueChecks(_domain, _relayer, _ttl);
  }

  function executeCalldata(bytes32 _intentId, bytes memory _data) external {
    return _executeCalldata(_intentId, _data);
  }

  function verifySignature(address _signer, bytes memory _data, uint256 _noncer, bytes calldata _signature) external {
    return _verifySignature(_signer, _data, _noncer, _signature);
  }
}

contract UpgradeHelper is SafeTxBuilder {
  using stdStorage for StdStorage;
  using TypeCasts for address;
  using TypeCasts for bytes32;

  event IntentQueueProcessed(bytes32 indexed _messageId, uint256 _firstIdx, uint256 _lastIdx, uint256 _quote);
  event FillQueueProcessed(bytes32 indexed _messageId, uint256 _firstIdx, uint256 _lastIdx, uint256 _quote);
  event IntentExecuted(
    bytes32 indexed _intentId, address indexed _executor, address _asset, uint256 _amount, uint24 _fee
  );

  struct FillIntentParams {
    IEverclear.Intent intent;
    uint24 fee;
    address solver;
  }

  struct ProcessIntentQueueParams {
    uint32 amount;
    address relayer;
    uint256 messageFee;
    uint256 bufferBPS;
  }

  struct ProcessFillQueueParams {
    uint32 amount;
    address solver;
    uint256 messageFee;
    uint256 bufferBPS;
    uint256 length;
    address relayer;
  }

  struct AdditionalParams {
    uint32 destination;
    uint256 i;
    uint32 amount;
  }

  struct CachedSpokeState {
    address permit;
    uint32 EVERCLEAR;
    uint32 DOMAIN;
    address lighthouse;
    address watchtower;
    address messageReceiver;
    address gateway;
    address callExecutor;
    bool paused;
    uint64 nonce;
    uint256 messageGasLimit;
    address feeAdapter;
  }

  struct DeploymentParams {
    address owner;
    address spokeProxy;
    address spokeImpl;
  }

  struct DeploymentParamsV4 {
    address owner;
    address spokeProxy;
    address spokeImpl;
    address feeAdapter;
  }

  error Create3DeploymentFailed();
  error UpgradeFailed();
  error NoFeeAdapter();

  bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  address constant CREATE_3 = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
  address public SPOKE_PROXY_MAINNET_OWNER = 0xa02a88F0bbD47045001Bd460Ad186C30F9a974d6;
  address public SPOKE_PROXY_MAINNET = 0xa05A3380889115bf313f1Db9d5f335157Be4D816;
  address public SPOKE_IMPL_MAINNET = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;
  address public SPOKE_GATEWAY_MAINNET = 0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7;
  uint256 public MESSAGE_GAS_LIMIT = 2_000_000;
  address public USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public USDC_OPTIMISM = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
  address public WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public WETH_ARBITRUM = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public CLEAR_MAINNET = 0x58b9cB810A68a7f3e1E4f8Cb45D1B9B3c79705E8;
  address public MAILBOX_MAINNET = 0xc005dc82818d67AF737725bD4bf75435d065D239;
  uint256 public FIXED_MAIN_BLOCK = 21_244_576;
  uint32 constant HUB_ID = 25_327;
  address public HUB_GATEWAY_PROD = 0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa;
  bytes32 public USDC_MAINNET_ASSET_HASH = keccak256(abi.encode(USDC_MAINNET, 1));
  bytes32 public USDC_OPTIMISM_ASSET_HASH = keccak256(abi.encode(USDC_OPTIMISM, 10));
  bytes32 public USDC_ARBITRUM_ASSET_HASH = keccak256(abi.encode(USDC_ARBITRUM, 42_161));

  EverclearSpoke public spokeProxy;
  DeploymentParams public _params;
  DeploymentParamsV4 public _paramsV3;

  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  /**
   * **********************  Solana Upgrade  **********************
   */
  EverclearSpokeV3 public spokeProxyV3;

  /**
   * **********************  FeeAdapter Upgrade  **********************
   */
  EverclearSpokeV4 public spokeProxyV4;

  address public SPOKE_IMPL_MAINNET_V2 = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;

  address public FEE_RECIPIENT_MAINNET = SPOKE_PROXY_MAINNET_OWNER;
  uint256 public FEE_SIGNER_PK = 1;
  address public FEE_SIGNER = vm.addr(FEE_SIGNER_PK);
  address XERC20_MODULE_MAINNET;
  uint256 public FIXED_MAIN_BLOCK_UP2 = 22_146_818;

  mapping(uint256 _chainId => DeploymentParamsV4 _params) internal _deploymentParamsV4;

  /**
   * **********************  Swap Upgrade  **********************
   */
  struct CachedHubState {
    address owner;
    address lighthouse;
    address watchtower;
    address hubGateway;
    uint48 epochLength;
    uint48 expiryTimeBuffer;
    address settlementModule;
    address managerModule;
    address handlerModule;
    address messageReceiverModule;
  }

  address public constant SPOKE_IMPL_MAINNET_V4 = 0xd18C19169e7C87e7d84f27AD412a56C5D743D560;
  uint256 public constant FIXED_MAIN_BLOCK_UP5 = 22_716_806;
  bytes32 internal constant _SETTLEMENT_MODULE = keccak256('settlement_module');
  bytes32 internal constant _HANDLER_MODULE = keccak256('handler_module');
  bytes32 internal constant _MESSAGE_RECEIVER_MODULE = keccak256('message_receiver_module');
  bytes32 internal constant _MANAGER_MODULE = keccak256('manager_module');
  address public constant HUB_PROXY = 0xa05A3380889115bf313f1Db9d5f335157Be4D816;
  address public constant HUB_PROXY_IMPL = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;
  address public constant HUB_PROXY_OWNER = 0xac7599880cB5b5eCaF416BEE57C606f15DA5beB8;

  // Epoch as of 26th Aug - 235177 //
  uint256 internal constant FIXED_EVERCLEAR_BLOCK = 1_667_352;
  uint256 internal constant LAST_BLOCK_NUMBER_CARRY = 250_000; // CurrentEpoch of 213078 with 250_000
  address internal constant USDC_ARBITRUM = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
  address public immutable MANAGER = makeAddr('Manager');

  EverclearSpokeV5 public spokeProxyV5;
  TestEverclearSpokeV5 public testSpokeProxyV5;
  IEverclearHubV2 public hubProxy;
  IHubMessageReceiverV2 public hubMessageReceiverV2;
  IHandlerV2 public handlerV2;
  ISettlerV2 public settlerV2;
  IManagerV2 public managerV2;
  IEverclearHubV2 public everclearHubV2;
  uint64 public testNonce;

  /**
   * **********************  Helpers  **********************
   */
  function _cacheSpokeState() internal view returns (CachedSpokeState memory state) {
    state.permit = address(spokeProxy.PERMIT2());
    state.EVERCLEAR = spokeProxy.EVERCLEAR();
    state.DOMAIN = spokeProxy.DOMAIN();
    state.lighthouse = spokeProxy.lighthouse();
    state.watchtower = spokeProxy.watchtower();
    state.messageReceiver = spokeProxy.messageReceiver();
    state.gateway = address(spokeProxy.gateway());
    state.callExecutor = address(spokeProxy.callExecutor());
    state.paused = spokeProxy.paused();
    state.nonce = spokeProxy.nonce();
    state.messageGasLimit = spokeProxy.messageGasLimit();
  }

  function _cacheSpokeStateV3() internal view returns (CachedSpokeState memory state) {
    state.permit = address(spokeProxyV3.PERMIT2());
    state.EVERCLEAR = spokeProxyV3.EVERCLEAR();
    state.DOMAIN = spokeProxyV3.DOMAIN();
    state.lighthouse = spokeProxyV3.lighthouse();
    state.watchtower = spokeProxyV3.watchtower();
    state.messageReceiver = spokeProxyV3.messageReceiver();
    state.gateway = address(spokeProxyV3.gateway());
    state.callExecutor = address(spokeProxyV3.callExecutor());
    state.paused = spokeProxyV3.paused();
    state.nonce = spokeProxyV3.nonce();
    state.messageGasLimit = spokeProxyV3.messageGasLimit();
  }

  function _cacheSpokeStateV4() internal view returns (CachedSpokeState memory state) {
    state.permit = address(spokeProxyV4.PERMIT2());
    state.EVERCLEAR = spokeProxyV4.EVERCLEAR();
    state.DOMAIN = spokeProxyV4.DOMAIN();
    state.lighthouse = spokeProxyV4.lighthouse();
    state.watchtower = spokeProxyV4.watchtower();
    state.messageReceiver = spokeProxyV4.messageReceiver();
    state.gateway = address(spokeProxyV4.gateway());
    state.callExecutor = address(spokeProxyV4.callExecutor());
    state.paused = spokeProxyV4.paused();
    state.nonce = spokeProxyV4.nonce();
    state.messageGasLimit = spokeProxyV4.messageGasLimit();
  }

  function _getDestinations(IEverclearV2.Intent memory _intent, uint32 _destination) internal pure {
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;
    _intent.destinations = _destinations;
  }

  function _cacheSpokeStateV5() internal view returns (CachedSpokeState memory state) {
    state.permit = address(spokeProxyV5.PERMIT2());
    state.EVERCLEAR = spokeProxyV5.EVERCLEAR();
    state.DOMAIN = spokeProxyV5.DOMAIN();
    state.lighthouse = spokeProxyV5.lighthouse();
    state.watchtower = spokeProxyV5.watchtower();
    state.messageReceiver = spokeProxyV5.messageReceiver();
    state.gateway = address(spokeProxyV5.gateway());
    state.callExecutor = address(spokeProxyV5.callExecutor());
    state.paused = spokeProxyV5.paused();
    state.nonce = spokeProxyV5.nonce();
    state.messageGasLimit = spokeProxyV5.messageGasLimit();
    state.feeAdapter = spokeProxyV5.feeAdapter();
  }

  function _cacheHubState() internal view returns (CachedHubState memory state) {
    state.owner = hubProxy.owner();
    state.lighthouse = hubProxy.lighthouse();
    state.watchtower = hubProxy.watchtower();
    state.hubGateway = address(hubProxy.hubGateway());
    state.epochLength = hubProxy.epochLength();
    state.expiryTimeBuffer = hubProxy.expiryTimeBuffer();
    state.settlementModule = hubProxy.modules(_SETTLEMENT_MODULE);
    state.managerModule = hubProxy.modules(_MANAGER_MODULE);
    state.handlerModule = hubProxy.modules(_HANDLER_MODULE);
    state.messageReceiverModule = hubProxy.modules(_MESSAGE_RECEIVER_MODULE);
  }

  function _upgradeHub() internal {
    vm.createSelectFork(vm.envString('EVERCLEAR_RPC'), FIXED_EVERCLEAR_BLOCK);

    // Deploying
    // 1 - HubMessageReceiverV2 (incl. SettlerLogicV2)
    hubMessageReceiverV2 = new HubMessageReceiverV2();
    // 2 - HandlerV2
    handlerV2 = new HandlerV2();
    // 3 - SettlerV2
    settlerV2 = new SettlerV2();
    // 4 - Manager
    managerV2 = new ManagerV2();
    // 5 - EverclearHubV2
    everclearHubV2 = new EverclearHubV2();

    // Checking implementation correct and caching the state variables
    hubProxy = IEverclearHubV2(HUB_PROXY);
    address oldImplementation = (vm.load(HUB_PROXY, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, HUB_PROXY_IMPL);

    // Caching state variables
    CachedHubState memory state = _cacheHubState();

    // Initializing with new feeAdapter and upgrading
    bytes memory initializeCalldata = abi.encodeWithSelector(
      EverclearHubV2.initialize.selector,
      address(settlerV2),
      address(managerV2),
      address(handlerV2),
      address(hubMessageReceiverV2)
    );
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, everclearHubV2, initializeCalldata);

    vm.prank(HUB_PROXY_OWNER);
    (bool success,) = address(hubProxy).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(HUB_PROXY, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, address(everclearHubV2));

    // Storing value for lastBlockNumberCarryEpoch to prevent underflows in getCurrentEpoch
    vm.store(address(hubProxy), bytes32(uint256(6)), bytes32(LAST_BLOCK_NUMBER_CARRY));

    // Checking the cached state
    assertEq(state.owner, hubProxy.owner());
    assertEq(state.lighthouse, hubProxy.lighthouse());
    assertEq(state.watchtower, hubProxy.watchtower());
    assertEq(state.hubGateway, address(hubProxy.hubGateway()));
    assertEq(state.epochLength, hubProxy.epochLength());
    assertEq(state.expiryTimeBuffer, hubProxy.expiryTimeBuffer());
    assertEq(address(settlerV2), hubProxy.modules(_SETTLEMENT_MODULE));
    assertEq(address(managerV2), hubProxy.modules(_MANAGER_MODULE));
    assertEq(address(handlerV2), hubProxy.modules(_HANDLER_MODULE));
    assertEq(address(hubMessageReceiverV2), hubProxy.modules(_MESSAGE_RECEIVER_MODULE));
  }

  function _generateConfigs(
    IHubStorageV2.TokenSetup[] memory _configs,
    uint8 _adoptedForAssetsNumber,
    uint8 _feesNumber
  ) internal pure {
    for (uint8 _i; _i < _configs.length; _i++) {
      _configs[_i].tickerHash = keccak256(abi.encode(1));
      _configs[_i].fees = new IHubStorageV2.Fee[](_feesNumber);
      _configs[_i].adoptedForAssets = new IHubStorageV2.AssetConfig[](_adoptedForAssetsNumber);

      for (uint8 _j; _j < _feesNumber; _j++) {
        _configs[_i].fees[_j] = IHubStorageV2.Fee({recipient: vm.addr(_j + 1), fee: _j + 2});
      }

      for (uint8 _j; _j < _adoptedForAssetsNumber; _j++) {
        _configs[_i].adoptedForAssets[_j] = IHubStorageV2.AssetConfig({
          tickerHash: _configs[_i].tickerHash,
          adopted: vm.addr(_j + 1).toBytes32(),
          domain: _j,
          approval: _j % 2 == 0,
          strategy: IEverclearV2.Strategy.DEFAULT
        });
      }
    }
  }
}
