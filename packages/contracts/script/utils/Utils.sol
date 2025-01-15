// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ScriptUtils {
  error InvalidDomain(uint32 _domain);
  error NotImplemented();

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

  function toAsciiString(
    address x
  ) internal pure returns (string memory) {
    bytes memory s = new bytes(40);
    for (uint256 i = 0; i < 20; i++) {
      bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2 ** (8 * (19 - i)))));
      bytes1 hi = bytes1(uint8(b) / 16);
      bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
      s[2 * i] = char(hi);
      s[2 * i + 1] = char(lo);
    }
    return string(s);
  }

  function char(
    bytes1 b
  ) internal pure returns (bytes1 c) {
    if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
    else return bytes1(uint8(b) + 0x57);
  }

  function _checkValidDomain(
    uint32 _domain
  ) internal view {
    if (block.chainid != _domain) {
      revert InvalidDomain(_domain);
    }
  }
}
