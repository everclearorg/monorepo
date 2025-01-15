import * as c from '../common';
import { Realm } from '../types';

export async function deployXERC20(): Promise<void> {
  const environment = await c.chooseEnvironment();

  const domain = await c.chooseDomain(environment, Realm.SPOKE);

  const address = await c.getContractAddress(domain!, Realm.SPOKE, environment)!;
  if (!address) return;

  // add domain details
  let script = `deploy/XERC20.s.sol:DeployXERC20 --rpc-url ${domain!.rpc} --chain ${domain!.id} `;
  // provide a custom `run` signature
  script += '--sig "run(string memory,address)" ';
  // choose account to broadcast from
  script += `${await c.chooseAccount()} `;
  // provide contract address
  script += `${address} `;

  await c.runFoundryScript(script, Realm.SPOKE);
}
