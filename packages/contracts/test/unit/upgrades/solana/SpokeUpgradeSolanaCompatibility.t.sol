// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {ISpecifiesInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {EverclearSpokeV3, IEverclearSpokeV3} from 'contracts/intent/EverclearSpokeV3.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';

import {BaseTest} from 'test/unit/intent/EverclearSpoke.t.sol';
import {Constants} from 'test/utils/Constants.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ICREATE3, UpgradeHelper} from 'test//utils/UpgradeHelper.sol';

contract SpokeSolanaCompatibilityUpgradeTest is BaseTest, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  // ============ Upgrade ============ //
  function test_spokeSolanaCompatibilityUpgrade_upgrade() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP2);

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET_V2);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV3();

    // Generating the inputs for CREATE3
    uint8 version = 4;
    bytes32 _salt = keccak256(abi.encodePacked(SPOKE_PROXY_MAINNET, version));
    bytes32 _implementationSalt = keccak256(abi.encodePacked(_salt, 'implementation'));
    bytes memory _creation = type(EverclearSpokeV3).creationCode;

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
    (success,) = address(spokeProxyV3).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(0x123), _amount).toAddress();

    vm.startPrank(address(0x123));
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV3.newIntent(
      destinations, address(0x123).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce + 1, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
  }

  // ============ Admin Unit ============ //
  function test_spokeSolanaCompatibilityUpgrade_pause() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.lighthouse());
    spokeProxyV3.pause();
    assertEq(spokeProxyV3.paused(), true);

    vm.prank(spokeProxyV3.watchtower());
    spokeProxyV3.unpause();
    assertEq(spokeProxyV3.paused(), false);
  }

  function test_spokeSolanaCompatibilityUpgrade_setStrategyForAsset() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.setStrategyForAsset(address(0x123), IEverclear.Strategy.XERC20);
    assertEq(uint8(spokeProxyV3.strategies(address(0x123))), uint8(IEverclear.Strategy.XERC20));
  }

  function test_spokeSolanaCompatibilityUpgrade_setModuleForStrategy() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.setModuleForStrategy(IEverclear.Strategy.XERC20, ISettlementModule(address(0x123)));
    assertEq(address(spokeProxyV3.modules(IEverclear.Strategy.XERC20)), address(0x123));
  }

  function test_spokeSolanaCompatibilityUpgrade_updateSecurityModule() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.updateSecurityModule(address(0x123));
    address gateway = address(spokeProxyV3.gateway());
    address updatedModule = address(ISpecifiesInterchainSecurityModule(gateway).interchainSecurityModule());
    assertEq(updatedModule, address(0x123));
  }

  function test_spokeSolanaCompatibilityUpgrade_updateGateway() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.updateGateway(address(0x123));
    assertEq(address(spokeProxyV3.gateway()), address(0x123));
  }

  function test_spokeSolanaCompatibilityUpgrade_updateMessageReceiver() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.updateMessageReceiver(address(0x123));
    assertEq(spokeProxyV3.messageReceiver(), address(0x123));
  }

  function test_spokeSolanaCompatibilityUpgrade_updateMessageGasLimit() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.updateMessageGasLimit(1000);
    assertEq(spokeProxyV3.messageGasLimit(), 1000);
  }

  // ============ Public ============ //
  /**
   * @notice Tests the deposit function of the spoke proxy
   * @dev This function is used to deposit tokens into the spoke proxy
   */
  function test_spokeSolanaCompatibilityUpgrade_deposit() public {
    _upgradeSpoke();

    uint256 amount = 1e18;
    deal(USDC_MAINNET, address(this), amount);

    // Approving and depositing
    IERC20(USDC_MAINNET).approve(address(spokeProxyV3), amount);
    spokeProxyV3.deposit(USDC_MAINNET, amount);
    assertEq(spokeProxyV3.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), amount);
  }

  /**
   * @notice Tests the withdraw function of the spoke proxy
   * @dev This function is used to withdraw tokens from the spoke proxy
   */
  function test_spokeSolanaCompatibilityUpgrade_withdraw() public {
    _upgradeSpoke();

    uint256 amount = 1e18;
    deal(USDC_MAINNET, address(this), amount);

    // Approving and depositing
    IERC20(USDC_MAINNET).approve(address(spokeProxyV3), amount);
    spokeProxyV3.deposit(USDC_MAINNET, amount);
    assertEq(spokeProxyV3.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), amount);

    // Withdrawing
    spokeProxyV3.withdraw(USDC_MAINNET, amount);
    assertEq(spokeProxyV3.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), 0);
    assertEq(IERC20(USDC_MAINNET).balanceOf(address(this)), amount);
  }

  /**
   * @notice Tests the newIntent function that has bytes32 inputs for receiver and outputAsset
   * @param _amount The amount to send
   * @param _receiver The receiver address
   */
  function test_spokeSolanaCompatibilityUpgrade_newIntentBytes(
    uint256 _amount,
    bytes32 _receiver
  ) public {
    vm.assume(_receiver != 0);
    _amount = bound(_amount, 1, type(uint128).max);

    uint32[] memory destinations = _getDestinations(10);
    address _sender = address(0x123);

    // upgrading the spoke
    _upgradeSpoke();

    // dealing to the user
    address _inputAsset = deployAndDeal(_sender, _amount).toAddress();
    address _outputAsset = deployAndDeal(_sender, _amount).toAddress();

    vm.startPrank(_sender);
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    (bytes32 _intentId,) =
      spokeProxyV3.newIntent(destinations, _receiver, _inputAsset, _outputAsset.toBytes32(), _amount, 0, 0, hex'00');

    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

    vm.stopPrank();
  }

  /**
   * @notice Tests the processIntentQueue function using the newIntent function with address input
   * @param _intents The intents to process
   * @param _messageFee The message fee to process the intents
   */
  function test_spokeSolanaCompatibilityUpgrade_ProcessIntentQueue(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint32 _destination,
    uint256 _messageFee
  ) public validDestination(_destination) {
    _upgradeSpoke();
    address lightHouse = spokeProxyV3.lighthouse();

    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(lightHouse, _messageFee);

    IEverclear.Intent[] memory _intentsToProcess = new IEverclear.Intent[](_intents.length);
    bytes32[] memory _intentIds = new bytes32[](_intents.length);

    for (uint256 _i; _i < _intents.length; _i++) {
      (_intentIds[_i], _intentsToProcess[_i]) =
        _newIntentAndAssert(_intents[_i], AdditionalParams(_destination, _i, uint32(_intents.length)));
    }

    bytes memory _batchIntentmessage = MessageLib.formatIntentMessageBatch(_intentsToProcess);
    metadata = StandardHookMetadata.formatMetadata(0, MESSAGE_GAS_LIMIT, SPOKE_GATEWAY_MAINNET, '');

    vm.expectCall(
      address(MAILBOX_MAINNET),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)', HUB_ID, HUB_GATEWAY_PROD, _batchIntentmessage, metadata
      )
    );

    vm.startPrank(lightHouse);
    spokeProxyV3.processIntentQueue{value: _messageFee}(_intentsToProcess);
    assertEq(lightHouse.balance, 0);
  }

  // ============ Revert ============ //
  function testRevert_newIntent_OutputAssetZero_EverclearSpokeNewIntentInvalidIntent() public {
    _upgradeSpoke();

    // Configuring inputs
    address _sender = address(0x123);
    address _receiver = address(0);
    address _outputAsset = address(0);
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;

    // dealing to the user
    address _inputAsset = deployAndDeal(_sender, _amount).toAddress();

    vm.startPrank(_sender);
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    vm.expectRevert(abi.encodeWithSelector(IEverclearSpokeV3.EverclearSpoke_NewIntent_InvalidIntent.selector));
    spokeProxyV3.newIntent(
      destinations,
      _receiver, // receiver
      _inputAsset,
      _outputAsset, // outputAsset --> should revert as address(0) not valid when ttl != 0
      _amount,
      0,
      3600, // ttl
      hex'00'
    );
  }

  function testRevert_newIntent_OutputAssetNonZero_EverclearSpokeNewIntentInvalidIntent() public {
    _upgradeSpoke();

    // Configuring inputs
    address _sender = address(0x123);
    address _receiver = address(0);
    uint32[] memory destinations = new uint32[](2);
    destinations[0] = 10;
    destinations[1] = 20;
    uint256 _amount = 1e18;

    // dealing to the user
    address _inputAsset = deployAndDeal(_sender, _amount).toAddress();
    address _outputAsset = deployAndDeal(_sender, _amount).toAddress();

    vm.startPrank(_sender);
    IERC20(_inputAsset).approve(address(spokeProxyV3), _amount);

    vm.expectRevert(abi.encodeWithSelector(IEverclearSpokeV3.EverclearSpoke_NewIntent_InvalidIntent.selector));
    spokeProxyV3.newIntent(
      destinations,
      _receiver, // receiver
      _inputAsset,
      _outputAsset, // outputAsset --> should revert as it should be null when destination array length > 1
      _amount,
      0,
      0, // ttl
      hex'00'
    );
  }

  // ============ Helpers ============ //
  function _upgradeSpoke() internal {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP2);
    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET_V2);

    // Deploying impl and upgrading the contract
    address newEverclearSpoke = address(new EverclearSpokeV3());
    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    spokeProxyV3.upgradeToAndCall(newEverclearSpoke, '');

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);
  }

  function _newIntentAndAssert(
    IEverclear.Intent memory _intentParam,
    AdditionalParams memory _params
  ) internal returns (bytes32 _intentId, IEverclear.Intent memory _returnIntent) {
    // vm.assume(_intentParam.amount > 0);
    _intentParam.amount = bound(_intentParam.amount, 1, type(uint128).max);
    vm.assume(_intentParam.receiver.toAddress() != address(0));
    _getDestinations(_intentParam, _params.destination);

    // dealing to the user
    address _inputAsset = deployAndDeal(_intentParam.receiver, _intentParam.amount).toAddress();
    address _outputAsset = deployAndDeal(_intentParam.receiver, _intentParam.amount).toAddress();

    vm.startPrank(_intentParam.receiver.toAddress());
    IERC20(_inputAsset).approve(address(spokeProxyV3), _intentParam.amount);

    (_intentId, _returnIntent) = spokeProxyV3.newIntent(
      _intentParam.destinations,
      _intentParam.receiver.toAddress(),
      _inputAsset,
      _outputAsset,
      _intentParam.amount,
      _intentParam.maxFee % Constants.DBPS_DENOMINATOR,
      _intentParam.ttl,
      _intentParam.data
    );

    assertEq(uint8(spokeProxyV3.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

    vm.stopPrank();
  }
}
