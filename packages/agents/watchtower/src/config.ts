import { ajv, EverclearConfig, createLoggingContext, getDefaultABIConfig } from '@chimera-monorepo/utils';
import { config as dotenvConfig } from 'dotenv';
import lodash from 'lodash';
import { ChainConfig, WatcherConfig, TWatcherConfigSchema } from './lib/entities';
import { existsSync, readFileSync, getEverclearConfig } from './mockable';
import { getContext } from './watcher';
import { SubgraphConfig } from '@chimera-monorepo/adapters-subgraph';

dotenvConfig();

let cachedEverclearConfigUrl: string | undefined = undefined;
let cachedEverclearConfig: EverclearConfig = {} as any;

const DEFAULT_CONFIRMATIONS = 3;
const DEFAULT_SUBGRAPH_TIMEOUT = 7500;

/**
 * Get the centralized config and override it with local config.
 *
 * @returns The watcher config
 */
export const getConfig = async (): Promise<WatcherConfig> => {
  let configJson: Record<string, any> = {};
  let configFile: any = {};
  try {
    configJson = JSON.parse(process.env.WATCHTOWER_CONFIG || '');
  } catch (e: unknown) {
    console.info('No WATCHTOWER_CONFIG exists, using config file and individual env vars');
  }
  try {
    let json: string;

    const path = process.env.EVERCLEAR_CONFIG_FILE ?? process.env.WATCHTOWER_CONFIG_FILE ?? 'config.json';
    if (existsSync(path)) {
      json = readFileSync(path, { encoding: 'utf-8' });
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
    providers: (configJson?.hub?.providers || configFile?.hub?.providers || everclearConfig?.hub.providers || []).map(
      (url: string) => ({ url: url, priority: 0 }),
    ),
    deployments: configJson?.hub?.deployments || configFile?.hub?.deployments || everclearConfig?.hub.deployments,
    subgraphUrls:
      configJson?.hub?.subgraphUrls || configFile?.hub?.subgraphUrls || everclearConfig?.hub.subgraphUrls || [],
    gasMultiplier: configJson?.hub?.gasMultiplier || configFile?.hub?.gasMultiplier || 2,
  };

  const environment = process.env.watcher_ENVIRONMENT || configJson.environment || configFile.environment || 'staging';
  const abiConfig =
    configJson.abis || configFile.abis || everclearConfig?.abis || getDefaultABIConfig(environment, hubConfig.domain);

  const everclearChains = everclearConfig?.chains ?? {};
  const localChains = configJson.chains || configFile.chains || {};
  const domains = (Object.keys(localChains).length > 0 ? Object.keys(localChains) : Object.keys(everclearChains)).map(
    (x) => +x,
  );

  const chainsForWatcherConfig: Record<string, ChainConfig> = {};
  for (const domainId of domains) {
    const localChainConfig = localChains[domainId];
    const everclearChainConfig = everclearChains[domainId];

    const confirmations =
      localChainConfig?.confirmations || everclearChainConfig?.confirmations || DEFAULT_CONFIRMATIONS;

    const providers = (everclearChainConfig?.providers || []).map((url: string) => ({ url, priority: 1 }));
    if (localChainConfig?.providers?.length) {
      providers.push(...localChainConfig.providers.map((url: string) => ({ url, priority: 0 })));
    }

    const subgraphUrls: string[] = localChainConfig?.subgraphUrls || everclearChainConfig?.subgraphUrls || [];
    const deployments: any = localChainConfig?.deployments || everclearChainConfig?.deployments || {};
    const assets: any = localChainConfig?.assets || everclearChainConfig?.assets || {};
    const gasMultiplier = localChainConfig?.gasMultiplier || 2;

    chainsForWatcherConfig[domainId] = {
      providers,
      confirmations,
      subgraphUrls,
      deployments,
      assets,
      gasMultiplier,
    };
  }

  const watcherConfig: WatcherConfig = {
    web3SignerUrl: process.env.WEB3_SIGNER_URL || configJson.web3SignerUrl || configFile.web3SignerUrl,
    redis: {
      host: process.env.REDIS_HOST || configJson.redis?.host || configFile.redis?.host,
      port: process.env.REDIS_PORT || configJson.redis?.port || configFile.redis?.port || 6379,
    },
    server: {
      port: process.env.SERVER_SUB_PORT || configJson.server?.sub?.port || configFile.server?.sub?.port || 8080,
      host: process.env.SERVER_SUB_HOST || configJson.server?.sub?.host || configFile.server?.sub?.host || '0.0.0.0',
      adminToken:
        process.env.ADMIN_TOKEN || configJson.server?.adminToken || configFile.server?.adminToken || 'blahblah',
    },
    logLevel: process.env.LOG_LEVEL || configJson.logLevel || configFile.logLevel || 'info',
    network: process.env.NETWORK || configJson.network || configFile.network || 'testnet',
    environment,
    hub: hubConfig,
    chains: chainsForWatcherConfig,
    abis: abiConfig,
    discordHookUrl: process.env.DISCORD_HOOK_URL || configJson.discordHookUrl || configFile.discordHookUrl,
    twilio: {
      number: process.env.TWILIO_NUMBER || configJson.twilioNumber || configFile.twilioNumber,
      accountSid: process.env.TWILIO_ACCOUNT_SID || configJson.twilioAccountSid || configFile.twilioAccountSid,
      authToken: process.env.TWILIO_AUTH_TOKEN || configJson.twilioAuthToken || configFile.twilioAuthToken,
      toPhoneNumbers:
        process.env.TWILIO_TO_PHONE_NUMBERS || configJson.twilioToPhoneNumbers || configFile.twilioToPhoneNumbers || [],
    },
    telegram: {
      apiKey: process.env.TELEGRAM_API_KEY || configJson.telegramApiKey || configFile.telegramApiKey,
      chatId: process.env.TELEGRAM_CHAT_ID || configJson.telegramChatId || configFile.telegramChatId,
    },
    betterUptime: {
      apiKey: process.env.BETTER_UPTIME_API_KEY || configJson.betterUptimeApiKey || configFile.betterUptimeApiKey,
      requesterEmail:
        process.env.BETTER_UPTIME_REQUESTER_EMAIL ||
        configJson.betterUptimeRequesterEmail ||
        configFile.betterUptimeRequesterEmail,
    },
    failedCheckRetriesLimit: Number(
      process.env.FAILED_CHECK_RETRIES_LIMIT ||
        configJson.failedCheckRetriesLimit ||
        configFile.failedCheckRetriesLimit ||
        15,
    ),
    assetCheckInterval: Number(
      process.env.ASSET_CHECK_INTERVAL || configJson.assetCheckInterval || configFile.assetCheckInterval || 30_000,
    ),
    reloadConfigInterval: Number(
      process.env.RELOAD_CONFIG_INTERVAL ||
        configJson.reloadConfigInterval ||
        configFile.reloadConfigInterval ||
        100_000,
    ),
  };

  const validate = ajv.compile(TWatcherConfigSchema);

  const valid = validate(watcherConfig);

  if (!valid) {
    throw new Error(validate.errors?.map((err: unknown) => JSON.stringify(err, null, 2)).join(','));
  }

  return watcherConfig;
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

/**
 * Helper to get subgraph reader config
 * @param chains Chain entry of monitor config
 * @returns SubgraphConfig used to instantiate subgraph reader
 */
export const getSubgraphReaderConfig = (chains: WatcherConfig['chains']): SubgraphConfig => {
  const subgraphs: Record<string, { endpoints: string[]; timeout: number }> = {};
  Object.keys(chains).forEach((domainId) => {
    subgraphs[domainId] = { endpoints: chains[domainId].subgraphUrls, timeout: DEFAULT_SUBGRAPH_TIMEOUT };
  });
  return { subgraphs };
};
