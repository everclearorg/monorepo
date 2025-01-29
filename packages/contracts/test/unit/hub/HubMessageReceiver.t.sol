// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AssetUtils} from 'contracts/common/AssetUtils.sol';
import {MessageLib} from 'contracts/common/MessageLib.sol';

import {Constants as Common} from 'contracts/common/Constants.sol';

import {InvoiceListLib} from 'contracts/hub/lib/InvoiceListLib.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';
import {TestExtended} from 'test/utils/TestExtended.sol';

import {HubMessageReceiver, IHubMessageReceiver} from 'contracts/hub/modules/HubMessageReceiver.sol';
import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';
import {IHubStorage} from 'interfaces/hub/IHubStorage.sol';

contract TestHubMessageReceiver is HubMessageReceiver {
  function setGateway(
    address _gateway
  ) external {
    hubGateway = IHubGateway(_gateway);
  }

  function setEpochLength(
    uint48 _epochLength
  ) external {
    epochLength = _epochLength;
  }

  function deductProtocolFees(
    bytes32 _tickerHash,
    uint256 _amount
  ) public returns (uint24 _totalFeeBps, uint256 _amountAfterFees) {
    return _deductProtocolFees(_tickerHash, _amount);
  }

  function mockAssetFees(bytes32 _tickerHash, IHubStorage.Fee[] memory _fees) external {
    for (uint256 _i; _i < _fees.length; _i++) {
      _tokenConfigs[_tickerHash].fees.push(_fees[_i]);
    }
  }

  function mockIntentStatus(bytes32 _intentId, uint8 _status) external {
    _contexts[_intentId].status = IEverclear.IntentStatus(_status);
  }

  function mockAdoptedForAssetsApproval(bytes32 _inputAssetHash, bool _adopted) external {
    _adoptedForAssets[_inputAssetHash].approval = _adopted;
  }

  function mockTickerHash(bytes32 _inputAssetHash, bytes32 _tickerHash) external {
    _adoptedForAssets[_inputAssetHash].tickerHash = _tickerHash;
  }

  function mockSupportedDomains(uint32[] memory _domains, bool _supported) external {
    if (_supported) {
      for (uint256 _i; _i < _domains.length; _i++) {
        Uint32Set.add(_supportedDomains, _domains[_i]);
      }
    } else {
      for (uint256 _i; _i < _domains.length; _i++) {
        Uint32Set.remove(_supportedDomains, _domains[_i]);
      }
    }
  }

  function mockOutputAssetHash(bytes32 _tickerHash, uint32 _domain, bytes32 _outputAssetHash) external {
    _tokenConfigs[_tickerHash].assetHashes[_domain] = _outputAssetHash;
  }

  function getContext(
    bytes32 _intentId
  ) external view returns (IntentContext memory _context) {
    _context = _contexts[_intentId];
  }

  function mockInvoicesLength(
    bytes32 _tickerHash
  ) external {
    InvoiceListLib.append(
      invoices[_tickerHash],
      IHubStorage.Invoice({intentId: keccak256('0'), owner: keccak256('0'), entryEpoch: 1, amount: 1})
    );
  }
}

contract BaseTest is TestExtended {
  TestHubMessageReceiver public hubMessageReceiver;

  address immutable GATEWAY = makeAddr('GATEWAY');

  function setUp() public {
    hubMessageReceiver = new TestHubMessageReceiver();
    hubMessageReceiver.setGateway(GATEWAY);
    hubMessageReceiver.setEpochLength(1);
  }

  function _processIntent(
    IEverclear.Intent memory _intent,
    bool _status
  ) internal returns (uint8 __status, bytes32 _intentId, bytes32 _inputAssetHash, bytes32 _outputAssetHash) {
    __status = _status ? uint8(IEverclear.IntentStatus.NONE) : uint8(IEverclear.IntentStatus.FILLED);
    _intentId = keccak256(abi.encode(_intent));
    _inputAssetHash = AssetUtils.getAssetHash(_intent.inputAsset, _intent.origin);
    _outputAssetHash = AssetUtils.getAssetHash(_intent.outputAsset, _intent.destinations[0]);
  }
}

contract Unit_ReceiveIntents is BaseTest {
  event IntentProcessed(bytes32 indexed _intentId, IEverclear.IntentStatus indexed _status);

  /**
   * @notice Test receiving an intent message with a random status
   * @param _intent The intent object
   * @param _status The status of the intent
   */
  function test_ReceiveIntent_RandomStatus(IEverclear.Intent memory _intent, uint8 _status) public {
    vm.assume(
      _status != uint8(IEverclear.IntentStatus.NONE) && _status != uint8(IEverclear.IntentStatus.FILLED)
        && _status <= uint8(type(IEverclear.IntentStatus).max)
    );
    bytes32 _intentId = keccak256(abi.encode(_intent));
    hubMessageReceiver.mockIntentStatus(_intentId, _status);
    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    _intents[0] = _intent;
    bytes memory _message = MessageLib.formatIntentMessageBatch(_intents);

    vm.prank(GATEWAY);
    hubMessageReceiver.receiveMessage(_message);
  }

  /**
   * @notice Test receiving an intent message with an unsupported status
   * @param _intent The intent object
   * @param _status The status of the intent
   */
  function test_ReceiveIntent_Unsupported_UnapprovedInputAsset(IEverclear.Intent memory _intent, bool _status) public {
    vm.assume(_intent.destinations.length > 0);
    (uint8 __status, bytes32 _intentId, bytes32 _inputAssetHash,) = _processIntent(_intent, _status);
    hubMessageReceiver.mockIntentStatus(_intentId, __status);
    hubMessageReceiver.mockAdoptedForAssetsApproval(_inputAssetHash, false);

    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    _intents[0] = _intent;
    bytes memory _message = MessageLib.formatIntentMessageBatch(_intents);

    vm.expectEmit(address(hubMessageReceiver));
    emit IntentProcessed(_intentId, IEverclear.IntentStatus.UNSUPPORTED);

    vm.prank(GATEWAY);
    hubMessageReceiver.receiveMessage(_message);

    assertEq(
      uint8(hubMessageReceiver.getContext(_intentId).status),
      uint8(IEverclear.IntentStatus.UNSUPPORTED),
      'Incorrect status'
    );
  }

  /**
   * @notice Test receiving an intent message with an unsupported status
   * @param _intent The intent object
   * @param _status The status of the intent
   */
  function test_ReceiveIntent_Unsupported_InvalidDomain(IEverclear.Intent memory _intent, bool _status) public {
    vm.assume(_intent.destinations.length > 0);

    (uint8 __status, bytes32 _intentId, bytes32 _inputAssetHash,) = _processIntent(_intent, _status);
    hubMessageReceiver.mockIntentStatus(_intentId, __status);
    hubMessageReceiver.mockAdoptedForAssetsApproval(_inputAssetHash, true);
    hubMessageReceiver.mockSupportedDomains(_intent.destinations, false);

    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    _intents[0] = _intent;
    bytes memory _message = MessageLib.formatIntentMessageBatch(_intents);

    vm.expectEmit(address(hubMessageReceiver));
    emit IntentProcessed(_intentId, IEverclear.IntentStatus.UNSUPPORTED);

    vm.prank(GATEWAY);
    hubMessageReceiver.receiveMessage(_message);

    assertEq(
      uint8(hubMessageReceiver.getContext(_intentId).status),
      uint8(IEverclear.IntentStatus.UNSUPPORTED),
      'Incorrect status'
    );
  }

  /**
   * @notice Test receiving an intent message with an unsupported status, due to an unapproved output asset
   * @param _intent The intent object
   * @param _status The status of the intent
   */
  function test_ReceiveIntent_Unsupported_UnapprovedOutputAsset(
    IEverclear.Intent memory _intent,
    bool _status,
    uint32 _destination
  ) public {
    vm.assume(_intent.outputAsset != 0);
    _intent.destinations = new uint32[](1);
    _intent.destinations[0] = _destination;

    (uint8 __status, bytes32 _intentId, bytes32 _inputAssetHash, bytes32 _outputAssetHash) =
      _processIntent(_intent, _status);
    hubMessageReceiver.mockIntentStatus(_intentId, __status);
    hubMessageReceiver.mockAdoptedForAssetsApproval(_inputAssetHash, true);
    hubMessageReceiver.mockSupportedDomains(_intent.destinations, true);
    hubMessageReceiver.mockAdoptedForAssetsApproval(_outputAssetHash, false);

    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    _intents[0] = _intent;
    bytes memory _message = MessageLib.formatIntentMessageBatch(_intents);

    vm.expectEmit(address(hubMessageReceiver));
    emit IntentProcessed(_intentId, IEverclear.IntentStatus.UNSUPPORTED);

    vm.prank(GATEWAY);
    hubMessageReceiver.receiveMessage(_message);

    assertEq(
      uint8(hubMessageReceiver.getContext(_intentId).status),
      uint8(IEverclear.IntentStatus.UNSUPPORTED),
      'Incorrect status'
    );
  }

  /**
   * @notice Test receiving an intent message without invoices, going through the fast path
   * @param _intent The intent object
   * @param _status The status of the intent
   * @param _tickerHash The ticker hash of the asset of the intent
   */
  function test_ReceiveIntent_WithoutInvoices_FastPath_NotFilled(
    IEverclear.Intent memory _intent,
    bool _status,
    bytes32 _tickerHash
  ) public {
    vm.assume(_intent.ttl != 0);
    vm.assume(_intent.destinations.length > 0);
    (uint8 __status, bytes32 _intentId, bytes32 _inputAssetHash, bytes32 _outputAssetHash) =
      _processIntent(_intent, _status);
    hubMessageReceiver.mockIntentStatus(_intentId, __status);
    hubMessageReceiver.mockAdoptedForAssetsApproval(_inputAssetHash, true);
    hubMessageReceiver.mockSupportedDomains(_intent.destinations, true);
    hubMessageReceiver.mockAdoptedForAssetsApproval(_outputAssetHash, true);
    hubMessageReceiver.mockTickerHash(_inputAssetHash, _tickerHash);
    hubMessageReceiver.mockOutputAssetHash(_tickerHash, _intent.destinations[0], _outputAssetHash);

    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    _intents[0] = _intent;
    bytes memory _message = MessageLib.formatIntentMessageBatch(_intents);

    vm.expectEmit(address(hubMessageReceiver));
    emit IntentProcessed(_intentId, IEverclear.IntentStatus.DEPOSIT_PROCESSED);

    vm.prank(GATEWAY);
    hubMessageReceiver.receiveMessage(_message);

    assertEq(
      uint8(hubMessageReceiver.getContext(_intentId).status),
      uint8(IEverclear.IntentStatus.DEPOSIT_PROCESSED),
      'Incorrect status'
    );
  }

  /**
   * @notice Test receiving an intent message with invoices
   * @param _intent The intent object
   * @param _status The status of the intent
   * @param _tickerHash The ticker hash of the asset of the intent
   */
  function test_ReceiveIntent_WithInvoices(IEverclear.Intent memory _intent, bool _status, bytes32 _tickerHash) public {
    vm.assume(_intent.ttl != 0);
    vm.assume(_intent.destinations.length > 0);
    (uint8 __status, bytes32 _intentId, bytes32 _inputAssetHash, bytes32 _outputAssetHash) =
      _processIntent(_intent, _status);
    hubMessageReceiver.mockIntentStatus(_intentId, __status);
    hubMessageReceiver.mockAdoptedForAssetsApproval(_inputAssetHash, true);
    hubMessageReceiver.mockSupportedDomains(_intent.destinations, true);
    hubMessageReceiver.mockAdoptedForAssetsApproval(_outputAssetHash, true);
    hubMessageReceiver.mockTickerHash(_inputAssetHash, _tickerHash);
    hubMessageReceiver.mockOutputAssetHash(_tickerHash, _intent.destinations[0], _outputAssetHash);
    hubMessageReceiver.mockInvoicesLength(_tickerHash);

    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    _intents[0] = _intent;
    bytes memory _message = MessageLib.formatIntentMessageBatch(_intents);

    vm.expectEmit(address(hubMessageReceiver));
    if (__status == uint8(IEverclear.IntentStatus.FILLED)) {
      emit IntentProcessed(_intentId, IEverclear.IntentStatus.ADDED_AND_FILLED);

      vm.prank(GATEWAY);
      hubMessageReceiver.receiveMessage(_message);

      assertEq(
        uint8(hubMessageReceiver.getContext(_intentId).status),
        uint8(IEverclear.IntentStatus.ADDED_AND_FILLED),
        'Incorrect status'
      );
    } else {
      emit IntentProcessed(_intentId, IEverclear.IntentStatus.ADDED);

      vm.prank(GATEWAY);
      hubMessageReceiver.receiveMessage(_message);

      assertEq(
        uint8(hubMessageReceiver.getContext(_intentId).status), uint8(IEverclear.IntentStatus.ADDED), 'Incorrect status'
      );
    }
  }
}

contract Unit_ReceiveFillMessages is BaseTest {
  event FillProcessed(bytes32 indexed _intentId, IEverclear.IntentStatus _status);

  /**
   * @notice Test receiving a fill message with a random status
   * @param _fillMessage The fill message object
   * @param _status The status of the fill
   */
  function test_ReceiveFillMessage_RandomStatus(IEverclear.FillMessage memory _fillMessage, uint8 _status) public {
    vm.assume(
      _status != uint8(IEverclear.IntentStatus.NONE) && _status != uint8(IEverclear.IntentStatus.ADDED)
        && _status != uint8(IEverclear.IntentStatus.DEPOSIT_PROCESSED)
        && _status <= uint8(type(IEverclear.IntentStatus).max)
    );
    hubMessageReceiver.mockIntentStatus(_fillMessage.intentId, _status);

    IEverclear.FillMessage[] memory _fillMessages = new IEverclear.FillMessage[](1);
    _fillMessages[0] = _fillMessage;
    bytes memory _message = MessageLib.formatFillMessageBatch(_fillMessages);

    vm.prank(GATEWAY);
    hubMessageReceiver.receiveMessage(_message);
  }

  /**
   * @notice Test receiving a fill message with a none status
   * @param _fillMessage The fill message object
   */
  function test_ReceiveFillMessage_NoneStatus(
    IEverclear.FillMessage memory _fillMessage
  ) public {
    hubMessageReceiver.mockIntentStatus(_fillMessage.intentId, uint8(IEverclear.IntentStatus.NONE));

    IEverclear.FillMessage[] memory _fillMessages = new IEverclear.FillMessage[](1);
    _fillMessages[0] = _fillMessage;
    bytes memory _message = MessageLib.formatFillMessageBatch(_fillMessages);

    vm.expectEmit(address(hubMessageReceiver));
    emit FillProcessed(_fillMessage.intentId, IEverclear.IntentStatus.FILLED);

    vm.prank(GATEWAY);
    hubMessageReceiver.receiveMessage(_message);

    assertEq(
      uint8(hubMessageReceiver.getContext(_fillMessage.intentId).status),
      uint8(IEverclear.IntentStatus.FILLED),
      'Incorrect status'
    );
  }

  /**
   * @notice Test receiving a fill message with an added status
   * @param _fillMessage The fill message object
   */
  function test_ReceiveFillMessage_AddedStatus(
    IEverclear.FillMessage memory _fillMessage
  ) public {
    hubMessageReceiver.mockIntentStatus(_fillMessage.intentId, uint8(IEverclear.IntentStatus.ADDED));

    IEverclear.FillMessage[] memory _fillMessages = new IEverclear.FillMessage[](1);
    _fillMessages[0] = _fillMessage;
    bytes memory _message = MessageLib.formatFillMessageBatch(_fillMessages);

    vm.expectEmit(address(hubMessageReceiver));
    emit FillProcessed(_fillMessage.intentId, IEverclear.IntentStatus.ADDED_AND_FILLED);

    vm.prank(GATEWAY);
    hubMessageReceiver.receiveMessage(_message);

    assertEq(
      uint8(hubMessageReceiver.getContext(_fillMessage.intentId).status),
      uint8(IEverclear.IntentStatus.ADDED_AND_FILLED),
      'Incorrect status'
    );
  }
}

contract Unit_Reverts is BaseTest {
  /**
   * @notice Test reverting when receiving a message with an invalid message type
   * @param _messageType The message type
   * @param _data The data of the message
   */
  function test_Revert_ReceiveMessage_InvalidMessageType(uint8 _messageType, bytes memory _data) public {
    _messageType = uint8(bound(uint256(_messageType), 2, uint256(type(MessageLib.MessageType).max)));
    bytes memory _message = MessageLib.formatMessage(MessageLib.MessageType(_messageType), _data);

    vm.expectRevert(IHubMessageReceiver.HubMessageReceiver_ReceiveMessage_InvalidMessageType.selector);

    vm.prank(GATEWAY);
    hubMessageReceiver.receiveMessage(_message);
  }

  /**
   * @notice Test reverting when receiving a message without being the gateway
   * @param _caller The caller of the function
   * @param _message The message to be received
   */
  function test_Revert_ReceiveMessage_NonGateway(address _caller, bytes calldata _message) public {
    vm.assume(_caller != GATEWAY && _caller != address(0));

    vm.expectRevert(IHubStorage.HubStorage_Unauthorized.selector);

    vm.prank(_caller);
    hubMessageReceiver.receiveMessage(_message);
  }
}

contract Unit_DeductProtocolFees is BaseTest {
  /**
   * @notice Test deducting protocol fees
   * @param _tickerHash The ticker hash of the asset
   * @param _intentAmount The amount of the intent
   * @param _fee1 The fee of the first recipient
   * @param _fee2 The fee of the second recipient
   * @param _recipient1 The address of the first recipient
   * @param _recipient2 The address of the second recipient
   */
  function test_DeductProtocolFees(
    bytes32 _tickerHash,
    uint256 _intentAmount,
    uint24 _fee1,
    uint24 _fee2,
    address _recipient1,
    address _recipient2
  ) public {
    vm.assume(_recipient1 != _recipient2);
    vm.assume(_intentAmount > Common.DBPS_DENOMINATOR);
    vm.assume(_fee2 <= Common.DBPS_DENOMINATOR && _fee1 <= Common.DBPS_DENOMINATOR - _fee2);
    vm.assume(type(uint256).max / _intentAmount >= _fee1);
    vm.assume(type(uint256).max / _intentAmount >= _fee2);

    IHubStorage.Fee[] memory _fees = new IHubStorage.Fee[](2);

    _fees[0] = IHubStorage.Fee({recipient: _recipient1, fee: _fee1});
    _fees[1] = IHubStorage.Fee({recipient: _recipient2, fee: _fee2});

    hubMessageReceiver.mockAssetFees(_tickerHash, _fees);

    (uint24 _totalFeeDbps, uint256 _amountAfterFees) = hubMessageReceiver.deductProtocolFees(_tickerHash, _intentAmount);
    uint256 _recipient1Balance = hubMessageReceiver.feeVault(_tickerHash, _recipient1);
    uint256 _recipient2Balance = hubMessageReceiver.feeVault(_tickerHash, _recipient2);

    assertEq(_totalFeeDbps, _fee1 + _fee2, 'Incorrect total fee');
    assertEq(
      _amountAfterFees,
      _intentAmount - _intentAmount * _fee1 / Common.DBPS_DENOMINATOR - _intentAmount * _fee2 / Common.DBPS_DENOMINATOR,
      'Incorrect amount after fees'
    );
    assertEq(_recipient1Balance, _intentAmount * _fee1 / Common.DBPS_DENOMINATOR, 'Incorrect recipient 1 balance');
    assertEq(_recipient2Balance, _intentAmount * _fee2 / Common.DBPS_DENOMINATOR, 'Incorrect recipient 2 balance');
  }

  /**
   * @notice Test accumulating protocol fees
   * @param _tickerHash The ticker hash of the asset
   * @param _intentAmount The amount of the intent
   * @param _fee1 The fee of the first recipient
   * @param _fee2 The fee of the second recipient
   * @param _recipient1 The address of the first recipient
   * @param _recipient2 The address of the second recipient
   */
  function test_DeductProtocolFees_Accumulation(
    bytes32 _tickerHash,
    uint256 _intentAmount,
    uint24 _fee1,
    uint24 _fee2,
    address _recipient1,
    address _recipient2
  ) public {
    vm.assume(_recipient1 != _recipient2);
    vm.assume(_intentAmount > Common.DBPS_DENOMINATOR);
    vm.assume(_fee2 <= Common.DBPS_DENOMINATOR && _fee1 <= Common.DBPS_DENOMINATOR - _fee2);
    vm.assume(type(uint256).max / _intentAmount >= _fee1);
    vm.assume(type(uint256).max / _intentAmount >= _fee2);

    IHubStorage.Fee[] memory _fees = new IHubStorage.Fee[](2);

    _fees[0] = IHubStorage.Fee({recipient: _recipient1, fee: _fee1});
    _fees[1] = IHubStorage.Fee({recipient: _recipient2, fee: _fee2});

    hubMessageReceiver.mockAssetFees(_tickerHash, _fees);

    hubMessageReceiver.deductProtocolFees(_tickerHash, _intentAmount);
    hubMessageReceiver.deductProtocolFees(_tickerHash, _intentAmount);

    uint256 _recipient1Balance = hubMessageReceiver.feeVault(_tickerHash, _recipient1);
    uint256 _recipient2Balance = hubMessageReceiver.feeVault(_tickerHash, _recipient2);

    assertEq(_recipient1Balance, _intentAmount * _fee1 / Common.DBPS_DENOMINATOR * 2, 'Incorrect recipient 1 balance');
    assertEq(_recipient2Balance, _intentAmount * _fee2 / Common.DBPS_DENOMINATOR * 2, 'Incorrect recipient 2 balance');
  }
}
