import { confirm } from '@inquirer/prompts';

import * as c from '../common';
import { Realm } from '../types';

export async function deployAdapters() {
  // choose environment (production or staging)
  const environment = await c.chooseEnvironment();

  // by default, always verify
  let verify = true;
  // get domain according to environment and realm
  const domain = await c.chooseDomain(environment, Realm.SPOKE);

  if (domain == undefined) {
    return;
  }

  // if no verification details, choose to continue without verifying
  if (domain.verifierAPIKey == undefined) {
    if (
      await confirm({
        message: 'Verification details not found. Continue without verifying?',
        default: false,
      })
    ) {
      verify = false;
    } else {
      return;
    }
  }

  let script = `deploy/Adapters.s.sol:MainnetProduction --rpc-url ${domain.rpc} --chain ${domain.id} --slow`;

  // if verifying, add verification arguments
  if (verify) script += ` --etherscan-api-key ${domain.verifierAPIKey!} --verify`;

  // choose account to broadcast from
  script += ` --sig "run(string)" ${await c.chooseAccount()}`;

  await c.runFoundryScript(script, Realm.SPOKE);
}
