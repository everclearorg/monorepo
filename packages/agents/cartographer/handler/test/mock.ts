import { Logger, chainDataToMap, mkAddress } from '@chimera-monorepo/utils';
import { createStubInstance, stub, SinonStubbedInstance, SinonStub } from 'sinon';
import { Database } from '@chimera-monorepo/database';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { CartographerConfig, AppContext } from '@chimera-monorepo/cartographer-core';

export const createMockDatabase = (): SinonStubbedInstance<Database> => {
  return {
    saveOriginIntents: stub().resolves(),
    saveDestinationIntents: stub().resolves(),
    saveSettlementIntents: stub().resolves(),
    saveHubIntents: stub().resolves(),
    saveHubInvoices: stub().resolves(),
    saveHubDeposits: stub().resolves(),
    saveMessages: stub().resolves(),
    saveProtocolUpdateLogs: stub().resolves(),
    saveHubTokenUpdateLogs: stub().resolves(),
    saveHubAssetUpdateLogs: stub().resolves(),
    saveHubMeta: stub().resolves(),
    saveSpokeMeta: stub().resolves(),
    saveQueues: stub().resolves(),
    saveOrders: stub().resolves(),
    saveAssets: stub().resolves(),
    saveTokens: stub().resolves(),
    saveDepositors: stub().resolves(),
    saveBalances: stub().resolves(),
    saveCheckPoint: stub().resolves(),
    getCheckPoint: stub().resolves(0),
    refreshIntentsView: stub().resolves(),
    refreshInvoicesView: stub().resolves(),
  } as unknown as SinonStubbedInstance<Database>;
};

export const createCartographerConfig = (): CartographerConfig => {
  return {
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
        network: 'evm',
      },
      '1338': {
        providers: ['http://rpc-1338:8545'],
        subgraphUrls: ['http://subgraph-1338/graphql'],
        deployments: {
          everclear: mkAddress('0x1338ccc'),
          gateway: mkAddress('0x1338fff'),
        },
        network: 'evm',
      },
    },
    hub: {
      domain: '1339',
      providers: ['http://rpc-1339:8545'],
      subgraphUrls: ['http://subgraph-1339/graphql'],
      deployments: {
        everclear: mkAddress('0x1339ccc'),
        gateway: mkAddress('0x1339fff'),
      },
    },
  } as CartographerConfig;
};

const mockChainData = [
  { name: 'Unit Test Chain 1', chainId: '1337', domainId: '1337', confirmations: 1, assetId: {} },
  { name: 'Unit Test Chain 2', chainId: '1338', domainId: '1338', confirmations: 1, assetId: {} },
];

export interface MockSubgraphReader {
  getOriginIntentById: SinonStub;
  getDestinationIntentById: SinonStub;
  getHubIntentById: SinonStub;
  getHubInvoiceById: SinonStub;
  getSettlementIntentById: SinonStub;
  getHubDepositEnqueuedById: SinonStub;
  getHubDepositProcessedById: SinonStub;
}

export const createMockSubgraphReader = (): MockSubgraphReader => {
  return {
    getOriginIntentById: stub().resolves(undefined),
    getDestinationIntentById: stub().resolves(undefined),
    getHubIntentById: stub().resolves(undefined),
    getHubInvoiceById: stub().resolves(undefined),
    getSettlementIntentById: stub().resolves(undefined),
    getHubDepositEnqueuedById: stub().resolves(undefined),
    getHubDepositProcessedById: stub().resolves(undefined),
  };
};

export const createAppContext = (): AppContext => {
  return {
    logger: createStubInstance(Logger),
    config: createCartographerConfig(),
    adapters: {
      subgraph: createMockSubgraphReader() as unknown as SubgraphReader,
      chainreader: createStubInstance(ChainReader),
      database: createMockDatabase() as unknown as Database,
    },
    chainData: chainDataToMap(mockChainData),
    domains: mockChainData.map((c) => c.domainId),
  };
};
