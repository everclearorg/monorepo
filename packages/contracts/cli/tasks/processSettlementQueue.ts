import * as c from '../common';
import { Realm } from '../types';

export async function processSettlementQueue(): Promise<void> {
  const environment = await c.chooseEnvironment();

  const domain = await c.chooseDomain(environment, Realm.HUB);

  const address = await c.getContractAddress(domain!, Realm.HUB, environment)!;
  if (!address) return;

  let updateArgs = await c.inputNumber('Input the message value');
  updateArgs += ` ${await c.inputNumber('Input the domain of the settlement queue to be processed')}`;
  updateArgs += ` ${await c.inputNumber('Input the amount of settlements to be processed')}`;

  // add domain details
  let script = `hub/Process.s.sol:ProcessSettlementQueue --rpc-url ${domain!.rpc} --chain ${domain!.id} `;
  // provide a custom `run` signature
  script += '--sig "run(string,address,uint256,uint32,uint32)" ';
  // choose account to broadcast from
  script += `${await c.chooseAccount()} `;
  // provide contract address
  script += `${address} `;
  // add variable update args as input for script
  script += updateArgs;

  await c.runFoundryScript(script, Realm.HUB);
}
