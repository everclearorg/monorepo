// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MessageLibV2} from 'contracts/common/MessageLibV2.sol';
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
  function deploy(
    bytes32 _salt,
    bytes calldata _creationCode
  ) external payable returns (address _deployed);
}

contract TestEverclearSpokeV5 is EverclearSpokeV5 {
  function processQueueChecks(
    uint32 _domain,
    address _relayer,
    uint256 _ttl
  ) external view {
    return _processQueueChecks(_domain, _relayer, _ttl);
  }

  function executeCalldata(
    bytes32 _intentId,
    bytes memory _data
  ) external {
    return _executeCalldata(_intentId, _data);
  }

  function verifySignature(
    address _signer,
    bytes memory _data,
    uint256 _nonce,
    bytes calldata _signature
  ) external {
    return _verifySignature(_signer, _data, _nonce, _signature);
  }
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

contract TestEverclearSpokeV5 is EverclearSpokeV5 {
  function processQueueChecks(uint32 _domain, address _relayer, uint256 _ttl) external view {
    return _processQueueChecks(_domain, _relayer, _ttl);
  }

  function executeCalldata(bytes32 _intentId, bytes memory _data) external {
    return _executeCalldata(_intentId, _data);
  }

  function verifySignature(address _signer, bytes memory _data, uint256 _nonce, bytes calldata _signature) external {
    return _verifySignature(_signer, _data, _nonce, _signature);
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
  address public USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
  address public USDC_MANTLE = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
  address public USDC_BNB = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
  address public USDC_LINEA = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
  address public USDC_POLYGON = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
  address public USDC_AVALANCHE = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
  address public USDC_SCROLL = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
  address public USDC_TAIKO = 0x07d83526730c7438048D55A4fc0b850e2aaB6f0b;
  // address public USDC_ZIRCUIT = ;
  address public USDC_MODE = 0xd988097fb8612cc24eeC14542bC03424c656005f;
  address public USDC_UNICHAIN = 0x078D782b760474a361dDA0AF3839290b0EF57AD6;
  address public USDC_ZKSYNC = 0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4;
  address public USDC_RONIN = 0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc;
  address public USDC_BERACHAIN = 0x549943e04f40284185054145c6E4e9568C1D3241;
  address public USDC_SONIC = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
  address public USDC_INK = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
  bytes32 public USDC_SOLANA = 0xc6fa7af3bedbad3a3d65f36aabc97431b1bbe4c2d2f6e0e47ca60203452f5d61;

  address public USDT_MAINNET = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
  address public USDT_ARBITRUM = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
  address public USDT_OPTIMISM = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;

  address public WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public WETH_ARBITRUM = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public CLEAR_MAINNET = 0x58b9cB810A68a7f3e1E4f8Cb45D1B9B3c79705E8;
  address public MAILBOX_MAINNET = 0xc005dc82818d67AF737725bD4bf75435d065D239;
  address public AAVE_ARBITRUM = 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196;
  uint256 public FIXED_MAIN_BLOCK = 21_244_576;
  uint32 constant HUB_ID = 25_327;

  address public HUB_GATEWAY_PROD = 0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa;
  bytes32 public USDC_MAINNET_ASSET_HASH = keccak256(abi.encode(USDC_MAINNET, 1));
  bytes32 public USDC_OPTIMISM_ASSET_HASH = keccak256(abi.encode(USDC_OPTIMISM, 10));
  bytes32 public USDC_BASE_ASSET_HASH = keccak256(abi.encode(USDC_BASE, 8453));
  bytes32 public USDC_MANTLE_ASSET_HASH = keccak256(abi.encode(USDC_MANTLE, 5000));
  bytes32 public USDC_ARBITRUM_ASSET_HASH = keccak256(abi.encode(USDC_ARBITRUM, 42_161));
  bytes32 public USDC_BNB_ASSET_HASH = keccak256(abi.encode(USDC_BNB, 56));

  bytes32 public USDC_LINEA_ASSET_HASH = keccak256(abi.encode(USDC_LINEA, 59_144));
  bytes32 public USDC_POLYGON_ASSET_HASH = keccak256(abi.encode(USDC_POLYGON, 137));
  bytes32 public USDC_AVALANCHE_ASSET_HASH = keccak256(abi.encode(USDC_AVALANCHE, 43_114));
  bytes32 public USDC_SCROLL_ASSET_HASH = keccak256(abi.encode(USDC_SCROLL, 534_353));
  bytes32 public USDC_TAIKO_ASSET_HASH = keccak256(abi.encode(USDC_TAIKO, 167_000));
  // bytes32 public USDC_ZIRCUIT_ASSET_HASH = keccak256(abi.encode(USDC_ZIRCUIT, 0));
  bytes32 public USDC_MODE_ASSET_HASH = keccak256(abi.encode(USDC_MODE, 34_443));
  bytes32 public USDC_UNICHAIN_ASSET_HASH = keccak256(abi.encode(USDC_UNICHAIN, 130));
  bytes32 public USDC_ZKSYNC_ASSET_HASH = keccak256(abi.encode(USDC_ZKSYNC, 324));
  bytes32 public USDC_RONIN_ASSET_HASH = keccak256(abi.encode(USDC_RONIN, 2020));
  bytes32 public USDC_BERACHAIN_ASSET_HASH = keccak256(abi.encode(USDC_BERACHAIN, 80_094));
  bytes32 public USDC_SONIC_ASSET_HASH = keccak256(abi.encode(USDC_SONIC, 146));
  bytes32 public USDC_INK_ASSET_HASH = keccak256(abi.encode(USDC_INK, 57_073));
  bytes32 public USDC_SOLANA_ASSET_HASH = keccak256(abi.encode(USDC_SOLANA, 1_399_811_149));

  bytes32 public USDT_ETHEREUM_ASSET_HASH = keccak256(abi.encode(USDT_MAINNET, 1));
  bytes32 public USDT_ARBITRUM_ASSET_HASH = keccak256(abi.encode(USDT_ARBITRUM, 42_161));
  bytes32 public USDT_OPTIMISM_ASSET_HASH = keccak256(abi.encode(USDT_OPTIMISM, 10));

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
  uint256 public constant DEFAULT_GAS_LIMIT = 500_000;
  uint256 public constant FILL_SIGNER_PK = 99_900_999;
  address public FILL_SIGNER = vm.addr(FILL_SIGNER_PK);

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

  function _getDestinations(
    IEverclearV2.Intent memory _intent,
    uint32 _destination
  ) internal pure {
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

  function _configureIntentMessages(
    uint256 _total,
    address _inputAsset,
    address _outputAsset,
    uint32 _origin,
    uint32[] memory _destinations,
    bool _netting
  ) internal returns (IEverclearV2.Intent[] memory _intents, bytes memory _message) {
    _intents = new IEverclearV2.Intent[](_total);
    for (uint256 i; i < _total; i++) {
      address _initiator = address(uint160(uint256(keccak256(abi.encodePacked(i, 'initiator')))));
      address _receiver = address(uint160(uint256(keccak256(abi.encodePacked(i, 'receiver')))));

      _intents[i] = IEverclearV2.Intent({
        initiator: _initiator.toBytes32(),
        receiver: _receiver.toBytes32(),
        inputAsset: _inputAsset.toBytes32(),
        outputAsset: _outputAsset.toBytes32(),
        origin: _origin,
        nonce: testNonce++,
        timestamp: uint48(block.timestamp),
        ttl: _netting ? 0 : 2 hours,
        amount: 1000e18,
        amountOutMin: _netting ? 0 : 990e18,
        destinations: _destinations,
        data: ''
      });
    }
    _message = MessageLibV2.formatIntentMessageBatch(_intents);
  }
}
