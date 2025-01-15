import * as c from '../common';
import { Realm } from '../types';

export async function returnUnsupportedIntent(): Promise<void> {
  const environment = await c.chooseEnvironment();

  const domain = await c.chooseDomain(environment, Realm.HUB);

  const address = await c.getContractAddress(domain!, Realm.HUB, environment)!;
  if (!address) return;

  let updateArgs = await c.inputNumber('Input the message value');
  updateArgs += ` ${await c.inputBytes32('Input the bytes32 intent ID')}`;

  // add domain details
  let script = `hub/Process.s.sol:ReturnUnsupportedIntent --rpc-url ${domain!.rpc} --chain ${domain!.id} `;
  // provide a custom `run` signature
  script += '--sig "run(string,address,uint256,bytes32)" ';
  // choose account to broadcast from
  script += `${await c.chooseAccount()} `;
  // provide contract address
  script += `${address} `;
  // add variable update args as input for script
  script += updateArgs;

  await c.runFoundryScript(script, Realm.HUB);
}
