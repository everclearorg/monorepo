import fs from 'fs';
import path from 'path';
import { select } from '@inquirer/prompts';

import * as c from '../common';
import { Realm } from '../types';

interface Asset {
  symbol: string;
  contractName: string;
}

export async function handleAssetConfig(): Promise<void> {
  // choose environment (production or staging)
  const environment = await c.chooseEnvironment();

  // get domain according to environment and realm
  const domain = await c.chooseDomain(environment, Realm.HUB);

  const address = await c.getContractAddress(domain!, Realm.HUB, environment)!;
  if (!address) return;

  let assets: Asset[] | undefined;
  try {
    const filePath = path.join(__dirname, `../config/assets/${environment.toLowerCase()}.json`);
    const fileContent = await fs.promises.readFile(filePath, 'utf8');
    assets = JSON.parse(fileContent) as Asset[];
  } catch (error) {
    console.error('Error reading JSON file:', error);
    throw error;
  }

  if (assets == undefined) return;

  const choice: Asset = await select({
    message: 'Select asset',
    choices: assets.map((x) => ({ name: x.symbol, value: x })),
  });

  let script = `assets/${environment.toLowerCase()}/${choice.contractName}.s.sol:${choice.contractName}`;

  // add environment and domain details
  script += ` --rpc-url ${domain!.rpc} --chain ${domain!.id}`;

  // choose account to broadcast from
  script += ` --sig "run(string,address)" ${await c.chooseAccount()} ${address}`;

  await c.runFoundryScript(script, Realm.HUB);
}
