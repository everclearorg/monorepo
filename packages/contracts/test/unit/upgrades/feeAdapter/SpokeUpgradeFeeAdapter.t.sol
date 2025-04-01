// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {FeeAdapter, IFeeAdapter} from 'contracts/intent/FeeAdapter.sol';

import {ISpecifiesInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {EverclearSpokeV4, IEverclearSpokeV4} from 'contracts/intent/EverclearSpokeV4.sol';

import {FeeAdapter} from 'contracts/intent/FeeAdapter.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {ISpokeStorageV4} from 'interfaces/intent/ISpokeStorageV4.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';

import {Deploy} from 'script/utils/Deploy.sol';
import {BaseTest} from 'test/unit/intent/EverclearSpoke.t.sol';
import {Constants} from 'test/utils/Constants.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ICREATE3, UpgradeHelper} from 'test//utils/UpgradeHelper.sol';

contract SpokeUpgradeFeeAdapterTest is BaseTest, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  FeeAdapter public feeAdapter;

  // ============ Upgrade ============ //
  function test_spokeFeeAdapterUpgrade_upgrade() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP2);

    // Deploying the feeAdapter
    feeAdapter = new FeeAdapter(
      SPOKE_PROXY_MAINNET, FEE_RECIPIENT_MAINNET, FEE_SIGNER, XERC20_MODULE_MAINNET, SPOKE_PROXY_MAINNET_OWNER
    );

    // Checking implementation correct and caching the state variables
    spokeProxyV4 = EverclearSpokeV4(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET_V2);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV4();

    // Generating the inputs for CREATE3
    uint8 version = 4;
    bytes32 _salt = keccak256(abi.encodePacked(SPOKE_PROXY_MAINNET, version));
    bytes32 _implementationSalt = keccak256(abi.encodePacked(_salt, 'implementation'));
    bytes memory _creation = type(EverclearSpokeV4).creationCode;

    // Deploying the new implementation
    bytes memory create3Calldata = abi.encodeWithSelector(ICREATE3.deploy.selector, _implementationSalt, _creation);
    (bool success, bytes memory returnData) = CREATE_3.call(create3Calldata);
    if (!success) revert Create3DeploymentFailed();
    address newEverclearSpoke = abi.decode(returnData, (address));

    // Deploying feeAdapter, impl and upgrading the contract
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV4.initialize.selector, address(feeAdapter));
    success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    (success,) = address(spokeProxyV4).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;

    // Checking the new intent function (bytes32) reverts if the caller is not the feeAdapter
    vm.expectRevert(ISpokeStorageV4.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV4.newIntent(
      _intent.destinations,
      _intent.receiver,
      _intent.inputAsset.toAddress(),
      address(0).toBytes32(),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the new intent function (address w/o permit2) reverts if the caller is not the feeAdapter
    vm.expectRevert(ISpokeStorageV4.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV4.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the new intent function (address w/ permit2) reverts if the caller is not the feeAdapter
    IEverclearSpokeV4.Permit2Params memory permit2Params;
    vm.expectRevert(ISpokeStorageV4.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV4.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data,
      permit2Params
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV4.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV4.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV4.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV4.lighthouse());
    assertEq(state.watchtower, spokeProxyV4.watchtower());
    assertEq(state.messageReceiver, spokeProxyV4.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV4.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV4.callExecutor()));
    assertEq(state.paused, spokeProxyV4.paused());
    assertEq(state.nonce, spokeProxyV4.nonce());
    assertEq(state.messageGasLimit, spokeProxyV4.messageGasLimit());
    assertEq(address(feeAdapter), spokeProxyV4.feeAdapter());
  }

  // ============ Admin Unit ============ //
  function test_spokeUpgradeFeeAdapter_pause() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV4.lighthouse());
    spokeProxyV4.pause();
    assertEq(spokeProxyV4.paused(), true);

    vm.prank(spokeProxyV4.watchtower());
    spokeProxyV4.unpause();
    assertEq(spokeProxyV4.paused(), false);
  }

  function test_spokeUpgradeFeeAdapter_setStrategyForAsset() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV4.owner());
    spokeProxyV4.setStrategyForAsset(address(0x123), IEverclear.Strategy.XERC20);
    assertEq(uint8(spokeProxyV4.strategies(address(0x123))), uint8(IEverclear.Strategy.XERC20));
  }

  function test_spokeUpgradeFeeAdapter_setModuleForStrategy() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV4.owner());
    spokeProxyV4.setModuleForStrategy(IEverclear.Strategy.XERC20, ISettlementModule(address(0x123)));
    assertEq(address(spokeProxyV4.modules(IEverclear.Strategy.XERC20)), address(0x123));
  }

  function test_spokeUpgradeFeeAdapter_updateSecurityModule() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV4.owner());
    spokeProxyV4.updateSecurityModule(address(0x123));
    address gateway = address(spokeProxyV4.gateway());
    address updatedModule = address(ISpecifiesInterchainSecurityModule(gateway).interchainSecurityModule());
    assertEq(updatedModule, address(0x123));
  }

  function test_spokeUpgradeFeeAdapter_updateGateway() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV4.owner());
    spokeProxyV4.updateGateway(address(0x123));
    assertEq(address(spokeProxyV4.gateway()), address(0x123));
  }

  function test_spokeUpgradeFeeAdapter_updateMessageReceiver() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV4.owner());
    spokeProxyV4.updateMessageReceiver(address(0x123));
    assertEq(spokeProxyV4.messageReceiver(), address(0x123));
  }

  function test_spokeUpgradeFeeAdapter_updateMessageGasLimit() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV4.owner());
    spokeProxyV4.updateMessageGasLimit(1000);
    assertEq(spokeProxyV4.messageGasLimit(), 1000);
  }

  /**
   * @notice Tests the updateFeeAdapter function of the spoke proxy
   * @dev This function is newly added to the spoke proxy
   */
  function test_spokeUpgradeFeeAdapter_updateFeeAdapter() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV4.owner());
    spokeProxyV4.updateFeeAdapter(address(0x123));
    assertEq(spokeProxyV4.feeAdapter(), address(0x123));
  }

  // ============ Public ============ //
  /**
   * @notice Tests the deposit function of the spoke proxy
   * @dev This function is used to deposit tokens into the spoke proxy
   */
  function test_spokeUpgradeFeeAdapter_deposit() public {
    _upgradeSpoke();

    uint256 amount = 1e18;
    deal(USDC_MAINNET, address(this), amount);

    // Approving and depositing
    IERC20(USDC_MAINNET).approve(address(spokeProxyV4), amount);
    spokeProxyV4.deposit(USDC_MAINNET, amount);
    assertEq(spokeProxyV4.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), amount);
  }

  /**
   * @notice Tests the withdraw function of the spoke proxy
   * @dev This function is used to withdraw tokens from the spoke proxy
   */
  function test_spokeUpgradeFeeAdapter_withdraw() public {
    _upgradeSpoke();

    uint256 amount = 1e18;
    deal(USDC_MAINNET, address(this), amount);

    // Approving and depositing
    IERC20(USDC_MAINNET).approve(address(spokeProxyV4), amount);
    spokeProxyV4.deposit(USDC_MAINNET, amount);
    assertEq(spokeProxyV4.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), amount);

    // Withdrawing
    spokeProxyV4.withdraw(USDC_MAINNET, amount);
    assertEq(spokeProxyV4.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), 0);
    assertEq(IERC20(USDC_MAINNET).balanceOf(address(this)), amount);
  }

  /**
   * @notice Tests the newIntent function that has bytes32 inputs for receiver and outputAsset
   * @param _amount The amount to send
   * @param _receiver The receiver address
   */
  function test_spokeUpgradeFeeAdapter_newIntentBytes(uint256 _amount, bytes32 _receiver) public {
    vm.assume(_receiver != 0);
    _amount = bound(_amount, 1, type(uint128).max);

    uint32[] memory destinations = _getDestinations(10);
    address _sender = address(0x123);

    // upgrading the spoke
    _upgradeSpoke();

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

    assertEq(uint8(spokeProxyV4.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

    vm.stopPrank();
  }

  /**
   * @notice Tests the processIntentQueue function using the newIntent function with address input
   * @param _intents The intents to process
   * @param _messageFee The message fee to process the intents
   */
  function test_spokeUpgradeFeeAdapter_ProcessIntentQueue(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint32 _destination,
    uint256 _messageFee
  ) public validDestination(_destination) {
    _upgradeSpoke();
    address lightHouse = spokeProxyV4.lighthouse();

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
    spokeProxyV4.processIntentQueue{value: _messageFee}(_intentsToProcess);
    assertEq(lightHouse.balance, 0);
  }

  // ============ Revert ============ //
  /**
   * @notice Tests the revert of the newIntent function when caller is not feeAdapter
   */
  function testRevert_newIntent_addressInput_EverclearSpokeFeeAdapterNotAuthorized() public {
    _upgradeSpoke();

    vm.expectRevert(abi.encodeWithSelector(ISpokeStorageV4.EverclearSpoke_FeeAdapter_NotAuthorized.selector));
    spokeProxyV4.newIntent(new uint32[](0), address(0), address(0), address(0), 0, 0, 0, hex'00');
  }

  /**
   * @notice Tests the revert of the newIntent function with bytes32 inputs when caller is not feeAdapter
   */
  function testRevert_newIntent_bytes32Input_EverclearSpokeFeeAdapterNotAuthorized() public {
    _upgradeSpoke();

    vm.expectRevert(abi.encodeWithSelector(ISpokeStorageV4.EverclearSpoke_FeeAdapter_NotAuthorized.selector));
    spokeProxyV4.newIntent(new uint32[](0), bytes32(0), address(0), bytes32(0), 0, 0, 0, hex'00');
  }

  /**
   * @notice Tests the revert of the newIntent function with permit2 inputs when caller is not feeAdapter
   */
  function testRevert_newIntent_permit2Input_EverclearSpokeFeeAdapterNotAuthorized() public {
    _upgradeSpoke();

    IEverclearSpokeV4.Permit2Params memory permit2Params;
    vm.expectRevert(abi.encodeWithSelector(ISpokeStorageV4.EverclearSpoke_FeeAdapter_NotAuthorized.selector));
    spokeProxyV4.newIntent(new uint32[](0), address(0), address(0), address(0), 0, 0, 0, hex'00', permit2Params);
  }

  function testRevert_newIntent_OutputAssetZero_EverclearSpokeNewIntentInvalidIntent() public {
    _upgradeSpoke();

    // Configuring inputs
    address _sender = address(0x123);
    address _receiver = address(0);
    address _outputAsset = address(0);
    uint32[] memory destinations = _getDestinations(10);
    uint256 _amount = 1e18;

    // configuring the feeparams
    IFeeAdapter.FeeParams memory _feeParams;
    _feeParams.fee = 1e8;
    _feeParams.deadline = block.timestamp + 1 days;

    // dealing to the user
    address _inputAsset = deployAndDeal(_sender, _amount + _feeParams.fee).toAddress();

    // generating signature after asset is created
    _feeParams.sig = _generateSignature(FEE_SIGNER_PK, abi.encode(_feeParams.fee, 0, _inputAsset, _feeParams.deadline));

    vm.startPrank(_sender);
    IERC20(_inputAsset).approve(address(feeAdapter), _amount + _feeParams.fee);

    vm.expectRevert(abi.encodeWithSelector(IEverclearSpokeV4.EverclearSpoke_NewIntent_InvalidIntent.selector));
    feeAdapter.newIntent(
      destinations,
      _receiver, // receiver
      _inputAsset,
      _outputAsset, // outputAsset --> should revert as address(0) not valid when ttl != 0
      _amount,
      0,
      3600, // ttl
      hex'00',
      _feeParams
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

    vm.expectRevert(abi.encodeWithSelector(IEverclearSpokeV4.EverclearSpoke_NewIntent_InvalidIntent.selector));
    feeAdapter.newIntent(
      destinations,
      _receiver, // receiver
      _inputAsset,
      _outputAsset, // outputAsset --> should revert as it should be null when destination array length > 1
      _amount,
      0,
      0, // ttl
      hex'00',
      _feeParams
    );
  }

  // ============ Helpers ============ //
  function _upgradeSpoke() internal {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP2);
    // Checking implementation correct and caching the state variables
    spokeProxyV4 = EverclearSpokeV4(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET_V2);

    // Deploying the feeAdapter
    feeAdapter = new FeeAdapter(
      SPOKE_PROXY_MAINNET, FEE_RECIPIENT_MAINNET, FEE_SIGNER, XERC20_MODULE_MAINNET, SPOKE_PROXY_MAINNET_OWNER
    );

    // Deploying impl and upgrading the contract
    address newEverclearSpoke = address(new EverclearSpokeV4());
    bytes memory upgradeCalldata = abi.encodeWithSelector(IEverclearSpokeV4.initialize.selector, address(feeAdapter));

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    spokeProxyV4.upgradeToAndCall(newEverclearSpoke, upgradeCalldata);

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

    assertEq(uint8(spokeProxyV4.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));

    vm.stopPrank();
  }
}
