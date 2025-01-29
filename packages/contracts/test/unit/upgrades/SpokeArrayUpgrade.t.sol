// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {ISpecifiesInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {EverclearSpoke, IEverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';

import {Deploy} from 'script/utils/Deploy.sol';
import {BaseTest} from 'test/unit/intent/EverclearSpoke.t.sol';
import {Constants} from 'test/utils/Constants.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'forge-std/console.sol';
import {ICREATE3, UpgradeHelper} from 'test//utils/UpgradeHelper.sol';

contract SpokeArrayUpgradeTest is BaseTest, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  address public HUB_GATEWAY = 0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa;

  // ============ Upgrade ============ //
  function test_spokeArrayUpgrade_upgrade() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK);

    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();

    // Generating the inputs for CREATE3
    uint8 version = 2;
    bytes32 _salt = keccak256(abi.encodePacked(SPOKE_PROXY_MAINNET, version));
    bytes32 _implementationSalt = keccak256(abi.encodePacked(_salt, 'implementation'));
    bytes memory _creation = type(EverclearSpoke).creationCode;

    // Deploying the new implementation
    bytes memory create3Calldata = abi.encodeWithSelector(ICREATE3.deploy.selector, _implementationSalt, _creation);
    (bool success, bytes memory returnData) = CREATE_3.call(create3Calldata);
    if (!success) revert Create3DeploymentFailed();
    address newEverclearSpoke = abi.decode(returnData, (address));

    // Deploying impl and upgrading the contract
    success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    (success,) = address(spokeProxy).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function reverts
    vm.expectRevert(IEverclearSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxy.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxy.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxy.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxy.DOMAIN());
    assertEq(state.lighthouse, spokeProxy.lighthouse());
    assertEq(state.watchtower, spokeProxy.watchtower());
    assertEq(state.messageReceiver, spokeProxy.messageReceiver());
    assertEq(state.gateway, address(spokeProxy.gateway()));
    assertEq(state.callExecutor, address(spokeProxy.callExecutor()));
    assertEq(state.paused, spokeProxy.paused());
    assertEq(state.nonce, spokeProxy.nonce());
    assertEq(state.messageGasLimit, spokeProxy.messageGasLimit());
  }

  // ============ Admin Unit ============ //
  function test_spokeArrayUpgrade_pause() public {
    _upgradeSpoke();

    vm.prank(spokeProxy.lighthouse());
    spokeProxy.pause();
    assertEq(spokeProxy.paused(), true);

    vm.prank(spokeProxy.watchtower());
    spokeProxy.unpause();
    assertEq(spokeProxy.paused(), false);
  }

  function test_spokeArrayUpgrade_setStrategyForAsset() public {
    _upgradeSpoke();

    vm.prank(spokeProxy.owner());
    spokeProxy.setStrategyForAsset(address(0x123), IEverclear.Strategy.XERC20);
    assertEq(uint8(spokeProxy.strategies(address(0x123))), uint8(IEverclear.Strategy.XERC20));
  }

  function test_spokeArrayUpgrade_setModuleForStrategy() public {
    _upgradeSpoke();

    vm.prank(spokeProxy.owner());
    spokeProxy.setModuleForStrategy(IEverclear.Strategy.XERC20, ISettlementModule(address(0x123)));
    assertEq(address(spokeProxy.modules(IEverclear.Strategy.XERC20)), address(0x123));
  }

  function test_spokeArrayUpgrade_updateSecurityModule() public {
    _upgradeSpoke();

    vm.prank(spokeProxy.owner());
    spokeProxy.updateSecurityModule(address(0x123));
    address gateway = address(spokeProxy.gateway());
    address updatedModule = address(ISpecifiesInterchainSecurityModule(gateway).interchainSecurityModule());
    assertEq(updatedModule, address(0x123));
  }

  function test_spokeArrayUpgrade_updateGateway() public {
    _upgradeSpoke();

    vm.prank(spokeProxy.owner());
    spokeProxy.updateGateway(address(0x123));
    assertEq(address(spokeProxy.gateway()), address(0x123));
  }

  function test_spokeArrayUpgrade_updateMessageReceiver() public {
    _upgradeSpoke();

    vm.prank(spokeProxy.owner());
    spokeProxy.updateMessageReceiver(address(0x123));
    assertEq(spokeProxy.messageReceiver(), address(0x123));
  }

  function test_spokeArrayUpgrade_updateMessageGasLimit() public {
    _upgradeSpoke();

    vm.prank(spokeProxy.owner());
    spokeProxy.updateMessageGasLimit(1000);
    assertEq(spokeProxy.messageGasLimit(), 1000);
  }

  // ============ Public ============ //
  function test_spokeArrayUpgrade_deposit() public {
    _upgradeSpoke();

    uint256 amount = 1e18;
    deal(USDC_MAINNET, address(this), amount);

    // Approving and depositing
    IERC20(USDC_MAINNET).approve(address(spokeProxy), amount);
    spokeProxy.deposit(USDC_MAINNET, amount);
    assertEq(spokeProxy.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), amount);
  }

  function test_spokeArrayUpgrade_withdraw() public {
    _upgradeSpoke();

    uint256 amount = 1e18;
    deal(USDC_MAINNET, address(this), amount);

    // Approving and depositing
    IERC20(USDC_MAINNET).approve(address(spokeProxy), amount);
    spokeProxy.deposit(USDC_MAINNET, amount);
    assertEq(spokeProxy.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), amount);

    // Withdrawing
    spokeProxy.withdraw(USDC_MAINNET, amount);
    assertEq(spokeProxy.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), 0);
    assertEq(IERC20(USDC_MAINNET).balanceOf(address(this)), amount);
  }

  /**
   * @notice Tests the processIntentQueue function
   * @param _intents The intents to process
   * @param _amount The amount of intents to process
   * @param _messageFee The message fee to process the intents
   */
  function test_spokeArrayUpgrade_ProcessIntentQueue(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint32 _destination,
    uint32 _amount,
    uint256 _messageFee
  ) public validDestination(_destination) {
    _upgradeSpoke();
    address lightHouse = spokeProxy.lighthouse();

    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(lightHouse, _messageFee);

    _amount = uint32(bound(uint256(_amount), 1, MAX_FUZZED_ARRAY_LENGTH));
    IEverclear.Intent[] memory _intentsToProcess = new IEverclear.Intent[](_amount);

    for (uint256 _i; _i < MAX_FUZZED_ARRAY_LENGTH; _i++) {
      _newIntentAndAssert(_intents[_i], _intentsToProcess, AdditionalParams(_destination, _i, _amount));
    }

    bytes memory _batchIntentmessage = MessageLib.formatIntentMessageBatch(_intentsToProcess);

    uint256 _initialLighthouseBal = lightHouse.balance;
    metadata = StandardHookMetadata.formatMetadata(0, MESSAGE_GAS_LIMIT, SPOKE_GATEWAY_MAINNET, '');
    bytes32 _messageId = _mockDispatch(SPOKE_GATEWAY_MAINNET, MAILBOX_MAINNET, _batchIntentmessage, metadata);

    vm.expectCall(
      address(MAILBOX_MAINNET),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)', HUB_ID, HUB_GATEWAY, _batchIntentmessage, metadata
      )
    );

    vm.startPrank(lightHouse);
    spokeProxy.processIntentQueue{value: _messageFee}(_intentsToProcess);
    assertEq(lightHouse.balance, _initialLighthouseBal - _messageFee);
  }

  // ============ Helpers ============ //
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

  function _upgradeSpoke() internal {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK);
    // Checking implementation correct and caching the state variables
    spokeProxy = EverclearSpoke(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET);

    // Deploying impl and upgrading the contract
    address newEverclearSpoke = address(new EverclearSpoke());

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    spokeProxy.upgradeToAndCall(newEverclearSpoke, '');

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);
  }

  function _newIntentAndAssert(
    IEverclear.Intent memory _intentParam,
    IEverclear.Intent[] memory _intentsToProcess,
    AdditionalParams memory _params
  ) internal {
    vm.assume(_intentParam.amount > 0);
    vm.assume(_intentParam.receiver.toAddress() != address(0));
    _getDestinations(_intentParam, _params.destination);

    address _inputAsset = deployAndDeal(_intentParam.receiver, _intentParam.amount).toAddress();
    address _outputAsset = deployAndDeal(_intentParam.receiver, _intentParam.amount).toAddress();

    vm.startPrank(_intentParam.receiver.toAddress());
    IERC20(_inputAsset).approve(address(spokeProxy), _intentParam.amount);

    (bytes32 _intentId, IEverclear.Intent memory _intent) = spokeProxy.newIntent(
      _intentParam.destinations,
      _intentParam.receiver.toAddress(),
      _inputAsset,
      _outputAsset,
      _intentParam.amount,
      _intentParam.maxFee % Constants.DBPS_DENOMINATOR,
      _intentParam.ttl,
      _intentParam.data
    );

    if (_params.i < _params.amount) {
      _intentsToProcess[_params.i] = _intent;
    }

    vm.stopPrank();
  }
}
