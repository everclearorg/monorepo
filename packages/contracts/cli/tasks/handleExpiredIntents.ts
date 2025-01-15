import * as c from '../common';
import { Realm } from '../types';

export async function handleExpiredIntents(): Promise<void> {
  const environment = await c.chooseEnvironment();

  const domain = await c.chooseDomain(environment, Realm.HUB);

  const address = await c.getContractAddress(domain!, Realm.HUB, environment)!;
  if (!address) return;

  let updateArgs = ` ${await c.inputBytes('Input the encoded intents IDs array')}`;

  // add domain details
  let script = `hub/Process.s.sol:HandleExpiredIntents --rpc-url ${domain!.rpc} --chain ${domain!.id} `;
  // provide a custom `run` signature
  script += '--sig "run(string,address,bytes)" ';
  // choose account to broadcast from
  script += `${await c.chooseAccount()} `;
  // provide contract address
  script += `${address} `;
  // add variable update args as input for script
  script += updateArgs;

  await c.runFoundryScript(script, Realm.HUB);
}
