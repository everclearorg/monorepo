// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';
import {TestExtended} from 'test/utils/TestExtended.sol';
import {Deploy} from 'utils/Deploy.sol';

import {EverclearHub, IEverclearHub} from 'contracts/hub/EverclearHub.sol';
import {HubGateway} from 'contracts/hub/HubGateway.sol';
import {EverclearSpoke, IEverclearSpoke} from 'contracts/intent/EverclearSpoke.sol';
import {SpokeGateway} from 'contracts/intent/SpokeGateway.sol';

import {IInterchainSecurityModule} from '@hyperlane/interfaces/IInterchainSecurityModule.sol';
import {IMessageReceiver} from 'interfaces/common/IMessageReceiver.sol';
import {ISpokeStorage} from 'interfaces/intent/ISpokeStorage.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

contract Upgrades_Test is TestExtended {
  using stdStorage for StdStorage;

  address deployer = makeAddr('deployer');
  bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  event Upgraded(address indexed implementation);
  event Initialized(uint64 version);

  function _getImplementationAddress(
    address _target
  ) internal returns (address _implementation) {
    bytes32 _implAsB32 = vm.load(address(_target), IMPLEMENTATION_SLOT);
    _implementation = address(uint160(uint256(_implAsB32)));
  }
}

contract Unit_EverclearSpoke_Upgrades_Test is Upgrades_Test {
  /**
   * @notice Tests the deployment of an EverclearSpoke contract
   * @param _init The initialization parameters for the spoke
   */
  function test_EverclearSpoke_DeployUpgradeable(
    ISpokeStorage.SpokeInitializationParams calldata _init
  ) public {
    vm.assume(_init.owner != address(0));
    address _implPredicted = _addressFrom(deployer, 0);
    address _proxyPredicted = _addressFrom(deployer, 1);

    // is event emitted?
    _expectEmit(_proxyPredicted);
    emit Upgraded(_implPredicted);

    // is event emitted?
    _expectEmit(_proxyPredicted);
    emit Initialized(1);

    vm.startPrank(deployer); // nonce 0

    // deploy both contracts, get proxy address
    EverclearSpoke _spokeProxy = Deploy.EverclearSpokeProxy(_init);

    vm.stopPrank(); // nonce 2

    // do implementation addresses match?
    assertEq(_getImplementationAddress(address(_spokeProxy)), _implPredicted, 'Implementation addresses mismatch');

    // do proxy addresses match?
    assertEq(_proxyPredicted, address(_spokeProxy), 'Proxies addresses mismatch');
  }

  /**
   * @notice Tests the upgrade of an EverclearSpoke contract
   * @param _init The initialization parameters for the spoke
   * @param _newImpl The new implementation address
   */
  function test_EverclearSpoke_UpgradeContract(
    ISpokeStorage.SpokeInitializationParams calldata _init,
    address _newImpl
  ) public {
    vm.assume(_init.owner != address(0));
    assumeNotPrecompile(_newImpl);
    assumeNotForgeAddress(_newImpl);

    // deploy proxy + implementation
    vm.startPrank(deployer);
    EverclearSpoke _spokeProxy = Deploy.EverclearSpokeProxy(_init);
    vm.stopPrank();

    // mock that `_newImpl` implements UUPS
    vm.mockCall(
      address(_newImpl), abi.encodeWithSelector(UUPSUpgradeable.proxiableUUID.selector), abi.encode(IMPLEMENTATION_SLOT)
    );

    // check that the event is emitted
    _expectEmit(address(_spokeProxy));
    emit Upgraded(_newImpl);

    vm.prank(_init.owner);
    _spokeProxy.upgradeToAndCall(_newImpl, '');
  }
}

contract Unit_SpokeGateway_Upgrades_Test is Upgrades_Test {
  /**
   * @notice Tests the deployment of a SpokeGateway contract
   * @param _owner The owner of the gateway
   * @param _everclearSpoke The spoke contract address
   * @param _mailbox The mailbox contract address
   * @param _securityModule The security module contract address
   * @param _hubChainId The chain ID of the hub
   * @param _hubGateway The gateway address of the hub
   */
  function test_SpokeGateway_DeployUpgradeable(
    address _owner,
    address _everclearSpoke,
    address _mailbox,
    address _securityModule,
    uint32 _hubChainId,
    bytes32 _hubGateway
  ) public {
    vm.assume(_owner != address(0) && address(_everclearSpoke) != address(0)); // owner

    address _implPredicted = _addressFrom(deployer, 0);
    address _proxyPredicted = _addressFrom(deployer, 1);

    // is event emitted?
    _expectEmit(_proxyPredicted);
    emit Upgraded(_implPredicted);

    // is event emitted?
    _expectEmit(_proxyPredicted);
    emit Initialized(1);

    vm.startPrank(deployer); // nonce 0

    // deploy both contracts, get proxy address
    SpokeGateway _gatewayProxy =
      Deploy.SpokeGatewayProxy(_owner, _mailbox, _everclearSpoke, _securityModule, _hubChainId, _hubGateway);

    vm.stopPrank(); // nonce 2

    // do implementation addresses match?
    assertEq(_getImplementationAddress(address(_gatewayProxy)), _implPredicted, 'Implementation addresses mismatch');

    // do proxy addresses match?
    assertEq(_proxyPredicted, address(_gatewayProxy), 'Proxies addresses mismatch');
  }

  /**
   * @notice Tests the upgrade of a SpokeGateway contract
   * @param _owner The owner of the gateway
   * @param _everclearSpoke The spoke contract address
   * @param _mailbox The mailbox contract address
   * @param _securityModule The security module contract address
   * @param _newImpl The new implementation address
   * @param _hubChainId The chain ID of the hub
   * @param _hubGateway The gateway address of the hub
   */
  function test_SpokeGateway_UpgradeContract(
    address _owner,
    address _everclearSpoke,
    address _mailbox,
    address _securityModule,
    address _newImpl,
    uint32 _hubChainId,
    bytes32 _hubGateway
  ) public {
    vm.assume(_owner != address(0) && address(_everclearSpoke) != address(0)); // owner
    assumeNotPrecompile(_newImpl);
    assumeNotForgeAddress(_newImpl);

    // deploy proxy + implementation
    vm.startPrank(deployer);
    SpokeGateway _gatewayProxy =
      Deploy.SpokeGatewayProxy(_owner, _mailbox, _everclearSpoke, _securityModule, _hubChainId, _hubGateway);
    vm.stopPrank();

    // mock that `_newImpl` implements UUPS
    vm.mockCall(
      address(_newImpl), abi.encodeWithSelector(UUPSUpgradeable.proxiableUUID.selector), abi.encode(IMPLEMENTATION_SLOT)
    );

    // check that the event is emitted
    _expectEmit(address(_gatewayProxy));
    emit Upgraded(_newImpl);

    vm.prank(_owner);
    _gatewayProxy.upgradeToAndCall(_newImpl, '');
  }
}

contract Unit_HubGateway_Upgrades_Test is Upgrades_Test {
  /**
   * @notice Tests the deployment of a HubGateway contract
   * @param _owner The owner of the gateway
   * @param _mailbox The mailbox contract address
   * @param _everclearHub The hub contract address
   * @param _securityModule The security module contract address
   */
  function test_HubGateway_DeployUpgradeable(
    address _owner,
    address _mailbox,
    address _everclearHub,
    address _securityModule
  ) public {
    vm.assume(_owner != address(0) && address(_everclearHub) != address(0)); // owner

    address _implPredicted = _addressFrom(deployer, 0);
    address _proxyPredicted = _addressFrom(deployer, 1);

    // is event emitted?
    _expectEmit(_proxyPredicted);
    emit Upgraded(_implPredicted);

    // is event emitted?
    _expectEmit(_proxyPredicted);
    emit Initialized(1);

    vm.startPrank(deployer); // nonce 0

    // deploy both contracts, get proxy address
    HubGateway _gatewayProxy = Deploy.HubGatewayProxy(_owner, _mailbox, _everclearHub, _securityModule);

    vm.stopPrank(); // nonce 2

    // do implementation addresses match?
    assertEq(_getImplementationAddress(address(_gatewayProxy)), _implPredicted, 'Implementation addresses mismatch');

    // do proxy addresses match?
    assertEq(_proxyPredicted, address(_gatewayProxy), 'Proxies addresses mismatch');
  }

  /**
   * @notice Tests the upgrade of a HubGateway contract
   * @param _mailbox The mailbox contract address
   * @param _everclearHub The hub contract address
   * @param _securityModule The security module contract address
   * @param _newImpl The new implementation address
   */
  function test_HubGateway_UpgradeContract(
    address _owner,
    address _mailbox,
    address _everclearHub,
    address _securityModule,
    address _newImpl
  ) public {
    vm.assume(_owner != address(0) && address(_everclearHub) != address(0)); // owner
    assumeNotPrecompile(_newImpl);
    assumeNotForgeAddress(_newImpl);

    // deploy proxy + implementation
    vm.startPrank(deployer);
    HubGateway _gatewayProxy = Deploy.HubGatewayProxy(_owner, _mailbox, _everclearHub, _securityModule);
    vm.stopPrank();

    // mock that `_newImpl` implements UUPS
    vm.mockCall(
      address(_newImpl), abi.encodeWithSelector(UUPSUpgradeable.proxiableUUID.selector), abi.encode(IMPLEMENTATION_SLOT)
    );

    // check that the event is emitted
    _expectEmit(address(_gatewayProxy));
    emit Upgraded(_newImpl);

    vm.prank(_owner);
    _gatewayProxy.upgradeToAndCall(_newImpl, '');
  }
}

contract Unit_EverclearHub_Upgrades_Test is Upgrades_Test {
  /**
   * @notice Tests the deployment of an EverclearHub contract
   * @param _init The initialization parameters for the hub
   */
  function test_EverclearHub_DeployUpgradeable(
    IEverclearHub.HubInitializationParams calldata _init
  ) public {
    address _implPredicted = _addressFrom(deployer, 0);
    address _proxyPredicted = _addressFrom(deployer, 1);

    // is event emitted?
    _expectEmit(_proxyPredicted);
    emit Upgraded(_implPredicted);

    // is event emitted?
    _expectEmit(_proxyPredicted);
    emit Initialized(1);

    vm.startPrank(deployer); // nonce 0

    // deploy both contracts, get proxy address
    EverclearHub _hubProxy = Deploy.EverclearHubProxy(_init);

    vm.stopPrank(); // nonce 2

    // do implementation addresses match?
    assertEq(_getImplementationAddress(address(_hubProxy)), _implPredicted, 'Implementation addresses mismatch');

    // do proxy addresses match?
    assertEq(_proxyPredicted, address(_hubProxy), 'Proxies addresses mismatch');
  }

  /**
   * @notice Tests the upgrade of an EverclearHub contract
   * @param _init The initialization parameters for the hub
   * @param _newImpl The new implementation address
   */
  function test_EverclearHub_UpgradeContract(
    IEverclearHub.HubInitializationParams calldata _init,
    address _newImpl
  ) public {
    assumeNotPrecompile(_newImpl);
    assumeNotForgeAddress(_newImpl);

    // deploy proxy + implementation
    vm.startPrank(deployer);
    EverclearHub _hubProxy = Deploy.EverclearHubProxy(_init);
    vm.stopPrank();

    // mock that `_newImpl` implements UUPS
    vm.mockCall(
      address(_newImpl), abi.encodeWithSelector(UUPSUpgradeable.proxiableUUID.selector), abi.encode(IMPLEMENTATION_SLOT)
    );

    // check that the event is emitted
    _expectEmit(address(_hubProxy));
    emit Upgraded(_newImpl);

    vm.prank(address(_init.owner));
    _hubProxy.upgradeToAndCall(_newImpl, '');
  }
}
