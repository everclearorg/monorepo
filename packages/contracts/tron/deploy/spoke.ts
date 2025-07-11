// Run command: yarn ts-node --files --project tsconfig.json tron/deploy/spoke.ts
import * as TronWeb from 'tronweb';
import dotenv from 'dotenv';
dotenv.config();
import { Interface } from '@ethersproject/abi';

// The JSON artifacts produced by TronBox or another compiler
import EverclearSpokeArtifact from '../build/contracts/EverclearSpoke.json';
import SpokeGatewayArtifact from '../build/contracts/SpokeGateway.json';
import ERC1967ProxyArtifact from '../build/contracts/ERC1967Proxy.json';
import CallExecutorArtifact from '../build/contracts/CallExecutor.json';
import MessageReceiverArtifact from '../build/contracts/SpokeMessageReceiver.json';

const tronWeb = new TronWeb.TronWeb({
  fullHost: process.env.TRON_MAINNET_RPC!,
  privateKey: process.env.TRON_KEY,
});

interface DeploymentParams {
  gateway: string;
  executor: string;
  messageReceiver: string;
  lighthouse: string;
  watchtower: string;
  ism: string;
  mailbox: string;
  hubDomain: number;
  hubGateway: string;
  owner: string;
  maxSolversFee: number;
}

// Global //
const POLYMER_ISM: string = '41cbcbc532cf88bacf1c8a6359604c784d042bb692';
const POLYMER_MAILBOX: string = '415b34081e9d453fc2ba925d893583d89d1b7175dd';
const MESSAGE_RECEIVER: string = '4147120c330314b3929b3efa22234a069f84e2c80d';
const CALL_EXECUTOR: string = '41902fdfc8e489100aadfc982d7c5144253b5dfb81';
const GATEWAY_IMPL: string = '417039676630aba9606afa13bfb4b822d67c05282a';
const SPOKE_IMPL: string = 'TRooMrhE5VP2JFRyBf74fqMijMGx8usXuX';
const tronLighthouse: string = 'TFAJBqyUQmudXW1fanNN4a5V76qEDTouT7';
const tronWatchtower: string = 'TJx4rVn6Nf2P1ZL9m5G737EYLD3BQdF7rj';
const tronOwner: string = 'TATCzhQqxq9DRppGHiEFvFuoDW6tHaESqg'; // NOTE: Using EOA to enable the update of the gateway
const tronMaxSolversFee: number = 5000;
const hubDomain: number = 25327;
const tronIsm: string = POLYMER_ISM;
const tronMailbox: string = POLYMER_MAILBOX;

// Production // 
const SPOKE_PROD: string = '419b266df36c882a73d45b18876104d5728424828f';
const hubGatewayProd: string = '41EFfAB7cCEBF63FbEFB4884964b12259d4374FaAa';
const HUB_GATEWAY_PROD = '0x000000000000000000000000effab7ccebf63fbefb4884964b12259d4374faaa';

// Staging //
const SPOKE_STAGING: string = '41d84173290e0e486b12b973f704cddef6e46a308e';
const hubGatewayStaging: string = '41e5f2f4afad6211cfbd6a882d5a6a435530ee3909'; // 0xe5F2F4afAd6211cfBD6a882D5a6a435530Ee3909
const HUB_GATEWAY_STAGING = '0x000000000000000000000000e5f2f4afad6211cfbd6a882d5a6a435530ee3909';

function configureDeploymentParameters(): DeploymentParams {
  return {
    gateway: 'TATCzhQqxq9DRppGHiEFvFuoDW6tHaESqg', // TODO: Need to change to valid address on Spoke via a call
    executor: CALL_EXECUTOR,
    messageReceiver: MESSAGE_RECEIVER,
    lighthouse: tronLighthouse,
    watchtower: tronWatchtower,
    ism: tronIsm,
    mailbox: tronMailbox,
    hubDomain: hubDomain,
    hubGateway: hubGatewayStaging,
    owner: tronOwner,
    maxSolversFee: tronMaxSolversFee,
  };
}

async function deployContract(abi: unknown[], bytecode: string, constructorArgs: unknown[] = []): Promise<string> {
  // Calculating and logging resource usage
  const deployTx = await tronWeb.transactionBuilder.createSmartContract({
    abi,
    bytecode,
    feeLimit: 1_000_000_000,
  });
  await calculateResourceUsage(tronWeb.defaultAddress.base58, deployTx.raw_data_hex);

  const contractInstance = await tronWeb.contract().new({
    abi,
    bytecode,
    feeLimit: 1_000_000_000,
    callValue: 0,
    parameters: constructorArgs,
  });
  return contractInstance.address;
}

/**
 * Deploy a UUPS-like proxy approach:
 * 1) Deploy the impl
 * 2) Encode an "initialize" call
 * 3) Deploy the proxy with that init call
 */
async function deploySpokeProxy(
  implAbi: unknown[],
  implBytecode: string,
  proxyAbi: unknown[],
  proxyBytecode: string,
  params: DeploymentParams,
): Promise<string> {
  // 1) Deploy the implementation
  // const implAddress = await deployContract(implAbi, implBytecode);
  // console.log(`Implementation deployed at ${implAddress}`);

  // 2) Deploy the proxy, passing (implementation, initCall) to constructor
  const implAddress = SPOKE_IMPL;
  const contractInstance = await tronWeb.contract().new({
    abi: proxyAbi,
    bytecode: proxyBytecode,
    feeLimit: 1_000_000_000,
    callValue: 0,
    parameters: [implAddress, '0x'],
  });
  const proxyAddress = contractInstance.address;

  // 3) Call the initialize function on the proxy
  console.log('Initializing Spoke...');
  const spokeInstance = await tronWeb.contract(implAbi, proxyAddress);

  // Initialize the spoke
  await spokeInstance
    .initialize([
      params.gateway,
      params.executor,
      params.messageReceiver,
      params.lighthouse,
      params.watchtower,
      params.hubDomain,
      params.owner,
    ])
    .send({
      feeLimit: 1_000_000_000,
    });

  return proxyAddress;
}

function toEthHex(tronAddr: string): `0x${string}` {
  const hex41 = tronWeb.address.toHex(tronAddr);
  return ('0x' + hex41.slice(2)) as `0x${string}`; // drop the 0x41 prefix
}

async function deployGatewayProxy(
  implAbi: unknown[],
  implBytecode: string,
  proxyAbi: unknown[],
  proxyBytecode: string,
  params: DeploymentParams,
  receiver: string,
): Promise<string> {
  // // 1) Deploy the implementation
  // const implAddress = await deployContract(implAbi, implBytecode);
  // console.log(`Implementation deployed at ${implAddress}`);

  // // 2) Deploy the proxy, passing (implementation, initCall) to constructor
  const implAddress = GATEWAY_IMPL;
  const iface = new Interface(implAbi as any);
  const initData = iface.encodeFunctionData('initialize', [
    toEthHex(params.owner),
    toEthHex(params.mailbox),
    toEthHex(receiver),
    toEthHex(params.ism),
    params.hubDomain,
    HUB_GATEWAY_PROD,
  ]);

  const contractInstance = await tronWeb.contract().new({
    abi: proxyAbi,
    bytecode: proxyBytecode,
    feeLimit: 1_000_000_000,
    callValue: 0,
    parameters: [implAddress, initData],
  });
  const proxyAddress = contractInstance.address;
  return proxyAddress;
}

async function calculateResourceUsage(deployerAddress: string, raw_bytes: string): Promise<void> {
  const rawDataHex = raw_bytes;
  const byteCount = rawDataHex.length / 2;
  const bandwidthUsage = byteCount * 2;
  const resources = await tronWeb.trx.getAccountResources(deployerAddress);
  const availableBandwidth = resources.freeNetLimit + resources.NetLimit;

  console.log('-------------------');
  console.log(`${byteCount} deployment bytes`);
  console.log(`${bandwidthUsage} bandwidth required`);
  console.log(`Available bandwidth: ${availableBandwidth}`);

  console.log('-------------------');
  console.log('Free Bandwidth (freeNetLimit):', resources.freeNetLimit || 0);
  console.log('Free Bandwidth used (freeNetUsed):', resources.freeNetUsed || 0);

  console.log('Paid Bandwidth (NetLimit):', resources.NetLimit || 0);
  console.log('Paid Bandwidth used (NetUsed):', resources.NetUsed || 0);

  console.log('Energy Limit (EnergyLimit):', resources.EnergyLimit || 0);
  console.log('Energy used (EnergyUsed):', resources.EnergyUsed || 0);
  console.log('-------------------');

  if (availableBandwidth < bandwidthUsage)
    throw new Error(`Not enough free bandwidth ${availableBandwidth - bandwidthUsage}`);
}

(async () => {
  try {
    // configuring the parameters
    const params = configureDeploymentParameters();
    console.log('Deployment parameters:', params);

    // // Deploy Call Executor (no proxy for example)
    // const executorAddr = await deployContract(CallExecutorArtifact.abi, CallExecutorArtifact.bytecode);
    // console.log('CallExecutor at:', executorAddr);

    // // Deploy MessageReceiver (no proxy for example)
    // const messageReceiverAddr = await deployContract(MessageReceiverArtifact.abi, MessageReceiverArtifact.bytecode);
    // console.log('MessageReceiver at:', messageReceiverAddr);

    // // Deploy Spoke (UUPS style)
    // const spokeAddress = await deploySpokeProxy(
    //   EverclearSpokeArtifact.abi,
    //   EverclearSpokeArtifact.bytecode,
    //   ERC1967ProxyArtifact.abi,
    //   ERC1967ProxyArtifact.bytecode.object,
    //   params,
    // );
    // console.log('Everclear Spoke (proxy) at:', spokeAddress);

    // Deploy Gateway (UUPS style)
    const spokeAddress = SPOKE_PROD;
    const gatewayAddress = await deployGatewayProxy(
      SpokeGatewayArtifact.abi,
      SpokeGatewayArtifact.bytecode,
      ERC1967ProxyArtifact.abi,
      ERC1967ProxyArtifact.bytecode.object,
      params,
      spokeAddress,
    );
    console.log('Spoke Gateway (proxy) at:', gatewayAddress);

    console.log('DONE!');
  } catch (err) {
    console.error(err);
  }
})();
