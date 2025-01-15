/* eslint-disable @typescript-eslint/no-explicit-any */
import { ajv, EverclearConfig, ChainConfig, createLoggingContext, ThresholdsConfig } from '@chimera-monorepo/utils';
import { MonitorConfig, TMonitorConfigSchema } from './types';
import { config as dotenvConfig } from 'dotenv';
import lodash from 'lodash';
import * as fs from 'fs';
import { getContext } from './context';
import { getDefaultABIConfig, getEverclearConfig } from './mockable';

dotenvConfig();
const DEFAULT_POLL_INTERVAL = 5_000; // 5s
const DEFAULT_CONFIRMATIONS = 3;

let cachedEverclearConfigUrl: string | undefined = undefined;
let cachedEverclearConfig: EverclearConfig = {} as any;

export const DefaultThresholds: ThresholdsConfig = {
  maxExecutionQueueCount: 100,
  maxExecutionQueueLatency: 3600,
  maxSettlementQueueCount: 100,
  maxIntentQueueCount: 100,
  maxIntentQueueLatency: 3600,
  openTransferMaxTime: 86400, // 1 day
  openTransferInterval: 86400, // 1 day
  maxSettlementQueueLatency: 3600, // Seconds
  maxSettlementQueueAssetAmounts: { '': 1000 },
  maxDepositQueueCount: 100,
  maxDepositQueueLatency: 3600, // Seconds
  messageMaxDelay: 1800,
  maxInvoiceProcessingTime: 23 * 3600,
  minGasOnRelayer: 1,
  minGasOnGateway: 1,
  maxShadowExportDelay: 900,
  maxShadowExportLatency: 10,
  maxTokenomicsExportDelay: 1800,
  maxTokenomicsExportLatency: 10,
};

export const DefaultTokenomicsTables = [
  'bridge_in_error',
  'bridge_updated',
  'bridged_in',
  'bridged_lock',
  'bridged_lock_error',
  'bridged_out',
  'chain_gateway_added',
  'chain_gateway_removed',
  'early_exit',
  'eip712_domain_changed',
  'epoch_rewards_updated',
  'eth_withdrawn',
  'fee_info',
  'gateway_updated',
  'hub_gauge_updated',
  'mailbox_updated',
  'message_gas_limit_updated',
  'mint_message_sent',
  'new_lock_position',
  'ownership_transferred',
  'process_error',
  'retry_bridge_out',
  'retry_lock',
  'retry_message',
  'retry_mint',
  'retry_transfer',
  'return_fee_updated',
  'reward_claimed',
  'reward_metadata_updated',
  'rewards_claimed',
  'security_module_updated',
  'vote_cast',
  'vote_delegated',
  'withdraw',
  'withdraw_eth',
];

export const DefaultShadowTables = [
  'closedepochsprocessed',
  'depositenqueued',
  'depositprocessed',
  'finddepositdomain',
  'findinvoicedomain',
  'invoiceenqueued',
  'matchdeposit',
  'settledeposit',
  'settlementenqueued',
  'settlementqueueprocessed',
  'settlementsent',
];

export const getConfig = async (): Promise<MonitorConfig> => {
  let configJson: Record<string, any> = {};
  let configFile: any = {};
  try {
    configJson = JSON.parse(process.env.MONITOR_CONFIG || '');
  } catch (e: unknown) {
    console.info('No MONITOR_CONFIG exists, using config file and individual env vars');
  }
  try {
    let json: string;

    const path = process.env.MONITOR_CONFIG_FILE ?? 'config.json';
    if (fs.existsSync(path)) {
      json = fs.readFileSync(path, { encoding: 'utf-8' });
      configFile = JSON.parse(json);
    }
  } catch (e: unknown) {
    console.error('Error reading config file!');
    process.exit(1);
  }

  const everclearConfigUrl =
    process.env.EVERCLEAR_CONFIG || configJson.everclearConfig || configFile.everclearConfig || undefined;

  cachedEverclearConfigUrl = everclearConfigUrl;
  const everclearConfig = await getEverclearConfig(everclearConfigUrl);
  if (everclearConfig) cachedEverclearConfig = everclearConfig;

  const hubConfig = {
    domain: configJson?.hub?.domain || configFile?.hub?.domain || everclearConfig?.hub.domain,
    providers: configJson?.hub?.providers || configFile?.hub?.providers || everclearConfig?.hub.providers,
    deployments: configJson?.hub?.deployments || configFile?.hub?.deployments || everclearConfig?.hub.deployments,
    assets: configJson?.hub?.assets || configFile?.hub?.assets || everclearConfig?.hub?.assets,
    subgraphUrls:
      configJson?.hub?.subgraphUrls || configFile?.hub?.subgraphUrls || everclearConfig?.hub.subgraphUrls || [],
  };

  const environment = configJson.environment || configFile.environment || 'production';
  const abiConfig = getDefaultABIConfig(environment, hubConfig.domain);

  const everclearChains = everclearConfig?.chains ?? {};
  const localChains = configJson.chains || configFile.chains || everclearChains || {};
  const localThresholds = configJson.thresholds || configFile.thresholds || {};

  const chainsForMonitorConfig: Record<string, ChainConfig> = {};
  for (const domainId of Object.keys(localChains)) {
    const localChainConfig = localChains[domainId];
    const everclearChainConfig = everclearChains[domainId];

    const confirmations =
      localChainConfig?.confirmations || everclearChainConfig?.confirmations || DEFAULT_CONFIRMATIONS;

    const providers: string[] = localChainConfig?.providers || everclearChainConfig?.providers || [];

    const subgraphUrls: string[] = localChainConfig?.subgraphUrls || everclearChainConfig?.subgraphUrls || [];

    const deployments: any = localChainConfig?.deployments || everclearChainConfig?.deployments || {};
    const assets: any = localChainConfig?.assets || everclearChainConfig?.assets || {};

    chainsForMonitorConfig[domainId] = {
      providers,
      subgraphUrls,
      confirmations,
      deployments,
      assets,
    };
  }

  const thresholdsConfig: ThresholdsConfig = { ...DefaultThresholds, ...localThresholds };

  const database = process.env.MONITOR_DATABASE_URL || configJson.database?.url || configFile.database?.url;

  const monitorConfig: MonitorConfig = {
    environment: configJson.environment || configFile.environment || 'production',
    network: configJson.network || configFile.network || 'mainnet',
    hub: hubConfig,
    chains: chainsForMonitorConfig,
    agents: configJson.agents || configFile.agents,
    redis: configJson.redis || configFile.redis,
    server: {
      port: configJson?.server?.port || configFile?.server?.port || 8080,
      adminToken: configJson?.server?.adminToken || configFile?.server?.adminToken || 'blahblah',
      host: configJson?.server?.host || configFile?.server?.host || '0.0.0.0',
    },
    logLevel: configJson.logLevel || configFile.logLevel || 'info',
    polling: {
      agent: configJson?.polling?.agent || configFile?.polling?.agent || DEFAULT_POLL_INTERVAL,
      config: configJson?.polling?.config || configFile?.polling?.config || DEFAULT_POLL_INTERVAL,
    },
    abis: abiConfig,
    database: {
      url: database || '',
    },
    relayers: configJson.relayers || configFile.relayers || [],
    thresholds: thresholdsConfig,
    betterUptime: configJson.betterUptime || configFile.betterUptime || {},
    telegram: configJson.telegram || configFile.telegram || {},
    healthUrls: process.env.MONITOR_HEALTH_URLS || configJson.healthUrls || configFile.healthUrls || {},
    shadowTables: configJson.shadowTables || configFile.shadowTables || DefaultShadowTables,
    tokenomicsTables: configJson.tokenomicsTables || configFile.tokenomicsTables || DefaultTokenomicsTables,
  };

  const validate = ajv.compile(TMonitorConfigSchema);
  const valid = validate(monitorConfig);
  if (!valid) {
    throw new Error(validate.errors?.map((err: any) => JSON.stringify(err, null, 2)).join(','));
  }

  return monitorConfig;
};

/**
 * Check the Everclear configuration changes to apply them gracefully.
 *
 * @returns true - reload, false - no need
 */
export const shouldReloadEverclearConfig = async (): Promise<{ reloadConfig: boolean; reloadSubgraph: boolean }> => {
  const { logger } = getContext();
  const { requestContext, methodContext } = createLoggingContext(shouldReloadEverclearConfig.name);
  let reloadSubgraph = false;
  let reloadConfig = false;

  const everclearConfig = await getEverclearConfig(cachedEverclearConfigUrl);

  if (!everclearConfig) return { reloadConfig, reloadSubgraph };
  for (const domainId of Object.keys(cachedEverclearConfig.chains)) {
    const cachedSubgraphUrls = cachedEverclearConfig.chains[domainId].subgraphUrls;
    const newSubgraphUrls = everclearConfig.chains[domainId].subgraphUrls;
    if (!lodash.isEqual(cachedSubgraphUrls, newSubgraphUrls)) {
      logger.info(`Subgraph urls changed`, requestContext, methodContext, {
        domainId,
        cached: cachedSubgraphUrls.join(','),
        new: newSubgraphUrls.join(','),
      });
      reloadSubgraph = true;
      reloadConfig = true;
    }
  }

  if (!reloadSubgraph) {
    reloadConfig = !lodash.isEqual(everclearConfig, cachedEverclearConfig);
  }

  return { reloadConfig, reloadSubgraph };
};
