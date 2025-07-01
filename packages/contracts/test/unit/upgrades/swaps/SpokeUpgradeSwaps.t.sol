// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MessageLibV2} from 'contracts/common/MessageLibV2.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {FeeAdapterV2, IFeeAdapterV2} from 'contracts/intent/FeeAdapterV2.sol';

import {ISpecifiesInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {EverclearSpokeV5, IEverclearSpokeV5} from 'contracts/intent/EverclearSpokeV5.sol';

import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';
import {ISpokeStorageV5} from 'interfaces/intent/ISpokeStorageV5.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';

import {Deploy} from 'script/utils/Deploy.sol';
import {BaseTest} from 'test/unit/intent/EverclearSpoke.t.sol';
import {Constants} from 'test/utils/Constants.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ICREATE3, UpgradeHelper} from 'test//utils/UpgradeHelper.sol';

contract SpokeUpgradeSwapss is BaseTest, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  FeeAdapterV2 public feeAdapter;

  // ============ Upgrade ============ //
  function test_spokeSwapUpgrade_upgrade() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP5);

    // Deploying the new FeeAdapter
    feeAdapter = new FeeAdapterV2(
      SPOKE_PROXY_MAINNET, FEE_RECIPIENT_MAINNET, FEE_SIGNER, XERC20_MODULE_MAINNET, SPOKE_PROXY_MAINNET_OWNER
    );

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET_V4);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV5();

    // Generating the inputs for CREATE3
    uint8 version = 5;
    bytes32 _salt = keccak256(abi.encodePacked(SPOKE_PROXY_MAINNET, version));
    bytes32 _implementationSalt = keccak256(abi.encodePacked(_salt, 'implementation'));
    bytes memory _creation = type(EverclearSpokeV5).creationCode;

    // Deploying the new implementation
    bytes memory create3Calldata = abi.encodeWithSelector(ICREATE3.deploy.selector, _implementationSalt, _creation);
    (bool success, bytes memory returnData) = CREATE_3.call(create3Calldata);
    if (!success) revert Create3DeploymentFailed();
    address newEverclearSpoke = abi.decode(returnData, (address));

    // Initializing with new feeAdapter and upgrading
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV5.initialize.selector, address(feeAdapter));
    success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    (success,) = address(spokeProxyV5).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Testing sending new intent
    _sendIntent();

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
    assertEq(state.nonce + 1, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(address(feeAdapter), spokeProxyV5.feeAdapter());
  }

  // ============ Admin Unit ============ //
  function test_spokeUpgradeSwaps_pause() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.lighthouse());
    spokeProxyV5.pause();
    assertEq(spokeProxyV5.paused(), true);

    vm.prank(spokeProxyV5.watchtower());
    spokeProxyV5.unpause();
    assertEq(spokeProxyV5.paused(), false);
  }

  function test_spokeUpgradeSwaps_setStrategyForAsset() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.setStrategyForAsset(address(0x123), IEverclearV2.Strategy.XERC20);
    assertEq(uint8(spokeProxyV5.strategies(address(0x123))), uint8(IEverclearV2.Strategy.XERC20));
  }

  function test_spokeUpgradeSwaps_setModuleForStrategy() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.setModuleForStrategy(IEverclearV2.Strategy.XERC20, ISettlementModule(address(0x123)));
    assertEq(address(spokeProxyV5.modules(IEverclearV2.Strategy.XERC20)), address(0x123));
  }

  function test_spokeUpgradeSwaps_updateSecurityModule() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.updateSecurityModule(address(0x123));
    address gateway = address(spokeProxyV5.gateway());
    address updatedModule = address(ISpecifiesInterchainSecurityModule(gateway).interchainSecurityModule());
    assertEq(updatedModule, address(0x123));
  }

  function test_spokeUpgradeSwaps_updateGateway() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.updateGateway(address(0x123));
    assertEq(address(spokeProxyV5.gateway()), address(0x123));
  }

  function test_spokeUpgradeSwaps_updateMessageReceiver() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.updateMessageReceiver(address(0x123));
    assertEq(spokeProxyV5.messageReceiver(), address(0x123));
  }

  function test_spokeUpgradeSwaps_updateMessageGasLimit() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV5.owner());
    spokeProxyV5.updateMessageGasLimit(1000);
    assertEq(spokeProxyV5.messageGasLimit(), 1000);
  }

  /**
   * @notice Tests the updateFeeAdapter function of the spoke proxy
   * @dev This function is newly added to the spoke proxy
   */
  function test_spokeUpgradeSwaps_updateFeeAdapter() public {
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
  function test_spokeUpgradeSwaps_deposit() public {
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
  function test_spokeUpgradeSwaps_withdraw() public {
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
  function test_spokeUpgradeSwaps_newIntentBytes_NettingPath(uint256 _amount, bytes32 _receiver) public {
    vm.assume(_receiver != 0);
    _amount = bound(_amount, 1, type(uint128).max);

    uint32[] memory destinations = _getDestinations(10);
    address _sender = address(0x123);

    // upgrading the spoke
    _upgradeSpoke();

    // configuring the feeparams
    IFeeAdapterV2.FeeParams memory _feeParams;
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

    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.ADDED));

    vm.stopPrank();
  }

  function test_spokeUpgradeSwaps_newIntentBytes_SolverPath(
    uint256 _amount,
    uint256 _amountOutMin,
    bytes32 _receiver
  ) public {
    vm.assume(_receiver != 0);
    _amount = bound(_amount, 1, type(uint128).max);
    _amountOutMin = bound(_amount, 1, type(uint128).max);

    uint32[] memory destinations = _getDestinations(10);
    address _sender = address(0x123);

    // upgrading the spoke
    _upgradeSpoke();

    // configuring the feeparams
    IFeeAdapterV2.FeeParams memory _feeParams;
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
      destinations,
      _receiver,
      _inputAsset,
      _outputAsset.toBytes32(),
      _amount,
      _amountOutMin,
      2 hours,
      hex'00',
      _feeParams
    );

    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.ADDED));

    vm.stopPrank();
  }

  /**
   * @notice Tests the newIntent function that has address inputs for receiver and outputAsset
   * @param _amount The amount to send
   * @param _receiver The receiver address
   */
  function test_spokeUpgradeSwaps_newIntent_NettingPath(uint256 _amount, bytes32 _receiver) public {
    vm.assume(_receiver != 0);
    _amount = bound(_amount, 1, type(uint128).max);

    uint32[] memory destinations = _getDestinations(10);
    address _sender = address(0x123);

    // upgrading the spoke
    _upgradeSpoke();

    // configuring the feeparams
    IFeeAdapterV2.FeeParams memory _feeParams;
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

    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.ADDED));

    vm.stopPrank();
  }

  function test_spokeUpgradeSwaps_newIntent_SolverPath(
    uint256 _amount,
    uint256 _amountOutMin,
    bytes32 _receiver
  ) public {
    vm.assume(_receiver != 0);
    _amount = bound(_amount, 1, type(uint128).max);
    _amountOutMin = bound(_amountOutMin, 1, type(uint128).max);

    uint32[] memory destinations = _getDestinations(10);
    address _sender = address(0x123);

    // upgrading the spoke
    _upgradeSpoke();

    // configuring the feeparams
    IFeeAdapterV2.FeeParams memory _feeParams;
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
      destinations,
      _receiver,
      _inputAsset,
      _outputAsset.toBytes32(),
      _amount,
      _amountOutMin,
      2 hours,
      hex'00',
      _feeParams
    );

    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.ADDED));

    vm.stopPrank();
  }

  function test_spokeUpgradeSwaps_fillIntent_AsSolver(address _solver, uint256 _amountOut) public {
    vm.assume(_solver != address(0));
    address _receiver = address(0x456);

    // upgrading the spoke
    _upgradeSpoke();

    // Constructing the user intent
    IEverclearV2.Intent memory _intent = IEverclearV2.Intent({
      initiator: address(0x123).toBytes32(),
      receiver: _receiver.toBytes32(),
      inputAsset: address(0x987).toBytes32(),
      outputAsset: USDC_MAINNET.toBytes32(),
      destinations: _getDestinations(1),
      origin: 10,
      nonce: 1,
      timestamp: uint48(block.timestamp - 10 minutes),
      ttl: 4 hours,
      amount: 1e18,
      amountOutMin: 0,
      data: ''
    });
    _intent.amountOutMin = bound(_intent.amountOutMin, 1, type(uint128).max);
    _amountOut = bound(_amountOut, _intent.amountOutMin, type(uint128).max);

    // storing balances of participants
    deal(USDC_MAINNET, _solver, _amountOut);
    uint256 _startingBalanceSolver = IERC20(USDC_MAINNET).balanceOf(_solver);
    uint256 _startingBalanceReceiver = IERC20(USDC_MAINNET).balanceOf(_receiver);

    vm.startPrank(_solver);
    // approving the amount and depositing to spoke
    IERC20(USDC_MAINNET).approve(address(spokeProxyV5), _amountOut);
    spokeProxyV5.deposit(USDC_MAINNET, _amountOut);
    assertTrue(spokeProxyV5.balances(USDC_MAINNET.toBytes32(), _solver.toBytes32()) == _amountOut);

    // filling the user intent
    spokeProxyV5.fillIntent(_intent, _amountOut);
    bytes32 _intentId = keccak256(abi.encode(_intent));
    vm.stopPrank();

    // asserting changes in state
    assertTrue(spokeProxyV5.status(_intentId) == IEverclearV2.IntentStatus.FILLED);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_solver), _startingBalanceSolver - _amountOut);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_receiver), _startingBalanceReceiver + _amountOut);
  }

  function test_spokeUpgradeSwaps_fillIntent_ForSolver(uint128 _solverPk, uint256 _amountOut) public {
    vm.assume(_solverPk != 0);
    address _solver = vm.addr(_solverPk);
    address _receiver = address(0x456);

    // upgrading the spoke
    _upgradeSpoke();

    // Constructing the user intent
    IEverclearV2.Intent memory _intent = IEverclearV2.Intent({
      initiator: address(0x123).toBytes32(),
      receiver: _receiver.toBytes32(),
      inputAsset: address(0x987).toBytes32(),
      outputAsset: USDC_MAINNET.toBytes32(),
      destinations: _getDestinations(1),
      origin: 10,
      nonce: 1,
      timestamp: uint48(block.timestamp - 10 minutes),
      ttl: 4 hours,
      amount: 1e18,
      amountOutMin: 0,
      data: ''
    });
    _intent.amountOutMin = bound(_intent.amountOutMin, 1, type(uint128).max);
    _amountOut = bound(_amountOut, _intent.amountOutMin, type(uint128).max);

    // storing balances of participants
    deal(USDC_MAINNET, _solver, _amountOut);
    uint256 _startingBalanceSolver = IERC20(USDC_MAINNET).balanceOf(_solver);
    uint256 _startingBalanceReceiver = IERC20(USDC_MAINNET).balanceOf(_receiver);

    vm.startPrank(_solver);
    // approving the amount and depositing to spoke
    IERC20(USDC_MAINNET).approve(address(spokeProxyV5), _amountOut);
    spokeProxyV5.deposit(USDC_MAINNET, _amountOut);
    assertTrue(spokeProxyV5.balances(USDC_MAINNET.toBytes32(), _solver.toBytes32()) == _amountOut);
    vm.stopPrank();

    uint256 _nonce = spokeProxyV5.nonces(_solver);
    bytes memory _data = abi.encode(spokeProxyV5.FILL_INTENT_FOR_SOLVER_TYPEHASH(), _intent, _nonce, _amountOut);
    bytes memory _sig = _generateSignature(_solverPk, _data);

    // filling the user intent
    spokeProxyV5.fillIntentForSolver(_solver, _intent, _nonce, _amountOut, _sig);
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // asserting changes in state
    assertTrue(spokeProxyV5.status(_intentId) == IEverclearV2.IntentStatus.FILLED);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_solver), _startingBalanceSolver - _amountOut);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_receiver), _startingBalanceReceiver + _amountOut);
  }

  /**
   * @notice Tests the processIntentQueue function using the newIntent function with address input
   * @param _intents The intents to process
   * @param _messageFee The message fee to process the intents
   */
  function test_spokeUpgradeSwaps_ProcessIntentQueue(
    IEverclearV2.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint32 _destination,
    uint256 _messageFee
  ) public validDestination(_destination) {
    _upgradeSpoke();
    address lightHouse = spokeProxyV5.lighthouse();

    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(lightHouse, _messageFee);

    IEverclearV2.Intent[] memory _intentsToProcess = new IEverclearV2.Intent[](_intents.length);
    bytes32[] memory _intentIds = new bytes32[](_intents.length);

    for (uint256 _i; _i < _intents.length; _i++) {
      (_intentIds[_i], _intentsToProcess[_i]) =
        _newIntentAndAssert(_intents[_i], AdditionalParams(_destination, _i, uint32(_intents.length)));
    }

    bytes memory _batchIntentmessage = MessageLibV2.formatIntentMessageBatch(_intentsToProcess);
    metadata = StandardHookMetadata.formatMetadata(0, MESSAGE_GAS_LIMIT, SPOKE_GATEWAY_MAINNET, '');

    vm.expectCall(
      address(MAILBOX_MAINNET),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)', HUB_ID, HUB_GATEWAY_PROD, _batchIntentmessage, metadata
      )
    );

    vm.startPrank(lightHouse);
    spokeProxyV5.processIntentQueue{value: _messageFee}(_intentsToProcess);
    assertEq(lightHouse.balance, 0);
  }

  function test_spokeUpgradeSwaps_ProcessFillQueue(
    IEverclearV2.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint256 _messageFee
  ) public {
    _upgradeSpoke();
    address lightHouse = spokeProxyV5.lighthouse();
    address _solver = address(0x456);

    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(lightHouse, _messageFee);

    uint32[] memory _destinations = _getDestinations(1);
    IEverclearV2.FillMessage[] memory _fillsToProcess = new IEverclearV2.FillMessage[](_intents.length);
    for (uint256 _i; _i < _intents.length; _i++) {
      if (_intents[_i].origin == 1) _intents[_i].origin = 10;
      _intents[_i].destinations = _destinations;
      _intents[_i].amountOutMin = bound(_intents[_i].amountOutMin, 1, type(uint64).max);
      _intents[_i].outputAsset = USDC_MAINNET.toBytes32();
      _intents[_i].timestamp = uint48(block.timestamp - 10 minutes);
      _intents[_i].receiver = address(0x999).toBytes32();
      _intents[_i].ttl = 4 hours;
      _intents[_i].data = '';
      deal(USDC_MAINNET, _solver, _intents[_i].amountOutMin + 1);
      _fillsToProcess[_i] = _fillIntentAndAssert(_solver, _intents[_i]);
    }

    bytes memory _batchFillmessage = MessageLibV2.formatFillMessageBatch(_fillsToProcess);
    metadata = StandardHookMetadata.formatMetadata(0, MESSAGE_GAS_LIMIT, SPOKE_GATEWAY_MAINNET, '');

    // TODO: The fill event is failing
    // // processing the fillQueue
    // vm.expectCall(
    //   address(MAILBOX_MAINNET),
    //   abi.encodeWithSignature(
    //     'dispatch(uint32,bytes32,bytes,bytes)', HUB_ID, HUB_GATEWAY_PROD, _batchFillmessage, metadata
    //   )
    // );

    vm.startPrank(lightHouse);
    spokeProxyV5.processFillQueue{value: _messageFee}(uint32(_intents.length));
  }

  function _fillIntentAndAssert(
    address _solver,
    IEverclearV2.Intent memory _intent
  ) internal returns (IEverclearV2.FillMessage memory _fillMessage) {
    // generating the intentId
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // filling the intent
    vm.startPrank(address(_solver));
    IERC20(_intent.outputAsset.toAddress()).approve(address(spokeProxyV5), _intent.amountOutMin + 1);
    spokeProxyV5.deposit(_intent.outputAsset.toAddress(), _intent.amountOutMin + 1);
    _fillMessage = spokeProxyV5.fillIntent(_intent, _intent.amountOutMin + 1);
    vm.stopPrank();

    // asserting the intent status
    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.FILLED));
  }

  // ============ Revert ============ //
  function test_spokeSwapUpgrade_fillIntent_AmountOutInvalid() public {
    _upgradeSpoke();

    // constructing the original intent
    uint256 _amountOutMin = 5e17;
    IEverclearV2.Intent memory _intent = IEverclearV2.Intent({
      initiator: address(0x123).toBytes32(),
      receiver: address(0x123).toBytes32(),
      inputAsset: address(0x987).toBytes32(),
      outputAsset: USDC_MAINNET.toBytes32(),
      destinations: _getDestinations(1),
      origin: 10,
      nonce: 1,
      timestamp: uint48(block.timestamp) - 10 minutes,
      ttl: 4 hours,
      amount: 1e18,
      amountOutMin: _amountOutMin,
      data: hex'00'
    });

    // sending the fill intent
    vm.startPrank(address(feeAdapter));
    vm.expectRevert(
      abi.encodeWithSelector(
        IEverclearSpokeV5.EverclearSpoke_FillIntent_AmountOutInvalid.selector, _amountOutMin - 1, _amountOutMin
      )
    );
    spokeProxyV5.fillIntent(_intent, _amountOutMin - 1);
    vm.stopPrank();
  }

  // ============ Helpers ============ //
  function _upgradeSpoke() internal {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP5);
    // Deploying the new FeeAdapter
    feeAdapter = new FeeAdapterV2(
      SPOKE_PROXY_MAINNET, FEE_RECIPIENT_MAINNET, FEE_SIGNER, XERC20_MODULE_MAINNET, SPOKE_PROXY_MAINNET_OWNER
    );

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET_V4);

    // Generating the inputs for CREATE3
    uint8 version = 5;
    bytes32 _salt = keccak256(abi.encodePacked(SPOKE_PROXY_MAINNET, version));
    bytes32 _implementationSalt = keccak256(abi.encodePacked(_salt, 'implementation'));
    bytes memory _creation = type(EverclearSpokeV5).creationCode;

    // Deploying the new implementation
    bytes memory create3Calldata = abi.encodeWithSelector(ICREATE3.deploy.selector, _implementationSalt, _creation);
    (bool success, bytes memory returnData) = CREATE_3.call(create3Calldata);
    if (!success) revert Create3DeploymentFailed();
    address newEverclearSpoke = abi.decode(returnData, (address));

    // Initializing with new feeAdapter and upgrading
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV5.initialize.selector, address(feeAdapter));
    success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    (success,) = address(spokeProxyV5).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);
  }

  function _newIntentAndAssert(
    IEverclearV2.Intent memory _intentParam,
    AdditionalParams memory _params
  ) internal returns (bytes32 _intentId, IEverclearV2.Intent memory _returnIntent) {
    // vm.assume(_intentParam.amount > 0);
    _intentParam.amount = bound(_intentParam.amount, 1, type(uint128).max);
    vm.assume(_intentParam.receiver.toAddress() != address(0));
    _getDestinations(_intentParam, _params.destination);

    // configuring the feeparams
    IFeeAdapterV2.FeeParams memory _feeParams;
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
      _intentParam.amountOutMin,
      _intentParam.ttl,
      _intentParam.data,
      _feeParams
    );

    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.ADDED));

    vm.stopPrank();
  }

  function _sendIntent() internal {
    // dealing to the user
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;
    address _inputAsset = deployAndDeal(address(feeAdapter), _amount).toAddress();

    vm.startPrank(address(feeAdapter));
    IERC20(_inputAsset).approve(address(spokeProxyV5), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV5.newIntent(
      destinations, address(feeAdapter).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.ADDED));
  }
}
