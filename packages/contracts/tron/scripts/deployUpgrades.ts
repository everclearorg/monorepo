// Run command: yarn ts-node --files --project tsconfig.json tron/scripts/deploy.ts
import * as TronWeb from 'tronweb';
import dotenv from 'dotenv';
dotenv.config();
import { Interface } from '@ethersproject/abi';

// The JSON artifacts produced by TronBox or another compiler
import EverclearSpokeArtifact from '../build/contracts/EverclearSpoke.json';

import {
  CALL_EXECUTOR,
  MESSAGE_RECEIVER,
  tronLighthouse,
  tronWatchtower,
  tronIsm,
  tronMailbox,
  hubDomain,
  hubGatewayStaging,
  tronOwner,
  tronMaxSolversFee,
} from './constants';

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
  console.log('Contract constructor args:', constructorArgs);
  const deployTx = await tronWeb.transactionBuilder.createSmartContract({
    abi,
    bytecode,
    feeLimit: 1_000_000_000,
    parameters: constructorArgs,
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

    // // Deploy EverclearSpoke Impl
    // const spokeImpl = await deployContract(EverclearSpokeArtifact.abi, EverclearSpokeArtifact.bytecode);
    // console.log('EverclearSpoke at:', spokeImpl);

    console.log('DONE!');
  } catch (err) {
    console.error(err);
  }
})();
