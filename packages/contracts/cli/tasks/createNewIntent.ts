import * as c from '../common';
import { Realm } from '../types';
import fetch from 'node-fetch';
import { select, confirm } from '@inquirer/prompts';

export async function createNewIntent(): Promise<void> {
  const environment = await c.chooseEnvironment();

  // Select origin chain
  const originDomain = await c.chooseDomain(environment, Realm.SPOKE);
  const originAddress = await c.getContractAddress(originDomain!, Realm.SPOKE, environment);
  if (!originAddress) return;

  // Select origin asset
  const originAssetConfigPath = `../config/assets/${environment.toLowerCase()}.json`;
  const originAssetConfig = require(originAssetConfigPath);
  const originAssetChoices = originAssetConfig.map((asset: any) => ({ name: asset.symbol, value: asset.symbol }));
  const inputAssetSymbol = await select({ message: 'Select input asset for origin domain', choices: originAssetChoices });
  
  // Get input asset address from tokenInfo.json
  const tokenInfo = require('../config/tokenInfo.json');
  const inputAssetToken = tokenInfo.find((token: any) => token.symbol === inputAssetSymbol);
  if (!inputAssetToken || !inputAssetToken.addresses[originDomain!.id.toString()]) {
    throw new Error(`Asset ${inputAssetSymbol} not found for origin domain ${originDomain!.id}`);
  }
  const inputAsset = inputAssetToken.addresses[originDomain!.id.toString()];

  // Get fee adapter address for ORIGIN domain (where we're sending FROM)
  const spokeConfig = require('../config/spoke.json');
  const originSpoke = spokeConfig.find((spoke: any) => spoke.environment === environment && spoke.domainName === originDomain!.name);
  if (!originSpoke) {
    throw new Error('No matching origin spoke configuration found.');
  }

  const { feeAdapterAddress } = originSpoke;
  if (!feeAdapterAddress) {
    throw new Error('Fee Adapter Address is missing for the origin domain.');
  }

  console.log('Fee Adapter address:', feeAdapterAddress);

  // Select destination chain
  const destinationDomain = await c.chooseDomain(environment, Realm.SPOKE);

  // Select destination asset
  const destinationAssetConfigPath = `../config/assets/${environment.toLowerCase()}.json`;
  const destinationAssetConfig = require(destinationAssetConfigPath);
  const destinationAssetChoices = destinationAssetConfig.map((asset: any) => ({ name: asset.symbol, value: asset.symbol }));
  const outputAssetSymbol = await select({ message: 'Select output asset for destination domain', choices: destinationAssetChoices });
  
  // Get output asset address from tokenInfo.json
  const outputAssetToken = tokenInfo.find((token: any) => token.symbol === outputAssetSymbol);
  if (!outputAssetToken || !outputAssetToken.addresses[destinationDomain!.id.toString()]) {
    throw new Error(`Asset ${outputAssetSymbol} not found for destination domain ${destinationDomain!.id}`);
  }
  const outputAsset = outputAssetToken.addresses[destinationDomain!.id.toString()];

  // Input amount
  const amount = await c.inputNumber('Amount to deposit');

  // Ask if user wants to use fast path
  const useFastPath = await confirm({ 
    message: 'Use fast path? (If no, TTL and Max Fee will be set to 0)', 
    default: true 
  });

  let ttl: number;
  let fee: number;

  if (useFastPath) {
    // Fast path: ask for TTL and fee
    // Input ttl in minutes
    let ttlInput = await c.inputNumber('Time to live in minutes (minimum 120 minutes)');
    ttl = parseInt(ttlInput) * 60; // Convert minutes to seconds
    const minTTL = 2 * 60 * 60; // 2 hours in seconds
    if (ttl < minTTL) {
      console.log(`TTL must be at least ${minTTL / 60} minutes (2 hours).`);
      ttl = minTTL;
    }

    // Input fee in BPS
    let feeInput = await c.inputNumber('Fee in BPS (minimum 500)');
    fee = parseInt(feeInput);
    const minFee = 500; // Minimum fee in BPS
    if (fee < minFee) {
      console.log(`Fee must be at least ${minFee} BPS.`);
      fee = minFee;
    }
  } else {
    // Non-fast path: set TTL and fee to 0
    ttl = 0;
    fee = 0;
    console.log('Fast path disabled: TTL = 0, Max Fee = 0');
  }

  console.log('Selected Environment:', environment);
  console.log('Origin Domain:', originDomain!.name, `(${originDomain!.id})`);
  console.log('Destination Domain:', destinationDomain!.name, `(${destinationDomain!.id})`);
  console.log('Input Asset:', inputAssetSymbol, '-', inputAsset);
  console.log('Output Asset:', outputAssetSymbol, '-', outputAsset);
  console.log('Amount:', amount);
  console.log('Fast Path:', useFastPath);
  console.log('TTL:', ttl, 'seconds');
  console.log('Fee:', fee, 'BPS');

  // Get the account private key early
  const account = await c.chooseAccount();
  
  // Get the sender address from the private key
  const senderAddress = await c.getAddressFromAccount(account, originDomain!.rpc);
  console.log('Sender address:', senderAddress);
  
  // Check allowance and approve BEFORE calling API (so signature doesn't expire)
  console.log('\n--- Checking allowance for fee adapter ---');
  const hasAllowance = await c.checkAndApproveAllowance(
    inputAsset as string,
    senderAddress,
    feeAdapterAddress,
    amount,
    originDomain!.rpc,
    account
  );
  
  if (!hasAllowance) {
    console.log('Failed to approve allowance. Aborting transaction.');
    return;
  }

  console.log('\n--- Calling API to get transaction data ---');
  const apiUrl = environment === 'MainnetStaging' ? 'https://api.staging.everclear.org/intents' : 'https://api.everclear.org/intents';
  console.log('API URL:', apiUrl);

  const payload = {
    origin: originDomain!.id.toString(), // Use domain ID for origin
    destinations: [destinationDomain!.id.toString()], // Use domain ID for destinations
    to: senderAddress,
    inputAsset,
    amount,
    isFastPath: useFastPath, // Fast path boolean
    callData: '', // Add appropriate callData
    maxFee: fee.toString(), // Convert fee to string
  };

  console.log('\nPayload being sent to API:');
  console.log(JSON.stringify(payload, null, 2));

  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const data: any = await response.json();
  console.log('API Response:', data);

  if (!data.to || !data.data || !data.chainId) {
    console.error('Invalid API response:', data);
    return;
  }
  
  // Send the transaction immediately after getting the signature
  console.log('\n--- Sending transaction ---');
  await c.runCastSend(
    data.to,
    data.data,
    originDomain!.rpc,
    account,
    data.value || '0'
  );
}
