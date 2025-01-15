import * as c from '../common';
import { Environment, Realm } from '../types';

interface SetupDomainsAndGatewaysParams {
  contractName: string;
  signature: string;
}

export async function setupDomainsAndGateways() {
  // choose environment (production or staging)
  const environment = await c.chooseEnvironment();

  const domain = await c.chooseDomain(environment, Realm.HUB);
  const address = await c.getContractAddress(domain!, Realm.HUB, environment)!;
  if (!address) return;

  let script = 'hub/SetupDomainsAndGateways.s.sol';

  let params: SetupDomainsAndGatewaysParams;
  switch (environment) {
    case Environment.TESTNET_STAGING:
      params = {
        contractName: 'SetupDomainsAndGatewaysTestnetStaging',
        signature: 'run(string,address)',
      };
      break;
    case Environment.TESTNET_PRODUCTION:
      params = {
        contractName: 'SetupDomainsAndGatewaysTestnetProduction',
        signature: 'run(string,address)',
      };
      break;
    case Environment.MAINNET_STAGING:
      params = {
        contractName: 'SetupDomainsAndGatewaysMainnetStaging',
        signature: 'run(string,address)',
      };
      break;
    case Environment.MAINNET_PRODUCTION:
      params = {
        contractName: 'SetupDomainsAndGatewaysMainnetProduction',
        signature: 'run(string,address)',
      };
      break;
    default:
      throw new Error('Invalid environment');
  }

  // add domain details
  script += `:${params.contractName} --rpc-url ${domain!.rpc} --chain ${domain!.id} `;
  // provide a custom `run` signature
  script += `--sig "${params.signature}" `;
  // choose account to broadcast from
  script += `${await c.chooseAccount()} `;
  // provide contract address
  script += `${address} `;

  await c.runFoundryScript(script, Realm.HUB);
}
