import fs from 'fs';
import path from 'path';
import * as dotenv from 'dotenv';
import { execSync } from 'child_process';

import { select, confirm, input } from '@inquirer/prompts';
import { Domain, Environment, Realm, Contract } from './types';
import { Address, isAddress, isAddressEqual, zeroAddress, zeroHash } from 'viem';

export async function chooseEnvironment(): Promise<Environment> {
  return await select({
    message: 'Select environment',
    choices: [
      {
        name: 'Testnet Staging',
        value: Environment.TESTNET_STAGING,
      },
      {
        name: 'Testnet Production',
        value: Environment.TESTNET_PRODUCTION,
      },
      {
        name: 'Mainnet Staging',
        value: Environment.MAINNET_STAGING,
      },
      {
        name: 'Mainnet Production',
        value: Environment.MAINNET_PRODUCTION,
      },
    ],
  });
}

export async function chooseRealm(): Promise<Realm> {
  return await select({
    message: 'Select',
    choices: [
      {
        name: 'Hub',
        value: Realm.HUB,
      },
      {
        name: 'Spoke',
        value: Realm.SPOKE,
      },
    ],
  });
}

export async function chooseDomain(env: Environment, realm: Realm): Promise<Domain | undefined> {
  let domains: Domain[] | undefined;
  try {
    const filePath = path.join(__dirname, 'config/domains.json');
    const fileContent = await fs.promises.readFile(filePath, 'utf8');
    domains = JSON.parse(fileContent) as Domain[];
  } catch (error) {
    console.error('Error reading JSON file:', error);
    throw error;
  }
  // filter domains by environment and realm
  domains = domains.filter((x) => x.environments.includes(env) && x.realm == realm);

  // select domain from list
  if (realm == Realm.SPOKE) {
    return await select({
      message: 'Select Spoke domain',
      choices: domains.map((x) => ({ name: x.name, value: x })),
    });
  } else {
    if (domains.length == 1) {
      return domains[0];
    } else if (domains.length == 0) {
      console.error('No domains found');
      return;
    } else {
      return await select({
        message: 'Found multiple Hub domains',
        choices: domains.map((x) => ({ name: x.name, value: x })),
      });
    }
  }
}

export async function chooseAccount(): Promise<string> {
  dotenv.config();

  // get all env vars that match a private key
  const accounts = Object.keys(process.env)
    .filter((key) => /^0x[a-fA-F0-9]{64}$/.test(process.env[key] as string))
    .map((key) => key);

  if (accounts.length === 0) {
    throw new Error(`No available keys, please update .env`);
  }

  return await select({
    message: 'Select account to broadcast from',
    choices: accounts.map((x) => ({ name: x, value: x })),
  });
}

export async function inputAddress(message: string): Promise<Address> {
  let answer = await input({ message });
  while (!isAddress(answer) || isAddressEqual(answer, zeroAddress)) {
    answer = await input({ message: 'Enter a valid address' });
  }

  return answer as Address;
}

export async function inputNumber(message: string): Promise<string> {
  let answer = await input({ message });
  let parsed = parseInt(answer);
  while (isNaN(parsed)) {
    answer = await input({ message: 'Enter a valid number' });
    parsed = parseInt(answer);
  }

  return answer;
}

export async function inputBytes32(message: string): Promise<string> {
  let answer = await input({ message });
  while (!/^0x[a-fA-F0-9]{64}$/.test(answer) || answer == zeroHash) {
    answer = await input({ message: 'Enter a valid bytes32' });
  }

  return answer;
}

export async function inputBytes(message: string): Promise<string> {
  let answer = await input({ message });
  while (!/^0x[a-fA-F0-9]+$/.test(answer) || answer == zeroHash) {
    answer = await input({ message: 'Enter valid bytes' });
  }

  return answer;
}

export async function getContractAddress(domain: Domain, realm: Realm, env: Environment): Promise<string | undefined> {
  let contracts: Contract[] | undefined;
  try {
    const filePath = path.join(__dirname, `config/${realm}.json`);
    const fileContent = await fs.promises.readFile(filePath, 'utf8');
    contracts = JSON.parse(fileContent) as Contract[];
  } catch (error) {
    console.error('Error reading JSON file:', error);
    throw error;
  }

  if (contracts != undefined) {
    const found = contracts.find(
      (x) => x.domainName == domain.name && x.domainId == domain.id && env === x.environment,
    );
    if (found != undefined) {
      return found.address;
    } else {
      console.error('Error finding contract address');
      return;
    }
  } else {
    console.error('Error finding contract address');
    return;
  }
}

export async function runFoundryScript(body: string, realm: Realm): Promise<void> {
  let command = `forge script script/${body}`;

  let broadcast = await confirm({ message: 'Broadcast transactions?', default: false });
  if (broadcast) command += realm === Realm.HUB ? ` --broadcast --skip-simulation` : ` --broadcast`;

  const success = await _run(command);

  // rerun and broadcast?
  if (!broadcast && success) {
    broadcast = await confirm({ message: 'Run again and broadcast?', default: false });
    if (broadcast) {
      command += realm === Realm.HUB ? ` --broadcast  --skip-simulation` : ` --broadcast`;
      _run(command);
    }
  }
}

export async function runOnlyReadScript(body: string): Promise<void> {
  const command = `forge script script/${body} -vv`;
  await _run(command);
}

export function getAssetAddress(symbol: string, domainId: number, environment: Environment): string {
  // Asset address mappings per domain
  const assetAddresses: Record<string, Record<number, string>> = {
    // Mainnet assets
    USDC: {
      1: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // Ethereum
      10: '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85', // Optimism
      8453: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913', // Base
      42161: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // Arbitrum
      56: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d', // BNB
      137: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359', // Polygon
      43114: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E', // Avalanche
      59144: '0x176211869cA2b568f2A7D4EE941E073a821EE1ff', // Linea
      534352: '0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4', // Scroll
      167000: '0x07d83526730c7438048D55A4fc0b850e2aaB6f0b', // Taiko
      324: '0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4', // zkSync
    },
    USDT: {
      1: '0xdAC17F958D2ee523a2206206994597C13D831ec7', // Ethereum
      10: '0x94b008aA00579c1307B0EF2c499aD98a8ce58e58', // Optimism
      42161: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9', // Arbitrum
      56: '0x55d398326f99059fF775485246999027B3197955', // BNB
      137: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F', // Polygon
      43114: '0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7', // Avalanche
      59144: '0xA219439258ca9da29E9Cc4cE5596924745e12B93', // Linea
      534352: '0xf55BEC9cafDbE8730f096Aa55dad6D22d44099Df', // Scroll
      167000: '0x2DEF195713CF4a606B49D07E520e22C17899a736', // Taiko
    },
    WETH: {
      1: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // Ethereum
      10: '0x4200000000000000000000000000000000000006', // Optimism
      8453: '0x4200000000000000000000000000000000000006', // Base
      42161: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', // Arbitrum
      56: '0x2170Ed0880ac9A755fd29B2688956BD959F933F8', // BNB
      137: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619', // Polygon
      43114: '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB', // Avalanche
      59144: '0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f', // Linea
      534352: '0x5300000000000000000000000000000000000004', // Scroll
      167000: '0xA51894664A773981C6C112C43ce576f315d5b1B6', // Taiko
    },
    // Testnet assets
    TEST: {
      11155111: '0xd26e3540A0A368845B234736A0700E0a5A821bBA', // Sepolia
      97: '0x5f921E4DE609472632CEFc72a3846eCcfbed4ed8', // BSC Testnet
    },
  };

  const addressMap = assetAddresses[symbol];
  if (!addressMap) {
    throw new Error(`Asset ${symbol} not configured in address mappings`);
  }

  const address = addressMap[domainId];
  if (!address) {
    throw new Error(`Asset ${symbol} not found for domain ${domainId}`);
  }

  return address;
}

export async function getAddressFromAccount(accountEnvVar: string, rpc: string): Promise<string> {
  try {
    const command = `cast wallet address --private-key $${accountEnvVar}`;
    const address = execSync(command, { encoding: 'utf-8' }).trim();
    return address;
  } catch (error) {
    console.error(`Error getting address from account: ${error}`);
    throw error;
  }
}

export async function checkAndApproveAllowance(
  token: string,
  owner: string,
  spender: string,
  amount: string,
  rpc: string,
  accountEnvVar: string
): Promise<boolean> {
  try {
    // Check current allowance
    console.log('Checking allowance...');
    const allowanceCommand = `cast call ${token} "allowance(address,address)(uint256)" ${owner} ${spender} --rpc-url ${rpc}`;
    const currentAllowanceRaw = execSync(allowanceCommand, { encoding: 'utf-8' }).trim();
    
    // Parse the allowance - cast returns format like "100000 [1e5]" or just "0x..." hex
    // Extract just the first part before any space or bracket
    const currentAllowance = currentAllowanceRaw.split(/[\s\[]/)[0];
    
    console.log('Current allowance:', currentAllowance);
    console.log('Required amount:', amount);
    
    // Convert to decimal for comparison
    const allowanceDecimal = BigInt(currentAllowance);
    const amountDecimal = BigInt(amount);
    
    if (allowanceDecimal >= amountDecimal) {
      console.log('Sufficient allowance already exists.');
      return true;
    }
    
    // Ask user if they want to approve
    const shouldApprove = await confirm({ 
      message: `Insufficient allowance. Approve ${amount} tokens for ${spender}?`, 
      default: true 
    });
    
    if (!shouldApprove) {
      return false;
    }
    
    // Approve the tokens
    console.log('Approving tokens...');
    const approveCommand = `cast send ${token} "approve(address,uint256)" ${spender} ${amount} --rpc-url ${rpc} --private-key $${accountEnvVar}`;
    const success = await _run(approveCommand);
    
    if (success) {
      console.log('Approval successful!');
    }
    
    return success;
  } catch (error) {
    console.error(`Error checking/approving allowance: ${error}`);
    return false;
  }
}

export async function runCastSend(
  to: string,
  data: string,
  rpc: string,
  accountEnvVar: string,
  value: string = '0'
): Promise<void> {
  let command = `cast send ${to} ${data} --rpc-url ${rpc} --private-key $${accountEnvVar}`;
  
  if (value !== '0') {
    command += ` --value ${value}`;
  }

  const broadcast = await confirm({ message: 'Broadcast transaction?', default: false });
  
  if (broadcast) {
    console.log('Sending transaction...');
    await _run(command);
  } else {
    console.log('Transaction not sent. Command that would be executed:');
    console.log(command);
  }
}

async function _run(command: string): Promise<boolean> {
  try {
    execSync(command, { encoding: 'utf-8', stdio: 'inherit' });
  } catch (error) {
    console.error(`Error running Foundry script: ${error}`);
    return false;
  }
  return true;
}
