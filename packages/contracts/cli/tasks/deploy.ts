import { confirm } from '@inquirer/prompts';

import * as c from '../common';
import { Realm } from '../types';

export async function deployContracts() {
  // choose realm (hub or spoke)
  const realm = await c.chooseRealm();
  // choose environment (production or staging)
  const environment = await c.chooseEnvironment();

  // by default, always verify
  let verify = true;
  // get domain according to environment and realm
  const domain = await c.chooseDomain(environment, realm);

  if (domain == undefined) {
    return;
  }

  // if no verification details, choose to continue without verifying
  if (domain.verifierUrl == undefined || domain.verifierAPIKey == undefined) {
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

  let script = realm == Realm.HUB ? 'deploy/Hub.s.sol' : 'deploy/Spoke.s.sol';

  // add environment and domain details
  script += `:${environment} --rpc-url ${domain.rpc} --chain ${domain.id} --slow`;

  // if verifying, add verification arguments
  if (verify) script += ` --verifier-url ${domain.verifierUrl!} --etherscan-api-key ${domain.verifierAPIKey!} --verify`;

  // choose account to broadcast from
  script += ` --sig "run(string)" ${await c.chooseAccount()}`;

  // if deploying hub contracts, use 300% the gas estimated by forge
  if (realm == Realm.HUB) script += ' --gas-estimate-multiplier 300';

  await c.runFoundryScript(script, realm);
}
