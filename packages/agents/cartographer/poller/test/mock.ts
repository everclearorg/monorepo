import { Logger, chainDataToMap, mkAddress } from '@chimera-monorepo/utils';
import { createStubInstance, stub } from 'sinon';
import { Database } from '@chimera-monorepo/database';

import { CartographerConfig } from '../src/config';
import { AppContext, SubgraphReader } from '../src/shared';

export const createMockDatabase = (): Database => {
  return {
    getAllQueuedSettlements: stub().resolves([]),
    saveOriginIntents: stub().resolves(),
    saveDestinationIntents: stub().resolves(),
    saveSettlementIntents: stub().resolves(),
    saveHubIntents: stub().resolves(),
    saveMessages: stub().resolves(),
    saveQueues: stub().resolves(),
    saveAssets: stub().resolves(),
    saveTokens: stub().resolves(),
    saveDepositors: stub().resolves(),
    saveBalances: stub().resolves(),
    saveCheckPoint: stub().resolves(),
    getCheckPoint: stub().resolves(0),
    getMessageQueues: stub().resolves([]),
    saveHubDeposits: stub().resolves(),
    getQueuedIntents: stub().resolves([]),
    getSettlementQueues: stub().resolves([]),
    getQueuedSettlements: stub().resolves({}),
    getOriginIntentsByStatus: stub().resolves([]),
    getDestinationIntentsByStatus: stub().resolves([]),
    getMessagesByIntentIds: stub().resolves([]),
    getMessagesByStatus: stub().resolves([]),
    updateMessageStatus: stub().resolves([]),
    getLatestTimestamp: stub().resolves(Date.UTC(2024, 0)),
    getShadowEvents: stub().resolves([]),
    getVotes: stub().resolves([]),
    getTokenomicsEvents: stub().resolves([]),
    getNewLockPositionEvents: stub().resolves([]),
    getLockPositions: stub().resolves([]),
    saveLockPositions: stub().resolves(),
  };
};

export const createCartographerConfig = (overrides: Partial<CartographerConfig> = {}) => {
  const config = {
    pollInterval: 15000,
    logLevel: 'silent',
    database: 'postgres://postgres:qwery@localhost:5432/everclear?sslmode=disable',
    environment: 'production',
    healthUrls: {},
    service: 'intents',
    chains: {
      '1337': {
        providers: ['http://rpc-1337:8545'],
        subgraphUrls: ['http://subgraph-1337/graphql'],
        deployments: {
          everclear: mkAddress('0x1337ccc'),
          gateway: mkAddress('0x1337fff'),
        },
        minGasPrice: '3',
      },
      '1338': {
        providers: ['http://rpc-1338:8545'],
        subgraphUrls: ['http://subgraph-1338/graphql'],
        deployments: {
          everclear: mkAddress('0x1338ccc'),
          gateway: mkAddress('0x1338fff'),
        },
        minGasPrice: '3',
      },
    },
    hub: {
      domain: '1339',
      providers: ['http://rpc-1339:8545'],
      subgraphUrls: ['http://subgraph-1339/graphql'],
      deployments: {
        everclear: mkAddress('0x1339ccc'),
        gateway: mkAddress('0x1339fff'),
        gauge: mkAddress('0x1339eee'),
        rewardDistributor: mkAddress('0x1339bbb'),
        tokenomicsHubGateway: mkAddress('0x1339aaa'),
      },
    },
    ...overrides,
  };
  return config;
};

export const createProcessEnv = (overrides: Partial<CartographerConfig> = {}) => {
  const config = createCartographerConfig(overrides);
  return {
    CARTOGRAPHER_CONFIG: JSON.stringify({ ...config, databaseUrl: config.database }),
  };
};

const mockChainData = [
  {
    name: 'Unit Test Chain 1',
    chainId: '1337',
    domainId: '1337',
    confirmations: 1,
    assetId: {},
  },
  {
    name: 'Unit Test Chain 2',
    chainId: '1338',
    domainId: '1338',
    confirmations: 1,
    assetId: {},
  },
];

export const createAppContext = (overrides: Partial<CartographerConfig> = {}): AppContext => {
  return {
    logger: createStubInstance(Logger),
    config: createCartographerConfig({
      ...overrides,
    }) as CartographerConfig,
    adapters: {
      subgraph: createStubInstance(SubgraphReader),
      database: createMockDatabase() as Database,
    },
    chainData: chainDataToMap(mockChainData),
    domains: mockChainData.map((c) => c.domainId),
  };
};
