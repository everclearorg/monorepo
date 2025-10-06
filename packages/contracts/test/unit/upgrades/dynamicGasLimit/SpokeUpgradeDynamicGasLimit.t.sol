// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {FeeAdapter, IFeeAdapter} from 'contracts/intent/FeeAdapter.sol';

import {ISpecifiesInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {EverclearSpokeV5, IEverclearSpokeV5} from 'contracts/intent/EverclearSpokeV5.sol';

import {FeeAdapter} from 'contracts/intent/FeeAdapter.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {ISpokeStorageV5} from 'interfaces/intent/ISpokeStorageV5.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';

import {Deploy} from 'script/utils/Deploy.sol';
import {BaseTest} from 'test/unit/intent/EverclearSpoke.t.sol';
import {Constants} from 'test/utils/Constants.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ICREATE3, UpgradeHelper} from 'test//utils/UpgradeHelper.sol';

contract SpokeUpgradeDynamicGasLimitTest is BaseTest, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  FeeAdapter public feeAdapter = FeeAdapter(MAINNET_FEE_ADAPTER);

  // ============ Upgrade ============ //
  function test_spokeDynamicGasLimitUpgrade_upgrade() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP3);

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET_V3);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();

    // Generating the inputs for CREATE3
    uint8 version = 4;
    bytes32 _salt = keccak256(abi.encodePacked(SPOKE_PROXY_MAINNET, version));
    bytes32 _implementationSalt = keccak256(abi.encodePacked(_salt, 'implementation'));
    bytes memory _creation = type(EverclearSpokeV5).creationCode;

    // Deploying the new implementation
    bytes memory create3Calldata = abi.encodeWithSelector(ICREATE3.deploy.selector, _implementationSalt, _creation);
    (bool success, bytes memory returnData) = CREATE_3.call(create3Calldata);
    if (!success) revert Create3DeploymentFailed();
    address newEverclearSpoke = abi.decode(returnData, (address));

    // Deploying feeAdapter, impl and upgrading the contract
    success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, '');

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    (success,) = address(spokeProxyV5).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.messageReceiver, spokeProxyV5.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(address(feeAdapter), spokeProxyV5.feeAdapter());
  }

  // ============ Admin Unit ============ //
  function test_spokeUpgradeDynamicGasLimit_pause() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.lighthouse());
    spokeProxyV5.pause();
    assertEq(spokeProxyV5.paused(), true);

    vm.prank(spokeProxyV5.watchtower());
    spokeProxyV5.unpause();
    assertEq(spokeProxyV5.paused(), false);
  }

  function test_spokeUpgradeDynamicGasLimit_setStrategyForAsset() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.setStrategyForAsset(address(0x123), IEverclear.Strategy.XERC20);
    assertEq(uint8(spokeProxyV5.strategies(address(0x123))), uint8(IEverclear.Strategy.XERC20));
  }

  function test_spokeUpgradeDynamicGasLimit_setModuleForStrategy() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.setModuleForStrategy(IEverclear.Strategy.XERC20, ISettlementModule(address(0x123)));
    assertEq(address(spokeProxyV5.modules(IEverclear.Strategy.XERC20)), address(0x123));
  }

  function test_spokeUpgradeDynamicGasLimit_updateSecurityModule() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.updateSecurityModule(address(0x123));
    address gateway = address(spokeProxyV5.gateway());
    address updatedModule = address(ISpecifiesInterchainSecurityModule(gateway).interchainSecurityModule());
    assertEq(updatedModule, address(0x123));
  }

  function test_spokeUpgradeDynamicGasLimit_updateGateway() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.updateGateway(address(0x123));
    assertEq(address(spokeProxyV5.gateway()), address(0x123));
  }

  function test_spokeUpgradeDynamicGasLimit_updateMessageReceiver() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.updateMessageReceiver(address(0x123));
    assertEq(spokeProxyV5.messageReceiver(), address(0x123));
  }

  function test_spokeUpgradeDynamicGasLimit_updateMessageGasLimit() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.updateMessageGasLimit(1000);
    assertEq(spokeProxyV5.messageGasLimit(), 1000);
  }

  /**
   * @notice Tests the updateFeeAdapter function of the spoke proxy
   * @dev This function is newly added to the spoke proxy
   */
  function test_spokeUpgradeDynamicGasLimit_updateFeeAdapter() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.updateFeeAdapter(address(0x123));
    assertEq(spokeProxyV5.feeAdapter(), address(0x123));
  }

  // ============ Public ============ //
  /**
   * @notice Tests the deposit function of the spoke proxy
   * @dev This function is used to deposit tokens into the spoke proxy
   */
  function test_spokeUpgradeDynamicGasLimit_deposit() public {
    _upgradeSpoke();

    uint256 amount = 1e18;
    deal(USDC_MAINNET, address(this), amount);

    // Approving and depositing
    IERC20(USDC_MAINNET).approve(address(spokeProxyV5), amount);
    spokeProxyV5.deposit(USDC_MAINNET, amount);
    assertEq(spokeProxyV5.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), amount);
  }

  /**
   * @notice Tests the withdraw function of the spoke proxy
   * @dev This function is used to withdraw tokens from the spoke proxy
   */
  function test_spokeUpgradeDynamicGasLimit_withdraw() public {
    _upgradeSpoke();

    uint256 amount = 1e18;
    deal(USDC_MAINNET, address(this), amount);

    // Approving and depositing
    IERC20(USDC_MAINNET).approve(address(spokeProxyV5), amount);
    spokeProxyV5.deposit(USDC_MAINNET, amount);
    assertEq(spokeProxyV5.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), amount);

    // Withdrawing
    spokeProxyV5.withdraw(USDC_MAINNET, amount);
    assertEq(spokeProxyV5.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), 0);
    assertEq(IERC20(USDC_MAINNET).balanceOf(address(this)), amount);
  }

  /**
   * @notice Tests the newIntent function that has bytes32 inputs for receiver and outputAsset
   * @param _amount The amount to send
   * @param _receiver The receiver address
   */
  function test_spokeUpgradeDynamicGasLimit_newIntentBytes(uint256 _amount, bytes32 _receiver) public {
    _upgradeSpoke();

    vm.assume(_receiver != 0);
    _amount = bound(_amount, 1, type(uint128).max);
    _updateFeeSigner();

    uint32[] memory destinations = _getDestinations(10);
    address _sender = address(0x123);

    // configuring the feeparams
    IFeeAdapter.FeeParams memory _feeParams;
    _feeParams.fee = 1e8;
    _feeParams.deadline = block.timestamp + 1 days;

    // dealing to the user
    address _inputAsset = deployAndDeal(_sender, _amount + _feeParams.fee).toAddress();
    address _outputAsset = deployAndDeal(_sender, _amount).toAddress();

    // generating signature after asset is created
    _feeParams.sig = _generateSignature(FEE_SIGNER_PK, abi.encode(_feeParams.fee, 0, _inputAsset, _feeParams.deadline));

    vm.startPrank(_sender);
    IERC20(_inputAsset).approve(address(feeAdapter), _amount + _feeParams.fee);

    (bytes32 _intentId,) = feeAdapter.newIntent(
      destinations, _receiver, _inputAsset, _outputAsset.toBytes32(), _amount, 0, 0, hex'00', _feeParams
    );

    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

    vm.stopPrank();
  }

  /**
   * @notice Tests the processIntentQueue function using the newIntent function with address input
   * @param _intents The intents to process
   * @param _messageFee The message fee to process the intents
   */
  function test_spokeUpgradeDynamicGasLimit_ProcessIntentQueue(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint32 _destination,
    uint256 _messageFee,
    uint256 _dynamicGasLimit
  ) public validDestination(_destination) {
    _upgradeSpoke();
    _updateFeeSigner();
    address lightHouse = spokeProxyV5.lighthouse();

    _dynamicGasLimit = bound(_dynamicGasLimit, 600_000, spokeProxyV5.messageGasLimit());
    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(lightHouse, _messageFee);

    IEverclear.Intent[] memory _intentsToProcess = new IEverclear.Intent[](_intents.length);
    bytes32[] memory _intentIds = new bytes32[](_intents.length);

    for (uint256 _i; _i < _intents.length; _i++) {
      (_intentIds[_i], _intentsToProcess[_i]) =
        _newIntentAndAssert(_intents[_i], AdditionalParams(_destination, _i, uint32(_intents.length)));
    }

    bytes memory _batchIntentmessage = MessageLib.formatIntentMessageBatch(_intentsToProcess);
    metadata = StandardHookMetadata.formatMetadata(0, _dynamicGasLimit, SPOKE_GATEWAY_MAINNET, '');

    vm.expectCall(
      address(MAILBOX_MAINNET),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)', HUB_ID, HUB_GATEWAY_PROD, _batchIntentmessage, metadata
      )
    );

    vm.startPrank(lightHouse);
    spokeProxyV5.processIntentQueue{value: _messageFee}(_intentsToProcess, _dynamicGasLimit);
    assertEq(lightHouse.balance, 0);
  }

  /**
   * @notice Tests the processIntentQueueViaRelayer function using the newIntent function with address input
   * @param _intents The intents to process
   * @param _messageFee The message fee to process the intents
   */
  function test_spokeUpgradeDynamicGasLimit_ProcessIntentQueueViaRelayer(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint32 _destination,
    uint256 _messageFee,
    uint256 _dynamicGasLimit
  ) public validDestination(_destination) {
    _upgradeSpoke();
    _updateFeeSigner();
    _updateLighthouse(relayer);

    address lightHouse = spokeProxyV5.lighthouse();
    _dynamicGasLimit = bound(_dynamicGasLimit, 600_000, spokeProxyV5.messageGasLimit());

    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(lightHouse, _messageFee);

    IEverclear.Intent[] memory _intentsToProcess = new IEverclear.Intent[](_intents.length);
    bytes32[] memory _intentIds = new bytes32[](_intents.length);

    for (uint256 _i; _i < _intents.length; _i++) {
      (_intentIds[_i], _intentsToProcess[_i]) =
        _newIntentAndAssert(_intents[_i], AdditionalParams(_destination, _i, uint32(_intents.length)));
    }

    bytes memory _batchIntentmessage = MessageLib.formatIntentMessageBatch(_intentsToProcess);
    metadata = StandardHookMetadata.formatMetadata(0, _dynamicGasLimit, SPOKE_GATEWAY_MAINNET, '');

    vm.expectCall(
      address(MAILBOX_MAINNET),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)', HUB_ID, HUB_GATEWAY_PROD, _batchIntentmessage, metadata
      )
    );

    _processIntentQueueViaRelayer(_intentsToProcess, lightHouse, _dynamicGasLimit);
  }

  function test_spokeUpgradeDynamicGasLimit_ProcessFillQueue(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint128 _amount,
    uint256 _messageFee,
    uint256 _dynamicGasLimit
  ) public {
    _upgradeSpoke();
    address lightHouse = spokeProxyV5.lighthouse();
    _dynamicGasLimit = bound(_dynamicGasLimit, 600_000, spokeProxyV5.messageGasLimit());

    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(lightHouse, _messageFee);

    IEverclear.FillMessage[] memory _fillMessages = new IEverclear.FillMessage[](_intents.length);
    for (uint256 i; i < _intents.length; i++) {
      IEverclear.Intent memory _intent = _intents[i];

      // overriding the values for the solver path
      if (_intent.maxFee == 0 || _intent.maxFee > Constants.DBPS_DENOMINATOR) _intent.maxFee = 10_000;
      if (_intent.amount < 1e18 || _intent.amount > type(uint128).max) _intent.amount = _amount;
      _intent.ttl = 1 days;
      _intent.destinations = new uint32[](1);
      _intent.destinations[0] = 1;
      _intent.timestamp = uint48(block.timestamp);
      _intent.outputAsset = WETH_MAINNET.toBytes32();
      _intent.data = hex'';
      deal(WETH_MAINNET, address(this), _intent.amount);

      // sending fill message
      _fillMessages[i] = _newFillAndAssert(_intent);
    }

    bytes memory _batchFillMessage = MessageLib.formatFillMessageBatch(_fillMessages);
    metadata = StandardHookMetadata.formatMetadata(0, _dynamicGasLimit, SPOKE_GATEWAY_MAINNET, '');

    vm.expectCall(
      address(MAILBOX_MAINNET),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)', HUB_ID, HUB_GATEWAY_PROD, _batchFillMessage, metadata
      )
    );

    vm.startPrank(lightHouse);
    spokeProxyV5.processFillQueue{value: _messageFee}(uint32(_intents.length), _dynamicGasLimit);
    assertEq(lightHouse.balance, 0);
  }

  function test_spokeUpgradeDynamicGasLimit_ProcessFillQueueViaRelayer(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint128 _amount,
    uint256 _messageFee,
    uint256 _dynamicGasLimit
  ) public {
    _upgradeSpoke();
    _updateLighthouse(relayer);
    address lightHouse = spokeProxyV5.lighthouse();
    _dynamicGasLimit = bound(_dynamicGasLimit, 600_000, spokeProxyV5.messageGasLimit());

    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(lightHouse, _messageFee);

    IEverclear.FillMessage[] memory _fillMessages = new IEverclear.FillMessage[](_intents.length);
    for (uint256 i; i < _intents.length; i++) {
      IEverclear.Intent memory _intent = _intents[i];

      // overriding the values for the solver path
      if (_intent.maxFee == 0 || _intent.maxFee > Constants.DBPS_DENOMINATOR) _intent.maxFee = 10_000;
      if (_intent.amount < 1e18 || _intent.amount > type(uint128).max) _intent.amount = _amount;
      _intent.ttl = 1 days;
      _intent.destinations = new uint32[](1);
      _intent.destinations[0] = 1;
      _intent.timestamp = uint48(block.timestamp);
      _intent.outputAsset = WETH_MAINNET.toBytes32();
      _intent.data = hex'';
      deal(WETH_MAINNET, address(this), _intent.amount);

      // sending fill message
      _fillMessages[i] = _newFillAndAssert(_intent);
    }

    bytes memory _batchFillMessage = MessageLib.formatFillMessageBatch(_fillMessages);
    metadata = StandardHookMetadata.formatMetadata(0, _dynamicGasLimit, SPOKE_GATEWAY_MAINNET, '');

    vm.expectCall(
      address(MAILBOX_MAINNET),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)', HUB_ID, HUB_GATEWAY_PROD, _batchFillMessage, metadata
      )
    );

    _processFillQueueViaRelayer(uint32(_intents.length), lightHouse, _dynamicGasLimit);
  }

  // ============ Revert ============ //
  function testRevert_processIntentQueue_ExceedsGasLimit_EverclearSpokeQueueExceedsGasLimit() public {
    _upgradeSpoke();

    // Configuring inputs
    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    uint256 _dynamicGasLimit = spokeProxyV5.messageGasLimit() + 1;

    vm.expectRevert(
      abi.encodeWithSelector(IEverclearSpokeV5.EverclearSpoke_ProcessQueue_ExceedsGasLimit.selector, _dynamicGasLimit)
    );
    spokeProxyV5.processIntentQueue(_intents, _dynamicGasLimit);
  }

  function testRevert_processFillQueue_ExceedsGasLimit_EverclearSpokeQueueExceedsGasLimit() public {
    _upgradeSpoke();
    uint256 _dynamicGasLimit = spokeProxyV5.messageGasLimit() + 1;

    vm.expectRevert(
      abi.encodeWithSelector(IEverclearSpokeV5.EverclearSpoke_ProcessQueue_ExceedsGasLimit.selector, _dynamicGasLimit)
    );
    spokeProxyV5.processFillQueue(1, _dynamicGasLimit);
  }

  function testRevert_processIntentQueueViaRelayer_ExceedsGasLimit_EverclearSpokeQueueExceedsGasLimit() public {
    _upgradeSpoke();

    // Configuring inputs
    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    bytes memory _sig;
    uint256 _dynamicGasLimit = spokeProxyV5.messageGasLimit() + 1;

    vm.expectRevert(
      abi.encodeWithSelector(IEverclearSpokeV5.EverclearSpoke_ProcessQueue_ExceedsGasLimit.selector, _dynamicGasLimit)
    );
    spokeProxyV5.processIntentQueueViaRelayer(
      1, _intents, address(0x123), block.timestamp + 1, 0, _dynamicGasLimit, _sig
    );
  }

  function testRevert_processFillQueueViaRelayer_ExceedsGasLimit_EverclearSpokeQueueExceedsGasLimit() public {
    _upgradeSpoke();

    // Configuring inputs
    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    bytes memory _sig;
    uint256 _dynamicGasLimit = spokeProxyV5.messageGasLimit() + 1;

    vm.expectRevert(
      abi.encodeWithSelector(IEverclearSpokeV5.EverclearSpoke_ProcessQueue_ExceedsGasLimit.selector, _dynamicGasLimit)
    );
    spokeProxyV5.processFillQueueViaRelayer(1, 1, address(0x123), block.timestamp + 1, 0, _dynamicGasLimit, _sig);
  }

  // ============ Helpers ============ //
  function _upgradeSpoke() internal {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP3);
    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET_V3);

    // Deploying impl and upgrading the contract
    address newEverclearSpoke = address(new EverclearSpokeV5());

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    spokeProxyV5.upgradeToAndCall(newEverclearSpoke, '');

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Updating the messageGasLimit - which is now used as the maxGasLimit
    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    spokeProxyV5.updateMessageGasLimit(MAX_GAS_LIMIT);
  }

  function _newIntentAndAssert(
    IEverclear.Intent memory _intentParam,
    AdditionalParams memory _params
  ) internal returns (bytes32 _intentId, IEverclear.Intent memory _returnIntent) {
    _intentParam.amount = bound(_intentParam.amount, 1, type(uint128).max);
    vm.assume(_intentParam.receiver.toAddress() != address(0));
    _getDestinations(_intentParam, _params.destination);

    // configuring the feeparams
    IFeeAdapter.FeeParams memory _feeParams;
    _feeParams.fee = 1e8;
    _feeParams.deadline = block.timestamp + 1 days;

    // dealing to the user
    address _inputAsset = deployAndDeal(_intentParam.receiver, _intentParam.amount + _feeParams.fee).toAddress();
    address _outputAsset = deployAndDeal(_intentParam.receiver, _intentParam.amount).toAddress();

    // generating signature after asset is created
    _feeParams.sig = _generateSignature(FEE_SIGNER_PK, abi.encode(_feeParams.fee, 0, _inputAsset, _feeParams.deadline));

    vm.startPrank(_intentParam.receiver.toAddress());
    IERC20(_inputAsset).approve(address(feeAdapter), _intentParam.amount + _feeParams.fee);

    (_intentId, _returnIntent) = feeAdapter.newIntent(
      _intentParam.destinations,
      _intentParam.receiver.toAddress(),
      _inputAsset,
      _outputAsset,
      _intentParam.amount,
      _intentParam.maxFee % Constants.DBPS_DENOMINATOR,
      _intentParam.ttl,
      _intentParam.data,
      _feeParams
    );

    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

    vm.stopPrank();
  }

  function _updateLighthouse(
    address _newLighthouse
  ) internal {
    // keeping old values in the same slot
    uint32 ever = spokeProxyV5.EVERCLEAR();
    uint32 dom = spokeProxyV5.DOMAIN();

    // slot layout (little‑end of the 256‑bit word):
    // bits  0‥31   : ever
    // bits 32‥63   : dom
    // bits 64‥223  : lighthouse
    uint256 packed = uint256(ever) // no shift
      | (uint256(dom) << 32) // +4 bytes
      | (uint256(uint160(_newLighthouse)) << 64); // +8 bytes

    vm.store(address(spokeProxyV5), bytes32(uint256(0)), bytes32(packed));

    // asserting the outcome
    assertEq(spokeProxyV5.EVERCLEAR(), ever);
    assertEq(spokeProxyV5.DOMAIN(), dom);
    assertEq(spokeProxyV5.lighthouse(), _newLighthouse);
  }

  function _processIntentQueueViaRelayer(
    IEverclear.Intent[] memory _intents,
    address _lightHouse,
    uint256 _dynamicGasLimit
  ) internal {
    uint256 _nonce = 0;
    uint32 _amount = uint32(_intents.length);
    address _relayer = address(0x123);

    // generating the signature
    bytes memory _signature = _generateSignature(
      relayerPk,
      abi.encode(
        spokeProxyV5.PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH(), // typehash
        1, // domain
        _amount, // amount
        _relayer, // relayer
        block.timestamp + 1, // ttl
        _nonce, // nonce
        _dynamicGasLimit // dynamicGasLimit
      )
    );

    vm.startPrank(_relayer);
    spokeProxyV5.processIntentQueueViaRelayer(
      1, _intents, _relayer, block.timestamp + 1, _nonce, _dynamicGasLimit, _signature
    );
  }

  function _processFillQueueViaRelayer(uint32 _amount, address _lightHouse, uint256 _dynamicGasLimit) internal {
    uint256 _nonce = 0;
    address _relayer = address(0x123);

    // generating the signature
    bytes memory _signature = _generateSignature(
      relayerPk,
      abi.encode(
        spokeProxyV5.PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH(), // typehash
        1, // domain
        _amount, // amount
        _relayer, // relayer
        block.timestamp + 1, // ttl
        _nonce, // nonce
        _dynamicGasLimit // dynamicGasLimit
      )
    );

    vm.startPrank(_relayer);
    spokeProxyV5.processFillQueueViaRelayer(
      1, _amount, _relayer, block.timestamp + 1, _nonce, _dynamicGasLimit, _signature
    );
  }

  function _newFillAndAssert(
    IEverclear.Intent memory _intent
  ) internal returns (IEverclear.FillMessage memory _fillMessage) {
    uint24 _fee = _intent.maxFee - 1;

    // depositing into the contract
    address _inputAsset = _intent.outputAsset.toAddress();
    IERC20(_inputAsset).approve(address(spokeProxyV5), _intent.amount);
    spokeProxyV5.deposit(_inputAsset, _intent.amount);

    // filling the intent
    _fillMessage = spokeProxyV5.fillIntent(_intent, _fee);

    // asserting the intent is identified as filled
    bytes32 _intentId = keccak256(abi.encode(_intent));
    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclear.IntentStatus.FILLED));
  }

  function _updateFeeSigner() internal {
    vm.prank(spokeProxyV5.owner());
    feeAdapter.updateFeeSigner(FEE_SIGNER);
    assertEq(feeAdapter.feeSigner(), FEE_SIGNER);
  }
}
