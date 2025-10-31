// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ScriptUtils} from '../utils/Utils.sol';

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

import {FeeAdapter} from 'contracts/intent/FeeAdapter.sol';

import {MainnetProductionEnvironment} from '../MainnetProduction.sol';
import {MainnetStagingEnvironment} from '../MainnetStaging.sol';

contract DeployAdapterBase is Script, ScriptUtils {
  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  struct DeploymentParams {
    address spoke;
    address xerc20Module;
    address feeRecipient;
    address feeSigner;
    address owner;
  }

  FeeAdapter internal _feeAdapter;

  error WrongChainId();
  error FeeAdapterMismatch();
  error OwnerMismatch();
  error FeeRecipientMismatch();
  error FeeSignerMismatch();
  error SpokeMismatch();

  function run(
    string memory _account
  ) public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];
    if (
      _params.spoke == address(0) || _params.xerc20Module == address(0) || _params.feeRecipient == address(0)
        || _params.feeSigner == address(0) || _params.owner == address(0)
    ) {
      revert WrongChainId();
    }

    uint256 _deployerPk = vm.envUint(_account);
    address _deployer = vm.addr(_deployerPk);
    uint64 _nonce = vm.getNonce(_deployer);

    vm.startBroadcast(_deployerPk);

    address _expectedFeeAdapter = _addressFrom(_deployer, _nonce);

    // deploy feeAdapter
    _feeAdapter =
      new FeeAdapter(_params.spoke, _params.feeRecipient, _params.feeSigner, _params.xerc20Module, _params.owner);
    if (address(_feeAdapter) != _expectedFeeAdapter) revert FeeAdapterMismatch();

    if (_feeAdapter.owner() != _params.owner) {
      revert OwnerMismatch();
    }

    if (_feeAdapter.feeRecipient() != _params.feeRecipient) {
      revert FeeRecipientMismatch();
    }

    if (address(_feeAdapter.spoke()) != _params.spoke) {
      revert SpokeMismatch();
    }

    if (_feeAdapter.feeSigner() != _params.feeSigner) {
      revert FeeSignerMismatch();
    }

    vm.stopBroadcast();

    console.log('------------------------------------------------');
    console.log('FeeAdapter:', address(_feeAdapter));
    console.log('Chain ID:', block.chainid);
    console.log('------------------------------------------------');
  }
}

contract MainnetProduction is DeployAdapterBase, MainnetProductionEnvironment {
  function setUp() public {
    //// Arbitrum One
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ARBITRUM_ONE_SPOKE),
      xerc20Module: address(ARBITRUM_ONE_XERC20_MODULE),
      feeRecipient: ARBITRUM_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: ARBITRUM_ENG_MULTISIG
    });

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({ // set domain id as mapping key
      spoke: address(OPTIMISM_SPOKE),
      xerc20Module: address(OPTIMISM_XERC20_MODULE),
      feeRecipient: OPTIMISM_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: OPTIMISM_ENG_MULTISIG
    });

    //// Base
    _deploymentParams[BASE] = DeploymentParams({ // set domain id as mapping key
      spoke: address(BASE_SPOKE),
      xerc20Module: address(BASE_XERC20_MODULE),
      feeRecipient: BASE_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: BASE_ENG_MULTISIG
    });

    //// Bnb
    _deploymentParams[BNB] = DeploymentParams({ // set domain id as mapping key
      spoke: address(BNB_SPOKE),
      xerc20Module: address(BNB_XERC20_MODULE),
      feeRecipient: BNB_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: BNB_ENG_MULTISIG
    });

    //// Ethereum
    _deploymentParams[ETHEREUM] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ETHEREUM_SPOKE),
      xerc20Module: address(ETHEREUM_XERC20_MODULE),
      feeRecipient: ETHEREUM_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: ETHEREUM_ENG_MULTISIG
    });

    //// Zircuit
    _deploymentParams[ZIRCUIT] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ZIRCUIT_SPOKE),
      xerc20Module: address(ZIRCUIT_XERC20_MODULE),
      feeRecipient: ZIRCUIT_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: ZIRCUIT_ENG_MULTISIG
    });

    //// Blast
    _deploymentParams[BLAST] = DeploymentParams({ // set domain id as mapping key
      spoke: address(BLAST_SPOKE),
      xerc20Module: address(BLAST_XERC20_MODULE),
      feeRecipient: BLAST_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: BLAST_ENG_MULTISIG
    });

    /// Linea
    _deploymentParams[LINEA] = DeploymentParams({ // set domain id as mapping key
      spoke: address(LINEA_SPOKE),
      xerc20Module: address(LINEA_XERC20_MODULE),
      feeRecipient: LINEA_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: LINEA_ENG_MULTISIG
    });

    /// Polygon
    _deploymentParams[POLYGON] = DeploymentParams({ // set domain id as mapping key
      spoke: address(POLYGON_SPOKE),
      xerc20Module: address(POLYGON_XERC20_MODULE),
      feeRecipient: POLYGON_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: POLYGON_ENG_MULTISIG
    });

    /// Avalanche
    _deploymentParams[AVALANCHE] = DeploymentParams({ // set domain id as mapping key
      spoke: address(AVALANCHE_SPOKE),
      xerc20Module: address(AVALANCHE_XERC20_MODULE),
      feeRecipient: AVALANCHE_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: AVALANCHE_ENG_MULTISIG
    });

    /// zkSync
    _deploymentParams[ZKSYNC] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ZKSYNC_SPOKE),
      xerc20Module: address(ZKSYNC_XERC20_MODULE),
      feeRecipient: ZKSYNC_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: ZKSYNC_ENG_MULTISIG
    });

    // scroll
    _deploymentParams[SCROLL] = DeploymentParams({ // set domain id as mapping key
      spoke: address(SCROLL_SPOKE),
      xerc20Module: address(SCROLL_XERC20_MODULE),
      feeRecipient: SCROLL_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: SCROLL_ENG_MULTISIG
    });

    // taiko
    _deploymentParams[TAIKO] = DeploymentParams({ // set domain id as mapping key
      spoke: address(TAIKO_SPOKE),
      xerc20Module: address(TAIKO_XERC20_MODULE),
      feeRecipient: TAIKO_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: TAIKO_ENG_MULTISIG
    });

    // apechain
    _deploymentParams[APECHAIN] = DeploymentParams({ // set domain id as mapping key
      spoke: address(APECHAIN_SPOKE),
      xerc20Module: address(APECHAIN_XERC20_MODULE),
      feeRecipient: APECHAIN_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: APECHAIN_ENG_MULTISIG
    });

    // unichain
    _deploymentParams[UNICHAIN] = DeploymentParams({ // set domain id as mapping key
      spoke: address(UNICHAIN_SPOKE),
      xerc20Module: address(UNICHAIN_XERC20_MODULE),
      feeRecipient: UNICHAIN_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: UNICHAIN_ENG_MULTISIG
    });

    // ronin
    _deploymentParams[RONIN] = DeploymentParams({
      spoke: address(RONIN_SPOKE),
      xerc20Module: address(RONIN_XERC20_MODULE),
      feeRecipient: RONIN_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: RONIN_ENG_MULTISIG
    });

    // mode
    _deploymentParams[MODE] = DeploymentParams({
      spoke: address(MODE_SPOKE),
      xerc20Module: address(MODE_XERC20_MODULE),
      feeRecipient: MODE_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: MODE_ENG_MULTISIG
    });

    // berachain
    _deploymentParams[BERACHAIN] = DeploymentParams({
      spoke: address(BERACHAIN_SPOKE),
      xerc20Module: address(BERACHAIN_XERC20_MODULE),
      feeRecipient: BERACHAIN_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: BERACHAIN_ENG_MULTISIG
    });

    // mantle
    _deploymentParams[MANTLE] = DeploymentParams({
      spoke: address(MANTLE_SPOKE),
      xerc20Module: address(MANTLE_XERC20_MODULE),
      feeRecipient: MANTLE_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: MANTLE_ENG_MULTISIG
    });

    // sonic
    _deploymentParams[SONIC] = DeploymentParams({
      spoke: address(SONIC_SPOKE),
      xerc20Module: address(SONIC_XERC20_MODULE),
      feeRecipient: SONIC_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: SONIC_ENG_MULTISIG
    });

    // ink
    _deploymentParams[INK] = DeploymentParams({
      spoke: address(INK_SPOKE),
      xerc20Module: address(INK_XERC20_MODULE),
      feeRecipient: INK_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: INK_ENG_MULTISIG
    });

    // gnosis
    _deploymentParams[GNOSIS] = DeploymentParams({
      spoke: address(GNOSIS_SPOKE),
      xerc20Module: address(GNOSIS_XERC20_MODULE),
      feeRecipient: GNOSIS_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: GNOSIS_ENG_MULTISIG
    });
  }
}

contract MainnetStaging is DeployAdapterBase, MainnetStagingEnvironment {
  function setUp() public {
    //// Arbitrum One
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ARBITRUM_ONE_SPOKE),
      xerc20Module: address(ARBITRUM_ONE_XERC20_MODULE),
      feeRecipient: ARBITRUM_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: ARBITRUM_ENG_MULTISIG
    });

    //// Optimism
    _deploymentParams[OPTIMISM] = DeploymentParams({ // set domain id as mapping key
      spoke: address(OPTIMISM_SPOKE),
      xerc20Module: address(OPTIMISM_XERC20_MODULE),
      feeRecipient: OPTIMISM_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: OPTIMISM_ENG_MULTISIG
    });

    //// Base
    _deploymentParams[BASE] = DeploymentParams({ // set domain id as mapping key
      spoke: address(BASE_SPOKE),
      xerc20Module: address(BASE_XERC20_MODULE),
      feeRecipient: BASE_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: BASE_ENG_MULTISIG
    });

    // Arbitrum
    _deploymentParams[ARBITRUM_ONE] = DeploymentParams({ // set domain id as mapping key
      spoke: address(ARBITRUM_ONE_SPOKE),
      xerc20Module: address(ARBITRUM_ONE_XERC20_MODULE),
      feeRecipient: ARBITRUM_ENG_MULTISIG,
      feeSigner: L2_FEE_SIGNER,
      owner: ARBITRUM_ENG_MULTISIG
    });
  }
}
