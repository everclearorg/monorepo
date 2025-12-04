// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {StandardHookMetadata} from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import {
  IInterchainSecurityModule,
  ISpecifiesInterchainSecurityModule
} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';
import {IMessageRecipient} from '@hyperlane/interfaces/IMessageRecipient.sol';
import {IPolymer} from 'interfaces/common/IPolymer.sol';

import {GasTank} from 'contracts/common/GasTank.sol';
import {TypeCasts} from 'contracts/common/TypeCasts.sol';

import {ICCIP} from 'interfaces/common/ICCIP.sol';
import {IGatewayV3} from 'interfaces/common/IGatewayV3.sol';
import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';

/**
 * @title GatewayV3
 * @notice Abstract contract for GatewayV3 functionality.
 * @dev This contract must be inherited from implementations that must override the necessary check functions.
 */
abstract contract GatewayV3 is GasTank, IGatewayV3, IMessageRecipient, ISpecifiesInterchainSecurityModule {
  using TypeCasts for address;

  address public constant POLYMER_EMIT_MAILBOX = address(0x1);
  uint256 public constant POLYMER_ID = 1;
  uint256 public constant HL_ID = 2;
  uint256 public constant CCIP_ID = 3;

  // Tag to indicate a gas limit (or dest chain equivalent processing units) and Out Of Order Execution. This tag is
  // available for multiple chain families. If there is no chain family specific tag, this is the default available
  // for a chain.
  // Note: not available for Solana VM based chains.
  bytes4 public constant GENERIC_EXTRA_ARGS_V2_TAG = 0x181dcf10;

  // Note: used for solana
  bytes4 public constant SVM_EXTRA_ARGS_V1_TAG = 0x1f3b3aba;

  IMessageReceiver public receiver;

  /// @inheritdoc ISpecifiesInterchainSecurityModule
  IInterchainSecurityModule public interchainSecurityModule;

  address public hyperlaneMailbox;

  address public ccipMailbox;

  address public polymerMailbox;

  IPolymer public polymerProver;

  mapping(uint256 => uint256) public ecToCCIPChainId;

  mapping(uint256 => uint256) public ccipToECId;

  mapping(bytes32 => bool) public usedUniqueHashes;

  uint256[50] _gap;

  /**
   * @notice Checks that the function is called by the local receiver
   */
  modifier onlyReceiver() {
    if (msg.sender != address(receiver)) revert GatewayV3_SendMessage_UnauthorizedCaller();
    _;
  }

  /**
   * @notice Checks that an address is non-zero
   * @param _address The address to check
   */
  modifier validAddress(
    bytes32 _address
  ) {
    if (_address == 0) {
      revert GatewayV3_ZeroAddress();
    }
    _;
  }

  constructor() {
    _disableInitializers();
  }

  /*//////////////////////////////////////////////////////////////
                        GATED OWNER FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  function updateHyperlaneMailbox(
    address _newMailbox
  ) external onlyOwner {
    address oldMailbox = hyperlaneMailbox;
    hyperlaneMailbox = _newMailbox;
    emit HyperlaneMailboxUpdated(oldMailbox, _newMailbox);
  }

  function updateCCIPMailbox(
    address _newMailbox
  ) external onlyOwner {
    address oldMailbox = ccipMailbox;
    ccipMailbox = _newMailbox;
    emit CCIPMailboxUpdated(oldMailbox, _newMailbox);
  }

  function updatePolymerMailbox(
    address _newMailbox
  ) external onlyOwner {
    address oldMailbox = polymerMailbox;
    polymerMailbox = _newMailbox;
    emit PolymerMailboxUpdated(oldMailbox, _newMailbox);
  }

  function updatePolymerProver(
    address _newProver
  ) external onlyOwner {
    address oldProver = address(polymerProver);
    polymerProver = IPolymer(_newProver);
    emit PolymerProverUpdated(oldProver, _newProver);
  }

  function setCCIPChainIdMappings(
    uint256[] calldata _ecChainIds,
    uint256[] calldata _ccipChainIds
  ) external onlyOwner {
    if (_ecChainIds.length != _ccipChainIds.length) revert GatewayV3_Domain_ArrayLengthMismatch();
    for (uint256 i = 0; i < _ecChainIds.length; i++) {
      ecToCCIPChainId[_ecChainIds[i]] = _ccipChainIds[i];
      ccipToECId[_ccipChainIds[i]] = _ecChainIds[i];
    }
    emit CCIPMappingsUpdated(_ecChainIds, _ccipChainIds);
  }

  /*//////////////////////////////////////////////////////////////
                        GATED RECEIVER FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  function updateSecurityModule(
    address _newSecurityModule
  ) external onlyReceiver validAddress(_newSecurityModule.toBytes32()) {
    address _oldSecurityModule = address(interchainSecurityModule);
    interchainSecurityModule = IInterchainSecurityModule(_newSecurityModule);
    emit SecurityModuleUpdated(_oldSecurityModule, _newSecurityModule);
  }

  function sendMessage(
    uint32 _chainId,
    bytes calldata _message,
    uint256 _gasLimit
  ) external payable onlyReceiver returns (bytes32 _messageId, uint256 _feeSpent) {
    bytes32 _destinationGateway = _getGateway(_chainId);

    uint256 _initialBalance = address(this).balance;
    _messageId = _sendMessage(_chainId, _message, _gasLimit, _destinationGateway, msg.value);
    _feeSpent = _initialBalance - address(this).balance;
    uint256 _unusedFee = msg.value - _feeSpent;

    if (_unusedFee > 0) {
      (bool _success,) = tx.origin.call{value: _unusedFee}('');
      if (!_success) revert GatewayV3_SendMessage_UnsuccessfulRebate();
    }
  }

  function sendMessage(
    uint32 _chainId,
    bytes calldata _message,
    uint256 _fee,
    uint256 _gasLimit
  ) external onlyReceiver returns (bytes32 _messageId, uint256 _feeSpent) {
    bytes32 _destinationGateway = _getGateway(_chainId);

    if (_fee > address(this).balance) {
      revert GatewayV3_SendMessage_InsufficientBalance();
    }

    uint256 _initialBalance = address(this).balance;
    _messageId = _sendMessage(_chainId, _message, _gasLimit, _destinationGateway, _fee);
    _feeSpent = _initialBalance - address(this).balance;

    emit GasTankSpent(_feeSpent);
  }

  function ccipReceive(
    ICCIP.Any2EVMMessage calldata message
  ) external {
    // only called by mailbox
    if (msg.sender != address(ccipMailbox)) {
      revert GatewayV3_Handle_NotCalledByMailbox();
    }

    uint32 _origin = _convertFromCCIPChainId(message.sourceChainSelector);
    bytes32 _sender = bytes32(message.sender);

    // Calling handler
    _handle(_origin, _sender, message.data);
  }

  function polymerReceive(
    bytes memory _proof
  ) external {
    // Validate proof and extract rate data
    (uint32 _origin, address _sourceContract, bytes memory _topics, bytes memory _data) =
      polymerProver.validateEvent(_proof);

    // parsing the topics into individual bytes
    bytes32[] memory _topicsArray = new bytes32[](3);
    if (_topics.length != 96) revert GatewayV3_Handle_InvalidTopicsLength();

    assembly {
      let topicsPtr := add(_topics, 32)
      for { let i := 0 } lt(i, 3) { i := add(i, 1) } {
        mstore(add(add(_topicsArray, 32), mul(i, 32)), mload(add(topicsPtr, mul(i, 32))))
      }
    }

    // verifying the event signature
    bytes32 expectedSelector = keccak256('Dispatch(uint32,bytes32,bytes)');
    if (_topicsArray[0] != expectedSelector) revert GatewayV3_Handle_InvalidEventSelector();

    // verifying the destination domain is this one
    uint32 _destination = uint32(uint256(_topicsArray[1]));
    if (_destination != block.chainid) revert GatewayV3_Handle_InvalidDestinationDomain();

    // verifying the recipient is this contract
    bytes32 _receiver = _topicsArray[2];
    if (_receiver != address(this).toBytes32()) revert GatewayV3_Handle_InvalidRecipient();

    // replay protection
    bytes32 _uniqueHash = keccak256(abi.encode(_origin, _sourceContract, _topics, _data));
    if (usedUniqueHashes[_uniqueHash]) revert GatewayV3_Handle_ProofAlreadyUsed();
    usedUniqueHashes[_uniqueHash] = true;

    // decoding the non-indexed data
    (bytes memory _message) = abi.decode(_data, (bytes));

    // Calling handler
    _handle(_origin, _sourceContract.toBytes32(), _message);
  }

  function handle(
    uint32 _origin,
    bytes32 _sender,
    bytes calldata _message
  ) external payable {
    // only called by mailbox
    if (msg.sender != address(hyperlaneMailbox) && msg.sender != address(polymerMailbox)) {
      revert GatewayV3_Handle_NotCalledByMailbox();
    }

    _handle(_origin, _sender, _message);
  }

  /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  function quoteMessage(
    uint32 _chainId,
    bytes calldata _message,
    uint256 _gasLimit
  ) external view returns (uint256 _fee) {
    bytes memory _metadata = StandardHookMetadata.formatMetadata(0, _gasLimit, address(this), '');
    bytes32 _gateway = _getGateway(_chainId);
    _fee = IMailbox(hyperlaneMailbox).quoteDispatch(_chainId, _gateway, _message, _metadata);
  }

  /**
   * @notice Initializer for the Gateway upgradeable contract
   * @param _owner The owner of the Gateway contract
   * @param _receiver The local message receiver (EverclearHub / EverclearSpoke)
   * @param _interchainSecurityModule The chosen interchain security module
   * @dev Only called once on deployment and initialization
   */
  function _initializeGateway(
    address _owner,
    address _receiver,
    address _interchainSecurityModule,
    address _polymerProver,
    address _hyperlaneMailbox,
    address _ccipMailbox,
    address _polymerMailbox
  ) internal {
    receiver = IMessageReceiver(_receiver);
    polymerProver = IPolymer(_polymerProver);
    hyperlaneMailbox = _hyperlaneMailbox;
    ccipMailbox = _ccipMailbox;
    polymerMailbox = _polymerMailbox;
    interchainSecurityModule = IInterchainSecurityModule(_interchainSecurityModule);
    __initializeGasTank(_owner);
  }

  /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Handles incoming messages from the mailbox
   * @param _origin The id for the origin domain of the message
   * @param _sender The remote Gateway contract (on the origin domain)
   * @param _message The message payload
   */
  function _handle(
    uint32 _origin,
    bytes32 _sender,
    bytes memory _message
  ) internal {
    // // checking the mailbox calling is configured for the chain
    // address _mailbox = address(_activeMailbox(_origin));
    // if (msg.sender != address(_mailbox)) {
    //   revert GatewayV3_Handle_NotCalledByActiveMailbox();
    // }

    _checkValidSender(_origin, _sender);

    receiver.receiveMessage(_message);
  }

  function _sendMessage(
    uint32 _destDomain,
    bytes memory _message,
    uint256 _gasLimit,
    bytes32 _destGateway,
    uint256 _value
  ) internal returns (bytes32 _messageId) {
    address _mailbox = _activeMailbox(_destDomain);

    if (_mailbox == POLYMER_EMIT_MAILBOX) {
      emit Dispatch(_destDomain, _destGateway, _message);
      bytes32 _selectorHash = keccak256('Dispatch(uint32,bytes32,bytes)');
      return keccak256(abi.encode(block.chainid, address(this), _selectorHash, _destDomain, _destGateway, _message));
    } else {
      uint256 mailboxId;
      if (_mailbox == hyperlaneMailbox && hyperlaneMailbox != address(0)) {
        bytes memory _metadata = StandardHookMetadata.formatMetadata(0, _gasLimit, address(this), '');
        _messageId = IMailbox(hyperlaneMailbox).dispatch{value: _value}(_destDomain, _destGateway, _message, _metadata);
      } else if (_mailbox == polymerMailbox && polymerMailbox != address(0)) {
        bytes memory _metadata = StandardHookMetadata.formatMetadata(0, _gasLimit, address(this), '');
        _messageId = IMailbox(polymerMailbox).dispatch(_destDomain, _destGateway, _message, _metadata);
      } else if (_mailbox == ccipMailbox && ccipMailbox != address(0)) {
        uint64 _destDomainCCIP = _convertToCCIPChainId(_destDomain);
        ICCIP.EVM2AnyMessage memory _evm2AnyMessage = ICCIP.EVM2AnyMessage({
          receiver: abi.encode(_destGateway),
          data: _message,
          tokenAmounts: new ICCIP.EVMTokenAmount[](0),
          feeToken: address(0),
          extraArgs: abi.encodeWithSelector(
            GENERIC_EXTRA_ARGS_V2_TAG, (ICCIP.GenericExtraArgsV2({gasLimit: _gasLimit, allowOutOfOrderExecution: true}))
          )
        });
        _messageId = ICCIP(ccipMailbox).ccipSend{value: _value}(_destDomainCCIP, _evm2AnyMessage);
      } else {
        revert GatewayV3_SendMessage_UnsupportedMailbox();
      }
    }
  }

  /**
   * @notice Converts an Everclear chain ID to a CCIP chain ID
   * @param _ecChainId The Everclear chain ID to convert
   * @return _id The corresponding CCIP chain ID
   */
  function _convertToCCIPChainId(
    uint256 _ecChainId
  ) internal view returns (uint64 _id) {
    _id = uint64(ecToCCIPChainId[_ecChainId]);
    if (_id == 0) revert GatewayV3_Domain_NotFound();
  }

  /**
   * @notice Converts a CCIP chain ID to an Everclear chain ID
   * @param _ccipChainId The CCIP chain ID to convert
   * @return _id The corresponding Everclear chain ID
   */
  function _convertFromCCIPChainId(
    uint256 _ccipChainId
  ) internal view returns (uint32 _id) {
    _id = uint32(ccipToECId[_ccipChainId]);
    if (_id == 0) revert GatewayV3_Domain_NotFound();
  }

  /**
   * @notice Checks that an incoming message is valid
   * @param _origin The id for the origin domain of the message
   * @param _sender The remote Gateway contract (on the origin domain)
   */
  function _checkValidSender(
    uint32 _origin,
    bytes32 _sender
  ) internal view virtual;

  /**
   * @notice Returns the appropriate Gateway address on the destination domain for the message
   * @param _domain The destination domain id
   * @return _gateway The Gateway address
   */
  function _getGateway(
    uint32 _domain
  ) internal view virtual returns (bytes32 _gateway);

  /**
   * @notice Returns the active mailbox address for the given domain
   * @param _domain The domain id
   * @return The active mailbox address
   */
  function _activeMailbox(
    uint32 _domain
  ) internal view virtual returns (address);
}
