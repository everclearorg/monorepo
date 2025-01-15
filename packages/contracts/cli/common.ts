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

async function _run(command: string): Promise<boolean> {
  try {
    execSync(command, { encoding: 'utf-8', stdio: 'inherit' });
  } catch (error) {
    console.error(`Error running Foundry script: ${error}`);
    return false;
  }
  return true;
}
