// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Vm } from 'forge-std/Vm.sol';
import { console } from 'forge-std/console.sol';

import { MessageLib } from 'contracts/common/MessageLib.sol';

import { TestDAI } from 'test/utils/TestDAI.sol';

import { TestExtended } from 'test/utils/TestExtended.sol';
import { TestWETH } from 'test/utils/TestWETH.sol';

import { XERC20Module } from 'contracts/intent/modules/XERC20Module.sol';
import { ERC20, IXERC20, XERC20 } from 'test/utils/TestXToken.sol';

import { TypeCasts } from 'contracts/common/TypeCasts.sol';
import { AssetUtils } from 'contracts/common/AssetUtils.sol';

import { IInterchainSecurityModule } from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import { IMailbox } from '@hyperlane/interfaces/IMailbox.sol';

import { HubGateway, IHubGateway } from 'contracts/hub/HubGateway.sol';

import { CallExecutor, ICallExecutor } from 'contracts/intent/CallExecutor.sol';
import { EverclearSpoke, IEverclearSpoke } from 'contracts/intent/EverclearSpoke.sol';
import { ISpokeGateway, SpokeGateway } from 'contracts/intent/SpokeGateway.sol';
import { IFeeAdapter, FeeAdapter } from 'contracts/intent/FeeAdapter.sol';

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IMessageReceiver } from 'interfaces/common/IMessageReceiver.sol';

import { IHubStorage } from 'interfaces/hub/IHubStorage.sol';

import { ISpokeStorage } from 'interfaces/intent/ISpokeStorage.sol';
import { StdStorage, stdStorage } from 'test/utils/TestExtended.sol';

import { EverclearHub, IEverclearHub } from 'contracts/hub/EverclearHub.sol';
import { IEverclear } from 'interfaces/common/IEverclear.sol';

import { Handler } from 'contracts/hub/modules/Handler.sol';

import { HubMessageReceiver } from 'contracts/hub/modules/HubMessageReceiver.sol';

import { Manager } from 'contracts/hub/modules/Manager.sol';
import { Settler } from 'contracts/hub/modules/Settler.sol';
import { SpokeMessageReceiver } from 'contracts/intent/modules/SpokeMessageReceiver.sol';

import { Constants } from 'test/utils/Constants.sol';

import { Deploy } from 'utils/Deploy.sol';

struct HubDeploymentParams {
  address owner;
  address deployer;
  string domain;
  uint256 forkBlock;
  address mailbox;
  address ISM;
}

struct SpokeDeploymentParams {
  address owner;
  address deployer;
  string domain;
  address mailbox;
  address ISM;
  uint32 hubDomainId;
  address hubGateway;
  address feeRecipient;
}

struct SpokeChainValues {
  address ism;
  IEverclearSpoke spoke;
  uint32 chainId;
  uint256 fork;
  ISpokeGateway gateway;
  IMailbox mailbox;
  XERC20Module xerc20Module;
  IFeeAdapter feeAdapter;
}


/// @dev BSC_TESTNET RPCs not working - converted to Arbitrum Sepolia and retained naming as temporary fix
contract IntegrationBase is TestExtended {
  using stdStorage for StdStorage;
  using TypeCasts for address;

  address internal _user = makeAddr('user');
  address internal _user2 = makeAddr('user2');
  address internal _owner = makeAddr('owner');
  address internal _admin = makeAddr('admin');
  address internal _assetManager = makeAddr('asset_manager');
  address internal _solverOwner = makeAddr('solver_owner');
  address internal _solver = makeAddr('solver');
  address internal _solverOwner2 = makeAddr('solver_owner_2');
  address internal _solver2 = makeAddr('solver_2');
  address internal _feeRecipient = makeAddr('fee_recipient');
  address internal _feeRecipient2 = makeAddr('fee_recipient_2');
  address internal DEPLOYER = makeAddr('everclear_deployer');
  address internal HUB_DEPLOYER = makeAddr('hub_everclear_deployer');
  address internal LIGHTHOUSE = makeAddr('lighthouse');
  address internal WATCHTOWER = makeAddr('watchtower');
  address internal SECURITY_MODULE = makeAddr('security_module');

  IERC20 internal oUSDT = IERC20(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0); // sepolia ust, 6 decimals
  IERC20 internal dUSDT = IERC20(0x30fA2FbE15c1EaDfbEF28C188b7B8dbd3c1Ff2eB); // bsc usdt, 18 decimals (Arb Sep: 0x30fA2FbE15c1EaDfbEF28C188b7B8dbd3c1Ff2eB)
  IERC20 internal sepoliaDAI;
  IERC20 internal bscDAI;
  IERC20 internal sepoliaWETH;
  IERC20 internal bscWETH;
  IXERC20 internal sepoliaXToken;
  IXERC20 internal bscXToken;

  // Origin domain
  IEverclearSpoke public sepoliaEverclearSpoke;
  ISpokeGateway public sepoliaSpokeGateway;
  ICallExecutor public originCallExecutor;
  IMessageReceiver public originMessageReceiver;
  IMailbox public sepoliaMailbox = IMailbox(0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766); // sepolia mailbox
  address public sepoliaISM = makeAddr('origin_ism');
  XERC20Module public sepoliaXERC20Module;
  IFeeAdapter public sepoliaFeeAdapter;

  // Destination domain
  IEverclearSpoke public bscEverclearSpoke;
  ISpokeGateway public bscSpokeGateway;
  ICallExecutor public destinationCallExecutor;
  IMessageReceiver public destinationMessageReceiver;
  IMailbox public bscMailbox = IMailbox(0x598facE78a4302f11E3de0bee1894Da0b2Cb71F8); // bsc mailbox (Arb Sep: 0x598facE78a4302f11E3de0bee1894Da0b2Cb71F8, BSC:0xF9F6F5646F478d5ab4e20B0F910C92F1CCC9Cc6D)
  address public bscTestnetISM = makeAddr('destination_ism');
  XERC20Module public bscXERC20Module;
  IFeeAdapter public bscFeeAdapter;

  // Hub
  IEverclearHub public hub;
  IHubGateway public hubGateway;
  IMailbox public hubMailbox = IMailbox(address(0x3C5154a193D6e2955650f9305c8d80c18C814A68));
  address public hubISM = makeAddr('hub_ism');

  uint256 totalProtocolFees;
  uint256 addressGeneratedNonce = 1;
  uint256 ETHEREUM_SEPOLIA_FORK;
  uint256 BSC_TESTNET_FORK;
  uint256 HUB_FORK;

  uint256 ETHEREUM_SEPOLIA_FORK_BLOCK = 7_894_090; // ethereum sepolia 11155111
  uint256 BSC_TESTNET_FORK_BLOCK = 132_009_583; // bsc testnet 97 (Arb Sep: 132009583)
  uint256 HUB_FORK_BLOCK = 8_486_730; // scroll sepolia 534351

  uint32 ETHEREUM_SEPOLIA_ID = 11_155_111;
  uint32 BSC_TESTNET_ID = 421614; // (Arb: 421614, BSC: 97)
  uint32 HUB_CHAIN_ID = 534_351;

  // 10% default max discount discount
  uint24 public defaultMaxDiscountDbps = 10_000;
  // 1% default discount per epoch
  uint24 public defaultDiscountPerEpoch = 1000;

  mapping(uint32 _chainId => SpokeChainValues) public spokeChainValues;

  function setUp() public {
    HubDeploymentParams memory hubParams = HubDeploymentParams({
      owner: _owner,
      deployer: HUB_DEPLOYER,
      domain: 'scroll-sepolia',
      forkBlock: HUB_FORK_BLOCK,
      mailbox: address(hubMailbox),
      ISM: hubISM
    });

    // deploy hub contracts
    (HUB_FORK, hub, hubGateway) = _deployHubContracts(hubParams);

    SpokeDeploymentParams memory originParams = SpokeDeploymentParams({
      owner: _owner,
      deployer: DEPLOYER,
      domain: 'sepolia',
      mailbox: address(sepoliaMailbox),
      ISM: sepoliaISM,
      hubDomainId: HUB_CHAIN_ID,
      hubGateway: address(hubGateway),
      feeRecipient: _feeRecipient
    });

    SpokeDeploymentParams memory destinationParams = SpokeDeploymentParams({
      owner: _owner,
      deployer: DEPLOYER,
      domain: 'arb-sepolia',
      mailbox: address(bscMailbox),
      ISM: bscTestnetISM,
      hubDomainId: HUB_CHAIN_ID,
      hubGateway: address(hubGateway),
      feeRecipient: _feeRecipient
    });

    // deploy origin spoke contracts
    (
      ETHEREUM_SEPOLIA_FORK,
      sepoliaEverclearSpoke,
      sepoliaSpokeGateway,
      originCallExecutor,
      originMessageReceiver
    ) = _deploySpokeContracts(originParams);

    // configure xerc20
    vm.startPrank(DEPLOYER);
    sepoliaXERC20Module = new XERC20Module(address(sepoliaEverclearSpoke));
    sepoliaXToken = new XERC20('TXT', 'test', DEPLOYER);
    sepoliaXToken.setLimits(address(sepoliaXERC20Module), type(uint128).max, type(uint128).max);
    sepoliaEverclearSpoke.setStrategyForAsset(address(sepoliaXToken), IEverclear.Strategy.XERC20);
    sepoliaEverclearSpoke.setModuleForStrategy(IEverclear.Strategy.XERC20, sepoliaXERC20Module);

    // Configure fee adapter
    sepoliaFeeAdapter = IFeeAdapter(
      address(new FeeAdapter(address(sepoliaEverclearSpoke), _feeRecipient, address(sepoliaXERC20Module), _owner))
    );

    // deploy dai test contract for sepolia
    sepoliaDAI = new TestDAI('DAI', 'DAI');

    // deploy weth test contract for sepolia
    sepoliaWETH = new TestWETH('WETH', 'WETH');
    vm.stopPrank();

    // deploy destination spoke contracts
    (
      BSC_TESTNET_FORK,
      bscEverclearSpoke,
      bscSpokeGateway,
      destinationCallExecutor,
      destinationMessageReceiver
    ) = _deploySpokeContracts(destinationParams);

    // configure xerc20
    vm.startPrank(DEPLOYER);
    bscXERC20Module = new XERC20Module(address(bscEverclearSpoke));
    bscXToken = new XERC20('TXT', 'test', DEPLOYER);
    bscXToken.setLimits(address(bscXERC20Module), type(uint128).max, type(uint128).max);
    bscEverclearSpoke.setStrategyForAsset(address(bscXToken), IEverclear.Strategy.XERC20);
    bscEverclearSpoke.setModuleForStrategy(IEverclear.Strategy.XERC20, bscXERC20Module);

    // Configure fee adapter
    bscFeeAdapter = IFeeAdapter(
      address(new FeeAdapter(address(bscEverclearSpoke), _feeRecipient, address(bscXERC20Module), _owner))
    );

    // deploy dai test contract for bsc
    bscDAI = new TestDAI('DAI', 'DAI');

    // deploy weth test contract for bsc
    bscWETH = new TestWETH('WETH', 'WETH');
    vm.stopPrank();

    ////////////////////////////// START ADMIN SETUP //////////////////////////////
    vm.selectFork(HUB_FORK);
    vm.startPrank(_admin);

    // assign asset manager
    hub.assignRole(_assetManager, IHubStorage.Role.ASSET_MANAGER);

    // register origin gateway
    vm.startPrank(HUB_DEPLOYER);

    // hub gateway was running out of gas
    vm.deal(address(hub), 10_000 ether);

    hub.updateChainGateway(ETHEREUM_SEPOLIA_ID, address(sepoliaSpokeGateway).toBytes32());
    hub.updateChainGateway(BSC_TESTNET_ID, address(bscSpokeGateway).toBytes32());

    vm.stopPrank();
    ////////////////////////////// END ADMIN SETUP //////////////////////////////

    ////////////////////////////// START ASSET SETUP //////////////////////////////
    IHubStorage.Fee[] memory _fees = new IHubStorage.Fee[](2);
    _fees[0] = IHubStorage.Fee({ recipient: _feeRecipient, fee: 1000 });
    _fees[1] = IHubStorage.Fee({ recipient: _feeRecipient2, fee: 2000 });

    for (uint256 _i; _i < _fees.length; _i++) {
      totalProtocolFees += _fees[_i].fee;
    }

    // default usdt
    address[] memory _assetAddresses = new address[](2);
    _assetAddresses[0] = address(oUSDT);
    _assetAddresses[1] = address(dUSDT);

    uint32[] memory _assetDomains = new uint32[](2);
    _assetDomains[0] = ETHEREUM_SEPOLIA_ID;
    _assetDomains[1] = BSC_TESTNET_ID;

    IHubStorage.AssetConfig[] memory _adoptedForAssets = new IHubStorage.AssetConfig[](2);
    _adoptedForAssets[0] = IHubStorage.AssetConfig({
      tickerHash: keccak256('USDT'),
      adopted: address(oUSDT).toBytes32(),
      domain: ETHEREUM_SEPOLIA_ID,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });
    _adoptedForAssets[1] = IHubStorage.AssetConfig({
      tickerHash: keccak256('USDT'),
      adopted: address(dUSDT).toBytes32(),
      domain: BSC_TESTNET_ID,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    IHubStorage.TokenSetup memory _tokenConfig;
    _tokenConfig.tickerHash = keccak256('USDT');
    _tokenConfig.initLastClosedEpochProcessed = true;
    _tokenConfig.prioritizedStrategy = IEverclear.Strategy.DEFAULT;
    _tokenConfig.maxDiscountDbps = 5000;
    _tokenConfig.discountPerEpoch = 1000;
    _tokenConfig.fees = _fees;
    _tokenConfig.adoptedForAssets = _adoptedForAssets;

    // DAI setup
    address[] memory _assetAddresses1 = new address[](2);
    _assetAddresses1[0] = address(sepoliaDAI);
    _assetAddresses1[1] = address(bscDAI);

    uint32[] memory _assetDomains1 = new uint32[](2);
    _assetDomains1[0] = ETHEREUM_SEPOLIA_ID;
    _assetDomains1[1] = BSC_TESTNET_ID;

    IHubStorage.AssetConfig[] memory _adoptedForAssets1 = new IHubStorage.AssetConfig[](2);
    _adoptedForAssets1[0] = IHubStorage.AssetConfig({
      tickerHash: keccak256('DAI'),
      adopted: address(sepoliaDAI).toBytes32(),
      domain: ETHEREUM_SEPOLIA_ID,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    _adoptedForAssets1[1] = IHubStorage.AssetConfig({
      tickerHash: keccak256('DAI'),
      adopted: address(bscDAI).toBytes32(),
      domain: BSC_TESTNET_ID,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    IHubStorage.TokenSetup memory _tokenConfig1;
    _tokenConfig1.tickerHash = keccak256('DAI');
    _tokenConfig1.prioritizedStrategy = IEverclear.Strategy.DEFAULT;
    _tokenConfig1.maxDiscountDbps = defaultMaxDiscountDbps;
    _tokenConfig1.discountPerEpoch = defaultDiscountPerEpoch;
    _tokenConfig1.fees = _fees;
    _tokenConfig1.adoptedForAssets = _adoptedForAssets1;
    _tokenConfig1.initLastClosedEpochProcessed = true;
    // End DAI setup

    IHubStorage.TokenSetup[] memory _tokenSetups = new IHubStorage.TokenSetup[](3);
    _tokenSetups[0] = _tokenConfig;
    _tokenSetups[1] = _tokenConfig1;
    _tokenSetups[2] = _getWETHTokenSetup(_fees);

    vm.prank(_assetManager);
    hub.setTokenConfigs(_tokenSetups);

    // xtoken
    address[] memory _assetAddresses2 = new address[](2);
    _assetAddresses2[0] = address(sepoliaXToken);
    _assetAddresses2[1] = address(bscXToken);

    uint32[] memory _assetDomains2 = new uint32[](2);
    _assetDomains2[0] = ETHEREUM_SEPOLIA_ID;
    _assetDomains2[1] = BSC_TESTNET_ID;

    IHubStorage.AssetConfig[] memory _adoptedForAssets2 = new IHubStorage.AssetConfig[](2);
    _adoptedForAssets2[0] = IHubStorage.AssetConfig({
      tickerHash: keccak256('TXT'),
      adopted: address(sepoliaXToken).toBytes32(),
      domain: ETHEREUM_SEPOLIA_ID,
      approval: true,
      strategy: IEverclear.Strategy.XERC20
    });
    _adoptedForAssets2[1] = IHubStorage.AssetConfig({
      tickerHash: keccak256('TXT'),
      adopted: address(bscXToken).toBytes32(),
      domain: BSC_TESTNET_ID,
      approval: true,
      strategy: IEverclear.Strategy.XERC20
    });

    IHubStorage.TokenSetup memory _tokenConfig2;
    _tokenConfig2.tickerHash = keccak256('TXT');
    _tokenConfig2.initLastClosedEpochProcessed = true;
    _tokenConfig2.prioritizedStrategy = IEverclear.Strategy.XERC20;
    _tokenConfig2.maxDiscountDbps = 5000;
    _tokenConfig2.discountPerEpoch = 1000;
    _tokenConfig2.fees = _fees;
    _tokenConfig2.adoptedForAssets = _adoptedForAssets2;

    IHubStorage.TokenSetup[] memory _tokenSetups2 = new IHubStorage.TokenSetup[](1);
    _tokenSetups2[0] = _tokenConfig2;

    vm.prank(_assetManager);
    hub.setTokenConfigs(_tokenSetups2);

    ////////////////////////////// END ASSET SETUP //////////////////////////////

    // configure solver
    uint32[] memory _supportedDomains = new uint32[](2);
    _supportedDomains[0] = ETHEREUM_SEPOLIA_ID;
    _supportedDomains[1] = BSC_TESTNET_ID;

    IHubStorage.DomainSetup[] memory _domainSetup = new IHubStorage.DomainSetup[](2);
    _domainSetup[0] = IHubStorage.DomainSetup(ETHEREUM_SEPOLIA_ID, 30_000_000);
    _domainSetup[1] = IHubStorage.DomainSetup(BSC_TESTNET_ID, 120_000_000);

    vm.prank(HUB_DEPLOYER);
    hub.addSupportedDomains(_domainSetup);

    vm.prank(_solver);
    hub.setUserSupportedDomains(_supportedDomains);

    vm.prank(_solver2);
    hub.setUserSupportedDomains(_supportedDomains);

    ////////////// CONFIGURE CHAIN VALUES //////////////
    spokeChainValues[ETHEREUM_SEPOLIA_ID] = SpokeChainValues({
      spoke: sepoliaEverclearSpoke,
      fork: ETHEREUM_SEPOLIA_FORK,
      chainId: ETHEREUM_SEPOLIA_ID,
      ism: sepoliaISM,
      gateway: sepoliaSpokeGateway,
      mailbox: sepoliaMailbox,
      xerc20Module: sepoliaXERC20Module,
      feeAdapter: sepoliaFeeAdapter
    });

    spokeChainValues[BSC_TESTNET_ID] = SpokeChainValues({
      spoke: bscEverclearSpoke,
      fork: BSC_TESTNET_FORK,
      chainId: BSC_TESTNET_ID,
      ism: bscTestnetISM,
      gateway: bscSpokeGateway,
      mailbox: bscMailbox,
      xerc20Module: bscXERC20Module,
      feeAdapter: bscFeeAdapter
    });
  }

  function _deployHubContracts(
    HubDeploymentParams memory _params
  ) internal returns (uint256 _forkId, IEverclearHub _hub, HubGateway _gateway) {
    _forkId = vm.createSelectFork(vm.rpcUrl(_params.domain), _params.forkBlock);

    vm.setNonce(_params.deployer, 0); // set 0

    vm.startPrank(_params.deployer);

    Manager _manager = new Manager(); // 0 -> 1
    Settler _settler = new Settler(); // 1 -> 2
    Handler _handler = new Handler(); // 1 -> 2
    HubMessageReceiver _messageReceiver = new HubMessageReceiver(); // 1 -> 2

    // predict gateway address
    address _predictedGateway = _addressFrom(_params.deployer, 7); // nonce zero

    IEverclearHub.HubInitializationParams memory _init = IEverclearHub.HubInitializationParams(
      _params.deployer,
      _admin,
      address(_manager),
      address(_settler),
      address(_handler),
      address(_messageReceiver),
      LIGHTHOUSE,
      IHubGateway(_predictedGateway),
      2 days, // ownership acceptance delay
      3 hours, // expiry time buffer
      25, // epoch length in blocks
      1000, // 1% discount per epoch
      2, // min supported domains);
      40_000, // base gas units to process settlement batch
      50_000, // gas units per settlement
      30_000 // 30% gas buffer bps
    );

    _hub = Deploy.EverclearHubProxy(_init);

    // deploy hub gateway
    _gateway = Deploy.HubGatewayProxy(_params.owner, _params.mailbox, address(_hub), _params.ISM); // 4 -> 6
    assertEq(_predictedGateway, address(_gateway), string.concat(_params.domain, ' Hub Gateway address mismatch'));

    vm.stopPrank();

    console.log('------------------------', _params.domain, '------------------------');
    console.log('Everclear Hub:', address(_hub));
    console.log('Hub Gateway:', address(_gateway));
    console.log('Manager:', address(_manager));
    console.log('Settler:', address(_settler));
    console.log('Handler:', address(_handler));
    console.log('Hub Message Receiver:', address(_messageReceiver));
    console.log('Chain ID:', block.chainid);
  }

  function _deploySpokeContracts(
    SpokeDeploymentParams memory _params
  )
    internal
    returns (
      uint256 _forkId,
      EverclearSpoke _spoke,
      SpokeGateway _gateway,
      CallExecutor _executor,
      SpokeMessageReceiver _messageReceiver
    )
  {
    _forkId = vm.createSelectFork(vm.rpcUrl(_params.domain));

    vm.setNonce(_params.deployer, 0); // set 0

    // predict gateway address
    address _predictedGateway = _addressFrom(_params.deployer, 3); // nonce zero
    // predict call executor address
    address _predictedCallExecutor = _addressFrom(_params.deployer, 4); // nonce one
    // predict message receiver address
    address _predictedMessageReceiver = _addressFrom(_params.deployer, 5); // nonce one

    vm.startPrank(_params.deployer);

    // deploy Everclear spoke
    ISpokeStorage.SpokeInitializationParams memory _init = ISpokeStorage.SpokeInitializationParams(
      ISpokeGateway(_predictedGateway),
      ICallExecutor(_predictedCallExecutor),
      _predictedMessageReceiver,
      LIGHTHOUSE,
      WATCHTOWER,
      _params.hubDomainId,
      _params.deployer
    ); // 0 -> 2
    _spoke = Deploy.EverclearSpokeProxy(_init);

    // deploy spoke gateway
    _gateway = Deploy.SpokeGatewayProxy(
      _params.owner,
      address(_params.mailbox),
      address(_spoke),
      _params.ISM,
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32()
    ); // 2 -> 4
    assertEq(_predictedGateway, address(_gateway), string.concat(_params.domain, ' Spoke Gateway address mismatch'));

    // deploy call executor
    _executor = new CallExecutor(); // 4 -> 5
    assertEq(
      _predictedCallExecutor,
      address(_executor),
      string.concat(_params.domain, ' Call Executor address mismatch')
    );

    _messageReceiver = new SpokeMessageReceiver();
    assertEq(_predictedMessageReceiver, address(_messageReceiver), 'Message receiver addresses mismatch');

    vm.stopPrank();

    console.log('------------------------', _params.domain, '------------------------');
    console.log('Everclear Spoke:', address(_spoke));
    console.log('Spoke Gateway:', address(_gateway));
    console.log('Spoke Message Receiver:', address(_messageReceiver));
    console.log('ISM:', address(_params.ISM));
    console.log('Call Executor:', address(_executor));
    console.log('Chain ID:', block.chainid);
  }

  /*///////////////////////////////////////////////////////////////
                             HELPERS 
  //////////////////////////////////////////////////////////////*/

  function _bytes32ToUint32(bytes32 _input) public pure returns (uint32 _output) {
    assembly {
      _output := mload(add(_input, 32))
    }
  }

  function _body(bytes memory _bytes) internal pure returns (bytes memory _result) {
    _result = new bytes(_bytes.length - 77);

    for (uint256 _i; _i < _bytes.length - 77; _i++) {
      _result[_i] = _bytes[_i + 77];
    }
  }

  function _getWETHTokenSetup(
    IHubStorage.Fee[] memory _fees
  ) internal view returns (IHubStorage.TokenSetup memory _tokenConfig) {
    // WETH setup
    address[] memory _assetAddresses = new address[](2);
    _assetAddresses[0] = address(sepoliaWETH);
    _assetAddresses[1] = address(bscWETH);

    uint32[] memory _assetDomains = new uint32[](2);
    _assetDomains[0] = ETHEREUM_SEPOLIA_ID;
    _assetDomains[1] = BSC_TESTNET_ID;

    IHubStorage.AssetConfig[] memory _adoptedForAssets = new IHubStorage.AssetConfig[](2);
    _adoptedForAssets[0] = IHubStorage.AssetConfig({
      tickerHash: keccak256('WETH'),
      adopted: address(sepoliaWETH).toBytes32(),
      domain: ETHEREUM_SEPOLIA_ID,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    _adoptedForAssets[1] = IHubStorage.AssetConfig({
      tickerHash: keccak256('WETH'),
      adopted: address(bscWETH).toBytes32(),
      domain: BSC_TESTNET_ID,
      approval: true,
      strategy: IEverclear.Strategy.DEFAULT
    });

    _tokenConfig.tickerHash = keccak256('WETH');
    _tokenConfig.prioritizedStrategy = IEverclear.Strategy.DEFAULT;
    _tokenConfig.maxDiscountDbps = defaultMaxDiscountDbps;
    _tokenConfig.discountPerEpoch = defaultDiscountPerEpoch;
    _tokenConfig.fees = _fees;
    _tokenConfig.adoptedForAssets = _adoptedForAssets;
    _tokenConfig.initLastClosedEpochProcessed = true;
    // End WETH setup
  }

  /*///////////////////////////////////////////////////////////////
                    REUSABLE INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function _processSettlementMessage(uint32 _destination, bytes memory _settlementMessageBody) internal {
    SpokeChainValues memory _chainValues = spokeChainValues[_destination];

    vm.selectFork(_chainValues.fork);

    bytes memory _settlementMessageFormatted = _formatHLMessage(
      3,
      1337,
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _destination,
      address(_chainValues.gateway).toBytes32(),
      _body(_settlementMessageBody)
    );

    // mock call to ISM
    vm.mockCall(
      _chainValues.ism,
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _settlementMessageFormatted),
      abi.encode(true)
    );

    // deliver settlement message to spoke
    vm.prank(makeAddr('caller'));
    _chainValues.mailbox.process(bytes(''), _settlementMessageFormatted);
  }

  function _processDepositsAndInvoices(
    bytes32 _tickerHash,
    uint32 _maxEpochs,
    uint32 _maxDeposits,
    uint32 _maxInvoices
  ) internal {
    vm.selectFork(HUB_FORK);

    hub.processDepositsAndInvoices(_tickerHash, _maxEpochs, _maxDeposits, _maxInvoices);
  }

  function _processDepositsAndInvoices(bytes32 _tickerHash) internal {
    _processDepositsAndInvoices(_tickerHash, 0, 0, 0);
  }

  function _processSettlementQueue(
    uint32 _chainId,
    uint32 _amount
  ) internal returns (bytes memory _settlementMessageBody) {
    vm.selectFork(HUB_FORK);
    vm.recordLogs();

    // process settlement queue
    vm.deal(LIGHTHOUSE, 100 ether);
    vm.prank(LIGHTHOUSE);
    hub.processSettlementQueue{ value: 1 ether }(_chainId, _amount);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    _settlementMessageBody = abi.decode(entries[0].data, (bytes));
  }

  function _createIntentAndReceiveInHub(
    address _user,
    IERC20 _assetOrigin,
    IERC20 _assetDestination,
    uint32 _origin,
    uint32 _destination,
    uint256 _intentAmount
  ) internal returns (bytes32 _intentId, IEverclear.Intent memory _intent) {
    return
      _createIntentAndReceiveInHubWithTTL({
        _user: _user,
        _assetOrigin: _assetOrigin,
        _assetDestination: _assetDestination,
        _origin: _origin,
        _destination: _destination,
        _intentAmount: _intentAmount,
        _ttl: 0
      });
  }

  function _createIntentAndReceiveInHubWithTTL(
    address _user,
    IERC20 _assetOrigin,
    IERC20 _assetDestination,
    uint32 _origin,
    uint32 _destination,
    uint256 _intentAmount,
    uint48 _ttl
  ) internal returns (bytes32 _intentId, IEverclear.Intent memory _intent) {
    // build destinations array
    uint32[] memory _destA = new uint32[](1);
    _destA[0] = _destination;

    return
      _createIntentAndReceiveInHubWithTTLAndDestinations(
        _user,
        _assetOrigin,
        _assetDestination,
        _origin,
        _destA,
        _intentAmount,
        _ttl
      );
  }

  function _createIntentAndReceiveInHubWithTTLAndDestinations(
    address _user,
    IERC20 _assetOrigin,
    IERC20 _assetDestination,
    uint32 _origin,
    uint32[] memory _destinations,
    uint256 _intentAmount,
    uint48 _ttl
  ) internal returns (bytes32 _intentId, IEverclear.Intent memory _intent) {
    SpokeChainValues memory _chainValues = spokeChainValues[_origin];

    /*///////////////////////////////////////////////////////////////
                            ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // select origin fork
    vm.selectFork(_chainValues.fork);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    deal(address(_assetOrigin), _user, _intentAmount);

    // approve tokens
    vm.prank(_user);
    _assetOrigin.approve(address(_chainValues.spoke), type(uint256).max);

    // create new intent
    vm.prank(_user);

    bytes memory _intentCalldata = abi.encode(makeAddr('target'), abi.encodeWithSignature('doSomething()'));

    (_intentId, _intent) = _chainValues.spoke.newIntent(
      _destinations,
      _user,
      address(_assetOrigin),
      address(_assetDestination),
      _intentAmount,
      Constants.MAX_FEE,
      _ttl,
      _intentCalldata
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    _chainValues.spoke.processIntentQueue{ value: 1 ether }(_intentsA);

    /*///////////////////////////////////////////////////////////////
                            EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBody = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessage = _formatHLMessage(
      3,
      1337,
      _origin,
      address(_chainValues.gateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBody
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessage),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessage);
  }

  function _createIntentWithFeeAdapterAndReceiveInHub(
    address _user,
    IERC20 _assetOrigin,
    IERC20 _assetDestination,
    uint32 _origin,
    uint32 _destination,
    uint256 _intentAmount,
    uint256 _tokenFee,
    uint256 _ethFee
  ) internal returns (bytes32 _intentId, IEverclear.Intent memory _intent) {
    return
      _createIntentWithFeeAdapterAndReceiveInHubWithTTL({
        _user: _user,
        _assetOrigin: _assetOrigin,
        _assetDestination: _assetDestination,
        _origin: _origin,
        _destination: _destination,
        _intentAmount: _intentAmount,
        _ttl: 0,
        _tokenFee: _tokenFee,
        _ethFee: _ethFee
      });
  }

  function _createIntentWithFeeAdapterAndReceiveInHubWithTTL(
    address _user,
    IERC20 _assetOrigin,
    IERC20 _assetDestination,
    uint32 _origin,
    uint32 _destination,
    uint256 _intentAmount,
    uint48 _ttl,
    uint256 _tokenFee,
    uint256 _ethFee
  ) internal returns (bytes32 _intentId, IEverclear.Intent memory _intent) {
    // build destinations array
    uint32[] memory _destA = new uint32[](1);
    _destA[0] = _destination;

    return
      _createIntentWithFeeAdapterAndReceiveInHubWithTTLAndDestinations(
        _user,
        _assetOrigin,
        _assetDestination,
        _origin,
        _destA,
        _intentAmount,
        _ttl,
        _tokenFee,
        _ethFee
      );
  }

  function _createIntentWithFeeAdapterAndReceiveInHubWithTTLAndDestinations(
    address _user,
    IERC20 _assetOrigin,
    IERC20 _assetDestination,
    uint32 _origin,
    uint32[] memory _destinations,
    uint256 _intentAmount,
    uint48 _ttl,
    uint256 _tokenFee,
    uint256 _ethFee
  ) internal returns (bytes32 _intentId, IEverclear.Intent memory _intent) {
    SpokeChainValues memory _chainValues = spokeChainValues[_origin];

    /*///////////////////////////////////////////////////////////////
                            ORIGIN DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // select origin fork
    vm.selectFork(_chainValues.fork);

    // deal to lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);
    // deal origin usdt to user
    deal(address(_assetOrigin), _user, _intentAmount + _tokenFee);
    // deal the user the ethFee if needed
    vm.deal(_user, _ethFee);

    // approve tokens
    vm.prank(_user);
    _assetOrigin.approve(address(_chainValues.feeAdapter), type(uint256).max);

    // create new intent
    vm.prank(_user);

    (_intentId, _intent) = _chainValues.feeAdapter.newIntent{ value: _ethFee }(
      _destinations,
      _user,
      address(_assetOrigin),
      address(_assetDestination),
      _intentAmount,
      Constants.MAX_FEE,
      _ttl,
      hex'00',
      _tokenFee
    );

    // create intent message
    IEverclear.Intent[] memory _intentsA = new IEverclear.Intent[](1);
    _intentsA[0] = _intent;

    // process intent queue
    vm.prank(LIGHTHOUSE);
    _chainValues.spoke.processIntentQueue{ value: 1 ether }(_intentsA);

    /*///////////////////////////////////////////////////////////////
                            EVERCLEAR DOMAIN 
  //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    bytes memory _intentMessageBody = MessageLib.formatIntentMessageBatch(_intentsA);
    bytes memory _intentMessage = _formatHLMessage(
      3,
      1337,
      _origin,
      address(_chainValues.gateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _intentMessageBody
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _intentMessage),
      abi.encode(true)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _intentMessage);
  }

  function _fillIntentAndReceiveInHub(
    bytes32 _intentId,
    IEverclear.Intent memory _intent,
    IERC20 _assetDestination,
    uint32 _destination,
    uint256 _intentAmount,
    address _solver
  ) internal {
    /*///////////////////////////////////////////////////////////////
                        DESTINATION DOMAIN 
  //////////////////////////////////////////////////////////////*/
    SpokeChainValues memory _chainValues = spokeChainValues[_destination];

    // switch to destination fork
    vm.selectFork(_chainValues.fork);

    // deal output asset to solver
    deal(address(_assetDestination), _solver, _intentAmount);

    vm.startPrank(_solver);
    // approve Everclear spoke
    _assetDestination.approve(address(_chainValues.spoke), type(uint256).max);

    // deposit output asset
    _chainValues.spoke.deposit(address(_assetDestination), _intentAmount);

    vm.mockCall(makeAddr('target'), abi.encodeWithSignature('doSomething()'), abi.encode(true));

    // execute user intent
    IEverclear.FillMessage memory _fillMessage = _chainValues.spoke.fillIntent(_intent, _intent.maxFee);

    vm.stopPrank();

    // deal lighthouse
    vm.deal(LIGHTHOUSE, 100 ether);

    // process fill queue
    vm.prank(LIGHTHOUSE);
    _chainValues.spoke.processFillQueue{ value: 1 ether }(1);

    /*///////////////////////////////////////////////////////////////
                         EVERCLEAR DOMAIN 
    //////////////////////////////////////////////////////////////*/

    // switch to everclear fork
    vm.selectFork(HUB_FORK);

    // create intent message
    IEverclear.FillMessage[] memory _fillMessages = new IEverclear.FillMessage[](1);
    _fillMessages[0] = _fillMessage;

    bytes memory _fillMessageBody = MessageLib.formatFillMessageBatch(_fillMessages);
    bytes memory _fillMessageFormatted = _formatHLMessage(
      3,
      1337,
      _destination,
      address(_chainValues.gateway).toBytes32(),
      HUB_CHAIN_ID,
      address(hubGateway).toBytes32(),
      _fillMessageBody
    );

    // mock call to ISM
    vm.mockCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _fillMessageFormatted),
      abi.encode(true)
    );
    vm.expectCall(
      address(hubISM),
      abi.encodeWithSelector(IInterchainSecurityModule.verify.selector, bytes(''), _fillMessageFormatted)
    );

    // deliver intent message to hub
    vm.prank(makeAddr('caller'));
    hubMailbox.process(bytes(''), _fillMessageFormatted);
  }

  function _rollEpochs(uint48 _epochs) internal {
    vm.selectFork(HUB_FORK);
    vm.roll(block.number + hub.epochLength() * _epochs);
  }

  function _switchFork(uint256 _fork) internal {
    vm.selectFork(_fork);
  }

  function _switchHubFork() internal {
    _switchFork(HUB_FORK);
  }

  function _generateAddress() internal returns (address _addr) {
    _addr = vm.addr(addressGeneratedNonce);
    addressGeneratedNonce++;
  }

  function _getTokenBalanceInSepolia(address _account, address _token) internal returns (uint256) {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    return ERC20(_token).balanceOf(_account);
  }

  function _getTokenBalanceInBscTestnet(address _account, address _token) internal returns (uint256) {
    _switchFork(BSC_TESTNET_FORK);
    return ERC20(_token).balanceOf(_account);
  }

  function _getTokenVirtualBalanceInSepolia(address _account, address _token) internal returns (uint256) {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    return sepoliaEverclearSpoke.balances(_token.toBytes32(), _account.toBytes32());
  }

  function _getTokenVirtualBalanceInBscTestnet(address _account, address _token) internal returns (uint256) {
    _switchFork(BSC_TESTNET_FORK);
    return bscEverclearSpoke.balances(_token.toBytes32(), _account.toBytes32());
  }

  function _getTokenMintableByUserInSepolia(address _account, address _token) internal returns (uint256) {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    return sepoliaXERC20Module.mintable(_account, _token);
  }

  function _getTokenMintableByUserInBscTestnet(address _account, address _token) internal returns (uint256) {
    _switchFork(BSC_TESTNET_FORK);
    return bscXERC20Module.mintable(_account, _token);
  }

  function _getInvoicesForAsset(
    bytes32 _tickerHash
  ) internal returns (bytes32 _head, bytes32 _tail, uint256 _nonce, uint256 _length) {
    _switchHubFork();
    return hub.invoices(_tickerHash);
  }

  function _closeEpochAndProcessDepositsAndInvoices(bytes32 _tickerHash) internal {
    _rollEpochs(1);
    _processDepositsAndInvoices(_tickerHash);
  }

  function _elapseTimeInChains(uint256 _time) internal {
    _unifyUnixBlocktimestampInChains(block.timestamp + _time);
  }

  function _unifyUnixBlocktimestampInChains(uint256 _blocktimestamp) internal {
    _switchFork(ETHEREUM_SEPOLIA_FORK);
    vm.warp(_blocktimestamp);

    _switchFork(BSC_TESTNET_FORK);
    vm.warp(_blocktimestamp);

    _switchHubFork();
    vm.warp(_blocktimestamp);
  }

  function _setAdpotedForAsset(IHubStorage.AssetConfig memory _config) internal {
    _switchHubFork();
    vm.prank(_assetManager);
    hub.setAdoptedForAsset(_config);
  }

  function _setUserSupportedDomains(address _account, uint32[] memory _domains) internal {
    _switchHubFork();
    vm.prank(_account);
    hub.setUserSupportedDomains(_domains);
  }

  function _mockMintAndApprove(address _token, address _account, uint32 _chainId, uint256 _amount) internal {
    _switchFork(spokeChainValues[_chainId].fork);
    XERC20(address(_token)).mockMint(_account, _amount);

    // approve tokens
    vm.prank(_account);
    ERC20(address(_token)).approve(address(spokeChainValues[_chainId].xerc20Module), type(uint256).max);
  }

  function _setPrioritizedStrategy(bytes32 _tickerHash, IEverclear.Strategy _strategy) internal {
    _switchHubFork();
    vm.prank(_assetManager);
    hub.setPrioritizedStrategy(_tickerHash, _strategy);
  }

  function _withdrawFees(
    bytes32 _tickerHash,
    address _withdrawer,
    address _recipient,
    uint256 _amount,
    uint32[] memory _destinations
  ) internal {
    _switchHubFork();
    vm.prank(_withdrawer);
    hub.withdrawFees(_recipient.toBytes32(), _tickerHash, _amount, _destinations);
  }

  function _generateEvenSplitIntentsAndConfirmStatusIsAdded(
    address _initiator,
    uint64 _nonce,
    uint256 _numOfIntents,
    uint32 _domain,
    IEverclearSpoke _spoke,
    IFeeAdapter.OrderParameters memory _params
  ) internal returns (IEverclear.Intent[] memory) {
    // Calculating the normalised amount
    uint256 _toSend = _params.amount / _numOfIntents;
    uint256 _toSendNormalised = AssetUtils.normalizeDecimals(
      ERC20(_params.inputAsset).decimals(),
      Constants.DEFAULT_NORMALIZED_DECIMALS,
      _toSend
    );

    // Initialising the intent and updating
    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](_numOfIntents);
    for (uint256 i = 0; i < _numOfIntents - 1; i++) {
      _intents[i] = IEverclear.Intent({
        initiator: _initiator.toBytes32(),
        receiver: _params.receiver.toBytes32(),
        inputAsset: _params.inputAsset.toBytes32(),
        outputAsset: _params.outputAsset.toBytes32(),
        maxFee: _params.maxFee,
        origin: _domain,
        nonce: _nonce,
        timestamp: uint48(block.timestamp),
        ttl: _params.ttl,
        amount: _toSendNormalised,
        destinations: _params.destinations,
        data: _params.data
      });

      // Iterating the nonce
      _nonce++;
    }

    // Last intent
    _toSend = _params.amount - (_toSend * (_numOfIntents - 1));
    _toSendNormalised = AssetUtils.normalizeDecimals(
      ERC20(_params.inputAsset).decimals(),
      Constants.DEFAULT_NORMALIZED_DECIMALS,
      _toSend
    );
    _intents[_numOfIntents - 1] = IEverclear.Intent({
      initiator: _initiator.toBytes32(),
      receiver: _params.receiver.toBytes32(),
      inputAsset: _params.inputAsset.toBytes32(),
      outputAsset: _params.outputAsset.toBytes32(),
      maxFee: _params.maxFee,
      origin: _domain,
      nonce: _nonce,
      timestamp: uint48(block.timestamp),
      ttl: _params.ttl,
      amount: _toSendNormalised,
      destinations: _params.destinations,
      data: _params.data
    });

    // Checking the status is added on the Spoke
    for (uint256 i; i < _numOfIntents; i++) {
      bytes32 _intentId = keccak256(abi.encode(_intents[i]));
      assertEq(uint8(_spoke.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));
    }

    return _intents;
  }

  function _generateUnknownSplitIntentsAndConfirmStatusIsAdded(
    address _initiator,
    uint64 _nonce,
    uint32 _domain,
    IEverclearSpoke _spoke,
    IFeeAdapter.OrderParameters[] memory _params
  ) internal returns (IEverclear.Intent[] memory) {
    // Initialising the intent and updating
    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](_params.length);
    for (uint256 i = 0; i < _params.length; i++) {
      // Normalising the amount
      uint256 _toSendNormalised = AssetUtils.normalizeDecimals(
        ERC20(_params[i].inputAsset).decimals(),
        Constants.DEFAULT_NORMALIZED_DECIMALS,
        _params[i].amount
      );
      _intents[i] = IEverclear.Intent({
        initiator: _initiator.toBytes32(),
        receiver: _params[i].receiver.toBytes32(),
        inputAsset: _params[i].inputAsset.toBytes32(),
        outputAsset: _params[i].outputAsset.toBytes32(),
        maxFee: _params[i].maxFee,
        origin: _domain,
        nonce: _nonce,
        timestamp: uint48(block.timestamp),
        ttl: _params[i].ttl,
        amount: _toSendNormalised,
        destinations: _params[i].destinations,
        data: _params[i].data
      });

      // Iterating the nonce
      _nonce++;
    }

    // Checking the status is added on the Spoke
    for (uint256 i; i < _params.length; i++) {
      bytes32 _intentId = keccak256(abi.encode(_intents[i]));
      assertEq(uint8(_spoke.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));
    }

    return _intents;
  }

  function _normaliseAmount(uint256 _amount, address _asset) internal returns (uint256) {
    return AssetUtils.normalizeDecimals(ERC20(_asset).decimals(), Constants.DEFAULT_NORMALIZED_DECIMALS, _amount);
  }

  function _calculateAmountAfterFeesForMultipleIntents(
    uint256[] memory _normalizedAmounts,
    address _outputAsset
  ) internal returns (uint256 _amountAfterFees) {
    for (uint256 i; i < _normalizedAmounts.length; i++) {
      uint256 _amountFeesApplied = _normalizedAmounts[i] -
        ((totalProtocolFees * _normalizedAmounts[i]) / Constants.DBPS_DENOMINATOR);
      _amountAfterFees += AssetUtils.normalizeDecimals(
        Constants.DEFAULT_NORMALIZED_DECIMALS,
        ERC20(_outputAsset).decimals(),
        _amountFeesApplied
      );
    }
  }

  function _calculateAmountAfterFeesForIntentArray(IEverclear.Intent[] memory _intents, address _outputAsset) internal returns (uint256 _amountAfterFees) {
    for (uint256 i; i < _intents.length; i++) {
      uint256 _amountFeesApplied = _intents[i].amount -
        ((totalProtocolFees * _intents[i].amount) / Constants.DBPS_DENOMINATOR);
      _amountAfterFees += AssetUtils.normalizeDecimals(
        Constants.DEFAULT_NORMALIZED_DECIMALS,
        ERC20(_outputAsset).decimals(),
        _amountFeesApplied
      );
    }
  }
}
