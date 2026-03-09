/* eslint-disable @typescript-eslint/no-explicit-any */
import {
  ajv,
  EverclearConfig,
  ChainConfig,
  createLoggingContext,
  ThresholdsConfig,
  jsonifyError,
} from '@chimera-monorepo/utils';
import { MonitorConfig, TMonitorConfigSchema } from './types';
import { config as dotenvConfig } from 'dotenv';
import lodash from 'lodash';
import * as fs from 'fs';
import { getContext } from './context';
import { getDefaultABIConfig, getEverclearConfig, getSsmParameter } from './mockable';

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

export const getConfig = async (): Promise<MonitorConfig> => {
  let configJson: Record<string, any> = {};
  let configFile: any = {};
  let configStr: string | undefined;
  let triageConfigJson: Record<string, any> = {};

  const paramName = process.env.CONFIG_PARAMETER_NAME;
  if (paramName) {
    try {
      configStr = await getSsmParameter(paramName);
      if (!configStr) {
        console.info(paramName, 'is not found in parameter store');
      }
    } catch (e: unknown) {
      console.info('Error getting', paramName, 'from parameter store', e);
    }
  } else {
    console.info('Monitor CONFIG_PARAMETER_NAME is not set');
  }

  try {
    configJson = JSON.parse(configStr || process.env.MONITOR_CONFIG || '');
  } catch (e: unknown) {
    console.info('No MONITOR_CONFIG exists, using config file and individual env vars');
  }

  try {
    triageConfigJson = JSON.parse(process.env.TRIAGE_CONFIG || '{}');
  } catch (e: unknown) {
    console.info('TRIAGE_CONFIG is not valid JSON, ignoring override');
  }

  const normalizeTriageConfig = (input: Record<string, any>): Record<string, any> => {
    if (!input || typeof input !== 'object') {
      return {};
    }
    if (input.triage && typeof input.triage === 'object') {
      return input.triage;
    }
    const triageKeys = new Set([
      'mode',
      'timeoutMs',
      'lookbackHours',
      'retentionHours',
      'timeBucketMinutes',
      'providers',
      'routing',
      'autoResolve',
      'circuitBreaker',
    ]);
    const hasDirectShape = Object.keys(input).some((k) => triageKeys.has(k));
    return hasDirectShape ? input : {};
  };
  const triageOverride = normalizeTriageConfig(triageConfigJson);

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

  const everclearConfigUrl = process.env.EVERCLEAR_CONFIG || configJson.everclearConfig || configFile.everclearConfig;

  cachedEverclearConfigUrl = everclearConfigUrl;
  let everclearConfig;
  if (everclearConfigUrl) {
    try {
      everclearConfig = await getEverclearConfig(everclearConfigUrl);
    } catch (e) {
      console.error('Failed to fetch everclear config:', e);
    }
  } else {
    console.warn('Everclear config URL not set');
  }
  if (everclearConfig) cachedEverclearConfig = everclearConfig;

  const hubDomain = configJson?.hub?.domain || configFile?.hub?.domain || everclearConfig?.hub.domain;
  const hubProviders = configJson?.hub?.providers || configFile?.hub?.providers || everclearConfig?.hub.providers;
  const hubDeployments =
    configJson?.hub?.deployments || configFile?.hub?.deployments || everclearConfig?.hub.deployments;
  const hubAssets = configJson?.hub?.assets || configFile?.hub?.assets || everclearConfig?.hub?.assets;
  const hubSubgraphUrls =
    configJson?.hub?.subgraphUrls || configFile?.hub?.subgraphUrls || everclearConfig?.hub?.subgraphUrls || [];
  const hubEnvioSubgraphUrl =
    configJson?.hub?.envioSubgraphUrl || configFile?.hub?.envioSubgraphUrl || everclearConfig?.hub?.envioSubgraphUrl;

  // Get hub-specific gas thresholds if provided
  const hubMinGasOnRelayer =
    configJson?.hub?.minGasOnRelayer ||
    configFile?.hub?.minGasOnRelayer ||
    configJson?.thresholds?.minGasOnRelayer ||
    configFile?.thresholds?.minGasOnRelayer;
  const hubMinGasOnGateway =
    configJson?.hub?.minGasOnGateway ||
    configFile?.hub?.minGasOnGateway ||
    configJson?.thresholds?.minGasOnGateway ||
    configFile?.thresholds?.minGasOnGateway;

  const hubConfig = {
    domain: hubDomain,
    providers: hubProviders,
    deployments: hubDeployments,
    assets: hubAssets,
    subgraphUrls: hubSubgraphUrls,
    envioSubgraphUrl: hubEnvioSubgraphUrl,
    // Only include these properties if they were specified
    ...(hubMinGasOnRelayer !== undefined && { minGasOnRelayer: hubMinGasOnRelayer }),
    ...(hubMinGasOnGateway !== undefined && { minGasOnGateway: hubMinGasOnGateway }),
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
    const network: string = localChainConfig?.network || everclearChainConfig?.network || 'evm';

    // Include chain-specific gas thresholds if provided
    const minGasOnRelayer = localChainConfig?.minGasOnRelayer || localThresholds?.minGasOnRelayer;
    const minGasOnGateway = localChainConfig?.minGasOnGateway || localThresholds?.minGasOnGateway;

    chainsForMonitorConfig[domainId] = {
      providers,
      subgraphUrls,
      confirmations,
      deployments,
      assets,
      network,
      // Only include these properties if they were specified
      ...(minGasOnRelayer !== undefined && { minGasOnRelayer }),
      ...(minGasOnGateway !== undefined && { minGasOnGateway }),
    };

    if (localChainConfig?.privateKey) {
      chainsForMonitorConfig[domainId].privateKey = localChainConfig.privateKey;
    }
  }

  const thresholdsConfig: ThresholdsConfig = { ...DefaultThresholds, ...localThresholds };

  const database = process.env.MONITOR_DATABASE_URL || configJson.database?.url || configFile.database?.url;

  const configuredAdminToken =
    process.env.MONITOR_ADMIN_TOKEN || configJson?.server?.adminToken || configFile?.server?.adminToken;
  const allowMissingAdminToken = ['development', 'dev', 'local', 'test'].includes(String(environment).toLowerCase());
  if (!configuredAdminToken && !allowMissingAdminToken) {
    throw new Error('server.adminToken is required in non-development environments');
  }

  const monitorConfig: MonitorConfig = {
    environment: configJson.environment || configFile.environment || 'production',
    network: configJson.network || configFile.network || 'mainnet',
    hub: hubConfig,
    chains: chainsForMonitorConfig,
    agents: configJson.agents || configFile.agents,
    redis: configJson.redis || configFile.redis,
    server: {
      port: configJson?.server?.port || configFile?.server?.port || 8080,
      adminToken: configuredAdminToken || 'development-only-token',
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
    ...(() => {
      const eventPipelineConfig = {
        ...(configJson.eventPipeline || configFile.eventPipeline || {}),
        ...((process.env.ALERT_EVENT_WEBHOOK_URL || process.env.MONITOR_WEBHOOK_URL)
          ? { webhookUrl: process.env.ALERT_EVENT_WEBHOOK_URL || process.env.MONITOR_WEBHOOK_URL }
          : {}),
        ...((process.env.ALERT_EVENT_WEBHOOK_SECRET || process.env.MONITOR_WEBHOOK_SECRET)
          ? { webhookSecret: process.env.ALERT_EVENT_WEBHOOK_SECRET || process.env.MONITOR_WEBHOOK_SECRET }
          : {}),
        ...(process.env.ALERT_EVENT_ENVIRONMENT ? { environment: process.env.ALERT_EVENT_ENVIRONMENT } : {}),
        ...(process.env.ALERT_EVENT_RETRIES ? { retries: Number(process.env.ALERT_EVENT_RETRIES) } : {}),
        ...(process.env.ALERT_EVENT_RETRY_BASE_MS
          ? { retryBaseMs: Number(process.env.ALERT_EVENT_RETRY_BASE_MS) }
          : {}),
        ...(process.env.ALERT_EVENT_TIMEOUT_MS ? { timeoutMs: Number(process.env.ALERT_EVENT_TIMEOUT_MS) } : {}),
      };
      return Object.keys(eventPipelineConfig).length > 0
        ? { eventPipeline: eventPipelineConfig }
        : {};
    })(),
    triage: Object.keys(triageOverride).length > 0 ? triageOverride : configJson.triage || configFile.triage || {},
    healthUrls: process.env.MONITOR_HEALTH_URLS || configJson.healthUrls || configFile.healthUrls || {},
    tokenomicsTables: configJson.tokenomicsTables || configFile.tokenomicsTables || DefaultTokenomicsTables,
    solana: configJson?.solana || configFile?.solana || {},
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

  if (!cachedEverclearConfigUrl) return { reloadConfig: false, reloadSubgraph: false };

  let everclearConfig: EverclearConfig | undefined = undefined;
  try {
    everclearConfig = await getEverclearConfig(cachedEverclearConfigUrl);
  } catch (e) {
    logger.error('Failed to fetch everclear config', requestContext, methodContext, jsonifyError(e as Error));
  }
  if (!everclearConfig) return { reloadConfig: false, reloadSubgraph: false };

  // If we have no cached config (e.g. initial fetch failed), signal a reload
  if (!cachedEverclearConfig.chains) {
    return { reloadConfig: true, reloadSubgraph: true };
  }

  let reloadSubgraph = false;
  let reloadConfig = false;
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
