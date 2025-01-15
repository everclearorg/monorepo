import * as c from '../common';
import { select, confirm } from '@inquirer/prompts';
import { Realm } from '../types';
import { pad } from 'viem';

interface VarUpdate {
  name: string;
  contractName: string;
  realm: Realm;
  handler?: () => Promise<string>;
  signature?: string;
}

const variables: VarUpdate[] = [
  {
    name: 'Assign Role',
    contractName: 'AssignRole',
    realm: Realm.HUB,
    handler: handleAssignRole,
    signature: 'run(string,address,address,uint8)',
  },
  {
    name: 'Propose New Owner',
    contractName: 'ProposeNewOwner',
    realm: Realm.HUB,
    handler: handleProposeNewOwner,
    signature: 'run(string,address,address)',
  },
  {
    name: 'Epoch Length',
    contractName: 'UpdateEpochLength',
    realm: Realm.HUB,
    handler: handleEpochLengthUpdate,
    signature: 'run(string,address,uint48)',
  },
  {
    name: 'Expiry Time Buffer',
    contractName: 'UpdateExpiryTimeBuffer',
    realm: Realm.HUB,
    handler: handleExpiryTimeBufferUpdate,
    signature: 'run(string,address,uint48)',
  },
  {
    name: 'Lighthouse',
    contractName: 'UpdateLighthouse',
    realm: Realm.HUB,
    handler: handleLighthouseUpdate,
    signature: 'run(string,address,address)',
  },
  {
    name: 'Watchtower',
    contractName: 'UpdateWatchtower',
    realm: Realm.HUB,
    handler: handleWatchtowerUpdate,
    signature: 'run(string,address,address)',
  },
  {
    name: 'Mininum Supported Domains',
    contractName: 'UpdateMinSupportedDomains ',
    realm: Realm.HUB,
    handler: handleMinSupportedDomainsUpdate,
    signature: 'run(string,address,uint8)',
  },
  {
    name: 'Security Module',
    contractName: 'UpdateSecurityModule',
    realm: Realm.HUB,
    handler: handleSecurityModuleUpdate,
    signature: 'run(string,address,address)',
  },
  {
    name: 'Gas Config',
    contractName: 'UpdateGasConfig',
    realm: Realm.HUB,
    handler: handleGasConfigUpdate,
    signature: 'run(string,address,(uint256,uint256,uint256))',
  },
  {
    name: 'Add Chain Gateway',
    contractName: 'AddChainGateway',
    realm: Realm.HUB,
    handler: handleAddChainGateway,
    signature: 'run(string,address,uint32,address)',
  },
  {
    name: 'Pause',
    contractName: 'Pause',
    realm: Realm.HUB,
    signature: 'run(string,address)',
  },
  {
    name: 'Unpause',
    contractName: 'Unpause',
    realm: Realm.HUB,
    signature: 'run(string,address)',
  },
  {
    name: 'Pause',
    contractName: 'Pause',
    realm: Realm.SPOKE,
  },
  {
    name: 'Unpause',
    contractName: 'Unpause',
    realm: Realm.SPOKE,
  },
  {
    name: 'Transfer Ownership',
    contractName: 'TransferOwnership',
    handler: handleTransferOwnership,
    realm: Realm.HUB,
    signature: 'run(string,address,address)',
  },
  {
    name: 'Transfer Ownership',
    contractName: 'TransferOwnership',
    handler: handleTransferOwnership,
    realm: Realm.SPOKE,
    signature: 'run(string,address,address)',
  },
  {
    name: 'Transfer Gateway Ownership',
    contractName: 'TransferGatewayOwnership',
    handler: handleTransferOwnership,
    realm: Realm.HUB,
    signature: 'run(string,address,address)',
  },
  {
    name: 'Transfer Gateway Ownership',
    contractName: 'TransferGatewayOwnership',
    handler: handleTransferOwnership,
    realm: Realm.SPOKE,
    signature: 'run(string,address,address)',
  },
];

async function handleEpochLengthUpdate(): Promise<string> {
  return await c.inputNumber('Input new epoch length in blocks');
}

async function handleExpiryTimeBufferUpdate(): Promise<string> {
  return await c.inputNumber('Input new expiry time buffer in seconds');
}

async function handleLighthouseUpdate(): Promise<string> {
  return (await c.inputAddress('Input new lighthouse address')) as string;
}

async function handleWatchtowerUpdate(): Promise<string> {
  return (await c.inputAddress('Input new watchtower address')) as string;
}

async function handleMinSupportedDomainsUpdate(): Promise<string> {
  return await c.inputNumber('Input new minimum amount of supported domains');
}

async function handleSecurityModuleUpdate(): Promise<string> {
  return (await c.inputAddress('Input new ISM address')) as string;
}

async function handleGasConfigUpdate(): Promise<string> {
  const settlementBaseGasUnits = await c.inputNumber('Input new settlement base gas units');
  const averageGasUnitsPerSettlement = await c.inputNumber('Input new settlement gas units per settlement');
  const bufferDBPS = await c.inputNumber('Input new buffer DBPS');

  return `${settlementBaseGasUnits} ${averageGasUnitsPerSettlement} ${bufferDBPS}`;
}

async function handleAddChainGateway(): Promise<string> {
  return `${await c.inputNumber('Input domain id')} ${await c.inputAddress('Input chain gateway address')}`;
}

async function handleProposeNewOwner(): Promise<string> {
  const account = await c.inputAddress('Input new owner');
  return `${account}`;
}

async function handleAssignRole(): Promise<string> {
  const account = await c.inputAddress('Input account');
  const role = await select({
    message: 'Select role',
    choices: [
      {
        name: 'Admin',
        value: '2',
      },
      {
        name: 'Asset Manager',
        value: '1',
      },
      {
        name: 'Revoke roles',
        value: '0',
      },
    ],
  });
  return `${account} ${role}`;
}

async function handleTransferOwnership(): Promise<string> {
  return (await c.inputAddress('Input new owner')) as string;
}

export async function variableUpdate(): Promise<void> {
  const realm = await c.chooseRealm();

  const environment = await c.chooseEnvironment();

  const domain = await c.chooseDomain(environment, realm);

  const address = await c.getContractAddress(domain!, realm, environment)!;
  if (!address) return;

  const choice = await select({
    message: 'Select action',
    pageSize: variables.length,
    choices: variables.filter((x) => x.realm == realm).map((x) => ({ name: x.name, value: x })),
  });

  const updateArgs = choice.handler == undefined ? '' : await choice.handler();

  let script = realm == Realm.HUB ? 'hub/HubUpdate.s.sol' : 'spoke/SpokeUpdate.s.sol';
  // add domain details
  script += `:${choice.contractName} --rpc-url ${domain!.rpc} --chain ${domain!.id} `;
  // provide a custom `run` signature
  script += `--sig "${choice.signature}" `;
  // choose account to broadcast from
  script += `${await c.chooseAccount()} `;
  // provide contract address
  script += `${address} `;
  // add variable update args as input for script
  script += updateArgs;

  await c.runFoundryScript(script, realm);
}
