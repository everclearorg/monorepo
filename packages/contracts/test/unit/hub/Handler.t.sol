// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {TestExtended} from '../../utils/TestExtended.sol';

import {Handler, IHandler} from 'contracts/hub/modules/Handler.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';

import {IGateway} from 'interfaces/common/IGateway.sol';
import {IHubGateway} from 'interfaces/hub/IHubGateway.sol';

import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {Uint32Set} from 'contracts/hub/lib/Uint32Set.sol';

contract TestHandler is Handler {
  function mockStatus(bytes32 _intentId, uint8 _status) public {
    _contexts[_intentId].status = IEverclear.IntentStatus(_status);
  }

  function mockTTL(bytes32 _intentId, uint48 _ttl) public {
    _contexts[_intentId].intent.ttl = _ttl;
  }

  function mockIntentTimestamp(bytes32 _intentId, uint48 _intentTimestamp) public {
    _contexts[_intentId].intent.timestamp = _intentTimestamp;
  }

  function mockExpiryTimeBuffer(
    uint48 _expiryBuffer
  ) public {
    expiryTimeBuffer = _expiryBuffer;
  }

  function mockHubGateway(
    address _hubGateway
  ) public {
    hubGateway = IHubGateway(_hubGateway);
  }

  function mockIntentData(bytes32 _intentId, IEverclear.Intent memory _intent) public {
    _contexts[_intentId].intent = _intent;
    _contexts[_intentId].intent.amount = _intent.amount;
    _contexts[_intentId].intent.inputAsset = _intent.inputAsset;
    _contexts[_intentId].intent.initiator = _intent.initiator;
  }

  function mockFeeVault(bytes32 _tickerHash, address _caller, uint256 _feeVault) public {
    feeVault[_tickerHash][_caller] = _feeVault;
  }

  function mockEpochLength(
    uint48 _epochLength
  ) public {
    epochLength = _epochLength;
  }

  function mockLiquidity(bytes32 _tickerHash, uint256 _liquidity, uint32 _destination) public {
    TokenConfig storage _tokenConfig = _tokenConfigs[_tickerHash];
    custodiedAssets[_tokenConfig.assetHashes[_destination]] = _liquidity;
  }

  function mockSupportedDomain(
    uint32 _domain
  ) public {
    Uint32Set.add(_supportedDomains, _domain);
  }
}

contract BaseTest is TestExtended {
  TestHandler internal handler;

  function setUp() public {
    handler = new TestHandler();
  }
}

contract Unit_HandleExpiredIntents is BaseTest {
  /**
   * @notice Test handling expired intents with invalid status
   * @param _intentId The intent ID
   * @param _status The status
   */
  function test_Revert_HandleExpiredIntent_InvalidStatus(bytes32 _intentId, uint8 _status) public {
    vm.assume(
      _status != uint8(IEverclear.IntentStatus.DEPOSIT_PROCESSED) && _status < uint8(type(IEverclear.IntentStatus).max)
    );

    bytes32[] memory _expiredIntentIds = new bytes32[](1);
    _expiredIntentIds[0] = _intentId;

    handler.mockStatus(_intentId, _status);

    vm.expectRevert(
      abi.encodeWithSelector(
        IHandler.Handler_HandleExpiredIntents_InvalidStatus.selector, _intentId, IEverclear.IntentStatus(_status)
      )
    );
    handler.handleExpiredIntents(_expiredIntentIds);
  }

  /**
   * @notice Test handling expired intents with zero TTL
   * @param _intentId The intent ID
   */
  function test_Revert_HandleExpiredIntent_ZeroTTL(
    bytes32 _intentId
  ) public {
    bytes32[] memory _expiredIntentIds = new bytes32[](1);
    _expiredIntentIds[0] = _intentId;

    handler.mockStatus(_intentId, uint8(IEverclear.IntentStatus.DEPOSIT_PROCESSED));
    handler.mockTTL(_intentId, 0);

    vm.expectRevert(abi.encodeWithSelector(IHandler.Handler_HandleExpiredIntents_ZeroTTL.selector, _intentId));
    handler.handleExpiredIntents(_expiredIntentIds);
  }

  /**
   * @notice Test handling expired intents that haven't expired
   * @param _intentId The intent ID
   * @param _blockTimestamp The block timestamp
   * @param _intentTimestamp The intent timestamp
   * @param _ttl The time-to-live
   * @param _expiryBuffer The expiry buffer
   */
  function test_Revert_HandleExpiredIntent_NotExpired(
    bytes32 _intentId,
    uint48 _blockTimestamp,
    uint48 _intentTimestamp,
    uint48 _ttl,
    uint48 _expiryBuffer
  ) public {
    // Avoid overflow
    _intentTimestamp = uint48(bound(uint256(_intentTimestamp), 0, type(uint48).max / 3));
    _ttl = uint48(bound(uint256(_intentTimestamp), 0, type(uint48).max / 3));
    _expiryBuffer = uint48(bound(uint256(_intentTimestamp), 0, type(uint48).max / 3));
    vm.assume(_blockTimestamp < _intentTimestamp + _ttl + _expiryBuffer);
    vm.assume(_ttl != 0);

    bytes32[] memory _expiredIntentIds = new bytes32[](1);
    _expiredIntentIds[0] = _intentId;

    vm.warp(_blockTimestamp);

    handler.mockStatus(_intentId, uint8(IEverclear.IntentStatus.DEPOSIT_PROCESSED));
    handler.mockTTL(_intentId, uint48(_ttl));
    handler.mockIntentTimestamp(_intentId, uint48(_intentTimestamp));
    handler.mockExpiryTimeBuffer(uint48(_expiryBuffer));

    vm.expectRevert(
      abi.encodeWithSelector(
        IHandler.Handler_HandleExpiredIntents_NotExpired.selector,
        _intentId,
        _blockTimestamp,
        _intentTimestamp + _ttl + _expiryBuffer
      )
    );
    handler.handleExpiredIntents(_expiredIntentIds);
  }
}

contract Unit_ReturnUnsupportedIntent is BaseTest {
  event ReturnUnsupportedIntent(uint32 indexed _domain, bytes32 _messageId, bytes32 _intentId);

  /**
   * @notice Test returning an unsupported intent
   * @param _intent The intent
   * @param _hubGateway The hub gateway
   * @param _messageId The message ID
   * @param _value The value
   */
  function test_ReturnUnsupportedIntent(
    IEverclear.Intent memory _intent,
    address _hubGateway,
    bytes32 _messageId,
    uint256 _value
  ) public {
    vm.assume(_value < address(this).balance);
    assumeNotPrecompile(_hubGateway);

    bytes32 _intentId = keccak256(abi.encode(_intent));

    IEverclear.Settlement[] memory _settlementMessageBatch = new IEverclear.Settlement[](1);
    _settlementMessageBatch[0] = IEverclear.Settlement({
      intentId: _intentId,
      amount: _intent.amount,
      asset: _intent.inputAsset,
      recipient: _intent.initiator,
      updateVirtualBalance: true
    });

    bytes memory _settlementMessageData = MessageLib.formatSettlementBatch(_settlementMessageBatch);

    handler.mockStatus(_intentId, uint8(IEverclear.IntentStatus.UNSUPPORTED));
    handler.mockHubGateway(_hubGateway);
    handler.mockIntentData(_intentId, _intent);

    vm.mockCall(
      _hubGateway,
      _value,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', _intent.origin, _settlementMessageData, 50_000),
      abi.encode(_messageId, 0)
    );
    vm.expectCall(
      _hubGateway,
      _value,
      abi.encodeWithSignature('sendMessage(uint32,bytes,uint256)', _intent.origin, _settlementMessageData, 50_000)
    );

    vm.expectEmit(address(handler));
    emit ReturnUnsupportedIntent(_intent.origin, _messageId, _intentId);

    handler.returnUnsupportedIntent{value: _value}(_intentId);
  }

  /**
   * @notice Test returning an unsupported intent with invalid status
   * @param _intentId The intent ID
   * @param _status The status
   */
  function test_Revert_ReturnUnsupportedIntent_InvalidStatus(bytes32 _intentId, uint8 _status) public {
    vm.assume(
      _status != uint8(IEverclear.IntentStatus.UNSUPPORTED) && _status < uint8(type(IEverclear.IntentStatus).max)
    );

    handler.mockStatus(_intentId, _status);

    vm.expectRevert(abi.encodeWithSelector(IHandler.Handler_ReturnUnsupportedIntent_InvalidStatus.selector));
    handler.returnUnsupportedIntent(_intentId);
  }
}

contract Unit_WithdrawFees is BaseTest {
  using TypeCasts for address;

  event FeesWithdrawn(
    address _withdrawer, bytes32 _feeRecipient, bytes32 _tickerHash, uint256 _amount, bytes32 _paymentId
  );

  /**
   * @notice Test withdrawing fees and creating an invoice
   * @param _tickerHash The ticker hash
   * @param _amount The amount to withdraw
   * @param _feeVault The fee vault
   * @param _destinations The destinations
   * @param _caller The caller
   */
  function test_WithdrawFees_CreateInvoice(
    bytes32 _tickerHash,
    uint256 _amount,
    uint256 _feeVault,
    uint32[] memory _destinations,
    address _caller
  ) public {
    vm.assume(_amount > 0);
    vm.assume(_feeVault > _amount);

    handler.mockFeeVault(_tickerHash, _caller, _feeVault);
    handler.mockEpochLength(1);

    for (uint256 _i; _i < _destinations.length; _i++) {
      handler.mockSupportedDomain(_destinations[_i]);
    }

    bytes32 _paymentId = keccak256(
      abi.encode(keccak256('protocol_payment'), _tickerHash, _amount, _caller, _caller.toBytes32(), _destinations, 1)
    );

    vm.expectEmit(address(handler));
    emit FeesWithdrawn(_caller, _caller.toBytes32(), _tickerHash, _amount, _paymentId);

    vm.prank(_caller);
    handler.withdrawFees(_caller.toBytes32(), _tickerHash, _amount, _destinations);
  }

  /**
   * @notice Test withdrawing fees and creating a settlement
   * @param _tickerHash The ticker hash
   * @param _amount The amount to withdraw
   * @param _feeVault The fee vault
   * @param _destinations The destinations
   * @param _caller The caller
   */
  function test_WithdrawFees_CreateSettlement(
    bytes32 _tickerHash,
    uint256 _amount,
    uint256 _feeVault,
    uint32[] memory _destinations,
    address _caller
  ) public {
    vm.assume(_amount > 0);
    vm.assume(_feeVault > _amount);
    vm.assume(_destinations.length > 0);

    handler.mockFeeVault(_tickerHash, _caller, _feeVault);
    handler.mockEpochLength(1);
    handler.mockLiquidity(_tickerHash, _amount, _destinations[0]);

    for (uint256 _i; _i < _destinations.length; _i++) {
      handler.mockSupportedDomain(_destinations[_i]);
    }

    bytes32 _paymentId = keccak256(
      abi.encode(keccak256('protocol_payment'), _tickerHash, _amount, _caller, _caller.toBytes32(), _destinations, 1)
    );

    vm.expectEmit(address(handler));
    emit FeesWithdrawn(_caller, _caller.toBytes32(), _tickerHash, _amount, _paymentId);

    vm.prank(_caller);
    handler.withdrawFees(_caller.toBytes32(), _tickerHash, _amount, _destinations);
  }

  /**
   * @notice Test withdrawing fees with insufficient funds
   * @param _tickerHash The ticker hash
   * @param _amount The amount to withdraw
   * @param _feeVault The fee vault
   * @param _destinations The destinations
   * @param _caller The caller
   */
  function test_Revert_WithdrawFees_InsufficientFunds(
    bytes32 _tickerHash,
    uint256 _amount,
    uint256 _feeVault,
    uint32[] memory _destinations,
    address _caller
  ) public {
    vm.assume(_feeVault < _amount);

    handler.mockFeeVault(_tickerHash, _caller, _feeVault);

    vm.expectRevert(abi.encodeWithSelector(IHandler.Handler_WithdrawFees_InsufficientFunds.selector));

    vm.prank(_caller);
    handler.withdrawFees(_caller.toBytes32(), _tickerHash, _amount, _destinations);
  }

  /**
   * @notice Test withdrawing fees with zero amount
   * @param _tickerHash The ticker hash
   * @param _feeVault The fee vault
   * @param _destinations The destinations
   * @param _caller The caller
   */
  function test_Revert_WithdrawFees_ZeroAmount(
    bytes32 _tickerHash,
    uint256 _feeVault,
    uint32[] memory _destinations,
    address _caller
  ) public {
    vm.assume(_feeVault > 0);

    handler.mockFeeVault(_tickerHash, _caller, _feeVault);

    vm.expectRevert(abi.encodeWithSelector(IHandler.Handler_WithdrawFees_ZeroAmount.selector));

    vm.prank(_caller);
    handler.withdrawFees(_caller.toBytes32(), _tickerHash, 0, _destinations);
  }

  /**
   * @notice Test withdrawing fees with an unsupported domain
   * @param _tickerHash The ticker hash
   * @param _amount The amount to withdraw
   * @param _feeVault The fee vault
   * @param _destinations The destinations
   * @param _caller The caller
   */
  function test_Revert_WithdrawFees_UnsupportedDomain(
    bytes32 _tickerHash,
    uint256 _amount,
    uint256 _feeVault,
    uint32[] memory _destinations,
    address _caller
  ) public {
    vm.assume(_amount > 0);
    vm.assume(_feeVault > _amount);
    vm.assume(_destinations.length > 0);

    handler.mockFeeVault(_tickerHash, _caller, _feeVault);

    vm.expectRevert(abi.encodeWithSelector(IHandler.Handler_WithdrawFees_UnsupportedDomain.selector, _destinations[0]));

    vm.prank(_caller);
    handler.withdrawFees(_caller.toBytes32(), _tickerHash, _amount, _destinations);
  }
}
