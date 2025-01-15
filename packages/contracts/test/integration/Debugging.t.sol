// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// import {console} from 'forge-std/console.sol';

// import { TypeCasts } from 'contracts/common/TypeCasts.sol';

// import { IEverclear } from 'interfaces/common/IEverclear.sol';
// import { IAuctioneer } from 'interfaces/hub/IAuctioneer.sol';

import {TestnetProductionEnvironment} from '../../script/TestnetProduction.sol';
import {TestnetStagingEnvironment} from '../../script/TestnetStaging.sol';
import {TestExtended} from '../utils/TestExtended.sol';

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

// contract TestnetProductionDebugging is TestExtended {
//   function test_hubMessage() public {
//     vm.createSelectFork('https://rpc.everclear.raas.gelato.cloud');
//     address _to = address(0xa05A3380889115bf313f1Db9d5f335157Be4D816);
//     address _from = address(0x6d2A06543D23Cc6523AE5046adD8bb60817E0a94);
//     uint256 _value = 0.000159522263756257 ether;
//     bytes memory _calldata = hex'99b90fcb1b125f3879d4a84843941f410b2d85af5b05e1fa45b4f4098318cd47737bfeb6';
//     vm.prank(_from);
//     (bool _success, bytes memory _ret) = _to.call{value: _value}(_calldata);
//     console.logBytes(_ret);
//     require(_success, string(_ret));
//   }
// }
