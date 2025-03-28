// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { MessageLib } from 'contracts/common/MessageLib.sol';
import { TypeCasts } from 'contracts/common/TypeCasts.sol';
import { FeeAdapter } from 'contracts/intent/FeeAdapter.sol';

import { ISpecifiesInterchainSecurityModule } from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import { EverclearSpokeV3, IEverclearSpokeV3 } from 'contracts/intent/EverclearSpokeV3.sol';
import { ISpokeStorageV3 } from 'interfaces/intent/ISpokeStorageV3.sol';
import { FeeAdapter } from 'contracts/intent/FeeAdapter.sol';
import { IEverclear } from 'interfaces/common/IEverclear.sol';

import { ISettlementModule } from 'interfaces/common/ISettlementModule.sol';
import { ISpokeGateway } from 'interfaces/intent/ISpokeGateway.sol';

import { Deploy } from 'script/utils/Deploy.sol';
import { BaseTest } from 'test/unit/intent/EverclearSpoke.t.sol';
import { Constants } from 'test/utils/Constants.sol';

import { StandardHookMetadata } from '@hyperlane/hooks/libs/StandardHookMetadata.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'forge-std/console.sol';
import { ICREATE3, UpgradeHelper } from 'test//utils/UpgradeHelper.sol';

contract SpokeArrayUpgradeTest is BaseTest, UpgradeHelper {
  using TypeCasts for address;
  using TypeCasts for bytes32;

  FeeAdapter public feeAdapter;

  // ============ Upgrade ============ //
  function test_spokeArrayUpgrade_upgrade() public {
    vm.createSelectFork(vm.envString('MAINNET_RPC'), FIXED_MAIN_BLOCK_UP2);

    // Deploying the feeAdapter
    feeAdapter = new FeeAdapter(
      SPOKE_PROXY_MAINNET,
      FEE_RECIPIENT_MAINNET,
      FEE_SIGNER,
      XERC20_MODULE_MAINNET,
      SPOKE_PROXY_MAINNET_OWNER
    );

    // Checking implementation correct and caching the state variables
    spokeProxyV3 = EverclearSpokeV3(SPOKE_PROXY_MAINNET);
    address oldImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(oldImplementation, SPOKE_IMPL_MAINNET);

    // Caching state variables
    CachedSpokeState memory state = _cacheSpokeState();

    // Generating the inputs for CREATE3
    uint8 version = 3;
    bytes32 _salt = keccak256(abi.encodePacked(SPOKE_PROXY_MAINNET, version));
    bytes32 _implementationSalt = keccak256(abi.encodePacked(_salt, 'implementation'));
    bytes memory _creation = type(EverclearSpokeV3).creationCode;

    // Deploying the new implementation
    bytes memory create3Calldata = abi.encodeWithSelector(ICREATE3.deploy.selector, _implementationSalt, _creation);
    (bool success, bytes memory returnData) = CREATE_3.call(create3Calldata);
    if (!success) revert Create3DeploymentFailed();
    address newEverclearSpoke = abi.decode(returnData, (address));

    // Deploying feeAdapter, impl and upgrading the contract
    success = false;
    bytes memory upgradeCalldata = abi.encodeWithSelector(
      UUPSUpgradeable.upgradeToAndCall.selector,
      newEverclearSpoke,
      address(feeAdapter)
    );

    vm.prank(SPOKE_PROXY_MAINNET_OWNER);
    (success, ) = address(spokeProxyV3).call(upgradeCalldata);
    if (!success) revert UpgradeFailed();

    // Checking the implementation address has updated
    address newImplementation = (vm.load(SPOKE_PROXY_MAINNET, IMPLEMENTATION_SLOT)).toAddress();
    assertEq(newImplementation, newEverclearSpoke);

    // Creating intent
    IEverclear.Intent memory _intent;
    _intent.destinations = new uint32[](11);

    // Checking the new intent function (address) reverts if the caller is not the feeAdapter
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver.toAddress(),
      _intent.inputAsset.toAddress(),
      address(0),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );
    
    // Checking the new intent function (bytes32) reverts if the caller is not the feeAdapter
    vm.expectRevert(ISpokeStorageV3.EverclearSpoke_FeeAdapter_NotAuthorized.selector);
    spokeProxyV3.newIntent(
      _intent.destinations,
      _intent.receiver,
      _intent.inputAsset.toAddress(),
      address(0).toBytes32(),
      _intent.amount,
      _intent.maxFee,
      _intent.ttl,
      _intent.data
    );

    // Checking the cached state
    assertEq(state.permit, address(spokeProxyV3.PERMIT2()));
    assertEq(state.EVERCLEAR, spokeProxyV3.EVERCLEAR());
    assertEq(state.DOMAIN, spokeProxyV3.DOMAIN());
    assertEq(state.lighthouse, spokeProxyV3.lighthouse());
    assertEq(state.watchtower, spokeProxyV3.watchtower());
    assertEq(state.messageReceiver, spokeProxyV3.messageReceiver());
    assertEq(state.gateway, address(spokeProxyV3.gateway()));
    assertEq(state.callExecutor, address(spokeProxyV3.callExecutor()));
    assertEq(state.paused, spokeProxyV3.paused());
    assertEq(state.nonce, spokeProxyV3.nonce());
    assertEq(state.messageGasLimit, spokeProxyV3.messageGasLimit());
  }
}
