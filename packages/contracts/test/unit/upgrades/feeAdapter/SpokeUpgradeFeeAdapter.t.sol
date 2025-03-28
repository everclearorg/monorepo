// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {FeeAdapter, IFeeAdapter} from 'contracts/intent/FeeAdapter.sol';

import {ISpecifiesInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {EverclearSpokeV3, IEverclearSpokeV3} from 'contracts/intent/EverclearSpokeV3.sol';

import {FeeAdapter} from 'contracts/intent/FeeAdapter.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {ISpokeStorageV3} from 'interfaces/intent/ISpokeStorageV3.sol';

import {ISettlementModule} from 'interfaces/common/ISettlementModule.sol';
import {ISpokeGateway} from 'interfaces/intent/ISpokeGateway.sol';

import {Deploy} from 'script/utils/Deploy.sol';
import {BaseTest} from 'test/unit/intent/EverclearSpoke.t.sol';
import {Constants} from 'test/utils/Constants.sol';

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'forge-std/console.sol';
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
    spokeProxyV3 = EverclearSpokeV3(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET_V2);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeStateV3();

    // Generating the inputs for CREATE3
    uint8 version = 3;
    bytes32 _salt = keccak256(abi.encodePacked(SPOKE_PROXY_MAINNET, version));
    bytes32 _implementationSalt = keccak256(abi.encodePacked(_salt, 'implementation'));
    bytes memory _creation = type(EverclearSpokeV3).creationCode;

    // Deploying the new implementation
    bytes memory create3Calldata = abi.encodeWithSelector(ICREATE3.deploy.selector, _implementationSalt, _creation);
    (bool success, bytes memory returnData) = CREATE_3.call(create3Calldata);
    if (!success) revert Create3DeploymentFailed();
    address newEverclearSpoke = abi.decode(returnData, (address));

    // Deploying feeAdapter, impl and upgrading the contract
    bytes memory initializeCalldata = abi.encodeWithSelector(EverclearSpokeV3.initialize.selector, address(feeAdapter));
    success = false;
    bytes memory upgradeCalldata =
      abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newEverclearSpoke, initializeCalldata);

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    (success,) = address(spokeProxyV3).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function (bytes32) reverts if the caller is not the feeAdapter
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
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
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
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
    IEverclearSpokeV3.Permit2Params memory permit2Params;
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
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
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
  }

  // ============ Admin Unit ============ //
  function test_spokeUpgradeFeeAdapter_pause() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.lighthouse());
    spokeProxyV3.pause();
    assertEq(spokeProxyV3.paused(), true);

    vm.prank(spokeProxyV3.watchtower());
    spokeProxyV3.unpause();
    assertEq(spokeProxyV3.paused(), false);
  }

  function test_spokeUpgradeFeeAdapter_setStrategyForAsset() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.setStrategyForAsset(address(0x123), IEverclear.Strategy.XERC20);
    assertEq(uint8(spokeProxyV3.strategies(address(0x123))), uint8(IEverclear.Strategy.XERC20));
  }

  function test_spokeUpgradeFeeAdapter_setModuleForStrategy() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.setModuleForStrategy(IEverclear.Strategy.XERC20, ISettlementModule(address(0x123)));
    assertEq(address(spokeProxyV3.modules(IEverclear.Strategy.XERC20)), address(0x123));
  }

  function test_spokeUpgradeFeeAdapter_updateSecurityModule() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.updateSecurityModule(address(0x123));
    address gateway = address(spokeProxyV3.gateway());
    address updatedModule = address(ISpecifiesInterchainSecurityModule(gateway).interchainSecurityModule());
    assertEq(updatedModule, address(0x123));
  }

  function test_spokeUpgradeFeeAdapter_updateGateway() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.updateGateway(address(0x123));
    assertEq(address(spokeProxyV3.gateway()), address(0x123));
  }

  function test_spokeUpgradeFeeAdapter_updateMessageReceiver() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.updateMessageReceiver(address(0x123));
    assertEq(spokeProxyV3.messageReceiver(), address(0x123));
  }

  function test_spokeUpgradeFeeAdapter_updateMessageGasLimit() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.updateMessageGasLimit(1000);
    assertEq(spokeProxyV3.messageGasLimit(), 1000);
  }

  function test_spokeUpgradeFeeAdapter_updateFeeAdapter() public {
    _upgradeSpoke();

    vm.prank(spokeProxyV3.owner());
    spokeProxyV3.updateFeeAdapter(address(0x123));
    assertEq(spokeProxyV3.feeAdapter(), address(0x123));
  }

  // ============ Public ============ //
  function test_spokeUpgradeFeeAdapter_deposit() public {
    _upgradeSpoke();

    uint256 amount = 1e18;
    deal(USDC_MAINNET, address(this), amount);

    // Approving and depositing
    IERC20(USDC_MAINNET).approve(address(spokeProxyV3), amount);
    spokeProxyV3.deposit(USDC_MAINNET, amount);
    assertEq(spokeProxyV3.balances(USDC_MAINNET.toBytes32(), address(this).toBytes32()), amount);
  }

  function test_spokeUpgradeFeeAdapter_withdraw() public {
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

  function test_spokeUpgradeFeeAdapter_newIntentBytes(uint256 _amount, bytes32 _receiver) public {
    vm.assume(_receiver != 0);
    _amount = bound(_amount, 1, type(uint128).max);

    uint32[] memory destinations = _getDestinations(10);
    address _sender = address(0x123);

    // upgrading the spoke
    _upgradeSpoke();
    console.log(address(feeAdapter));

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

    (, IEverclear.Intent memory _intent) = feeAdapter.newIntent(
      destinations, _receiver, _inputAsset, _outputAsset.toBytes32(), _amount, 0, 0, hex'00', _feeParams
    );

    vm.stopPrank();
  }

  /**
   * @notice Tests the processIntentQueue function using the newIntent function with address input
   * @param _intents The intents to process
   * @param _amount The amount of intents to process
   * @param _messageFee The message fee to process the intents
   */
  function test_spokeUpgradeFeeAdapter_ProcessIntentQueue(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint32 _destination,
    uint32 _amount,
    uint256 _messageFee
  ) public validDestination(_destination) {
    _upgradeSpoke();
    address lightHouse = spokeProxyV3.lighthouse();

    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(lightHouse, _messageFee);

    _amount = uint32(bound(uint256(_amount), 1, MAX_FUZZED_ARRAY_LENGTH));
    IEverclear.Intent[] memory _intentsToProcess = new IEverclear.Intent[](_amount);

    for (uint256 _i; _i < _amount; _i++) {
      _intentsToProcess[_i] = _newIntentAndAssert(_intents[_i], AdditionalParams(_destination, _i, _amount));
    }

    bytes memory _batchIntentmessage = MessageLib.formatIntentMessageBatch(_intentsToProcess);

    uint256 _initialLighthouseBal = lightHouse.balance;
    metadata = StandardHookMetadata.formatMetadata(0, MESSAGE_GAS_LIMIT, SPOKE_GATEWAY_MAINNET, '');
    bytes32 _messageId = _mockDispatch(SPOKE_GATEWAY_MAINNET, MAILBOX_MAINNET, _batchIntentmessage, metadata);

    vm.expectCall(
      address(MAILBOX_MAINNET),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)', HUB_ID, HUB_GATEWAY_PROD, _batchIntentmessage, metadata
      )
    );

    vm.startPrank(lightHouse);
    spokeProxyV3.processIntentQueue{value: _messageFee}(_intentsToProcess);
    assertEq(lightHouse.balance, _initialLighthouseBal - _messageFee);
  }

  // ============ Helpers ============ //
  function _upgradeSpoke() internal {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP2);
    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET_V2);

    // Deploying the feeAdapter
    feeAdapter = new FeeAdapter(
      SPOKE_PROXY_MAINNET, FEE_RECIPIENT_MAINNET, FEE_SIGNER, XERC20_MODULE_MAINNET, SPOKE_PROXY_MAINNET_OWNER
    );

    // Deploying impl and upgrading the contract
    address newEverclearSpoke = address(new EverclearSpokeV3());
    bytes memory upgradeCalldata = abi.encodeWithSelector(IEverclearSpokeV3.initialize.selector, address(feeAdapter));

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    spokeProxyV3.upgradeToAndCall(newEverclearSpoke, upgradeCalldata);

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);
  }

  function _newIntentAndAssert(
    IEverclear.Intent memory _intentParam,
    AdditionalParams memory _params
  ) internal returns (IEverclear.Intent memory _returnIntent) {
    vm.assume(_intentParam.amount > 0);
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

    (, _returnIntent) = feeAdapter.newIntent(
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

    vm.stopPrank();
  }
}
