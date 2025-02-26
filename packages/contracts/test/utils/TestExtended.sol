// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {TestERC20} from './TestERC20.sol';
import {XERC20} from './TestXToken.sol';
import {XERC20Lockbox} from './TestLockbox.sol';
import {Mocker} from './mocks/Mocker.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {MessageHashUtils} from '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';

import {TypeCasts} from 'contracts/common/TypeCasts.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';
import {VmSafe} from 'forge-std/Vm.sol';

import {Mocker} from './mocks/Mocker.sol';

import {IEverclear} from 'interfaces/common/IEverclear.sol';
import {IXERC20} from 'interfaces/common/IXERC20.sol';

contract TestExtended is Mocker {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  uint256 public constant BLOCK_TIME = 12 seconds;
  uint256 public constant MAX_FUZZED_ARRAY_LENGTH = 10;

  modifier validAddress(
    address _address
  ) {
    vm.assume(_address != address(0));
    _;
  }

  modifier nonContract(
    address _address
  ) {
    uint32 size;
    assembly {
      size := extcodesize(_address)
    }
    vm.assume(size == 0);
    _;
  }

  modifier validAndDifferentAddresses(address _address1, address _address2) {
    _validAndDifferentAddresses(_address1, _address2);
    _;
  }

  function _mineBlock() internal {
    _mineBlocks(1);
  }

  function _mineBlocks(
    uint256 _blocks
  ) internal {
    vm.warp(block.timestamp + _blocks * BLOCK_TIME);
    vm.roll(block.number + _blocks);
  }

  function _expectEmit(
    address _contract
  ) internal {
    vm.expectEmit(true, true, true, true, _contract);
  }

  function _addressFrom(address _origin, uint256 _nonce) internal pure returns (address _address) {
    bytes memory _data;
    if (_nonce == 0x00) {
      _data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, bytes1(0x80));
    } else if (_nonce <= 0x7f) {
      _data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), _origin, uint8(_nonce));
    } else if (_nonce <= 0xff) {
      _data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), _origin, bytes1(0x81), uint8(_nonce));
    } else if (_nonce <= 0xffff) {
      _data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), _origin, bytes1(0x82), uint16(_nonce));
    } else if (_nonce <= 0xffffff) {
      _data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), _origin, bytes1(0x83), uint24(_nonce));
    } else {
      _data = abi.encodePacked(bytes1(0xda), bytes1(0x94), _origin, bytes1(0x84), uint32(_nonce));
    }

    bytes32 _hash = keccak256(_data);
    assembly {
      mstore(0, _hash)
      _address := mload(0)
    }
  }

  function deployAndDeal(bytes32 _receiver, uint256 _amount) public returns (bytes32 _token) {
    _token = deployAndDeal(_receiver.toAddress(), _amount);
  }

  function deployAndDeal(address _receiver, uint256 _amount) public returns (bytes32 _token) {
    address _tokenAddress = address(new TestERC20('Token', 'TKN'));
    deal(_tokenAddress, _receiver, _amount);
    _token = _tokenAddress.toBytes32();
  }

  function deployAndDealXERC20Native(bytes32 _receiver, uint256 _amount) public returns (bytes32 _nativeToken, bytes32 _xerc20Token) {
    _nativeToken = deployAndDeal(_receiver, _amount);
    _xerc20Token = deployXERC20(_nativeToken);
  }

  function deployXERC20(bytes32 _nativeToken) public returns (bytes32 _xerc20Token) {
    // Deploy the XERC20 token
    address _tokenAddress = address(new XERC20('TokenX', 'TKNX', address(this)));
    _xerc20Token = _tokenAddress.toBytes32();

    // Deploy Lockbox
    address _lockboxAddress = address(new XERC20Lockbox(_xerc20Token.toAddress(), _nativeToken.toAddress(), false));
    IXERC20(_tokenAddress).setLockbox(_lockboxAddress);
  }

  function _validAndDifferentAddresses(address _address1, address _address2) internal pure {
    vm.assume(_address1 != address(0) && _address2 != address(0) && _address1 != _address2);
  }

  function _formatHLMessage(
    uint8 _version,
    uint32 _nonce,
    uint32 _originDomain,
    bytes32 _sender,
    uint32 _destinationDomain,
    bytes32 _recipient,
    bytes memory _messageBody
  ) internal pure returns (bytes memory) {
    return abi.encodePacked(_version, _nonce, _originDomain, _sender, _destinationDomain, _recipient, _messageBody);
  }

  function _createSignature(
    uint256 _solverPk,
    bytes32 _hash
  ) internal pure returns (bytes memory _signature, address _solver) {
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(_solverPk, MessageHashUtils.toEthSignedMessageHash(_hash));
    _signature = abi.encodePacked(_r, _s, _v);
    _solver = vm.addr(_solverPk);
  }

  function _limitDestinationLengthTo10(
    IEverclear.Intent memory _intent
  ) internal pure returns (IEverclear.Intent memory) {
    if (_intent.destinations.length < 10) return _intent;
    uint32[] memory _destinations = new uint32[](10);
    for (uint256 i; i < 10; i++) {
      _destinations[i] = _intent.destinations[i];
    }

    _intent.destinations = _destinations;
    return _intent;
  }
}
