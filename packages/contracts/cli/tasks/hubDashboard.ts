import * as c from '../common';
import { Realm } from '../types';

export async function hubDashboard(): Promise<void> {
  const environment = await c.chooseEnvironment();

  const domain = await c.chooseDomain(environment, Realm.HUB);

  const address = await c.getContractAddress(domain!, Realm.HUB, environment)!;
  if (!address) return;

  // add domain details
  let script = `hub/Dashboard.s.sol:Dashboard --rpc-url ${domain!.rpc} --chain ${domain!.id} `;
  // provide a custom `run` signature
  script += '--sig "run(address)" ';
  // provide contract address
  script += `${address} `;

  await c.runOnlyReadScript(script);
}
