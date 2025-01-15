import * as c from '../common';
import { Realm } from '../types';

export async function processFillQueue(): Promise<void> {
  const environment = await c.chooseEnvironment();

  const domain = await c.chooseDomain(environment, Realm.SPOKE);

  const address = await c.getContractAddress(domain!, Realm.SPOKE, environment)!;
  if (!address) return;

  let updateArgs = await c.inputNumber('Input the message value');
  updateArgs += ` ${await c.inputNumber('Input the amount of fill messages to be processed')}`;

  // add domain details
  let script = `spoke/ProcessFillQueue.s.sol:ProcessFillQueue --rpc-url ${domain!.rpc} --chain ${domain!.id} `;
  // provide a custom `run` signature
  script += '--sig "run(string,address,uint256,uint32)" ';
  // choose account to broadcast from
  script += `${await c.chooseAccount()} `;
  // provide contract address
  script += `${address} `;
  // add variable update args as input for script
  script += updateArgs;

  await c.runFoundryScript(script, Realm.SPOKE);
}
