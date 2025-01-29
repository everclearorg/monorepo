// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

import {MessageLib} from 'contracts/common/MessageLib.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {EverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';

import {TestnetProductionEnv, TestnetStagingEnv} from '../utils/Environment.sol';
import {TypedMemView} from '../utils/TypedMemView.sol';
import {ScriptUtils} from '../utils/Utils.sol';

contract ReceiveSettlementMessageBase is Script, ScriptUtils {
  /// Libraries
  using TypedMemView for bytes;
  using TypedMemView for bytes29;
  using TypeCasts for bytes32;
  using TypeCasts for address;

  /// Errors
  error InvalidOrigin(uint32 origin);
  error InvalidSender(address sender);
  error InvalidRecipient(address recipient);
  error InvalidMessageType(MessageLib.MessageType messageType);

  /// Constants
  // See: https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/solidity/contracts/libs/Message.sol
  uint256 private constant VERSION_OFFSET = 0;
  uint256 private constant NONCE_OFFSET = 1;
  uint256 private constant ORIGIN_OFFSET = 5;
  uint256 private constant SENDER_OFFSET = 9;
  uint256 private constant DESTINATION_OFFSET = 41;
  uint256 private constant RECIPIENT_OFFSET = 45;
  uint256 private constant BODY_OFFSET = 77;

  /// Storage
  mapping(uint32 _domain => EverclearSpoke _spoke) internal _spokes;

  uint32 internal _hubDomain;
  address internal _hubGateway;

  /**
   * @dev User-input. Should be taken from the `_message` value of the Dispatch event.
   * This will _NOT_ be only the message body.
   */
  bytes _message;
  uint256 _numberTxs;

  function _getInputs() internal {
    _message = vm.parseBytes(vm.prompt('Message'));
    _numberTxs = vm.parseUint(vm.prompt('Number of transactions'));
  }

  function _getBodyFromHyperlaneMessage(
    bytes memory _message
  ) public returns (bytes memory _body) {
    bytes29 _ref = TypedMemView.ref(_message, 0);
    uint256 _bodyLen = TypedMemView.len(_ref) - BODY_OFFSET;
    bytes29 _view = TypedMemView.slice(_ref, BODY_OFFSET, _bodyLen, 0);
    _body = TypedMemView.clone(_view);
  }

  function _getRecipientFromHyperlaneMessage(
    bytes memory _message
  ) public returns (address _recipient) {
    bytes32 _recipientLong = TypedMemView.index(TypedMemView.ref(_message, 0), RECIPIENT_OFFSET, 32);
    _recipient = TypeCasts.toAddress(_recipientLong);
  }

  function _getOriginFromHyperlaneMessage(
    bytes memory _message
  ) public returns (uint32 _origin) {
    _origin = uint32(TypedMemView.indexUint(TypedMemView.ref(_message, 0), ORIGIN_OFFSET, 4));
  }

  function _getSenderFromHyperlaneMessage(
    bytes memory _message
  ) public returns (bytes32 _sender) {
    _sender = TypedMemView.index(TypedMemView.ref(_message, 0), SENDER_OFFSET, 32);
  }

  function _slice(
    IEverclear.Settlement[] memory arr,
    uint256 start,
    uint256 end
  ) public pure returns (IEverclear.Settlement[] memory) {
    IEverclear.Settlement[] memory sliced = new IEverclear.Settlement[](end - start);
    for (uint256 i = 0; i < end - start; i++) {
      sliced[i] = arr[start + i];
    }
    return sliced;
  }

  function run() public {
    uint256 _deployerPk = vm.envUint('DEPLOYER_PK');

    // Parse information from hyperlane message
    address _recipient = _getRecipientFromHyperlaneMessage(_message);
    uint32 _origin = _getOriginFromHyperlaneMessage(_message);
    bytes32 _sender = _getSenderFromHyperlaneMessage(_message);
    bytes memory _body = _getBodyFromHyperlaneMessage(_message);

    // Sanity checks:
    // origin is the hub domain
    if (_origin != _hubDomain) {
      revert InvalidOrigin(_origin);
    }

    // sender is the hub gateway
    if (_sender.toAddress() != _hubGateway) {
      revert InvalidSender(_sender.toAddress());
    }

    // recipient is the appropriate spoke gateway
    EverclearSpoke _spoke = _spokes[uint32(block.chainid)];
    address _gateway = address(_spoke.gateway());
    if (_recipient != _gateway) {
      revert InvalidRecipient(_recipient);
    }

    // Parse the messages
    (MessageLib.MessageType _type, bytes memory _data) = MessageLib.parseMessage(_body);
    // Message type must be settlement
    if (_type != MessageLib.MessageType.SETTLEMENT) {
      revert InvalidMessageType(_type);
    }
    IEverclear.Settlement[] memory _settlements = MessageLib.parseSettlementBatch(_data);
    uint256 _numberSettlements = _settlements.length;
    uint256 _batchSize = _numberSettlements / _numberTxs;
    if (_numberSettlements % _numberTxs != 0) {
      _numberTxs += 1;
    }

    vm.startBroadcast(_deployerPk);

    uint256 _processedSettlements;
    for (uint256 i; i < _numberTxs; i++) {
      // Create body
      uint256 _start = i * _batchSize;
      uint256 _end = _start + _batchSize;
      if (_end > _numberSettlements || (_end < _numberSettlements && i == _numberTxs - 1)) {
        _end = _numberSettlements;
      }
      IEverclear.Settlement[] memory _truncated = _slice(_settlements, _start, _end);
      IMessageReceiver(address(_spoke)).receiveMessage(MessageLib.formatSettlementBatch(_truncated));
      _processedSettlements += _truncated.length;
    }

    vm.stopBroadcast();

    console.log('------------------------------------------------');
    console.log('Origin:', _origin);
    console.log('Sender:', _sender.toAddress());
    console.log('Recipient:', _recipient);
    console.log('Settlements:', _settlements.length);
    console.log('Transactions:', _numberTxs);
    console.log('Total Processed:', _processedSettlements);
    console.log('------------------------------------------------');
  }
}

contract TestnetStaging is ReceiveSettlementMessageBase, TestnetStagingEnv {
  function setUp() public {
    _spokes[SEPOLIA] = EverclearSpoke(payable(address(SEPOLIA_SPOKE)));
    _spokes[BSC_TESTNET] = EverclearSpoke(payable(address(BSC_SPOKE)));
    _spokes[ARB_SEPOLIA] = EverclearSpoke(payable(address(ARB_SEPOLIA_SPOKE)));
    _spokes[OP_SEPOLIA] = EverclearSpoke(payable(address(OP_SEPOLIA_SPOKE)));

    _hubDomain = EVERCLEAR_DOMAIN;
    _hubGateway = address(HUB_GATEWAY);

    _getInputs();
  }
}

contract TestnetProduction is ReceiveSettlementMessageBase, TestnetProductionEnv {
  function setUp() public {
    _spokes[SEPOLIA] = EverclearSpoke(payable(address(SEPOLIA_SPOKE)));
    _spokes[BSC_TESTNET] = EverclearSpoke(payable(address(BSC_SPOKE)));
    _spokes[ARB_SEPOLIA] = EverclearSpoke(payable(address(ARB_SEPOLIA_SPOKE)));
    _spokes[OP_SEPOLIA] = EverclearSpoke(payable(address(OP_SEPOLIA_SPOKE)));

    _hubDomain = EVERCLEAR_DOMAIN;
    _hubGateway = address(HUB_GATEWAY);

    _getInputs();
  }
}
