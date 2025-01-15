import * as c from '../common';
import { Realm } from '../types';

export async function spokeDashboard(): Promise<void> {
  const environment = await c.chooseEnvironment();

  const domain = await c.chooseDomain(environment, Realm.SPOKE);

  const address = await c.getContractAddress(domain!, Realm.SPOKE, environment)!;
  if (!address) return;

  // add domain details
  let script = `spoke/Dashboard.s.sol:Dashboard --rpc-url ${domain!.rpc} --chain ${domain!.id} `;
  // provide a custom `run` signature
  script += '--sig "run(address)" ';
  // provide contract address
  script += `${address} `;

  await c.runOnlyReadScript(script);
}
