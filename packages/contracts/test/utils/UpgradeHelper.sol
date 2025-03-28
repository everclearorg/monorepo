// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { EverclearSpoke, IEverclearSpoke } from 'contracts/intent/EverclearSpoke.sol';
import { EverclearSpokeV3, IEverclearSpokeV3 } from 'contracts/intent/EverclearSpokeV3.sol';
import { IEverclear } from 'interfaces/common/IEverclear.sol';
import { SafeTxBuilder } from 'test/utils/SafeTxBuilder.sol';

interface ICREATE3 {
  function deploy(bytes32 _salt, bytes calldata _creationCode) external payable returns (address _deployed);
}

contract UpgradeHelper is SafeTxBuilder {
  event IntentQueueProcessed(bytes32 indexed _messageId, uint256 _firstIdx, uint256 _lastIdx, uint256 _quote);
  event FillQueueProcessed(bytes32 indexed _messageId, uint256 _firstIdx, uint256 _lastIdx, uint256 _quote);
  event IntentExecuted(
    bytes32 indexed _intentId,
    address indexed _executor,
    address _asset,
    uint256 _amount,
    uint24 _fee
  );

  struct FillIntentParams {
    IEverclear.Intent intent;
    uint24 fee;
    address solver;
  }

  struct ProcessIntentQueueParams {
    uint32 amount;
    address relayer;
    uint256 messageFee;
    uint256 bufferBPS;
  }

  struct ProcessFillQueueParams {
    uint32 amount;
    address solver;
    uint256 messageFee;
    uint256 bufferBPS;
    uint256 length;
    address relayer;
  }

  struct AdditionalParams {
    uint32 destination;
    uint256 i;
    uint32 amount;
  }

  struct CachedSpokeState {
    address permit;
    uint32 EVERCLEAR;
    uint32 DOMAIN;
    address lighthouse;
    address watchtower;
    address messageReceiver;
    address gateway;
    address callExecutor;
    bool paused;
    uint64 nonce;
    uint256 messageGasLimit;
  }

  struct DeploymentParams {
    address owner;
    address spokeProxy;
    address spokeImpl;
  }

  struct DeploymentParamsV3 {
    address owner;
    address spokeProxy;
    address spokeImpl;
    address feeAdapter;
  }

  error Create3DeploymentFailed();
  error UpgradeFailed();

  bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  address constant CREATE_3 = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
  address public SPOKE_PROXY_MAINNET_OWNER = 0xa02a88F0bbD47045001Bd460Ad186C30F9a974d6;
  address public SPOKE_PROXY_MAINNET = 0xa05A3380889115bf313f1Db9d5f335157Be4D816;
  address public SPOKE_IMPL_MAINNET = 0x255aba6E7f08d40B19872D11313688c2ED65d1C9;
  address public SPOKE_GATEWAY_MAINNET = 0x9ADA72CCbAfe94248aFaDE6B604D1bEAacc899A7;
  uint256 public MESSAGE_GAS_LIMIT = 2_000_000;
  address public USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public MAILBOX_MAINNET = 0xc005dc82818d67AF737725bD4bf75435d065D239;
  uint256 public FIXED_MAIN_BLOCK = 21_244_576;
  uint32 constant HUB_ID = 25_327;
  address public HUB_GATEWAY_PROD = 0xEFfAB7cCEBF63FbEFB4884964b12259d4374FaAa;

  EverclearSpoke public spokeProxy;
  DeploymentParams public _params;
  DeploymentParamsV3 public _paramsV3;

  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;
  mapping(uint256 _chainId => DeploymentParamsV3 _params) internal _deploymentParamsV3;

  /**
   * **********************  FeeAdapter Upgrade  **********************
   */
  EverclearSpokeV3 public spokeProxyV3;

  address public SPOKE_IMPL_MAINNET_V2 = 0x7e3667D4dE0B592c78cAa70faC8FE6d5853DfAAc;

  address public FEE_RECIPIENT_MAINNET = SPOKE_PROXY_MAINNET_OWNER;
  uint256 public FEE_SIGNER_PK = 1;
  address public FEE_SIGNER = vm.addr(FEE_SIGNER_PK);
  address XERC20_MODULE_MAINNET;
  uint256 public FIXED_MAIN_BLOCK_UP2 = 22_146_318;

  function _cacheSpokeState() internal view returns (CachedSpokeState memory state) {
    state.permit = address(spokeProxy.PERMIT2());
    state.EVERCLEAR = spokeProxy.EVERCLEAR();
    state.DOMAIN = spokeProxy.DOMAIN();
    state.lighthouse = spokeProxy.lighthouse();
    state.watchtower = spokeProxy.watchtower();
    state.messageReceiver = spokeProxy.messageReceiver();
    state.gateway = address(spokeProxy.gateway());
    state.callExecutor = address(spokeProxy.callExecutor());
    state.paused = spokeProxy.paused();
    state.nonce = spokeProxy.nonce();
    state.messageGasLimit = spokeProxy.messageGasLimit();
  }
  function _cacheSpokeStateV3() internal view returns (CachedSpokeState memory state) {
    state.permit = address(spokeProxyV3.PERMIT2());
    state.EVERCLEAR = spokeProxyV3.EVERCLEAR();
    state.DOMAIN = spokeProxyV3.DOMAIN();
    state.lighthouse = spokeProxyV3.lighthouse();
    state.watchtower = spokeProxyV3.watchtower();
    state.messageReceiver = spokeProxyV3.messageReceiver();
    state.gateway = address(spokeProxyV3.gateway());
    state.callExecutor = address(spokeProxyV3.callExecutor());
    state.paused = spokeProxyV3.paused();
    state.nonce = spokeProxyV3.nonce();
    state.messageGasLimit = spokeProxyV3.messageGasLimit();
  }
}
