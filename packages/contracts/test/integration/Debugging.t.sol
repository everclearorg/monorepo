// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { console } from 'forge-std/console.sol';

// import { TypeCasts } from 'contracts/common/TypeCasts.sol';

import { IEverclear } from 'interfaces/common/IEverclear.sol';
import { IEverclearSpoke } from 'interfaces/intent/IEverclearSpoke.sol';

import { TestnetProductionEnvironment } from '../../script/TestnetProduction.sol';
import { TestnetStagingEnvironment } from '../../script/TestnetStaging.sol';
import { TestExtended } from '../utils/TestExtended.sol';

// contract TestnetStagingDebugging is TestExtended, TestnetStagingEnv {
//   function test_getUnclaimedBalances() public {
//     uint256 sepoliaFork = vm.createSelectFork(vm.rpcUrl('sepolia'));
//     uint256 unclaimed = SEPOLIA_SPOKE.unclaimed(SEPOLIA_TOKEN.toBytes32());
//     console.log('unclaimed sepolia:', unclaimed);
//     vm.createSelectFork(vm.rpcUrl('bsc'));
//     unclaimed = BSC_SPOKE.unclaimed(BNB_TESTNET_TOKEN.toBytes32());
//     console.log('unclaimed bsc:', unclaimed);
//   }
//   function test_bidForSolver() public {
//     vm.createSelectFork(vm.rpcUrl('scroll-sepolia'));
//     address _solver = 0x3acEB2dB94b34af0406C8245F035C47Ab05D7269;
//     uint24 _solverFee = 296;
//     uint256 _nonce = 0;
//     bytes
//       memory _signature = hex'8ea49ae59e6a5d1c8a286810ae09b33201cf803caddd1e54c3b427246c04d5251c906eadb603509206c3fdea077057c9b6c6125fd2e0f9ef414abfc7afb2c4361c';
//     IEverclear.Intent memory _intent = IEverclear.Intent({
//       initiator: 0x0C0e6d63A7933e1C2dE16E1d5E61dB1cA802BF51,
//       receiver: 0x0C0e6d63A7933e1C2dE16E1d5E61dB1cA802BF51,
//       inputAsset: 0x5f921E4DE609472632CEFc72a3846eCcfbed4ed8,
//       outputAsset: 0xd26e3540A0A368845B234736A0700E0a5A821bBA,
//       amount: 125000000000000000000,
//       origin: 97,
//       destination: 11155111,
//       nonce: 8,
//       timestamp: 1718800802,
//       data: bytes(''),
//       maxSolversFee: 500
//     });
//     IAuctioneer(AUCTIONEER).bidForSolver(_solver, _intent, _solverFee, _nonce, _signature);
//   }
// }

contract TestnetProductionDebugging is TestExtended {
  function test_hubMessage() public {
    vm.createSelectFork('https://zircuit-mainnet.drpc.org');
    address _to = address(0xD0E86F280D26Be67A672d1bFC9bB70500adA76fe);
    address _from = address(0x2c4Baf658254C03222AEd94C91E47342669829C5);
    uint256 _value = 0.002 ether;
    uint32[] memory _destinations = new uint32[](1);
    _destinations[0] = uint32(1);
    IEverclear.Intent[] memory _intents = new IEverclear.Intent[](1);
    _intents[0] = IEverclear.Intent({
      initiator: bytes32(0x000000000000000000000000e623934405855449f5539186889860d9da9bc3ec),
      receiver: bytes32(0x000000000000000000000000e623934405855449f5539186889860d9da9bc3ec),
      inputAsset: bytes32(0x0000000000000000000000009346a5043c590133fe900aec643d9622edddba57),
      outputAsset: bytes32(0x000000000000000000000000d7d2802f6b19843ac4dfe25022771fd83b5a7464),
      maxFee: uint24(0),
      origin: uint32(48900),
      nonce: uint64(117),
      timestamp: uint48(1741963819),
      ttl: uint48(0),
      amount: 8026525920369203764,
      destinations: _destinations,
      data: hex'00'
    });
    require(
      keccak256(abi.encode(_intents[0])) == bytes32(0x82bc3df115c087b598572cf8e199ec9046000b174661e53becbd9ac0d036d741),
      'failed id0 generation'
    );

    bytes memory _calldata = abi.encodeWithSelector(IEverclearSpoke.processIntentQueue.selector, _intents);

    vm.prank(_from);
    (bool _success, bytes memory _ret) = _to.call{ value: _value }(_calldata);
    console.logBytes(_calldata);
    require(_success, string(_ret));
  }
}
