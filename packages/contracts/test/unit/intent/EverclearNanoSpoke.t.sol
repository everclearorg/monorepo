// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IGateway} from 'interfaces/common/IGateway.sol';

import {EverclearNanoSpoke, IEverclearNanoSpoke} from 'contracts/intent/EverclearNanoSpoke.sol';

import {ISpokeGateway, SpokeGateway} from 'contracts/intent/SpokeGateway.sol';
import {SpokeMessageReceiver} from 'contracts/intent/modules/SpokeMessageReceiver.sol';
import {XERC20Module} from 'contracts/intent/modules/XERC20Module.sol';

import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {StdStorage, stdStorage} from 'forge-std/Test.sol';
import {Constants} from 'test/utils/Constants.sol';
import {TestExtended} from 'test/utils/TestExtended.sol';

import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Nonces} from '@openzeppelin/contracts/utils/Nonces.sol';
import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

import {IGasTank} from 'interfaces/common/IGasTank.sol';

import {IPermit2} from 'interfaces/common/IPermit2.sol';

import {ICallExecutor} from 'interfaces/intent/ICallExecutor.sol';
import {ISpokeStorage} from 'interfaces/intent/ISpokeStorage.sol';

import {XERC20} from 'test/utils/TestXToken.sol';

import {UnsafeUpgrades} from '@upgrades/Upgrades.sol';

import {console} from 'forge-std/console.sol';
import {Deploy} from 'utils/Deploy.sol';

/**
 * @dev Removed testing logic such as contract:
 *      - Unit_DepositWithdraw contract removed (included deposit and withdraw tests)
 *      - Unit_Fill contract removed (included fill intent tests)
 *      - Unit_ExecuteCalldata contract removed (included eecute calldata tests)
 *      - Unit_ProcessQueue removed tests linked to fillIntent queue
 *      - XERC20 related tests incl: test_SettleSingle_XERC20_Transfer, test_SettleSingle_XERC20_Failed
 */
contract TestEverclearNanoSpoke is EverclearNanoSpoke {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  function getIntentQueueIndexes() external view returns (uint256 _first, uint256 _last) {
    return (intentQueue.first, intentQueue.last);
  }

  function getIntentFromQueue(
    uint256 _position
  ) external view returns (bytes32 _intentId) {
    return intentQueue.queue[_position];
  }

  function getFillQueueIndexes() external view returns (uint256 _first, uint256 _last) {
    return (fillQueue.first, fillQueue.last);
  }

  function getFillFromQueue(
    uint256 _position
  ) external view returns (IEverclear.FillMessage memory _fillMessage) {
    return fillQueue.queue[_position];
  }

  function addBalance(bytes32 _account, bytes32 _asset, uint256 _amount) public {
    balances[_asset][_account] += _amount;
  }

  function addBalance(address _account, bytes32 _asset, uint256 _amount) public {
    balances[_asset][_account.toBytes32()] += _amount;
  }

  function getBalance(
    bytes32 _asset
  ) public returns (uint256 _amount) {
    _amount = IERC20(_asset.toAddress()).balanceOf(address(this));
  }

  function getBalance(
    address _asset
  ) public returns (uint256 _amount) {
    _amount = IERC20(_asset).balanceOf(address(this));
  }

  function mockPaused() public {
    paused = true;
  }

  function mockIntentStatus(bytes32 _intentId, IEverclear.IntentStatus __status) public {
    status[_intentId] = __status;
  }

  function mockMessageGasLimit(
    uint256 _gasLimit
  ) public {
    messageGasLimit = _gasLimit;
  }
}

/**
 * @title NanoSpoke Unit Tests
 * @notice Unit tests for the NanoSpoke contract
 */
contract BaseTest is TestExtended {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  event IntentAdded(bytes32 indexed _intentId, uint256 _queueIdx, IEverclear.Intent _intent);
  event IntentFilled(
    bytes32 indexed _intentId,
    address indexed _solver,
    uint256 _totalFeeBPS,
    uint256 _queueIdx,
    IEverclear.Intent _intent
  );
  event ExternalCalldataExecuted(bytes32 indexed _intentId, bytes _returnData);

  TestEverclearNanoSpoke everclearSpoke;
  ISpokeGateway spokeGateway;

  ICallExecutor immutable CALL_EXECUTOR = ICallExecutor(makeAddr('CALL_EXECUTOR'));
  address immutable LIGHTHOUSE = makeAddr('LIGHTHOUSE');
  uint256 immutable LIGHTHOUSE_KEY;
  address immutable WATCHTOWER = makeAddr('WATCHTOWER');
  address immutable MAILBOX = makeAddr('MAILBOX');
  address immutable SECURITY_MODULE = makeAddr('SECURITY_MODULE');
  address immutable DEPLOYER = makeAddr('DEPLOYER');
  address immutable OWNER = makeAddr('OWNER');

  XERC20Module public xERC20Module;
  SpokeMessageReceiver public messageReceiver;

  XERC20 public xtoken;
  uint32 public constant EVERCLEAR_ID = 1122;
  bytes32 public constant EVERCLEAR_GATEWAY = bytes32(keccak256('hub_gateway'));

  uint256 immutable GAS_LIMIT = 1e6;
  bytes metadata;

  constructor() {
    (LIGHTHOUSE, LIGHTHOUSE_KEY) = makeAddrAndKey('LIGHTHOUSE');
  }

  function newEverclearNanoSpoke(
    ISpokeGateway _gateway,
    ICallExecutor _callExecutor,
    address _messageReceiver,
    address _lighthouse,
    address _watchtower
  ) public {
    address _impl = address(new TestEverclearNanoSpoke());

    ISpokeStorage.SpokeInitializationParams memory _init = ISpokeStorage.SpokeInitializationParams(
      _gateway, _callExecutor, _messageReceiver, _lighthouse, _watchtower, Constants.EVERCLEAR_ID, OWNER
    );

    everclearSpoke = TestEverclearNanoSpoke(
      UnsafeUpgrades.deployUUPSProxy(_impl, abi.encodeCall(EverclearNanoSpoke.initialize, (_init)))
    );
  }

  function setUp() public virtual {
    address _predictedGateway = _addressFrom(DEPLOYER, 3);
    address _predictedMessageReceiver = _addressFrom(DEPLOYER, 4);

    vm.startPrank(DEPLOYER);

    // deploy spoke
    newEverclearNanoSpoke(
      ISpokeGateway(_predictedGateway), CALL_EXECUTOR, _predictedMessageReceiver, LIGHTHOUSE, WATCHTOWER
    );

    // deploy gateway
    spokeGateway = Deploy.SpokeGatewayProxy(
      OWNER, MAILBOX, address(everclearSpoke), SECURITY_MODULE, Constants.EVERCLEAR_ID, Constants.EVERCLEAR_GATEWAY
    );
    assertEq(_predictedGateway, address(spokeGateway), 'Spoke gateway addresses mismatch');

    // deploy message receiver
    messageReceiver = new SpokeMessageReceiver();
    assertEq(_predictedMessageReceiver, address(messageReceiver), 'Message receiver addresses mismatch');

    xERC20Module = new XERC20Module(address(everclearSpoke));
    xtoken = new XERC20('TXT', 'test', DEPLOYER);
    xtoken.setLimits(address(xERC20Module), type(uint128).max, type(uint128).max);

    vm.stopPrank();

    // NOTE: Removed as do not need
    // vm.startPrank(OWNER);
    // everclearSpoke.setStrategyForAsset(address(xtoken), IEverclear.Strategy.XERC20);
    // everclearSpoke.setModuleForStrategy(IEverclear.Strategy.XERC20, xERC20Module);
    // vm.stopPrank();

    everclearSpoke.mockMessageGasLimit(GAS_LIMIT);
    metadata = StandardHookMetadata.formatMetadata(0, GAS_LIMIT, address(spokeGateway), '');
  }

  function _createValidIntent(
    IEverclear.Intent memory _intent,
    uint64 _nonce
  )
    internal
    validAddress(_intent.receiver.toAddress())
    validAddress(_intent.initiator.toAddress())
    returns (IEverclear.Intent memory _intentMessage, bytes32 _intentId)
  {
    _validIntent(_intent);
    vm.assume(_intent.amount > 0);
    vm.assume(_intent.initiator != address(everclearSpoke).toBytes32());
    vm.assume(_intent.data.length < Constants.MAX_CALLDATA_SIZE);
    for (uint256 _i; _i < _intent.destinations.length; _i++) {
      vm.assume(_intent.destinations[_i] != block.chainid && _intent.destinations[_i] != Constants.EVERCLEAR_ID);
    }
    bytes32 _inputAsset = deployAndDeal(_intent.initiator, _intent.amount);
    bytes32 _outputAsset =
      _intent.destinations.length == 1 ? makeAddr('output_asset').toBytes32() : address(0).toBytes32();

    _intentMessage = IEverclear.Intent({
      initiator: _intent.initiator.toAddress().toBytes32(),
      receiver: _intent.receiver.toAddress().toBytes32(),
      inputAsset: _inputAsset,
      outputAsset: _outputAsset,
      amount: _intent.amount,
      maxFee: _intent.maxFee % Constants.DBPS_DENOMINATOR,
      origin: uint32(block.chainid),
      destinations: _intent.destinations,
      nonce: _nonce,
      timestamp: uint48(block.timestamp),
      ttl: _intent.ttl,
      data: _intent.data
    });

    _intentId = keccak256(abi.encode(_intentMessage));
  }

  function _newIntent(IEverclear.Intent memory _intent, uint64 _nonce) internal returns (bytes32 _intentId) {
    (IEverclear.Intent memory _intentMessage, bytes32 _intentId) = _createValidIntent(_intent, _nonce);
    uint256 _previousBalance = everclearSpoke.getBalance(_intentMessage.inputAsset);

    vm.prank(_intentMessage.initiator.toAddress());
    IERC20(_intentMessage.inputAsset.toAddress()).approve(address(everclearSpoke), _intentMessage.amount);

    vm.expectCall(
      _intentMessage.inputAsset.toAddress(),
      abi.encodeWithSelector(
        IERC20.transferFrom.selector, _intentMessage.initiator, address(everclearSpoke), _intentMessage.amount
      )
    );

    (, uint256 _lastIdx) = everclearSpoke.getIntentQueueIndexes();

    vm.startPrank(_intentMessage.initiator.toAddress());
    _expectEmit(address(everclearSpoke));
    emit IntentAdded(_intentId, _lastIdx + 1, _intentMessage);

    everclearSpoke.newIntent(
      _intentMessage.destinations,
      _intentMessage.receiver.toAddress(),
      _intentMessage.inputAsset.toAddress(),
      _intentMessage.outputAsset.toAddress(),
      _intentMessage.amount,
      _intentMessage.maxFee,
      _intentMessage.ttl,
      _intentMessage.data
    );
    vm.stopPrank();

    assertEq(uint8(everclearSpoke.status(_intentId)), uint8(IEverclear.IntentStatus.ADDED));
    // Could be greater if another intent with same asset was added previously
    assertEq(everclearSpoke.getBalance(_intentMessage.inputAsset), _previousBalance + _intentMessage.amount);

    (uint256 _first, uint256 _last) = everclearSpoke.getIntentQueueIndexes();
    assertEq(_first, 1);
    assertEq(everclearSpoke.getIntentFromQueue(_last), _intentId);
  }

  function _getDestinations(
    uint32 _destination
  ) internal view returns (uint32[] memory _destinations) {
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;
    return _destinations;
  }

  modifier validDestination(
    uint32 _destination
  ) {
    vm.assume(_destination != block.chainid && _destination != Constants.EVERCLEAR_ID);
    _;
  }

  function _getDestinations(IEverclear.Intent memory _intent, uint32 _destination) internal {
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _destination;
    _intent.destinations = _destinations;
  }

  function _mockTokenDecimals(bytes32 _token, uint8 _decimals) internal {
    _mockTokenDecimals(_token.toAddress(), _decimals);
  }

  function _mockTokenDecimals(address _token, uint8 _decimals) internal {
    vm.mockCall(_token, abi.encodeWithSignature('decimals()'), abi.encode(_decimals));
  }

  function _assertIntentQueueIndexes(uint256 _first, uint256 _last) internal {
    (uint256 _firstIdx, uint256 _lastIdx) = everclearSpoke.getIntentQueueIndexes();
    assertEq(_firstIdx, _first);
    assertEq(_lastIdx, _last);
  }

  function _getBlockchainIdValidDestinations() internal view returns (uint32[] memory _destinations) {
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = uint32(block.chainid);
    return _destinations;
  }

  function _validIntent(
    IEverclear.Intent memory _intent
  ) internal {
    // Edit the intent for valid combination
    if (_intent.destinations.length != 1) {
      _intent.outputAsset = 0;
      _intent.ttl = 0;
    } else if (_intent.ttl != 0 && _intent.outputAsset == 0) {
      _intent.outputAsset = makeAddr('output_asset').toBytes32();
    }
  }
}

/**
 * @title Withdraw Unit Tests
 * @dev Withdraw enabled due to virtual balance fallback
 */
contract Unit_Withdraw is BaseTest {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  event Withdrawn(address indexed _withdrawer, address indexed _asset, uint256 _amount);

  /**
   * @notice Tests the withdraw function
   * @param _settlementMessage The settlement message
   * @param _balance The balances
   */
  function test_Withdraw(IEverclear.Settlement memory _settlementMessage, address _recipient, uint256 _balance) public {
    _settlementMessage.recipient = _recipient.toBytes32();

    // Bounding values and configuring to update virtual balance
    vm.assume(_settlementMessage.recipient.toAddress() != address(0));
    vm.assume(_settlementMessage.recipient.toAddress() != address(everclearSpoke));
    _settlementMessage.amount = bound(_settlementMessage.amount, 1, type(uint64).max);
    _balance = bound(_balance, _settlementMessage.amount, type(uint128).max);
    _settlementMessage.asset = deployAndDeal(address(everclearSpoke), _balance);
    _settlementMessage.updateVirtualBalance = true;

    IEverclear.Settlement[] memory __settlementMessages = new IEverclear.Settlement[](1);
    _mockTokenDecimals(_settlementMessage.asset, 18);
    __settlementMessages[0] = _settlementMessage;
    bytes memory _message = MessageLib.formatSettlementBatch(__settlementMessages);

    // Mocking a revert message from the token in transfer(address,uint256)
    vm.mockCall(
      _settlementMessage.asset.toAddress(),
      abi.encodeWithSelector(
        bytes4(keccak256('transfer(address,uint256)')),
        _settlementMessage.recipient.toAddress(),
        _settlementMessage.amount
      ),
      abi.encode(false)
    );
    // Sending the message to the spoke
    vm.prank(address(everclearSpoke.gateway()));
    everclearSpoke.receiveMessage(_message);

    assertEq(
      IERC20(_settlementMessage.asset.toAddress()).balanceOf(_settlementMessage.recipient.toAddress()),
      0,
      'User token balance mismatch'
    );
    assertEq(
      IERC20(_settlementMessage.asset.toAddress()).balanceOf(address(everclearSpoke)),
      _balance,
      'Balance in EverclearSpoke mismatch'
    );
    assertEq(
      everclearSpoke.balances(_settlementMessage.asset, _settlementMessage.recipient),
      _settlementMessage.amount,
      'User virtual balance incorrect'
    );
    assertTrue(_settlementMessage.amount <= _balance, 'Balance in EverclearSpoke less than settlement');
    assertEq(uint8(everclearSpoke.status(_settlementMessage.intentId)), uint8(IEverclear.IntentStatus.SETTLED));

    // Mocking a successful transfer
    vm.mockCall(
      _settlementMessage.asset.toAddress(),
      abi.encodeWithSelector(
        bytes4(keccak256('transfer(address,uint256)')),
        _settlementMessage.recipient.toAddress(),
        _settlementMessage.amount
      ),
      abi.encode(true)
    );

    // Executing the withdrawal
    vm.startPrank(_settlementMessage.recipient.toAddress());
    _expectEmit(address(everclearSpoke));
    emit Withdrawn(
      _settlementMessage.recipient.toAddress(), _settlementMessage.asset.toAddress(), _settlementMessage.amount
    );
    everclearSpoke.withdraw(_settlementMessage.asset.toAddress(), _settlementMessage.amount);
    vm.stopPrank();

    assertEq(everclearSpoke.balances(_settlementMessage.asset, _settlementMessage.recipient), 0);
  }
}

/**
 * @title Intent Unit Tests
 */
contract Unit_Intent is BaseTest {
  using stdStorage for StdStorage;
  using TypeCasts for bytes32;

  /**
   * @notice Tests the newIntent function
   * @param _intent The intent to add
   */
  function test_NewIntent(
    IEverclear.Intent memory _intent
  ) public {
    _validIntent(_intent);
    _intent = _limitDestinationLengthTo10(_intent);

    _newIntent(_intent, 1);
  }

  /**
   * @notice Tests the that the newIntent function reverts when the intent amount is zero
   */
  function test_Revert_ZeroAmount(
    IEverclear.Intent memory _intent
  ) public {
    _validIntent(_intent);
    vm.expectRevert(IEverclearNanoSpoke.EverclearSpoke_NewIntent_ZeroAmount.selector);
    uint32[] memory _destinations = new uint32[](2);
    _destinations[0] = 32;
    _destinations[1] = 37;
    bytes memory _data = abi.encode('');
    address _inputAsset = makeAddr('input_asset');
    vm.mockCall(_inputAsset, abi.encodeWithSignature('decimals()'), abi.encode(18));
    everclearSpoke.newIntent({
      _destinations: _destinations,
      _receiver: makeAddr('recipient'),
      _inputAsset: _inputAsset,
      _outputAsset: address(0),
      _amount: 0,
      _maxFee: Constants.DBPS_DENOMINATOR,
      _ttl: 0,
      _data: _data
    });
  }

  /**
   * @notice Tests the newIntent function fails when using a single destination and a null output asset
   * @param _intent The intent to add
   */
  function test_Revert_NewIntent_SingleDestination_NullOutputAsset(
    IEverclear.Intent calldata _intent
  ) public {
    vm.assume(_intent.amount > 0);
    vm.assume(_intent.ttl != 0);
    vm.assume(_intent.destinations.length > 1);
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = _intent.destinations[0];

    vm.expectRevert(IEverclearNanoSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);

    everclearSpoke.newIntent(
      _destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );
  }

  /**
   * @notice Tests the newIntent function fails when using multiple destinations and a non null output asset
   * @param _intent The intent to add
   */
  function test_Revert_NewIntent_MultipleDestinations_NonNullOutputAsset(
    IEverclear.Intent calldata _intent
  ) public {
    vm.assume(_intent.amount > 0);
    vm.assume(_intent.ttl != 0);
    vm.assume(_intent.destinations.length > 1);

    vm.expectRevert(IEverclearNanoSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector);

    everclearSpoke.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      makeAddr('output_asset'),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );
  }

  /**
   * @notice Tests the newIntent function fails when the max fee is greater than the DBPS denominator
   * @param _intent The intent to add
   */
  function test_Revert_NewIntent_MaxFeeExceeded(
    IEverclear.Intent memory _intent
  ) public {
    vm.assume(_intent.destinations.length > 1);
    vm.assume(_intent.amount > 0);
    vm.assume(_intent.maxFee > Constants.DBPS_DENOMINATOR);
    _intent = _limitDestinationLengthTo10(_intent);

    vm.expectRevert(
      abi.encodeWithSelector(
        IEverclearNanoSpoke.EverclearSpoke_NewIntent_MaxFeeExceeded.selector, _intent.maxFee, Constants.DBPS_DENOMINATOR
      )
    );

    everclearSpoke.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      0,
      _intent.data
    );
  }

  /**
   * @notice Tests the newIntent function fails when the calldata exceeds the limit
   * @param _intent The intent to add
   */
  function test_Revert_NewIntent_CalldataExceedsLimit(
    IEverclear.Intent memory _intent
  ) public {
    vm.assume(_intent.amount > 0);
    vm.assume(_intent.destinations.length > 1);
    vm.assume(_intent.maxFee < Constants.DBPS_DENOMINATOR);
    vm.assume(_intent.data.length > 0);
    _intent = _limitDestinationLengthTo10(_intent);

    // Create a fixed array of 50,000 zero bytes
    bytes memory fixedData = new bytes(50_000);

    // Concatenate the fixed data with the fuzzed data
    bytes memory largeData = bytes.concat(fixedData, _intent.data);

    emit log_named_uint('data length', largeData.length);

    vm.expectRevert(abi.encodeWithSelector(IEverclearNanoSpoke.EverclearSpoke_NewIntent_CalldataExceedsLimit.selector));

    everclearSpoke.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      0,
      largeData
    );
  }

  /**
   * @notice Tests the newIntent function fails when the destination array is > 10
   * @param _intent The intent to add
   */
  function test_Revert_NewIntent_InvalidIntent(
    IEverclear.Intent calldata _intent
  ) public {
    vm.assume(_intent.amount > 0);
    vm.assume(_intent.destinations.length > 10);
    vm.assume(_intent.maxFee > Constants.DBPS_DENOMINATOR);
    vm.expectRevert(abi.encodeWithSelector(IEverclearNanoSpoke.EverclearSpoke_NewIntent_InvalidIntent.selector));

    everclearSpoke.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      0,
      _intent.data
    );
  }
}

/**
 * @title ProcessQueue Unit Tests
 */
contract Unit_ProcessQueue is BaseTest {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  event IntentQueueProcessed(bytes32 indexed _messageId, uint256 _firstIdx, uint256 _lastIdx, uint256 _quote);
  event IntentExecuted(
    bytes32 indexed _intentId, address indexed _executor, address _asset, uint256 _amount, uint24 _fee
  );

  struct ProcessIntentQueueParams {
    uint32 amount;
    address relayer;
    uint256 messageFee;
    uint256 bufferBPS;
  }

  struct AdditionalParams {
    uint32 destination;
    uint256 i;
    uint32 amount;
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
    IERC20(_inputAsset).approve(address(everclearSpoke), _intentParam.amount);

    (bytes32 _intentId, IEverclear.Intent memory _intent) = everclearSpoke.newIntent(
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

    _assertIntentQueueIndexes(1, _params.i + 1);
    bytes32 _queueIntentId = everclearSpoke.getIntentFromQueue(_params.i + 1);
    assertEq(_queueIntentId, _intentId);
  }

  /**
   * @notice Tests the processIntentQueue function
   * @param _intents The intents to process
   * @param _amount The amount of intents to process
   * @param _messageFee The message fee to process the intents
   */
  function test_ProcessIntentQueue(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint32 _destination,
    uint32 _amount,
    uint256 _messageFee
  ) public validDestination(_destination) {
    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(LIGHTHOUSE, _messageFee);

    _amount = uint32(bound(uint256(_amount), 1, MAX_FUZZED_ARRAY_LENGTH));
    IEverclear.Intent[] memory _intentsToProcess = new IEverclear.Intent[](_amount);

    for (uint256 _i; _i < MAX_FUZZED_ARRAY_LENGTH; _i++) {
      _newIntentAndAssert(_intents[_i], _intentsToProcess, AdditionalParams(_destination, _i, _amount));
    }

    bytes memory _batchIntentmessage = MessageLib.formatIntentMessageBatch(_intentsToProcess);

    uint256 _initialLighthouseBal = LIGHTHOUSE.balance;
    bytes32 _messageId = _mockDispatch(address(spokeGateway), MAILBOX, _batchIntentmessage, metadata);

    vm.expectCall(
      address(MAILBOX),
      abi.encodeWithSignature(
        'dispatch(uint32,bytes32,bytes,bytes)',
        Constants.EVERCLEAR_ID,
        Constants.EVERCLEAR_GATEWAY,
        _batchIntentmessage,
        metadata
      )
    );

    vm.startPrank(LIGHTHOUSE);

    (uint256 _first,) = everclearSpoke.getIntentQueueIndexes();

    _expectEmit(address(everclearSpoke));
    emit IntentQueueProcessed(_messageId, _first, _first + _amount, 0);
    everclearSpoke.processIntentQueue{value: _messageFee}(_intentsToProcess);

    assertEq(LIGHTHOUSE.balance, _initialLighthouseBal - _messageFee);
  }

  /**
   * @notice Tests the processIntentQueue function reverts when the intent is not found
   * @param _intents The intents to process
   * @param _destination The destination of the intents
   * @param _amount The amount of intents to process
   * @param _messageFee The message fee to process the intents
   */
  function test_Revert_ProcessIntentQueue_IntentNotFound(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint32 _destination,
    uint32 _amount,
    uint256 _messageFee
  ) public validDestination(_destination) {
    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(LIGHTHOUSE, _messageFee);

    _amount = uint32(bound(uint256(_amount), 1, MAX_FUZZED_ARRAY_LENGTH));
    IEverclear.Intent[] memory _intentsToProcess = new IEverclear.Intent[](_amount);

    for (uint256 _i; _i < MAX_FUZZED_ARRAY_LENGTH; _i++) {
      _newIntentAndAssert(_intents[_i], _intentsToProcess, AdditionalParams(_destination, _i, _amount));
    }

    bytes memory _batchIntentmessage = MessageLib.formatIntentMessageBatch(_intentsToProcess);
    _intentsToProcess[0] = IEverclear.Intent({
      initiator: makeAddr('fakeInitiator').toBytes32(),
      receiver: makeAddr('fakeReceiver').toBytes32(),
      inputAsset: _intentsToProcess[0].inputAsset,
      outputAsset: _intentsToProcess[0].outputAsset,
      amount: _intentsToProcess[0].amount,
      maxFee: _intentsToProcess[0].maxFee,
      origin: _intentsToProcess[0].origin,
      destinations: _intentsToProcess[0].destinations,
      nonce: _intentsToProcess[0].nonce,
      timestamp: _intentsToProcess[0].timestamp,
      ttl: _intentsToProcess[0].ttl,
      data: _intentsToProcess[0].data
    });
    bytes32 _intentHash = keccak256(abi.encode(_intentsToProcess[0]));

    bytes32 _messageId = _mockDispatch(address(spokeGateway), MAILBOX, _batchIntentmessage, metadata);

    vm.expectRevert(
      abi.encodeWithSelector(IEverclearNanoSpoke.EverclearSpoke_ProcessIntentQueue_NotFound.selector, _intentHash, 0)
    );

    vm.startPrank(LIGHTHOUSE);
    everclearSpoke.processIntentQueue{value: _messageFee}(_intentsToProcess);
  }

  /**
   * @notice Tests the processIntentQueue function with invalid amount
   * @param _intents The intents to process
   * @param _amount The amount of intents to process
   * @param _messageFee The message fee to process the intents
   */
  function test_Revert_ProcessIntentQueueInvalidAmount(
    IEverclear.Intent[MAX_FUZZED_ARRAY_LENGTH] memory _intents,
    uint256 _length,
    uint256 _amount,
    uint256 _messageFee
  ) public {
    _length = bound(_length, 1, MAX_FUZZED_ARRAY_LENGTH);
    _amount = bound(_amount, 1, MAX_FUZZED_ARRAY_LENGTH);
    vm.assume(_amount > _length);

    _messageFee = bound(_messageFee, 1, 10 ether);
    deal(LIGHTHOUSE, _messageFee);

    IEverclear.Intent[] memory _intentsToProcess = new IEverclear.Intent[](_amount);
    for (uint256 _i; _i < _length; _i++) {
      vm.assume(_intents[_i].amount > 0);
      vm.assume(_intents[_i].receiver.toAddress() != address(0));
      vm.assume(_intents[_i].destinations.length > 0);
      vm.assume(_intents[_i].destinations[0] != block.chainid && _intents[_i].destinations[0] != Constants.EVERCLEAR_ID);
      _getDestinations(_intents[_i], _intents[_i].destinations[0]);
      address _inputAsset = deployAndDeal(_intents[_i].receiver, _intents[_i].amount).toAddress();

      vm.startPrank(_intents[_i].receiver.toAddress());
      IERC20(_inputAsset).approve(address(everclearSpoke), _intents[_i].amount);

      (, _intentsToProcess[_i]) = everclearSpoke.newIntent(
        _intents[_i].destinations,
        _intents[_i].receiver.toAddress(),
        _inputAsset,
        makeAddr('output_asset'),
        _intents[_i].amount,
        _intents[_i].maxFee % Constants.DBPS_DENOMINATOR,
        _intents[_i].ttl,
        _intents[_i].data
      );

      vm.stopPrank();

      _assertIntentQueueIndexes(1, _i + 1);
    }

    _mockDispatch(address(spokeGateway), MAILBOX, MessageLib.formatIntentMessageBatch(_intentsToProcess), metadata);

    vm.startPrank(LIGHTHOUSE);

    vm.expectRevert(
      abi.encodeWithSelector(ISpokeStorage.EverclearSpoke_ProcessQueue_InvalidAmount.selector, 1, _length, _amount)
    );
    everclearSpoke.processIntentQueue{value: _messageFee}(_intentsToProcess);
  }
}

contract Unit_Settlement is BaseTest {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  event Settled(bytes32 indexed _intentId, address _account, address _asset, uint256 _amount);

  mapping(bytes32 => mapping(bytes32 => uint256)) public balances;

  event Transfer(address indexed from, address indexed to, uint256 value);
  event AssetTransferFailed(address indexed _asset, address indexed _recipient, uint256 _amount);
  event AssetMintFailed(
    address indexed _asset, address indexed _recipient, uint256 _amount, IEverclear.Strategy _strategy
  );

  /**
   * @notice Tests the settleSingle function
   * @param _settlementMessage The settlement message to process
   * @param _balance The balance to settle
   */
  function test_SettleSingle_Default_Transfer(IEverclear.Settlement memory _settlementMessage, uint256 _balance) public {
    // set up a valid settlement for the test case
    vm.assume(_settlementMessage.recipient.toAddress() != address(0));
    vm.assume(_settlementMessage.recipient.toAddress() != address(everclearSpoke));
    _settlementMessage.amount = bound(_settlementMessage.amount, 1, type(uint64).max);
    _balance = bound(_balance, _settlementMessage.amount, type(uint128).max);
    _settlementMessage.asset = deployAndDeal(address(everclearSpoke), _balance);
    _settlementMessage.updateVirtualBalance = false;

    IEverclear.Settlement[] memory __settlementMessages = new IEverclear.Settlement[](1);
    _mockTokenDecimals(_settlementMessage.asset, 18);
    __settlementMessages[0] = _settlementMessage;

    bytes memory _message = MessageLib.formatSettlementBatch(__settlementMessages);

    _expectEmit(address(everclearSpoke));
    emit Settled(
      _settlementMessage.intentId,
      _settlementMessage.recipient.toAddress(),
      _settlementMessage.asset.toAddress(),
      _settlementMessage.amount
    );

    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);

    assertEq(
      everclearSpoke.getBalance(_settlementMessage.asset),
      _balance - _settlementMessage.amount,
      'Contract balance mismatch'
    );
    assertEq(
      IERC20(_settlementMessage.asset.toAddress()).balanceOf(_settlementMessage.recipient.toAddress()),
      _settlementMessage.amount,
      'User token balance mismatch'
    );
    assertEq(uint8(everclearSpoke.status(_settlementMessage.intentId)), uint8(IEverclear.IntentStatus.SETTLED));
  }

  /**
   * @notice Tests the settleSingle function with a failed transfer revert
   * @param _settlementMessage The settlement message to process
   * @param _balance The balance to settle
   */
  function test_SettleSingle_Default_Transfer_FailedWithRevert(
    IEverclear.Settlement memory _settlementMessage,
    uint256 _balance
  ) public {
    // set up a valid settlement for the test case
    vm.assume(_settlementMessage.recipient.toAddress() != address(0));
    vm.assume(_settlementMessage.recipient.toAddress() != address(everclearSpoke));
    _settlementMessage.amount = bound(_settlementMessage.amount, 1, type(uint64).max);
    _balance = bound(_balance, _settlementMessage.amount, type(uint128).max);
    _settlementMessage.asset = deployAndDeal(address(everclearSpoke), _balance);
    _settlementMessage.updateVirtualBalance = false;

    IEverclear.Settlement[] memory __settlementMessages = new IEverclear.Settlement[](1);
    _mockTokenDecimals(_settlementMessage.asset, 18);
    __settlementMessages[0] = _settlementMessage;

    bytes memory _message = MessageLib.formatSettlementBatch(__settlementMessages);

    vm.mockCallRevert(
      _settlementMessage.asset.toAddress(),
      abi.encodeWithSelector(
        IERC20.transfer.selector, _settlementMessage.recipient.toAddress(), _settlementMessage.amount
      ),
      'blacklisted address'
    );

    _expectEmit(address(everclearSpoke));
    emit AssetTransferFailed(
      _settlementMessage.asset.toAddress(), _settlementMessage.recipient.toAddress(), _settlementMessage.amount
    );

    _expectEmit(address(everclearSpoke));
    emit Settled(
      _settlementMessage.intentId,
      _settlementMessage.recipient.toAddress(),
      _settlementMessage.asset.toAddress(),
      _settlementMessage.amount
    );

    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);

    assertEq(everclearSpoke.getBalance(_settlementMessage.asset), _balance, 'Contract balance mismatch');
    assertEq(
      IERC20(_settlementMessage.asset.toAddress()).balanceOf(_settlementMessage.recipient.toAddress()),
      0,
      'User token balance mismatch'
    );
    assertEq(
      everclearSpoke.balances(_settlementMessage.asset, _settlementMessage.recipient),
      _settlementMessage.amount,
      'User balance mismatch'
    );
    assertEq(uint8(everclearSpoke.status(_settlementMessage.intentId)), uint8(IEverclear.IntentStatus.SETTLED));
  }

  /**
   * @notice Tests the settleSingle function with a failed transfer without revert
   * @param _settlementMessage The settlement message to process
   * @param _balance The balance to settle
   */
  function test_SettleSingle_Default_Transfer_FailedWithFalse(
    IEverclear.Settlement memory _settlementMessage,
    uint256 _balance
  ) public {
    // set up a valid settlement for the test case
    vm.assume(_settlementMessage.recipient.toAddress() != address(0));
    vm.assume(_settlementMessage.recipient.toAddress() != address(everclearSpoke));
    _settlementMessage.amount = bound(_settlementMessage.amount, 1, type(uint64).max);
    _balance = bound(_balance, _settlementMessage.amount, type(uint128).max);
    _settlementMessage.asset = deployAndDeal(address(everclearSpoke), _balance);
    _settlementMessage.updateVirtualBalance = false;

    IEverclear.Settlement[] memory __settlementMessages = new IEverclear.Settlement[](1);
    _mockTokenDecimals(_settlementMessage.asset, 18);
    __settlementMessages[0] = _settlementMessage;

    bytes memory _message = MessageLib.formatSettlementBatch(__settlementMessages);

    vm.mockCall(
      _settlementMessage.asset.toAddress(),
      abi.encodeWithSelector(
        IERC20.transfer.selector, _settlementMessage.recipient.toAddress(), _settlementMessage.amount
      ),
      abi.encode(false)
    );

    _expectEmit(address(everclearSpoke));
    emit AssetTransferFailed(
      _settlementMessage.asset.toAddress(), _settlementMessage.recipient.toAddress(), _settlementMessage.amount
    );

    _expectEmit(address(everclearSpoke));
    emit Settled(
      _settlementMessage.intentId,
      _settlementMessage.recipient.toAddress(),
      _settlementMessage.asset.toAddress(),
      _settlementMessage.amount
    );

    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);

    assertEq(everclearSpoke.getBalance(_settlementMessage.asset), _balance, 'Contract balance mismatch');
    assertEq(
      IERC20(_settlementMessage.asset.toAddress()).balanceOf(_settlementMessage.recipient.toAddress()),
      0,
      'User token balance mismatch'
    );
    assertEq(
      everclearSpoke.balances(_settlementMessage.asset, _settlementMessage.recipient),
      _settlementMessage.amount,
      'User balance mismatch'
    );
    assertEq(uint8(everclearSpoke.status(_settlementMessage.intentId)), uint8(IEverclear.IntentStatus.SETTLED));
  }

  // NOTE: Test commented as virtual balance only updates on failed transfers
  // /**
  //  * @notice Tests the settleSingle function with a virtual balance update
  //  * @param _settlementMessage The settlement message to process
  //  * @param _balance The balance to settle
  //  */
  // function test_SettleSingle_Default_UpdateVirtualBalance(
  //   IEverclear.Settlement memory _settlementMessage,
  //   uint256 _balance
  // ) public {
  //   // set up a valid settlement for the test case
  //   vm.assume(_settlementMessage.recipient.toAddress() != address(0));
  //   vm.assume(_settlementMessage.recipient.toAddress() != address(everclearSpoke));
  //   _settlementMessage.amount = bound(_settlementMessage.amount, 1, type(uint64).max);
  //   _balance = bound(_balance, _settlementMessage.amount, type(uint128).max);
  //   _settlementMessage.asset = deployAndDeal(address(everclearSpoke), _balance);
  //   _settlementMessage.updateVirtualBalance = true;

  //   IEverclear.Settlement[] memory __settlementMessages = new IEverclear.Settlement[](1);
  //   _mockTokenDecimals(_settlementMessage.asset, 18);
  //   __settlementMessages[0] = _settlementMessage;

  //   bytes memory _message = MessageLib.formatSettlementBatch(__settlementMessages);

  //   _expectEmit(address(everclearSpoke));
  //   emit Settled(
  //     _settlementMessage.intentId,
  //     _settlementMessage.recipient.toAddress(),
  //     _settlementMessage.asset.toAddress(),
  //     _settlementMessage.amount
  //   );

  //   vm.prank(address(spokeGateway));
  //   everclearSpoke.receiveMessage(_message);

  //   assertEq(everclearSpoke.getBalance(_settlementMessage.asset), _balance, 'Contract balance must stay the same');
  //   assertEq(
  //     everclearSpoke.balances(_settlementMessage.asset, _settlementMessage.recipient),
  //     _settlementMessage.amount,
  //     'User balance mismatch'
  //   );
  //   assertEq(uint8(everclearSpoke.status(_settlementMessage.intentId)), uint8(IEverclear.IntentStatus.SETTLED));
  // }
}

contract Unit_Update_Gateway is BaseTest {
  event GatewayUpdated(address _oldGateway, address _newGateway);

  /**
   * @notice Tests the updateGateway function
   * @param _newGateway The new gateway address
   */
  function test_UpdateGateway(
    address _newGateway
  ) public {
    address _oldGateway = address(spokeGateway);
    _expectEmit(address(everclearSpoke));
    emit GatewayUpdated(_oldGateway, _newGateway);

    vm.prank(OWNER);
    everclearSpoke.updateGateway(_newGateway);
    assertEq(address(everclearSpoke.gateway()), _newGateway, 'Gateway not updated');
  }

  /**
   * @notice Tests the updateGateway function with non owner caller
   * @param _newGateway The new gateway address
   */
  function test_Revert_UpdateGateway_OnlyOwner(address _newGateway, address _notOwner) public {
    vm.assume(_notOwner != OWNER);

    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    everclearSpoke.updateGateway(_newGateway);
  }
}

contract Unit_Pause_Spoke is BaseTest {
  struct IntentParams {
    uint32 destination;
    address to;
    address inputAsset;
    address outputAsset;
    uint256 amount;
    uint24 maxFee;
    uint48 ttl;
    bytes data;
  }

  /**
   * @notice Tests newIntent function reverts when paused
   */
  function test_Revert_NewIntent_WhenPaused(
    address _caller,
    IntentParams calldata _intentParams
  ) public validDestination(_intentParams.destination) {
    everclearSpoke.mockPaused();

    vm.expectRevert(ISpokeStorage.EverclearSpoke_Paused.selector);

    vm.prank(_caller);
    everclearSpoke.newIntent(
      _getDestinations(_intentParams.destination),
      _intentParams.to,
      _intentParams.inputAsset,
      _intentParams.outputAsset,
      _intentParams.amount,
      _intentParams.maxFee,
      _intentParams.ttl,
      _intentParams.data
    );
  }

  /**
   * @notice Tests processIntentQueue function reverts when paused
   */
  function test_Revert_ProcessIntentQueue_WhenPaused(
    address _caller,
    IEverclear.Intent[] memory _intents,
    uint256 _messageFee
  ) public {
    everclearSpoke.mockPaused();
    deal(_caller, _messageFee);

    vm.expectRevert(ISpokeStorage.EverclearSpoke_Paused.selector);

    vm.prank(_caller);
    everclearSpoke.processIntentQueue{value: _messageFee}(_intents);
  }
}

contract Unit_UpdateMessageReceiver is BaseTest {
  event MessageReceiverUpdated(address _oldMessageReceiver, address _newMessageReceiver);

  /**
   * @notice Tests the updateMessageReceiver function
   * @param _newMessageReceiver The new message receiver address
   */
  function test_UpdateMessageReceiver(
    address _newMessageReceiver
  ) public {
    address _oldMessageReceiver = address(messageReceiver);

    _expectEmit(address(everclearSpoke));
    emit MessageReceiverUpdated(_oldMessageReceiver, _newMessageReceiver);

    vm.prank(OWNER);
    everclearSpoke.updateMessageReceiver(_newMessageReceiver);
    assertEq(address(everclearSpoke.messageReceiver()), _newMessageReceiver, 'Message receiver not updated');
  }

  /**
   * @notice Tests the updateMessageReceiver function with non owner caller
   * @param _newMessageReceiver The new message receiver address
   */
  function test_Revert_UpdateMessageReceiver_OnlyOwner(address _newMessageReceiver, address _notOwner) public {
    vm.assume(_notOwner != OWNER);

    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    everclearSpoke.updateMessageReceiver(_newMessageReceiver);
  }
}

/**
 * @title ReceiveMessage Unit Tests
 * @notice Unit tests for the EverclearSpoke receiveMessage function
 */
contract Unit_ReceiveMessage is BaseTest {
  using TypeCasts for address;

  event GatewayUpdated(address _oldGateway, address _newGateway);
  event LighthouseUpdated(address _oldLightHouse, address _newLightHouse);

  /**
   * @notice Tests that an updateGateway message is handled correctly
   * @param _gateway The new gateway address
   */
  function test_UpdateGateway(
    address _gateway
  ) public validAddress(_gateway) {
    // We need to format the message that will be received by the baseSpoke
    bytes memory _message = MessageLib.formatAddressUpdateMessage(Constants.GATEWAY_HASH, _gateway.toBytes32());
    // Expect an event emmission when the gateway is updated
    _expectEmit(address(everclearSpoke));
    emit GatewayUpdated(address(spokeGateway), _gateway);

    // ReceiveMessage can only be called by the gateway
    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);

    // Assert that the gateway was been updated correctly
    assertEq(address(everclearSpoke.gateway()), _gateway);
  }

  /**
   * @notice Tests that an updateGateway message with a zero address reverts
   */
  function test_Revert_UpdateGatewayZeroAddress() public {
    bytes memory _message = MessageLib.formatAddressUpdateMessage(Constants.GATEWAY_HASH, address(0).toBytes32());

    vm.expectRevert(abi.encodeWithSelector(ISpokeStorage.EverclearSpoke_ZeroAddress.selector));
    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);
  }

  /**
   * @notice Tests that an updateMailbox message is handled correctly
   * @dev We won't check that the mailbox is updated given this update
   *           happens within the gateway contract
   * @param _mailbox The new mailbox address
   */
  function test_UpdateMailbox(
    address _mailbox
  ) public validAddress(_mailbox) {
    bytes memory _message = MessageLib.formatAddressUpdateMessage(Constants.MAILBOX_HASH, _mailbox.toBytes32());
    // We need to mock the call to the gateway contract
    // (given the gateway hasnt been deployed and is just an empty address)
    vm.mockCall(address(spokeGateway), abi.encodeWithSignature('updateMailbox(address)', _mailbox), abi.encode(true));

    // We expect the call to the gateway address with the updateMailbox calldata
    vm.expectCall(address(spokeGateway), abi.encodeWithSignature('updateMailbox(address)', _mailbox));

    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);
  }

  /**
   * @notice Tests that an updateSecurityModule message is handled correctly
   * @param _securityModule The new security module address
   */
  function test_UpdateSecurityModule(
    address _securityModule
  ) public validAddress(_securityModule) {
    vm.mockCall(
      address(spokeGateway), abi.encodeWithSignature('updateSecurityModule(address)', _securityModule), abi.encode(true)
    );

    vm.expectCall(address(spokeGateway), abi.encodeWithSignature('updateSecurityModule(address)', _securityModule));
    vm.prank(OWNER);
    everclearSpoke.updateSecurityModule(_securityModule);
  }

  /**
   * @notice Tests that an updateLighthouse message is handled correctly
   * @param _lighthouse The new lighthouse address
   */
  function test_UpdateLighthouse(
    address _lighthouse
  ) public validAddress(_lighthouse) {
    bytes memory _message = MessageLib.formatAddressUpdateMessage(Constants.LIGHTHOUSE_HASH, _lighthouse.toBytes32());

    // Expect an event emmission when the lighthouse is updated
    _expectEmit(address(everclearSpoke));
    emit LighthouseUpdated(address(LIGHTHOUSE), _lighthouse);

    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);

    assertEq(everclearSpoke.lighthouse(), _lighthouse);
  }

  /**
   * @notice Tests that an updateLighthouse message with a zero address reverts
   */
  function test_Revert_UpdateLighthouseZeroAddress() public {
    bytes memory _message = MessageLib.formatAddressUpdateMessage(Constants.LIGHTHOUSE_HASH, address(0).toBytes32());

    vm.expectRevert(abi.encodeWithSelector(ISpokeStorage.EverclearSpoke_ZeroAddress.selector));
    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);
  }

  /**
   * @notice Tests that an updateWatchtower message is handled correctly
   * @param _watchtower The new watchtower address
   */
  function test_UpdateWatchtower(
    address _watchtower
  ) public validAddress(_watchtower) {
    bytes memory _message = MessageLib.formatAddressUpdateMessage(Constants.WATCHTOWER_HASH, _watchtower.toBytes32());

    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);

    assertEq(everclearSpoke.watchtower(), _watchtower);
  }

  /**
   * @notice Tests that an updateWatchtower message with a zero address reverts
   */
  function test_Revert_UpdateWatchtowerZeroAddress() public {
    bytes memory _message = MessageLib.formatAddressUpdateMessage(Constants.WATCHTOWER_HASH, address(0).toBytes32());

    vm.expectRevert(abi.encodeWithSelector(ISpokeStorage.EverclearSpoke_ZeroAddress.selector));
    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);
  }

  /**
   * @notice Tests that a call to receiveMessage from any address that is not the gateway reverts
   */
  function test_Revert_ReceiveMessageNonGateway(address _caller, bytes memory _message) public validAddress(_caller) {
    vm.assume(_caller != address(spokeGateway) && _caller != everclearSpoke.owner());

    vm.expectRevert(abi.encodeWithSelector(ISpokeStorage.EverclearSpoke_Unauthorized.selector));
    vm.prank(_caller);
    everclearSpoke.receiveMessage(_message);
  }

  /**
   * @notice Tests that a call to receiveMessage with an invalid message reverts
   */
  function test_Revert_ReceiveMessage_InvalidMessage(
    bytes memory _message
  ) public {
    vm.expectRevert();

    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);
  }

  /**
   * @notice Tests that a call to receiveMessage with an invalid var update reverts
   */
  function test_Revert_ReceiveMessage_InvalidVarUpdate(bytes32 _hash, address _address) public {
    bytes memory _message = MessageLib.formatAddressUpdateMessage(_hash, _address.toBytes32());

    vm.expectRevert(abi.encodeWithSelector(ISpokeStorage.EverclearSpoke_InvalidVarUpdate.selector));
    vm.prank(address(spokeGateway));
    everclearSpoke.receiveMessage(_message);
  }
}

contract Unit_PauseUnpause is BaseTest {
  /**
   * @notice Tests the pause function as the lighthouse
   */
  function test_Pause_AsLighthouse() public {
    vm.startPrank(LIGHTHOUSE);
    everclearSpoke.pause();

    assert(everclearSpoke.paused());
    everclearSpoke.unpause();

    assert(!everclearSpoke.paused());
    vm.stopPrank();
  }

  /**
   * @notice Tests the pause function as the watchtower
   */
  function test_Unpause_AsWatchtower() public {
    vm.startPrank(WATCHTOWER);
    everclearSpoke.pause();

    assert(everclearSpoke.paused());
    everclearSpoke.unpause();

    assert(!everclearSpoke.paused());
    vm.stopPrank();
  }

  /**
   * @notice Tests the pause function reverts when called by an unauthorized address
   */
  function test_Revert_Pause_NotAuthorized(
    address _caller
  ) public validAddress(_caller) {
    vm.assume(_caller != WATCHTOWER && _caller != LIGHTHOUSE);
    vm.expectRevert(abi.encodeWithSelector(ISpokeStorage.EverclearSpoke_Pause_NotAuthorized.selector));
    vm.prank(_caller);
    everclearSpoke.pause();
  }

  /**
   * @notice Tests the unpause function reverts when called by an unauthorized address
   */
  function test_Revert_Unpause_NotAuthorized(
    address _caller
  ) public validAddress(_caller) {
    vm.assume(_caller != WATCHTOWER && _caller != LIGHTHOUSE);
    vm.expectRevert(abi.encodeWithSelector(ISpokeStorage.EverclearSpoke_Pause_NotAuthorized.selector));
    vm.prank(_caller);
    everclearSpoke.unpause();
  }
}
