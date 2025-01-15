// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {MainnetProductionEnvironment} from '../MainnetProduction.sol';

import {TestnetProductionEnvironment} from '../TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../TestnetStaging.sol';
import {ScriptUtils} from '../utils/Utils.sol';

import {Script} from 'forge-std/Script.sol';

interface IGasmaster {
  function payForGas(
    bytes32 _messageId,
    uint32 _destinationDomain,
    uint256 _gasAmount,
    address _refundAddress
  ) external payable;
}

contract BumpGasBase is Script, ScriptUtils {
  mapping(uint32 _domain => IGasmaster _igp) internal _paymasters;

  uint256 _userPk;
  bytes32 _messageId;
  uint32 _destinationDomain;
  uint256 _gasAmount;
  address _refundAddress;

  error GasmasterNotFound(uint32 _domain);

  function _getInputs() internal {
    _userPk = vm.parseUint(vm.promptSecret('User private key'));
    _messageId = vm.parseBytes32(vm.prompt('Message id'));
    _destinationDomain = uint32(vm.parseUint(vm.prompt('Destination domain')));
    _gasAmount = vm.parseUint(vm.prompt('Gas amount'));

    _refundAddress = vm.addr(_userPk);
  }

  function run() public {
    vm.startBroadcast(_userPk);

    uint32 _domain = uint32(block.chainid);
    IGasmaster _igp = _paymasters[_domain];
    if (address(_igp) == address(0)) {
      revert GasmasterNotFound(_domain);
    }

    _igp.payForGas{value: 0.1 ether}(_messageId, _destinationDomain, _gasAmount, _refundAddress);

    vm.stopBroadcast();
  }
}

contract Staging is BumpGasBase, TestnetStagingEnvironment {
  function setUp() public {
    // https://docs.hyperlane.xyz/docs/reference/contract-addresses
    _paymasters[ETHEREUM_SEPOLIA] = IGasmaster(0x6f2756380FD49228ae25Aa7F2817993cB74Ecc56);
    _paymasters[BSC_TESTNET] = IGasmaster(0x0dD20e410bdB95404f71c5a4e7Fa67B892A5f949);
    _paymasters[EVERCLEAR_DOMAIN] = IGasmaster(0x86fb9F1c124fB20ff130C41a79a432F770f67AFD);

    _getInputs();
  }
}

contract TestnetProduction is BumpGasBase, TestnetProductionEnvironment {
  function setUp() public {
    // https://docs.hyperlane.xyz/docs/reference/contract-addresses
    _paymasters[ETHEREUM_SEPOLIA] = IGasmaster(0x6f2756380FD49228ae25Aa7F2817993cB74Ecc56);
    _paymasters[BSC_TESTNET] = IGasmaster(0x0dD20e410bdB95404f71c5a4e7Fa67B892A5f949);
    _paymasters[EVERCLEAR_DOMAIN] = IGasmaster(0x86fb9F1c124fB20ff130C41a79a432F770f67AFD);

    _getInputs();
  }
}

contract MainnetProduction is BumpGasBase, MainnetProductionEnvironment {
  function setUp() public {
    // https://docs.hyperlane.xyz/docs/reference/contract-addresses
    _paymasters[ARBITRUM_ONE] = IGasmaster(0x3b6044acd6767f017e99318AA6Ef93b7B06A5a22);
    _paymasters[BNB] = IGasmaster(0x78E25e7f84416e69b9339B0A6336EB6EFfF6b451);
    _paymasters[EVERCLEAR_DOMAIN] = IGasmaster(0xb58257cc81E47EC72fD38aE16297048de23163b4);

    _getInputs();
  }
}
