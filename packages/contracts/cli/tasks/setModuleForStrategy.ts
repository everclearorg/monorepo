import * as c from '../common';
import { Realm } from '../types';

export async function setModuleForStrategy(): Promise<void> {
  const environment = await c.chooseEnvironment();

  const domain = await c.chooseDomain(environment, Realm.SPOKE);

  const address = await c.getContractAddress(domain!, Realm.SPOKE, environment)!;
  if (!address) return;

  let updateArgs = await c.inputNumber('Input the strategy value');
  updateArgs += ` ${await c.inputAddress('Input the module address')}`;

  // add domain details
  let script = `spoke/SetModuleForStrategy.s.sol:SetModuleForStrategy --rpc-url ${domain!.rpc} --chain ${domain!.id} `;
  // provide a custom `run` signature
  script += '--sig "run(string,address,uint8,address)" ';
  // choose account to broadcast from
  script += `${await c.chooseAccount()} `;
  // provide contract address
  script += `${address} `;
  // add variable update args as input for script
  script += updateArgs;

  await c.runFoundryScript(script, Realm.SPOKE);
}
