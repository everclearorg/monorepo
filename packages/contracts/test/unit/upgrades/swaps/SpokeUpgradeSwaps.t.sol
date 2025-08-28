// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MessageLibV2} from 'contracts/common/MessageLibV2.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {FeeAdapterV2, IFeeAdapterV2} from 'contracts/intent/FeeAdapterV2.sol';
import {SpokeMessageReceiverV2} from 'contracts/intent/modules/SpokeMessageReceiverV2.sol';

import {ISpecifiesInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {EverclearSpokeV4, IEverclearSpokeV4} from 'contracts/intent/EverclearSpokeV4.sol';
import {EverclearSpokeV5, IEverclearSpokeV5} from 'contracts/intent/EverclearSpokeV5.sol';
import {ISpokeGateway} from 'contracts/intent/SpokeGateway.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IEverclearV2} from 'interfaces/common/IEverclearV2.sol';
import {ISpokeStorageV5} from 'interfaces/intent/ISpokeStorageV5.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';

import {Deploy} from 'script/utils/Deploy.sol';
import {BaseTest} from 'test/unit/intent/EverclearSpoke.t.sol';
import {Constants} from 'test/utils/Constants.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ICREATE3, TestEverclearSpokeV5, UpgradeHelper} from 'test//utils/UpgradeHelper.sol';

import 'forge-std/StdStorage.sol';

contract SpokeUpgradeSwaps is BaseTest, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;
  using stdStorage for StdStorage;

  FeeAdapterV2 public feeAdapterV2;
  SpokeMessageReceiverV2 public messageReceiverV2;

  // ============ Upgrade ============ //
  function test_spokeSwapUpgrade_upgrade() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP5);

    // Deploying the new FeeAdapter
    feeAdapterV2 = new FeeAdapterV2(
      SPOKE_PROXY_MAINNET, FEE_RECIPIENT_MAINNET, FEE_SIGNER, XERC20_MODULE_MAINNET, SPOKE_PROXY_MAINNET_OWNER
    );

    // deploying messageReceiverV2
    messageReceiverV2 = new SpokeMessageReceiverV2();

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
    bytes memory initializeCalldata =
      abi.encodeWithSelector(EverclearSpokeV5.initialize.selector, address(feeAdapterV2), address(messageReceiverV2));
    success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    (success,) = address(spokeProxyV5).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);
    assertEq(spokeProxyV5.feeAdapter(), address(feeAdapterV2));

    // Testing sending new intent
    _sendIntent();

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV5.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV5.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV5.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV5.lighthouse());
    assertEq(state.watchtower, spokeProxyV5.watchtower());
    assertEq(state.gateway, address(spokeProxyV5.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV5.callExecutor()));
    assertEq(state.paused, spokeProxyV5.paused());
    assertEq(state.nonce + 1, spokeProxyV5.nonce());
    assertEq(state.messageGasLimit, spokeProxyV5.messageGasLimit());
    assertEq(address(feeAdapterV2), spokeProxyV5.feeAdapter());
    assertEq(address(messageReceiverV2), spokeProxyV5.messageReceiver());
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
    IERC20(_inputAsset).approve(address(feeAdapterV2), _amount + _feeParams.fee);

    (bytes32 _intentId,) = feeAdapterV2.newIntent(
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
    IERC20(_inputAsset).approve(address(feeAdapterV2), _amount + _feeParams.fee);

    (bytes32 _intentId,) = feeAdapterV2.newIntent(
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
    IERC20(_inputAsset).approve(address(feeAdapterV2), _amount + _feeParams.fee);

    (bytes32 _intentId,) = feeAdapterV2.newIntent(
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
    IERC20(_inputAsset).approve(address(feeAdapterV2), _amount + _feeParams.fee);

    (bytes32 _intentId,) = feeAdapterV2.newIntent(
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
    uint32[] memory _solverDestinations = _getDestinations(1);

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
    spokeProxyV5.fillIntent(_intent, _amountOut, _solverDestinations);
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
    uint32[] memory _solverDestinations = _getDestinations(1);

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
    bytes32 domain = keccak256(abi.encode(block.chainid, address(spokeProxyV5)));
    bytes memory _payload =
      abi.encode(spokeProxyV5.FILL_INTENT_FOR_SOLVER_TYPEHASH(), domain, _solver, _intent, _nonce, _amountOut);
    bytes memory _sig = _generateSignature(_solverPk, _payload);

    // filling the user intent
    spokeProxyV5.fillIntentForSolver(_solver, _intent, _nonce, _amountOut, _solverDestinations, _sig);
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // asserting changes in state
    assertTrue(spokeProxyV5.status(_intentId) == IEverclearV2.IntentStatus.FILLED);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_solver), _startingBalanceSolver - _amountOut);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_receiver), _startingBalanceReceiver + _amountOut);
  }

  function test_spokeUpgradeSwaps_fillIntentWithPull(address _solver, uint256 _amountOut) public {
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
    uint32[] memory _solverDestinations = _getDestinations(1);

    // storing balances of participants
    deal(USDC_MAINNET, _solver, _amountOut);
    uint256 _startingBalanceSolver = IERC20(USDC_MAINNET).balanceOf(_solver);
    uint256 _startingBalanceReceiver = IERC20(USDC_MAINNET).balanceOf(_receiver);

    vm.startPrank(_solver);
    // approving the amount and depositing to spoke
    IERC20(USDC_MAINNET).approve(address(spokeProxyV5), _amountOut);

    // filling the user intent
    spokeProxyV5.fillIntentWithPull(_intent, _amountOut, _solverDestinations);
    bytes32 _intentId = keccak256(abi.encode(_intent));
    vm.stopPrank();

    // asserting changes in state
    assertTrue(spokeProxyV5.status(_intentId) == IEverclearV2.IntentStatus.FILLED);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_solver), _startingBalanceSolver - _amountOut);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_receiver), _startingBalanceReceiver + _amountOut);
  }

  function test_spokeUpgradeSwaps_fillIntentWithPull_amountOutEqualsAmountOutMin(
    uint256 _amountOut
  ) public {
    address _solver = address(0x999);
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
    _amountOut = _intent.amountOutMin;
    uint32[] memory _solverDestinations = _getDestinations(1);

    // storing balances of participants
    deal(USDC_MAINNET, _solver, _amountOut);
    uint256 _startingBalanceSolver = IERC20(USDC_MAINNET).balanceOf(_solver);
    uint256 _startingBalanceReceiver = IERC20(USDC_MAINNET).balanceOf(_receiver);

    vm.startPrank(_solver);
    // approving the amount and depositing to spoke
    IERC20(USDC_MAINNET).approve(address(spokeProxyV5), _amountOut);

    // filling the user intent
    spokeProxyV5.fillIntentWithPull(_intent, _amountOut, _solverDestinations);
    bytes32 _intentId = keccak256(abi.encode(_intent));
    vm.stopPrank();

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
    uint32[] memory _solverDestinations = _getDestinations(42_161);

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
      _fillsToProcess[_i] = _fillIntentAndAssert(_solver, _intents[_i], _solverDestinations);
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

  function test_spokeUpgradeSwaps_processIntentQueueViaRelayer(
    IEverclearV2.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint32 _destination
  ) public validDestination(_destination) {
    _upgradeSpoke();
    address _relayer = address(0x123);

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

    // constructing the signature and inputs
    uint256 _ttl = block.timestamp + 1 hours;
    uint256 _nonce = 0;
    _updateLighthouse(vm.addr(FEE_SIGNER_PK));
    bytes memory _sig = _generateSignature(
      FEE_SIGNER_PK,
      abi.encode(
        spokeProxyV5.PROCESS_INTENT_QUEUE_VIA_RELAYER_TYPEHASH(),
        block.chainid,
        _intentsToProcess.length,
        _relayer,
        _ttl,
        _nonce,
        0
      )
    );

    vm.startPrank(_relayer);
    spokeProxyV5.processIntentQueueViaRelayer(uint32(block.chainid), _intentsToProcess, _relayer, _ttl, _nonce, 0, _sig);
  }

  function test_spokeUpgradeSwaps_processFillQueueViaRelayer(
    IEverclearV2.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint256 _messageFee
  ) public {
    _upgradeSpoke();
    address _relayer = address(0x123);

    address lightHouse = spokeProxyV5.lighthouse();
    address _solver = address(0x456);
    uint32[] memory _solverDestinations = _getDestinations(42_161);

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
      _fillsToProcess[_i] = _fillIntentAndAssert(_solver, _intents[_i], _solverDestinations);
    }

    bytes memory _batchFillmessage = MessageLibV2.formatFillMessageBatch(_fillsToProcess);
    metadata = StandardHookMetadata.formatMetadata(0, MESSAGE_GAS_LIMIT, SPOKE_GATEWAY_MAINNET, '');

    // constructing the signature and inputs
    uint256 _ttl = block.timestamp + 1 hours;
    uint256 _nonce = 0;
    uint32 _amount = uint32(_intents.length);
    _updateLighthouse(vm.addr(FEE_SIGNER_PK));
    bytes memory _sig = _generateSignature(
      FEE_SIGNER_PK,
      abi.encode(
        spokeProxyV5.PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH(), block.chainid, _amount, _relayer, _ttl, _nonce, 0
      )
    );

    // TODO: Checking event emissions

    vm.startPrank(_relayer);
    spokeProxyV5.processFillQueueViaRelayer(uint32(block.chainid), _amount, _relayer, _ttl, _nonce, 0, _sig);
  }

  function test_spokeUpgradeSwaps_executeIntentCalldata() public {
    _upgradeSpoke();

    // configuring the input and mocking the storage to return SETTLED
    address _target = address(spokeProxyV5);
    IEverclearV2.Intent memory _intent;
    _intent.destinations = new uint32[](1);
    _intent.destinations[0] = 1;
    bytes memory _calldata = abi.encode(bytes4(keccak256('decimals()')));
    _intent.data = abi.encode(USDC_MAINNET, _calldata);
    bytes32 _intentId = keccak256(abi.encode(_intent));

    stdstore.target(_target).sig('status(bytes32)').with_key(_intentId).checked_write(uint256(6));
    (, bytes memory ret) = _target.staticcall(abi.encodeWithSignature('status(bytes32)', _intentId));
    uint256 v = abi.decode(ret, (uint256));
    assertEq(v, 6);

    spokeProxyV5.executeIntentCalldata(_intent);
  }

  // ============ Same-chain Swap ============ //
  function test_spokeUpgradeSwaps_newIntentSameChainSwap_netting() public {
    uint32[] memory destinations = _getDestinations(1);
    address _sender = address(0x123);
    address _receiver = _sender;
    uint256 _amount = 1e18;

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
    IERC20(_inputAsset).approve(address(feeAdapterV2), _amount + _feeParams.fee);

    (bytes32 _intentId,) =
      feeAdapterV2.newIntent(destinations, _receiver, _inputAsset, _outputAsset, _amount, 0, 0, hex'00', _feeParams);
    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.ADDED));

    vm.stopPrank();
  }

  function test_spokeUpgradeSwaps_newIntentSameChainSwap_solving() public {
    uint32[] memory destinations = _getDestinations(1);
    address _sender = address(0x123);
    address _receiver = _sender;
    uint256 _amount = 1e18;
    uint256 _amountOutMin = 1e12;
    uint48 _ttl = 2 days;

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
    IERC20(_inputAsset).approve(address(feeAdapterV2), _amount + _feeParams.fee);

    (bytes32 _intentId,) = feeAdapterV2.newIntent(
      destinations, _receiver, _inputAsset, _outputAsset, _amount, _amountOutMin, _ttl, hex'00', _feeParams
    );
    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.ADDED));

    vm.stopPrank();
  }

  function test_spokeUpgradeSwaps_fillIntentSameChainSwap() public {
    uint32[] memory destinations = _getDestinations(1);
    address _sender = address(0x123);
    address _receiver = _sender;
    uint256 _amount = 1e18;
    uint256 _amountOutMin = 1e12;
    uint48 _ttl = 2 days;

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
    IERC20(_inputAsset).approve(address(feeAdapterV2), _amount + _feeParams.fee);

    (bytes32 _intentId, IEverclearV2.Intent memory _intent) = feeAdapterV2.newIntent(
      destinations, _receiver, _inputAsset, _outputAsset, _amount, _amountOutMin, _ttl, '', _feeParams
    );
    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.ADDED));

    vm.stopPrank();

    // Filling the intent
    address _solver = address(0x789);
    uint32[] memory _solverDestinations = _getDestinations(42_161);
    deal(_outputAsset, _solver, _intent.amountOutMin + 1);
    _fillIntentAndAssert(_solver, _intent, _solverDestinations);
  }

  // ============ Receiving Messages ============ //

  function test_spokeUpgradeSwaps_receiveMessage_handleSettlement_settled() public {
    _upgradeSpoke();

    // configuring the inputs
    address _target = address(spokeProxyV5);
    bytes32 _intentId = keccak256(abi.encode('SETTLED'));
    IEverclearV2.Settlement memory _settlement;
    _settlement.intentId = _intentId;
    _settlement.asset = USDC_MAINNET.toBytes32();

    IEverclearV2.Settlement[] memory _settlements = new IEverclearV2.Settlement[](1);
    _settlements[0] = _settlement;
    bytes memory _settlementData = abi.encode(_settlements);
    bytes memory _message = abi.encode(uint8(2), _settlementData);

    // configuring the settlement status to be settled
    stdstore.target(_target).sig('status(bytes32)').with_key(_intentId).checked_write(uint256(6));
    (, bytes memory ret) = _target.staticcall(abi.encodeWithSignature('status(bytes32)', _intentId));
    uint256 v = abi.decode(ret, (uint256));
    assertEq(v, 6);

    // sending message
    vm.startPrank(spokeProxyV5.owner());
    spokeProxyV5.receiveMessage(_message);

    assertEq(uint8(spokeProxyV5.status(_intentId)), 6);
  }

  function test_spokeUpgradeSwaps_receiveMessage_handleSettlement_XERC20() public {
    _upgradeSpoke();

    // configuring the inputs
    uint256 _amount = 100e18;
    bytes32 _intentId = keccak256(abi.encode('SETTLED'));
    IEverclearV2.Settlement memory _settlement;
    _settlement.intentId = _intentId;
    _settlement.recipient = address(0x12345).toBytes32();
    _settlement.asset = CLEAR_MAINNET.toBytes32();
    _settlement.amount = _amount; // scaling

    IEverclearV2.Settlement[] memory _settlements = new IEverclearV2.Settlement[](1);
    _settlements[0] = _settlement;
    bytes memory _settlementData = abi.encode(_settlements);
    bytes memory _message = abi.encode(uint8(2), _settlementData);

    // sending message
    uint256 balance = IERC20(CLEAR_MAINNET).balanceOf(_settlement.recipient.toAddress());
    vm.startPrank(spokeProxyV5.owner());
    spokeProxyV5.receiveMessage(_message);

    assertEq(uint8(spokeProxyV5.status(_intentId)), 6);
    assertEq(IERC20(CLEAR_MAINNET).balanceOf(_settlement.recipient.toAddress()), balance + _amount);
  }

  function test_spokeUpgradeSwaps_receiveMessage_handleSettlement_ERC20_updateVirtual() public {
    _upgradeSpoke();

    // configuring the inputs
    uint256 _amount = 1e6;
    bytes32 _intentId = keccak256(abi.encode('SETTLED'));
    IEverclearV2.Settlement memory _settlement;
    _settlement.intentId = _intentId;
    _settlement.recipient = address(0x12345).toBytes32();
    _settlement.asset = USDC_MAINNET.toBytes32();
    _settlement.amount = _amount * 1e12; // scaling
    _settlement.updateVirtualBalance = true;

    IEverclearV2.Settlement[] memory _settlements = new IEverclearV2.Settlement[](1);
    _settlements[0] = _settlement;
    bytes memory _settlementData = abi.encode(_settlements);
    bytes memory _message = abi.encode(uint8(2), _settlementData);

    // transferring USDC to the contract
    deal(USDC_MAINNET, address(this), _amount);
    IERC20(USDC_MAINNET).transfer(address(spokeProxyV5), _amount);

    // sending message
    vm.startPrank(spokeProxyV5.owner());
    spokeProxyV5.receiveMessage(_message);

    assertEq(uint8(spokeProxyV5.status(_intentId)), 6);
    assertEq(spokeProxyV5.balances(USDC_MAINNET.toBytes32(), _settlement.recipient), _amount);
  }

  function test_spokeUpgradeSwaps_receiveMessage_handleSettlement_ERC20_transferSuccess() public {
    _upgradeSpoke();

    // configuring the inputs
    uint256 _amount = 1e6;
    bytes32 _intentId = keccak256(abi.encode('SETTLED'));
    IEverclearV2.Settlement memory _settlement;
    _settlement.intentId = _intentId;
    _settlement.recipient = address(0x12345).toBytes32();
    _settlement.asset = USDC_MAINNET.toBytes32();
    _settlement.amount = _amount * 1e12; // scaling

    IEverclearV2.Settlement[] memory _settlements = new IEverclearV2.Settlement[](1);
    _settlements[0] = _settlement;
    bytes memory _settlementData = abi.encode(_settlements);
    bytes memory _message = abi.encode(uint8(2), _settlementData);

    // transferring USDC to the contract
    deal(USDC_MAINNET, address(this), _amount);
    IERC20(USDC_MAINNET).transfer(address(spokeProxyV5), _amount);

    // sending message
    uint256 balance = IERC20(USDC_MAINNET).balanceOf(_settlement.recipient.toAddress());
    vm.startPrank(spokeProxyV5.owner());
    spokeProxyV5.receiveMessage(_message);

    assertEq(uint8(spokeProxyV5.status(_intentId)), 6);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_settlement.recipient.toAddress()), balance + _amount);
  }

  function test_spokeUpgradeSwaps_receiveMessage_handleSettlement_ERC20_transferFail() public {
    _upgradeSpoke();

    // configuring the inputs
    uint256 _amount = 1e6;
    bytes32 _intentId = keccak256(abi.encode('SETTLED'));
    IEverclearV2.Settlement memory _settlement;
    _settlement.intentId = _intentId;
    _settlement.recipient = address(0x1).toBytes32();
    _settlement.asset = USDC_MAINNET.toBytes32();
    _settlement.amount = _amount * 1e12; // scaling

    IEverclearV2.Settlement[] memory _settlements = new IEverclearV2.Settlement[](1);
    _settlements[0] = _settlement;
    bytes memory _settlementData = abi.encode(_settlements);
    bytes memory _message = abi.encode(uint8(2), _settlementData);

    // setting balance to 0 with deal
    deal(USDC_MAINNET, address(spokeProxyV5), 0);

    // sending message
    uint256 balance = IERC20(USDC_MAINNET).balanceOf(_settlement.recipient.toAddress());
    vm.startPrank(spokeProxyV5.owner());
    spokeProxyV5.receiveMessage(_message);

    assertEq(uint8(spokeProxyV5.status(_intentId)), 6);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_settlement.recipient.toAddress()), balance);
    assertEq(spokeProxyV5.balances(USDC_MAINNET.toBytes32(), _settlement.recipient), _amount);
  }

  function test_spokeUpgradeSwaps_receiveMessage_handleSettlement_zeroAmount() public {
    _upgradeSpoke();

    // configuring the inputs
    bytes32 _intentId = keccak256(abi.encode('SETTLED'));
    IEverclearV2.Settlement memory _settlement;
    _settlement.intentId = _intentId;
    _settlement.recipient = address(0x1).toBytes32();
    _settlement.asset = USDC_MAINNET.toBytes32();

    IEverclearV2.Settlement[] memory _settlements = new IEverclearV2.Settlement[](1);
    _settlements[0] = _settlement;
    bytes memory _settlementData = abi.encode(_settlements);
    bytes memory _message = abi.encode(uint8(2), _settlementData);

    // setting balance to 0 with deal
    deal(USDC_MAINNET, address(spokeProxyV5), 0);

    // sending message
    uint256 balance = IERC20(USDC_MAINNET).balanceOf(_settlement.recipient.toAddress());
    vm.startPrank(spokeProxyV5.owner());
    spokeProxyV5.receiveMessage(_message);

    assertEq(uint8(spokeProxyV5.status(_intentId)), 6);
    assertEq(IERC20(USDC_MAINNET).balanceOf(_settlement.recipient.toAddress()), balance);
    assertEq(spokeProxyV5.balances(USDC_MAINNET.toBytes32(), _settlement.recipient), 0);
  }

  function test_spokeUpgradeSwaps_receiveMessage_updateGateway() public {
    _upgradeSpoke();

    // configuring the inputs
    address _newGateway = address(0x123);
    bytes32 _updateVariable = keccak256(abi.encode('GATEWAY'));
    bytes memory _updateData = abi.encode(_newGateway);
    bytes memory _data = abi.encode(_updateVariable, _updateData);
    bytes memory _message = abi.encode(uint8(3), _data);

    // updating watchtower
    vm.startPrank(spokeProxyV5.owner());
    spokeProxyV5.receiveMessage(_message);
    assertEq(address(spokeProxyV5.gateway()), _newGateway);
  }

  function test_spokeUpgradeSwaps_receiveMessage_updateMailbox() public {
    _upgradeSpoke();

    // configuring the inputs
    address _newMailbox = address(0x123);
    bytes32 _updateVariable = keccak256(abi.encode('MAILBOX'));
    bytes memory _updateData = abi.encode(_newMailbox);
    bytes memory _data = abi.encode(_updateVariable, _updateData);
    bytes memory _message = abi.encode(uint8(3), _data);

    // updating watchtower
    vm.startPrank(spokeProxyV5.owner());
    spokeProxyV5.receiveMessage(_message);
    assertEq(address(ISpokeGateway(spokeProxyV5.gateway()).mailbox()), _newMailbox);
  }

  function test_spokeUpgradeSwaps_receiveMessage_updateLighthouse() public {
    _upgradeSpoke();

    // configuring the inputs
    address _newLighthouse = address(0x123);
    bytes32 _updateVariable = keccak256(abi.encode('LIGHTHOUSE'));
    bytes memory _updateData = abi.encode(_newLighthouse);
    bytes memory _data = abi.encode(_updateVariable, _updateData);
    bytes memory _message = abi.encode(uint8(3), _data);

    // updating lighthouse
    vm.startPrank(spokeProxyV5.owner());
    spokeProxyV5.receiveMessage(_message);
    assertEq(spokeProxyV5.lighthouse(), _newLighthouse);
  }

  function test_spokeUpgradeSwaps_receiveMessage_updateWatchtower() public {
    _upgradeSpoke();

    // configuring the inputs
    address _newWatchtower = address(0x123);
    bytes32 _updateVariable = keccak256(abi.encode('WATCHTOWER'));
    bytes memory _updateData = abi.encode(_newWatchtower);
    bytes memory _data = abi.encode(_updateVariable, _updateData);
    bytes memory _message = abi.encode(uint8(3), _data);

    // updating watchtower
    vm.startPrank(address(spokeProxyV5.gateway()));
    spokeProxyV5.receiveMessage(_message);
    assertEq(spokeProxyV5.watchtower(), _newWatchtower);
  }

  // ============ Revert ============ //
  function testRevert_spokeSwapUpgrade_newIntentBytes_InvalidIntent() public {
    _upgradeSpoke();

    // configuring the inputs
    uint32[] memory _destinations = new uint32[](11);
    bytes32 _receiver;
    address _inputAsset;
    bytes32 _outputAsset;
    uint256 _amount;
    uint256 _amountOutMin;
    uint48 _ttl;

    vm.startPrank(spokeProxyV5.feeAdapter());
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxyV5.newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, _amountOutMin, _ttl, '');
  }

  function testRevert_spokeSwapUpgrade_newIntentAddress_InvalidIntent() public {
    _upgradeSpoke();

    // configuring the inputs
    uint32[] memory _destinations = new uint32[](11);
    address _receiver;
    address _inputAsset;
    address _outputAsset;
    uint256 _amount;
    uint256 _amountOutMin;
    uint48 _ttl;

    vm.startPrank(spokeProxyV5.feeAdapter());
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxyV5.newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, _amountOutMin, _ttl, '');
  }

  function testRevert_spokeSwapUpgrade_newIntentPermit_InvalidIntent() public {
    _upgradeSpoke();

    // configuring the inputs
    uint32[] memory _destinations = new uint32[](11);
    address _receiver;
    address _inputAsset;
    address _outputAsset;
    uint256 _amount;
    uint256 _amountOutMin;
    uint48 _ttl;
    IEverclearSpokeV5.Permit2Params memory _permit2Params;

    vm.startPrank(spokeProxyV5.feeAdapter());
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_NewIntent_InvalidIntent.selector);
    spokeProxyV5.newIntent(
      _destinations, _receiver, _inputAsset, _outputAsset, _amount, _amountOutMin, _ttl, '', _permit2Params
    );
  }

  function testRevert_spokeSwapUpgrade_executeCalldata_InvalidStatus() public {
    _upgradeSpoke();

    // configuring the input and mocking the storage to return SETTLED
    address _target = address(spokeProxyV5);
    IEverclearV2.Intent memory _intent;
    _intent.destinations = new uint32[](1);
    _intent.destinations[0] = 1;
    bytes32 _intentId = keccak256(abi.encode(_intent));

    stdstore.target(_target).sig('status(bytes32)').with_key(_intentId).checked_write(uint256(5));
    (, bytes memory ret) = _target.staticcall(abi.encodeWithSignature('status(bytes32)', _intentId));
    uint256 v = abi.decode(ret, (uint256));
    assertEq(v, 5);

    // calling and expecting revert
    vm.expectRevert(
      abi.encodeWithSelector(IEverclearSpokeV5.EverclearSpoke_ExecuteIntentCalldata_InvalidStatus.selector, _intentId)
    );
    spokeProxyV5.executeIntentCalldata(_intent);
  }

  function testRevert_spokeSwapUpgrade_initialize_IntentQueueNonEmpty() public {
    uint256 blockWithIntentQueue = 23_182_349;

    vm.createSelectFork(vm.envString('MAINNET_RPC'), blockWithIntentQueue);
    // Deploying the new FeeAdapterV2
    feeAdapterV2 = new FeeAdapterV2(
      SPOKE_PROXY_MAINNET, FEE_RECIPIENT_MAINNET, FEE_SIGNER, XERC20_MODULE_MAINNET, SPOKE_PROXY_MAINNET_OWNER
    );

    // Deploying the new SpokeMessageReceiverV2
    messageReceiverV2 = new SpokeMessageReceiverV2();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(SPOKE_PROXY_MAINNET);

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
    bytes memory initializeCalldata =
      abi.encodeWithSelector(EverclearSpokeV5.initialize.selector, address(feeAdapterV2), address(messageReceiverV2));

    vm.startPrank(SPOKE_PROXY_MAINNET_OWNER);
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_Initialize_IntentQueueNotEmpty.selector);
    spokeProxyV5.upgradeToAndCall(newEverclearSpoke, initializeCalldata);
  }

  function testRevert_spokeSwapUpgrade_initialize_FillQueueNonEmpty() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP5);
    // Deploying the new FeeAdapterV2
    feeAdapterV2 = new FeeAdapterV2(
      SPOKE_PROXY_MAINNET, FEE_RECIPIENT_MAINNET, FEE_SIGNER, XERC20_MODULE_MAINNET, SPOKE_PROXY_MAINNET_OWNER
    );

    // Deploying the new SpokeMessageReceiverV2
    messageReceiverV2 = new SpokeMessageReceiverV2();

    // Checking implementation correct and caching the state variables
    spokeProxyV5 = EverclearSpokeV5(SPOKE_PROXY_MAINNET);

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

    // Sending a fill to the Spoke
    _fillIntentV4(USDC_MAINNET, address(0x123), 100e6);

    // Initializing with new feeAdapter and upgrading
    bytes memory initializeCalldata =
      abi.encodeWithSelector(EverclearSpokeV5.initialize.selector, address(feeAdapterV2), address(messageReceiverV2));

    vm.startPrank(SPOKE_PROXY_MAINNET_OWNER);
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_Initialize_FillQueueNotEmpty.selector);
    spokeProxyV5.upgradeToAndCall(newEverclearSpoke, initializeCalldata);
  }

  function testRevert_spokeSwapUpgrade_initializeTwice_revert() public {
    _upgradeSpoke();

    // configuring the inputs
    address _feeAdapter = address(0x123);
    address _messageReceiver = address(0x456);

    // Expecting reverting on second intialize
    vm.startPrank(spokeProxyV5.owner());
    vm.expectRevert();
    spokeProxyV5.initialize(_feeAdapter, _messageReceiver);
  }

  function testRevert_spokeSwapUpgrade_newIntentBytes_NotAuthorized() public {
    _upgradeSpoke();

    uint32[] memory _destinations;
    bytes32 _receiver;
    address _inputAsset;
    bytes32 _outputAsset;
    uint256 _amount;

    vm.expectRevert(ISpokeStorageV5.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV5.newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, 0, 0, '');
  }

  function testRevert_spokeSwapUpgrade_newIntent_NotAuthorized() public {
    _upgradeSpoke();

    uint32[] memory _destinations;
    address _receiver;
    address _inputAsset;
    address _outputAsset;
    uint256 _amount;

    vm.expectRevert(ISpokeStorageV5.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV5.newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, 0, 0, '');
  }

  function testRevert_spokeSwapUpgrade_newIntentPermit_NotAuthorized() public {
    _upgradeSpoke();

    uint32[] memory _destinations;
    address _receiver;
    address _inputAsset;
    address _outputAsset;
    uint256 _amount;
    IEverclearSpokeV5.Permit2Params memory _params;

    vm.expectRevert(ISpokeStorageV5.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV5.newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, 0, 0, '', _params);
  }

  function testRevert_spokeSwapUpgrade_newIntent_OutputAssetNull() public {
    _upgradeSpoke();

    // configuring the inputs
    uint32[] memory _destinations = new uint32[](1);
    address _receiver;
    address _inputAsset;
    address _outputAsset;
    uint256 _amount;
    uint256 _amountOutMin;
    uint48 _ttl = 1;

    vm.startPrank(spokeProxyV5.feeAdapter());
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_NewIntent_OutputAssetNull.selector);
    spokeProxyV5.newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, _amountOutMin, _ttl, '');
  }

  function testRevert_spokeSwapUpgrade_newIntent_ttl_OutputAssetNotNull() public {
    _upgradeSpoke();

    // configuring the inputs
    uint32[] memory _destinations = new uint32[](2);
    address _receiver;
    address _inputAsset;
    address _outputAsset;
    uint256 _amount;
    uint256 _amountOutMin;
    uint48 _ttl = 1;

    vm.startPrank(spokeProxyV5.feeAdapter());
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_NewIntent_OutputAssetNotNull.selector);
    spokeProxyV5.newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, _amountOutMin, _ttl, '');
  }

  function testRevert_spokeSwapUpgrade_newIntent_outputAsset_OutputAssetNotNull() public {
    _upgradeSpoke();

    // configuring the inputs
    uint32[] memory _destinations = new uint32[](2);
    address _receiver;
    address _inputAsset;
    address _outputAsset = address(0x123);
    uint256 _amount;
    uint256 _amountOutMin;
    uint48 _ttl;

    vm.startPrank(spokeProxyV5.feeAdapter());
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_NewIntent_OutputAssetNotNull.selector);
    spokeProxyV5.newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, _amountOutMin, _ttl, '');
  }

  function testRevert_spokeSwapUpgrade_newIntent_CalldataExceedsMaxSize() public {
    _upgradeSpoke();

    // configuring the inputs
    uint32[] memory _destinations = new uint32[](2);
    address _receiver;
    address _inputAsset;
    address _outputAsset;
    uint256 _amount;
    uint256 _amountOutMin;
    uint48 _ttl;
    bytes memory _maxCalldata = new bytes(50_001);

    vm.startPrank(spokeProxyV5.feeAdapter());
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_NewIntent_CalldataExceedsLimit.selector);
    spokeProxyV5.newIntent(
      _destinations, _receiver, _inputAsset, _outputAsset, _amount, _amountOutMin, _ttl, _maxCalldata
    );
  }

  function testRevert_spokeSwapUpgrade_newIntent_ZeroAmount() public {
    _upgradeSpoke();

    // configuring the inputs
    uint32[] memory _destinations = new uint32[](2);
    address _receiver;
    address _inputAsset = USDC_MAINNET;
    address _outputAsset;
    uint256 _amount;
    uint256 _amountOutMin;
    uint48 _ttl;

    vm.startPrank(spokeProxyV5.feeAdapter());
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_NewIntent_ZeroAmount.selector);
    spokeProxyV5.newIntent(_destinations, _receiver, _inputAsset, _outputAsset, _amount, _amountOutMin, _ttl, '');
  }

  function testRevert_spokeSwapUpgrade_fillIntent_IntentExpired() public {
    _upgradeSpoke();

    // configuring the inputs
    uint256 _amountOut;
    uint32[] memory _solverDestinations = _getDestinations(1);
    IEverclearV2.Intent memory _intent;
    _intent.destinations = new uint32[](1);
    _intent.destinations[0] = 1;
    _intent.timestamp = uint48(block.timestamp - 100);
    _intent.ttl = 1;
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // calling
    vm.expectRevert(
      abi.encodeWithSelector(IEverclearSpokeV5.EverclearSpoke_FillIntent_IntentExpired.selector, _intentId)
    );
    spokeProxyV5.fillIntent(_intent, _amountOut, _solverDestinations);
  }

  function testRevert_spokeSwapUpgrade_fillIntent_AmountOutInvalid() public {
    _upgradeSpoke();

    // configuring the inputs
    uint256 _amountOut = 999e6;
    uint32[] memory _solverDestinations = _getDestinations(1);
    IEverclearV2.Intent memory _intent;
    _intent.destinations = new uint32[](1);
    _intent.destinations[0] = 1;
    _intent.timestamp = uint48(block.timestamp);
    _intent.ttl = 1 days;
    _intent.amountOutMin = 1000e6;

    // calling
    vm.expectRevert(
      abi.encodeWithSelector(
        IEverclearSpokeV5.EverclearSpoke_FillIntent_AmountOutInvalid.selector, _amountOut, _intent.amountOutMin
      )
    );
    spokeProxyV5.fillIntent(_intent, _amountOut, _solverDestinations);
  }

  function testRevert_spokeSwapUpgrade_fillIntent_InvalidDestinationArray() public {
    _upgradeSpoke();

    // configuring the inputs
    uint256 _amountOut = 999e6;
    uint32[] memory _solverDestinations;
    IEverclearV2.Intent memory _intent;
    _intent.destinations = new uint32[](1);
    _intent.destinations[0] = 1;
    _intent.timestamp = uint48(block.timestamp);
    _intent.ttl = 1 days;
    _intent.amountOutMin = 1000e6;

    // calling
    vm.expectRevert(
      abi.encodeWithSelector(
        IEverclearSpokeV5.EverclearSpoke_FillIntent_AmountOutInvalid.selector, _amountOut, _intent.amountOutMin
      )
    );
    spokeProxyV5.fillIntent(_intent, _amountOut, _solverDestinations);
  }

  function testRevert_spokeSwapUpgrade_fillIntent_InvalidStatus() public {
    _upgradeSpoke();

    // configuring the inputs
    address _target = address(spokeProxyV5);
    uint256 _amountOut = 1000e6;
    uint32[] memory _solverDestinations = _getDestinations(1);
    IEverclearV2.Intent memory _intent;
    _intent.destinations = new uint32[](1);
    _intent.destinations[0] = 1;
    _intent.timestamp = uint48(block.timestamp);
    _intent.ttl = 1 days;
    _intent.amountOutMin = 999e6;
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // Setting the statue to non-zero
    stdstore.target(_target).sig('status(bytes32)').with_key(_intentId).checked_write(uint256(6));
    (, bytes memory ret) = _target.staticcall(abi.encodeWithSignature('status(bytes32)', _intentId));
    uint256 v = abi.decode(ret, (uint256));
    assertEq(v, 6);

    // calling
    vm.expectRevert(
      abi.encodeWithSelector(IEverclearSpokeV5.EverclearSpoke_FillIntent_InvalidStatus.selector, _intentId)
    );
    spokeProxyV5.fillIntent(_intent, _amountOut, _solverDestinations);
  }

  function testRevert_spokeSwapUpgrade_fillIntent_InsufficientFunds() public {
    _upgradeSpoke();

    // configuring the inputs
    uint256 _amountOut = 1000e6;
    uint32[] memory _solverDestinations = _getDestinations(1);
    IEverclearV2.Intent memory _intent;
    _intent.destinations = new uint32[](1);
    _intent.destinations[0] = 1;
    _intent.timestamp = uint48(block.timestamp);
    _intent.ttl = 1 days;
    _intent.amountOutMin = 999e6;

    // calling
    vm.expectRevert(
      abi.encodeWithSelector(IEverclearSpokeV5.EverclearSpoke_FillIntent_InsufficientFunds.selector, _amountOut, 0)
    );
    spokeProxyV5.fillIntent(_intent, _amountOut, _solverDestinations);
  }

  function testRevert_spokeSwapUpgrade_verifySignature_InvalidSignature() public {
    _upgradeSpoke();
    address _relayer = address(0x123);

    // constructing the signature and inputs
    IEverclearV2.Intent[] memory _intents = new IEverclearV2.Intent[](1);
    uint256 _ttl = block.timestamp + 1 hours;
    uint256 _nonce = 0;
    bytes memory _sig = _generateSignature(
      FEE_SIGNER_PK,
      abi.encode(
        spokeProxyV5.PROCESS_FILL_QUEUE_VIA_RELAYER_TYPEHASH(),
        block.chainid,
        _intents.length,
        _relayer,
        _ttl,
        _nonce,
        0
      )
    );

    vm.startPrank(_relayer);
    vm.expectRevert(IEverclearSpokeV5.EverclearSpoke_InvalidSignature.selector);
    spokeProxyV5.processFillQueueViaRelayer(
      uint32(block.chainid), uint32(_intents.length), _relayer, _ttl, _nonce, 0, _sig
    );
  }

  function testRevert_spokeSwapUpgrade_processIntentQueue_NotFound() public {
    _upgradeSpoke();

    // Adding an intent to the queue
    uint32[] memory destinations = _getDestinations(10);
    address _sender = address(0x123);
    uint256 _amount = 1e18;

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
    IERC20(_inputAsset).approve(address(feeAdapterV2), _amount + _feeParams.fee);
    feeAdapterV2.newIntent(destinations, address(0x123), _inputAsset, _outputAsset, _amount, 0, 0, hex'00', _feeParams);

    // configuring the invalid input
    IEverclearV2.Intent[] memory _intents = new IEverclearV2.Intent[](1);
    bytes32 _intentHash = keccak256(abi.encode(_intents[0]));

    // calling
    vm.expectRevert(
      abi.encodeWithSelector(IEverclearSpokeV5.EverclearSpoke_ProcessIntentQueue_NotFound.selector, _intentHash, 0)
    );
    spokeProxyV5.processIntentQueue(_intents);
  }

  function testRevert_spokeSwapUpgrade_processIntentQueue_ZeroAmount() public {
    _upgradeSpoke();

    // configuring intent queue with 0 elements
    IEverclearV2.Intent[] memory _intents;

    // calling process queue
    vm.expectRevert(abi.encodeWithSelector(ISpokeStorageV5.EverclearSpoke_ProcessQueue_ZeroAmount.selector));
    spokeProxyV5.processIntentQueue(_intents);
  }

  function testRevert_spokeSwapUpgrade_processIntentQueue_InvalidAmount() public {
    _upgradeSpoke();

    // configuring intent queue with 1 element
    IEverclearV2.Intent[] memory _intents = new IEverclearV2.Intent[](1);

    // calling process queue
    vm.expectRevert(abi.encodeWithSelector(ISpokeStorageV5.EverclearSpoke_ProcessQueue_InvalidAmount.selector, 1, 0, 1));
    spokeProxyV5.processIntentQueue(_intents);
  }

  function testRevert_spokeSwapUpgrade_executeCalldata_ExternalCallFailed() public {
    _upgradeSpoke();

    // configuring the inputs
    address _target = address(spokeProxyV5);
    IEverclearV2.Intent memory _intent;
    bytes32 _intentId = keccak256(abi.encode(_intent));

    stdstore.target(_target).sig('status(bytes32)').with_key(_intentId).checked_write(uint256(6));
    (, bytes memory ret) = _target.staticcall(abi.encodeWithSignature('status(bytes32)', _intentId));
    uint256 v = abi.decode(ret, (uint256));
    assertEq(v, 6);

    // calling and expecting revert
    vm.expectRevert(
      abi.encodeWithSelector(IEverclearSpokeV5.EverclearSpoke_ExecuteIntentCalldata_InvalidStatus.selector, _intentId)
    );
    spokeProxyV5.executeIntentCalldata(_intent);
  }

  function testRevert_spokeSwapUpgrade_processQueueChecks_WrongDomain() public {}

  function testRevert_spokeSwapUpgrade_processQueueChecks_NotRelayer() public {}

  function testRevert_spokeSwapUpgrade_processQueueChecks_TTLExpired() public {}

  function testRevert_spokeSwapUpgrade_receiveMessage_Unauthorized_NotGateway() public {
    _upgradeSpoke();

    // configuring the inputs
    bytes memory _message;

    // calling receiveMessage as unexpected address
    vm.expectRevert(ISpokeStorageV5.EverclearSpoke_Unauthorized.selector);
    spokeProxyV5.receiveMessage(_message);
  }

  function testRevert_spokeSwapUpgrade_receiveMessage_Unauthorized_Paused() public {
    _upgradeSpoke();

    // pausing
    vm.startPrank(spokeProxyV5.lighthouse());
    spokeProxyV5.pause();
    assertEq(spokeProxyV5.paused(), true);

    // configuring the inputs
    bytes memory _message;

    // calling receiveMessage whilst paused
    vm.expectRevert(ISpokeStorageV5.EverclearSpoke_Unauthorized.selector);
    spokeProxyV5.receiveMessage(_message);
  }

  function testRevert_spokeSwapUpgrade_receiveMessage_InvalidMessageType() public {
    _upgradeSpoke();

    // constructing invalid message
    bytes memory _data = abi.encode(address(0x123));
    bytes memory _message = abi.encode(uint8(0), _data);

    // calling receiveMessage with invalid payload
    vm.startPrank(address(spokeProxyV5.gateway()));
    vm.expectRevert(ISpokeStorageV5.EverclearSpoke_InvalidMessageType.selector);
    spokeProxyV5.receiveMessage(_message);
  }

  function testRevert_spokeSwapUpgrade_receiveMessage_InvalidVarUpdate() public {
    _upgradeSpoke();

    // constructing invalid message
    bytes memory _updateData;
    bytes memory _data = abi.encode(bytes32(0), _updateData);
    bytes memory _message = abi.encode(uint8(3), _data);

    // calling receiveMessage with invalid payload
    vm.startPrank(address(spokeProxyV5.gateway()));
    vm.expectRevert(ISpokeStorageV5.EverclearSpoke_InvalidVarUpdate.selector);
    spokeProxyV5.receiveMessage(_message);
  }

  function testRevert_spokeSwapUpgrade_receiveMessage_updateMailbox_ZeroAddress() public {}

  // ============ Helpers ============ //
  function _upgradeSpoke() internal {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP5);
    // Deploying the new FeeAdapterV2
    feeAdapterV2 = new FeeAdapterV2(
      SPOKE_PROXY_MAINNET, FEE_RECIPIENT_MAINNET, FEE_SIGNER, XERC20_MODULE_MAINNET, SPOKE_PROXY_MAINNET_OWNER
    );

    // Deploying the new SpokeMessageReceiverV2
    messageReceiverV2 = new SpokeMessageReceiverV2();

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
    bytes memory initializeCalldata =
      abi.encodeWithSelector(EverclearSpokeV5.initialize.selector, address(feeAdapterV2), address(messageReceiverV2));
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
    IERC20(_inputAsset).approve(address(feeAdapterV2), _intentParam.amount + _feeParams.fee);

    (_intentId, _returnIntent) = feeAdapterV2.newIntent(
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
    address _inputAsset = deployAndDeal(address(feeAdapterV2), _amount).toAddress();

    vm.startPrank(address(feeAdapterV2));
    IERC20(_inputAsset).approve(address(spokeProxyV5), _amount);

    // sending intent via new intent bytes path
    (bytes32 _intentId,) = spokeProxyV5.newIntent(
      destinations, address(feeAdapterV2).toBytes32(), _inputAsset, address(0x456).toBytes32(), _amount, 0, 0, hex'00'
    );
    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.ADDED));
  }

  function _fillIntentAndAssert(
    address _solver,
    IEverclearV2.Intent memory _intent,
    uint32[] memory _destinations
  ) internal returns (IEverclearV2.FillMessage memory _fillMessage) {
    // generating the intentId
    bytes32 _intentId = keccak256(abi.encode(_intent));

    // filling the intent
    vm.startPrank(address(_solver));
    IERC20(_intent.outputAsset.toAddress()).approve(address(spokeProxyV5), _intent.amountOutMin + 1);
    spokeProxyV5.deposit(_intent.outputAsset.toAddress(), _intent.amountOutMin + 1);
    _fillMessage = spokeProxyV5.fillIntent(_intent, _intent.amountOutMin + 1, _destinations);
    vm.stopPrank();

    // asserting the intent status
    assertEq(uint8(spokeProxyV5.status(_intentId)), uint8(IEverclearV2.IntentStatus.FILLED));
  }

  function _fillIntentV4(address _token, address _receiver, uint256 _amount) internal {
    // configuring spokeProxyV4
    spokeProxyV4 = EverclearSpokeV4(SPOKE_PROXY_MAINNET);

    // Configuring the input
    IEverclear.Intent memory _intent;
    _intent.outputAsset = _token.toBytes32();
    _intent.receiver = _receiver.toBytes32();
    _intent.origin = 10;
    _intent.destinations = new uint32[](1);
    _intent.destinations[0] = 1;
    _intent.amount = _amount;
    _intent.maxFee = 1000;
    _intent.timestamp = uint48(block.timestamp);
    _intent.ttl = 2 days;

    // Filling the intent queue with a new intent
    uint24 _fee = 100;
    deal(_token, address(this), _amount);
    IERC20(_token).approve(address(spokeProxyV4), _amount);
    spokeProxyV4.deposit(_token, _amount);
    spokeProxyV4.fillIntent(_intent, _fee);
  }

  function _updateLighthouse(
    address _newLighthouse
  ) internal {
    bytes32 _updateVariable = keccak256(abi.encode('LIGHTHOUSE'));
    bytes memory _updateData = abi.encode(_newLighthouse);
    bytes memory _data = abi.encode(_updateVariable, _updateData);
    bytes memory _message = abi.encode(uint8(3), _data);

    vm.startPrank(spokeProxyV5.owner());
    spokeProxyV5.receiveMessage(_message);
  }
}
