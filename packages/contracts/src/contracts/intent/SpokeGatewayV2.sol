// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {GatewayV3} from 'contracts/common/GatewayV3.sol';

import {IMailbox} from '@hyperlane/interfaces/IMailbox.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {IPolymer} from 'interfaces/common/IPolymer.sol';
import {ISpokeGatewayV2} from 'interfaces/intent/ISpokeGatewayV2.sol';

contract SpokeGateway is GatewayV3, UUPSUpgradeable, ISpokeGatewayV2 {
  using TypeCasts for address;

  uint32 public EVERCLEAR_ID;
  bytes32 public EVERCLEAR_GATEWAY;

  /**
   * Configurable Mailbox Update  ************************
   */
  address public constant POLYMER_ADDRESS = address(0x1);
  address public hyperlaneMailbox;
  address public ccipMailbox;
  IPolymer public polymerProver;
  uint256 private _nonce;

  mapping(uint256 => uint256) public ecToCCIPChainId;
  mapping(uint256 => uint256) public ccipToECId;
  mapping(bytes32 => bool) public usedProofHashes;

  constructor() GatewayV3() {}

  /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISpokeGatewayV2
  function initialize(
    address _polymerProver,
    address _hyperlaneMailbox,
    address _ccipMailbox
  ) external reinitializer(2) onlyOwner {
    polymerProver = IPolymer(_polymerProver);
    hyperlaneMailbox = _hyperlaneMailbox;
    ccipMailbox = _ccipMailbox;
  }

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

  function setCCIPChainIdMappings(uint256[] calldata _ecChainIds, uint256[] calldata _ccipChainIds) external onlyOwner {
    if (_ecChainIds.length != _ccipChainIds.length) revert GatewayV3_Domain_ArrayLengthMismatch();
    for (uint256 i = 0; i < _ecChainIds.length; i++) {
      ecToCCIPChainId[_ecChainIds[i]] = _ccipChainIds[i];
      ccipToECId[_ccipChainIds[i]] = _ecChainIds[i];
    }
    emit CCIPMappingsUpdated(_ecChainIds, _ccipChainIds);
  }

  /*//////////////////////////////////////////////////////////////
                        HANDLER FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  function ccipReceive(
    Any2EVMMessage calldata message
  ) external {
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
    bytes32[] memory topicsArray = new bytes32[](3);
    if (_topics.length < 96) revert GatewayV3_Handle_InvalidTopicsLength();

    assembly {
      let topicsPtr := add(_topics, 32)
      for { let i := 0 } lt(i, 3) { i := add(i, 1) } {
        mstore(add(add(topicsArray, 32), mul(i, 32)), mload(add(topicsPtr, mul(i, 32))))
      }
    }

    // verifying the event signature
    bytes32 expectedSelector = keccak256('Dispatch(uint32, bytes32, bytes)');
    if (topicsArray[0] != expectedSelector) revert GatewayV3_Handle_InvalidEventSelector();

    // verifying the destination domain is this one
    uint32 destination = uint32(uint256(topicsArray[1]));
    if (destination != block.chainid) revert GatewayV3_Handle_InvalidDestinationDomain();

    // verifying the recipient is this contract
    bytes32 receiver = topicsArray[2];
    if (receiver != address(this).toBytes32()) revert GatewayV3_Handle_InvalidRecipient();

    // decoding the non-indexed data
    (bytes memory _message) = abi.decode(_data, (bytes));

    // replay protection
    bytes32 proofHash = keccak256(abi.encodePacked(_origin, _sourceContract, _topics, _data, _nonce++));
    if (usedProofHashes[proofHash]) revert GatewayV3_Handle_ProofAlreadyUsed();
    usedProofHashes[proofHash] = true;

    // Calling handler
    _handle(_origin, _sourceContract.toBytes32(), _message);
  }

  function handle(uint32 _origin, bytes32 _sender, bytes calldata _message) external payable {
    _handle(_origin, _sender, _message);
  }

  /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Checks that the upgrade function is called by the owner
   */
  function _authorizeUpgrade(
    address
  ) internal override onlyOwner {}

  function _sendMessage(uint256 _destDomain, bytes memory _message, uint256 _gasLimit, bytes32 _destGateway) internal {
    address _mailbox = mailbox;
    if (_mailbox == POLYMER_ADDRESS) {
      emit Dispatch(_destDomain, _destGateway, _message);
    } else {
      uint256 mailboxId;
      if (_mailbox == hyperlaneMailbox && hyperlaneMailbox != address(0)) mailboxId = HL_ID;
      else if (_mailbox == ccipMailbox && ccipMailbox != address(0)) mailboxId = CCIP_ID;
      else revert GatewayV3_SendMessage_UnsupportedMailbox();

      bytes memory _calldata = _constructCalldata(mailboxId, _destDomain, _destGateway, _message, _gasLimit);
      (bool success,) = _mailbox.call{value: msg.value}(_calldata);
      if (!success) revert GatewayV3_SendMessage_CallFailure();
    }
  }

  function _handle(uint32 _origin, bytes32 _sender, bytes memory _message) internal override {
    // only called by mailbox
    if (msg.sender != address(hyperlaneMailbox)) {
      revert GatewayV3_Handle_NotCalledByMailbox();
    }

    _checkValidSender(_origin, _sender);

    receiver.receiveMessage(_message);
  }

  /*//////////////////////////////////////////////////////////////
                        INTERNAL VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Always returns the address for the HubGateway on the Everclear domain
   * @return _gateway The address of the everyclear gateway
   */
  function _getGateway(
    uint32
  ) internal view override(GatewayV3) returns (bytes32 _gateway) {
    return EVERCLEAR_GATEWAY;
  }

  /**
   * @notice Checks that the incoming message was sent by the HubGateway on the Everclear domain
   * @param _origin The origin domain of the message
   * @param _sender The sender of the message
   */
  function _checkValidSender(uint32 _origin, bytes32 _sender) internal view override(GatewayV3) {
    if (_origin != EVERCLEAR_ID) revert GatewayV3_Handle_InvalidOriginDomain();
    if (_sender != EVERCLEAR_GATEWAY) revert GatewayV3_Handle_InvalidSender();
  }

  function _convertFromCCIPChainId(
    uint256 _ccipChainId
  ) internal view returns (uint32 _id) {
    _id = uint32(ccipToECId[_ccipChainId]);
    if (_id == 0) revert GatewayV3_Domain_NotFound();
  }

  function _convertToCCIPChainId(
    uint256 _ecChainId
  ) internal view returns (uint64 _id) {
    _id = uint64(ecToCCIPChainId[_ecChainId]);
    if (_id == 0) revert GatewayV3_Domain_NotFound();
  }

  function _activeMailbox(
    uint32
  ) internal view override returns (IMailbox) {
    revert GatewayV3_ActiveMailbox_NotSupported();
  }
}
