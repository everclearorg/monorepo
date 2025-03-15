/* eslint-disable @typescript-eslint/no-explicit-any */
import { existsSync, readFileSync } from 'fs';
import { Type, Static } from '@sinclair/typebox';
import { config as dotenvConfig } from 'dotenv';
import {
  getDefaultABIConfig,
  ajv,
  ChainConfig,
  getEverclearConfig,
  LogLevel,
  TABIConfig,
  TChainConfig,
  THubConfig,
  TLogLevel,
  TRelayerConfig,
  TRewardConfig,
  TEnvironment,
  Environment,
  TSafeConfig,
  TokenVolumeReward,
  TokenStakingReward,
} from '@chimera-monorepo/utils';
import { InvalidConfig } from './errors';
import { getSsmParameter } from './tasks/helpers/mockable';

// FIXME: read from chaindata
const DEFAULT_SIZE = 10;
const DEFAULT_AGE = 90 * 60; // 90 minutes
const DEFAULT_CONFIRMATIONS = 3;
const DEFAULT_GAS_LIMIT = 30_000_000;
const DEFAULT_HEALTH_BASE_URI = 'https://uptime.betterstack.com/api/v1/heartbeat/';
const DEFAULT_REWARDS_CONFIG = {
  volume: {
    tokens: [
      {
        // 750000 CLEAR
        epochVolumeReward: '750000000000000000000000',
        baseRewardDbps: 12,
        maxBpsUsdVolumeCap: 250000000,
      },
    ],
  },
  staking: {
    tokens: [
      {
        apy: [
          { term: 3, apyBps: 400 },
          { term: 12, apyBps: 600 },
          { term: 15, apyBps: 800 },
          { term: 18, apyBps: 1000 },
          { term: 21, apyBps: 1200 },
          { term: 24, apyBps: 1400 },
        ],
      },
      {
        apy: [
          { term: 3, apyBps: 200 },
          { term: 6, apyBps: 400 },
          { term: 9, apyBps: 600 },
        ],
      },
    ],
  },
};

dotenvConfig();

export const TLighthouseService = Type.Union([
  Type.Literal('intent'),
  Type.Literal('fill'),
  Type.Literal('settlement'),
  Type.Literal('expired'),
  Type.Literal('invoice'),
  Type.Literal('reward'),
  Type.Literal('reward_metadata'),
]);
export type LighthouseService = Static<typeof TLighthouseService>;

export const TThresholdConfig = Type.Object({
  maxAge: Type.Number(),
  size: Type.Number(),
});
export type ThresholdConfig = Static<typeof TThresholdConfig>;

export const TLighthouseConfig = Type.Object({
  logLevel: TLogLevel,
  environment: TEnvironment,
  network: Type.String(),
  hub: THubConfig,
  abis: TABIConfig,
  database: Type.Object({
    url: Type.String(),
  }),
  relayers: Type.Array(TRelayerConfig),
  chains: Type.Record(Type.String(), TChainConfig),
  rewards: Type.Partial(TRewardConfig),
  service: TLighthouseService,
  healthUrls: Type.Partial(Type.Record(TLighthouseService, Type.String({ format: 'uri' }))),
  thresholds: Type.Record(Type.String(), TThresholdConfig),
  signer: Type.String(), // private key, mnemonic, web3signer url
  coingecko: Type.String(),
  safe: TSafeConfig,
  betterUptime: Type.Optional(
    Type.Object({
      apiKey: Type.Optional(Type.String()),
      requesterEmail: Type.Optional(Type.String()),
    }),
  ),
});
export type LighthouseConfig = Static<typeof TLighthouseConfig>;

export const loadConfig = async (): Promise<LighthouseConfig> => {
  let configJson: any = {};
  let configFile: any = {};
  let configStr: string | undefined;

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
    console.info('Lighthouse CONFIG_PARAMETER_NAME is not set');
  }

  // try to read from env
  try {
    configJson = JSON.parse(configStr || process.env.LIGHTHOUSE_CONFIG || '{}');
  } catch (e: unknown) {
    console.warn('No LIGHTHOUSE_CONFIG exists, using config file and individual env vars', e);
  }

  try {
    let json: string;

    const path = process.env.LIGHTHOUSE_CONFIG_FILE ?? 'config.json';
    if (existsSync(path)) {
      json = readFileSync(path, { encoding: 'utf-8' });
      configFile = JSON.parse(json);
    }
  } catch (e: unknown) {
    console.error('Error reading config file!', e);
    process.exit(1);
  }

  const everclearConfigUrl =
    process.env.EVERCLEAR_CONFIG || configJson.everclearConfig || configFile.everclearConfig || undefined;
  const everclearConfig = await getEverclearConfig(everclearConfigUrl);

  const environment = (process.env.LIGHTHOUSE_ENVIRONMENT ||
    configJson?.environment ||
    configFile?.environment ||
    'staging') as Environment;
  const network = configJson.network || configFile.network || 'mainnet';
  const localChains = configJson.chains || configFile.chains || {};
  const everclearChains = everclearConfig?.chains ?? {};

  const domains = (Object.keys(localChains).length > 0 ? Object.keys(localChains) : Object.keys(everclearChains)).map(
    (x) => +x,
  );

  const hubConfig = {
    domain: configJson?.hub?.domain || configFile?.hub?.domain || everclearConfig?.hub.domain,
    providers: configJson?.hub?.providers || configFile?.hub?.providers || everclearConfig?.hub.providers,
    deployments: configJson?.hub?.deployments || configFile?.hub?.deployments || everclearConfig?.hub.deployments,
    subgraphUrls:
      configJson?.hub?.subgraphUrls || configFile?.hub?.subgraphUrls || everclearConfig?.hub.subgraphUrls || [],
    confirmations: configJson?.hub?.confirmations || configFile?.hub?.confirmations,
    assets: configJson?.hub?.assets || configFile?.hub?.assets || everclearConfig?.hub.assets,
  };
  const abiConfig =
    configJson.abis || configFile.abis || everclearConfig?.abis || getDefaultABIConfig(environment, hubConfig.domain);

  // Get chains
  const chainsForLighthouseConfig: Record<string, ChainConfig> = {};
  for (const domainId of domains.concat(hubConfig.domain)) {
    const localChainConfig = localChains[domainId];
    const everclearChainConfig = everclearChains[domainId];

    const confirmations =
      localChainConfig?.confirmations || everclearChainConfig?.confirmations || DEFAULT_CONFIRMATIONS;

    const providers: string[] = localChainConfig?.providers || everclearChainConfig?.providers || [];

    const subgraphUrls: string[] = localChainConfig?.subgraphUrls || everclearChainConfig?.subgraphUrls || [];

    const deployments = localChainConfig?.deployments || everclearChainConfig?.deployments || {};
    const assets = localChainConfig?.assets || everclearChainConfig?.assets || {};
    const gasLimit = localChainConfig?.gasLimit || everclearChainConfig?.gasLimit || DEFAULT_GAS_LIMIT;

    chainsForLighthouseConfig[domainId] = {
      providers,
      subgraphUrls,
      confirmations,
      deployments,
      assets,
      gasLimit,
    };
  }

  // Get thresholds
  const thresholds: Record<string, ThresholdConfig> = {};
  [...domains, hubConfig.domain ?? undefined]
    .filter((x) => !!x)
    .forEach((domain) => {
      const age = (configJson?.thresholds || configFile?.thresholds)?.[domain]?.maxAge;
      const size = (configJson?.thresholds || configFile?.thresholds)?.[domain]?.size;
      thresholds[domain] = {
        maxAge: age ?? DEFAULT_AGE,
        size: size ?? DEFAULT_SIZE,
      };
    });

  const database = process.env.LIGHTHOUSE_DATABASE_URL || configJson.database?.url || configFile.database?.url;

  const healthUrls = configJson?.healthUrls || configFile?.healthUrls || {};
  for (const key in healthUrls) {
    if (!healthUrls[key].startsWith('http')) {
      healthUrls[key] = DEFAULT_HEALTH_BASE_URI + healthUrls[key];
    }
  }

  const rewards = configJson.rewards || configFile.rewards || {};
  if (rewards.volume?.tokens) {
    rewards.volume.tokens = rewards.volume.tokens.map((item: TokenVolumeReward, index: number) => {
      return { ...DEFAULT_REWARDS_CONFIG.volume.tokens[index], ...item };
    });
  }
  if (rewards.staking?.tokens) {
    rewards.staking.tokens = rewards.staking.tokens.map((item: TokenStakingReward, index: number) => {
      return { ...DEFAULT_REWARDS_CONFIG.staking.tokens[index], ...item };
    });
  }

  // Generate config
  const lighthouseConfig: LighthouseConfig = {
    chains: chainsForLighthouseConfig,
    hub: hubConfig,
    abis: abiConfig,
    database: {
      url: database || '',
    },
    thresholds,
    signer: process.env.LIGHTHOUSE_SIGNER || configJson?.signer || configFile?.signer || '',
    relayers: configJson.relayers || configFile.relayers || [],
    rewards,
    logLevel: (process.env.LIGHTHOUSE_LOG_LEVEL || configFile?.logLevel || 'info') as LogLevel,
    environment,
    network,
    service: (process.env.LIGHTHOUSE_SERVICE || configFile?.service || 'intent') as LighthouseService,
    healthUrls,
    coingecko: configJson?.coingecko || configFile?.coingecko || '',
    safe: configJson?.safe || configFile?.safe || {},
    betterUptime: configJson.betterUptime || configFile.betterUptime || {},
  };

  // Validate schema
  const validate = ajv.compile(TLighthouseConfig);
  const valid = validate(lighthouseConfig);
  if (!valid) {
    throw new InvalidConfig(
      validate.errors?.map((err: unknown) => JSON.stringify(err, null, 2)).join(',') ?? '',
      lighthouseConfig,
    );
  }

  return lighthouseConfig;
};

let config: LighthouseConfig | undefined;

/**
 * Caches and returns the environment config
 *
 * @returns The config
 */
export const getConfig = async (): Promise<LighthouseConfig> => {
  if (!config) {
    config = await loadConfig();
  }
  return config;
};
