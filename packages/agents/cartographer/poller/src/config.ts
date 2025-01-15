import { existsSync, readFileSync } from 'fs';

import { Type, Static } from '@sinclair/typebox';
import { config as dotenvConfig } from 'dotenv';
import { ajv, ChainConfig, getEverclearConfig, TChainConfig, THubConfig, TLogLevel } from '@chimera-monorepo/utils';
import { DEFAULT_SAFE_CONFIRMATIONS } from './lib/operations';

const DEFAULT_POLL_INTERVAL = 15_000;

dotenvConfig();

export const TService = Type.Union([
  Type.Literal('invoices'),
  Type.Literal('intents'),
  Type.Literal('depositors'),
  Type.Literal('monitor'),
]);

export const CartographerConfigSchema = Type.Object({
  pollInterval: Type.Integer({ minimum: 1000 }),
  logLevel: TLogLevel,
  database: Type.String({ format: 'uri' }),
  environment: Type.Union([Type.Literal('staging'), Type.Literal('production')]),
  chains: Type.Record(Type.String(), TChainConfig),
  hub: THubConfig,
  service: TService,
  healthUrls: Type.Partial(Type.Record(TService, Type.String({ format: 'uri' }))),
});

export type CartographerConfig = Static<typeof CartographerConfigSchema>;

/**
 * Gets and validates the config from the environment.
 *
 * @returns The config with sensible defaults
 */
export const getEnvConfig = async (): Promise<CartographerConfig> => {
  let configJson: Record<string, any> = {};
  let configFile: any = {};

  try {
    configJson = JSON.parse(process.env.CARTOGRAPHER_CONFIG || '{}');
  } catch (e: unknown) {
    console.info('No CARTOGRAPHER_CONFIG exists, using config file and individual env vars', e);
  }
  try {
    let json: string;

    const path = process.env.CARTOGRAPHER_CONFIG_FILE ?? 'config.json';
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
  const everclearChains = everclearConfig?.chains ?? {};
  const localChains = configJson.chains || configFile.chains || everclearChains || {};

  const hubConfig = {
    domain: configJson?.hub?.domain || configFile?.hub?.domain || everclearConfig?.hub.domain,
    providers: configJson?.hub?.providers || configFile?.hub?.providers || everclearConfig?.hub.providers,
    deployments: configJson?.hub?.deployments || configFile?.hub?.deployments || everclearConfig?.hub.deployments,
    subgraphUrls:
      configJson?.hub?.subgraphUrls || configFile?.hub?.subgraphUrls || everclearConfig?.hub.subgraphUrls || [],
    confirmations: configJson?.hub?.confirmations || configFile?.hub?.confirmations || DEFAULT_SAFE_CONFIRMATIONS,
  };

  const chainsForConfig: Record<string, ChainConfig> = {};
  for (const domainId of Object.keys(localChains)) {
    const localChainConfig = localChains[domainId];
    const everclearChainConfig = everclearChains[domainId];

    const confirmations =
      localChainConfig?.confirmations || everclearChainConfig?.confirmations || DEFAULT_SAFE_CONFIRMATIONS;
    const providers: string[] = localChainConfig?.providers || everclearChainConfig?.providers || [];
    const deployments: any = localChainConfig?.deployments || everclearChainConfig?.deployments || {};
    const subgraphUrls: string[] = localChainConfig?.subgraphUrls || everclearChainConfig?.subgraphUrls || [];

    chainsForConfig[domainId] = {
      subgraphUrls,
      providers,
      confirmations,
      deployments,
    };
  }

  const config: CartographerConfig = {
    pollInterval:
      process.env.CARTOGRAPHER_POLL_INTERVAL ||
      configJson.pollInterval ||
      configFile.pollInterval ||
      DEFAULT_POLL_INTERVAL,
    logLevel: process.env.CARTOGRAPHER_LOG_LEVEL || configJson.logLevel || configFile.logLevel || 'info',
    service: process.env.CARTOGRAPHER_SERVICE || configJson.service || configFile.service || 'messages',
    database: process.env.DATABASE_URL || configJson.databaseUrl || configFile.databaseUrl,
    environment:
      process.env.CARTOGRAPHER_ENVIRONMENT || configJson.environment || configFile.environment || 'production',
    chains: chainsForConfig,
    hub: hubConfig,
    healthUrls: process.env.CARTOGRAPHER_HEALTH_URLS || configJson.healthUrls || configFile.healthUrls || {},
  };

  const validate = ajv.compile(CartographerConfigSchema);

  const valid = validate(config);

  if (!valid) {
    throw new Error(validate.errors?.map((err: unknown) => JSON.stringify(err, null, 2)).join(','));
  }

  return config;
};

let everclearConfig: CartographerConfig | undefined;

/**
 * Caches and returns the environment config
 *
 * @returns The config
 */
export const getConfig = async (): Promise<CartographerConfig> => {
  if (!everclearConfig) {
    everclearConfig = await getEnvConfig();
  }
  return everclearConfig;
};
