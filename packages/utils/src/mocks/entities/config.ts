import { mkAddress } from '../mk';
import { Static, Type } from '@sinclair/typebox';
import { TABIConfig, TChainConfig, THubConfig } from '../../types';

const TServerConfig = Type.Object({
  port: Type.Integer({ minimum: 1, maximum: 65535 }),
  host: Type.String(),
  adminToken: Type.String(),
});

const TService = Type.Union([Type.Literal('poller')]);

const TMockConfigSchema = Type.Object({
  chains: Type.Record(Type.String(), TChainConfig),
  hub: THubConfig,
  abis: Type.Optional(TABIConfig),
  server: TServerConfig,
  database: Type.Object({
    url: Type.String(),
  }),
  healthUrls: Type.Partial(Type.Record(TService, Type.String({ format: 'uri' }))),
  web3SignerUrl: Type.Optional(Type.String()),
});

export type MockConfig = Static<typeof TMockConfigSchema>;

export const config = (overrides: Partial<MockConfig> = {}): MockConfig => {
  return {
    chains: chains(overrides.chains),
    hub: hub(overrides.hub),
    abis: abis(overrides.abis),
    server: server(overrides.server),
    database: database(overrides.database),
    healthUrls: healthUrls(overrides.healthUrls),
    web3SignerUrl: web3SignerUrl(overrides.web3SignerUrl),
  };
};

const chains = (overrides: Partial<MockConfig['chains']> = {}): MockConfig['chains'] => {
  return {
    '1337': {
      providers: ['http://localhost:8080'],
      subgraphUrls: ['https://mocksubgraph1.com'],
      confirmations: 3,
      deployments: {
        everclear: mkAddress('0xcccc'),
      },
    },
    '1338': {
      providers: ['http://localhost:8090'],
      subgraphUrls: ['https://mocksubgraph2.com'],
      confirmations: 3,
      deployments: {
        everclear: mkAddress('0xcccc'),
      },
    },
    ...overrides,
  };
};

const hub = (overrides: Partial<MockConfig['hub']> = {}): MockConfig['hub'] => {
  return {
    domain: '12312',
    providers: ['http://localhost:8080'],
    subgraphUrls: ['http://localhost:8080'],
    deployments: {
      everclear: mkAddress('0xccc'),
      gateway: mkAddress('0xfff'),
      gauge: mkAddress('0xddd'),
      rewardDistributor: mkAddress('0xeee'),
      tokenomicsHubGateway: mkAddress('0xaaa'),
    },
    ...overrides,
  };
};

const abis = (overrides: Partial<MockConfig['abis']> = {}): MockConfig['abis'] => {
  return {
    hub: {
      gateway: [],
      everclear: [],
      gauge: [],
      rewardDistributor: [],
      tokenomicsHubGateway: [],
    },
    spoke: {
      everclear: [],
      gateway: [],
    },
    ...overrides,
  };
};

const server = (overrides: Partial<MockConfig['server']> = {}): MockConfig['server'] => {
  return {
    port: 8080,
    host: '0.0.0.0',
    adminToken: '3AVxIuNe7wTUGsxEldtw',
    ...overrides,
  };
};

const database = (overrides: Partial<MockConfig['database']> = {}): MockConfig['database'] => {
  return {
    url: 'postgresql://user:pwd@0.0.0.0:5432/everclear',
    ...overrides,
  };
};

const healthUrls = (overrides: Partial<MockConfig['healthUrls']> = {}): MockConfig['healthUrls'] => {
  return {
    poller: 'https://uptime.betterstack.com/api/v1/heartbeat/HtEgtkVJoihnrYHrJhFj1RaW',
    ...overrides,
  };
};

const web3SignerUrl = (web3SignerUrl: string | undefined = undefined): string => {
  return web3SignerUrl ? web3SignerUrl : 'https://relayer-web3signer.chimera.mainnet.everclear.ninja';
};
