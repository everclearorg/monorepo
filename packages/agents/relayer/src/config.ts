import * as fs from 'fs';
import { getEverclearConfig, ajv, EVERCLEAR_CONFIG_URL, getDefaultABIConfig } from '@chimera-monorepo/utils';
import { RelayerConfig, RelayerConfigSchema } from './lib/entities';
import { ChainConfig } from './lib/entities';

const DEFAULT_CONFIRMATIONS = 3;

export const getEnvConfig = async (): Promise<RelayerConfig> => {
  let configJson: Record<string, any> = {};
  let configFile: any = {};

  try {
    configJson = JSON.parse(process.env.EVERCLEAR_CONFIG || process.env.RELAYER_CONFIG || '');
  } catch (e: unknown) {
    console.info('No RELAYER_CONFIG or EVERCLEAR_CONFIG exists; using config file and individual env vars.');
  }
  try {
    let json: string;

    const path = process.env.EVERCLEAR_CONFIG_FILE ?? process.env.RELAYER_CONFIG_FILE ?? 'config.json';
    if (fs.existsSync(path)) {
      json = fs.readFileSync(path, { encoding: 'utf-8' });
      configFile = JSON.parse(json);
    }
  } catch (e: unknown) {
    console.error('Error reading config file!');
    process.exit(1);
  }

  const everclearConfigUrl =
    process.env.EVERCLEAR_CONFIG || configJson.everclearConfig || configFile.everclearConfig || EVERCLEAR_CONFIG_URL;

  const everclearConfig = await getEverclearConfig(everclearConfigUrl);
  const everclearChains = everclearConfig?.chains ?? {};
  const localChains = configJson.chains || configFile.chains || everclearChains || {};
  const hubConfig = {
    domain: configJson?.hub?.domain || configFile?.hub?.domain || everclearConfig?.hub.domain,
    providers: configJson?.hub?.providers || configFile?.hub?.providers || everclearConfig?.hub.providers,
    deployments: configJson?.hub?.deployments || configFile?.hub?.deployments || everclearConfig?.hub.deployments,
    minGasPrice: configJson?.hub?.minGasPrice || configFile?.hub?.minGasPrice,
    confirmations:
      configJson?.hub?.confirmations ??
      configFile?.hub?.confirmations ??
      everclearConfig?.hub.confirmations ??
      DEFAULT_CONFIRMATIONS,
  };
  const environment =
    process.env.RELAYER_ENVIRONMENT || configJson?.environment || configFile?.environment || 'staging';
  const abiConfig =
    configJson.abis || configFile.abis || everclearConfig?.abis || getDefaultABIConfig(environment, hubConfig.domain);

  const chainsForRelayerConfig: Record<string, ChainConfig> = {};
  for (const domainId of Object.keys(localChains)) {
    const localChainConfig = localChains[domainId];
    const everclearChainConfig = everclearChains[domainId];

    const confirmations =
      localChainConfig?.confirmations || everclearChainConfig?.confirmations || DEFAULT_CONFIRMATIONS;
    const providers: string[] = localChainConfig?.providers || everclearChainConfig?.providers || [];
    const deployments: any = localChainConfig?.deployments || everclearChainConfig?.deployments || {};
    const minGasPrice = localChainConfig?.minGasPrice;

    chainsForRelayerConfig[domainId] = {
      providers,
      confirmations,
      deployments,
      minGasPrice,
    };
  }

  // Add hub chain to config chains
  chainsForRelayerConfig[hubConfig.domain] = {
    providers: hubConfig.providers || [],
    confirmations: hubConfig.confirmations,
    deployments: hubConfig.deployments || {},
    minGasPrice: hubConfig.minGasPrice,
  };

  const _relayerConfig: RelayerConfig = {
    logLevel:
      process.env.RELAYER_LOG_LEVEL ||
      configJson.logLevel ||
      configFile.logLevel ||
      process.env.EVERCLEAR_LOG_LEVEL ||
      'info',
    network:
      process.env.RELAYER_NETWORK ||
      configJson.network ||
      configFile.network ||
      process.env.EVERCLEAR_NETWORK ||
      'testnet',
    web3SignerUrl:
      process.env.RELAYER_WEB3_SIGNER_URL ||
      process.env.EVERCLEAR_WEB3_SIGNER_URL ||
      configJson.web3SignerUrl ||
      configFile.web3SignerUrl,
    server: {
      port: process.env.RELAYER_SERVER_PORT || configJson?.server?.port || configFile?.server?.port || 8080,
      host: process.env.RELAYER_SERVER_HOST || configJson?.server?.host || configFile?.server?.host || '0.0.0.0',
      adminToken:
        process.env.RELAYER_SERVER_ADMIN_TOKEN || configJson?.server?.adminToken || configFile?.server?.adminToken,
    },
    poller: {
      port: process.env.RELAYER_POLLER_PORT || configJson?.poller?.port || configFile?.poller?.port || 8081,
      host: process.env.RELAYER_POLLER_HOST || configJson?.poller?.host || configFile?.poller?.host || '0.0.0.0',
      interval:
        process.env.RELAYER_POLLER_INTERVAL || configJson?.poller?.interval || configFile?.poller?.interval || 1000,
    },
    redis: {
      host: process.env.RELAYER_REDIS_HOST || configJson?.redis?.host || configFile?.redis?.host,
      port: process.env.RELAYER_REDIS_PORT || configJson?.redis?.port || configFile?.redis?.port || 6379,
    },
    mode: {
      cleanup: process.env.EVERCLEAR_CLEAN_UP_MODE || configJson?.mode?.cleanup || configFile?.mode?.cleanup || false,
    },
    environment,
    chains: chainsForRelayerConfig,
    hub: hubConfig,
    abis: abiConfig,
    healthUrls: process.env.RELAYER_HEALTH_URLS || configJson.healthUrls || configFile.healthUrls || {},
  };

  if (!_relayerConfig.web3SignerUrl) {
    throw new Error(`Wallet missing, please add web3SignerUrl`);
  }

  const validate = ajv.compile(RelayerConfigSchema);
  const valid = validate(_relayerConfig);
  if (!valid) {
    throw new Error(validate.errors?.map((err: any) => JSON.stringify(err, null, 2)).join(','));
  }

  return _relayerConfig;
};

export let relayerConfig: RelayerConfig | undefined;

/**
 * Gets and validates the relayer config from the environment.
 * @returns The relayer config with sensible defaults
 */
export const getConfig = async (): Promise<RelayerConfig> => {
  if (!relayerConfig) {
    relayerConfig = await getEnvConfig();
  }
  return relayerConfig;
};
