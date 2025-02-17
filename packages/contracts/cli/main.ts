import { select } from '@inquirer/prompts';

import { deployContracts } from './tasks/deploy';

import { returnUnsupportedIntent } from './tasks/returnUnsupportedIntent';
import { handleExpiredIntents } from './tasks/handleExpiredIntents';
import { processIntentQueue } from './tasks/processIntentQueue';
import { processFillQueue } from './tasks/processFillQueue';
import { processSettlementQueue } from './tasks/processSettlementQueue';
import { variableUpdate } from './tasks/updates';
import { handleAssetConfig } from './tasks/asset';
import { setupDomainsAndGateways } from './tasks/setupDomainsAndGateways';
import { hubDashboard } from './tasks/hubDashboard';
import { spokeDashboard } from './tasks/spokeDashboard';
import { setModuleForStrategy } from './tasks/setModuleForStrategy';
import { deployXERC20 } from './tasks/deployXERC20';
import { assetDashboard } from './tasks/assetDashboard';
import { logOwners } from './tasks/logOwners';

async function main() {
  const mainTask = await select({
    message: 'Select action',
    pageSize: 13,
    choices: [
      {
        name: 'Deploy contracts',
        value: 'deploy',
      },
      {
        name: 'Deploy XERC20 module',
        value: 'deploy_xerc20',
      },
      {
        name: 'Setup hub domains and gateways',
        value: 'setup_hub_domains_and_gateways',
      },
      {
        name: 'Update protocol variable',
        value: 'var_update',
      },
      {
        name: 'Set / Update asset configuration',
        value: 'assets',
      },
      {
        name: 'Process Intent queue',
        value: 'process_intent_queue',
      },
      {
        name: 'Process Fill queue',
        value: 'process_fill_queue',
      },
      {
        name: 'Process Settlement queue',
        value: 'process_settlement_queue',
      },
      {
        name: 'Handle expired intents',
        value: 'handle_expired_intents',
      },
      {
        name: 'Return unsupported intent',
        value: 'return_unsupported_intent',
      },
      {
        name: 'Hub Dashboard',
        value: 'hub_dashboard',
      },
      {
        name: 'Spoke Dashboard',
        value: 'spoke_dashboard',
      },
      {
        name: 'Asset Dashboard',
        value: 'asset_dashboard',
      },
      {
        name: 'Set Module For Strategy',
        value: 'set_module_for_strategy',
      },
      {
        name: 'Cancel',
        value: 'cancel',
      },
      {
        name: 'Log All Owners',
        value: 'log_owners',
      },
    ],
  });

  switch (mainTask) {
    case 'deploy':
      deployContracts();
      break;
    case 'setup_hub_domains_and_gateways':
      setupDomainsAndGateways();
      break;
    case 'assets':
      handleAssetConfig();
      break;
    case 'var_update':
      variableUpdate();
      break;
    case 'process_intent_queue':
      processIntentQueue();
      break;
    case 'process_fill_queue':
      processFillQueue();
      break;
    case 'set_module_for_strategy':
      setModuleForStrategy();
      break;
    case 'process_settlement_queue':
      processSettlementQueue();
      break;
    case 'handle_expired_intents':
      handleExpiredIntents();
      break;
    case 'return_unsupported_intent':
      returnUnsupportedIntent();
      break;
    case 'hub_dashboard':
      hubDashboard();
      break;
    case 'spoke_dashboard':
      spokeDashboard();
      break;
    case 'deploy_xerc20':
      deployXERC20();
      break;
    case 'asset_dashboard':
      assetDashboard();
      break;
    case 'log_owners':
      logOwners();
      break;
    case 'cancel':
      return;
  }
}

main();
