import { Logger, chainDataToMap, mkAddress } from '@chimera-monorepo/utils';
import { createStubInstance, SinonStubbedInstance, stub } from 'sinon';

import { ChainService } from '@chimera-monorepo/chainservice';
import { TasksCache } from '@chimera-monorepo/adapters-cache';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { WatcherConfig, AppContext, Report, Severity } from '../src/lib/entities';
import { Wallet } from 'ethers';

let mockLogger: SinonStubbedInstance<Logger>;

const MOCK_DATABASE = { url: 'postgres.com' };
const MOCK_REDIS = { host: 'redis://localhost:6379' };
const MOCK_SERVER = { host: 'localhost', port: 8080, adminToken: 'foobar' };
const MOCK_TELEGRAM = { apiKey: '123', chatId: '456' };
const MOCK_BETTERUPTIME = { apiKey: '123', requesterEmail: 'email@mock' };
const MOCK_DISCORD_URL = 'https://discord.com/api/webhooks/xxx';
const MOCK_TWILLIO = {
  number: '234234',
  accountSid: 'aaa-bbb',
  authToken: 'xxx-xxx',
  toPhoneNumbers: ['123-456-789'],
};

export const createWatcherConfig = (overrides: Partial<WatcherConfig> = {}) => {
  const config = {
    chains: {
      1337: {
        providers: ['http://rpc-1337:8545'],
        deployments: {
          everclear: mkAddress('0x1337ccc'),
          gateway: mkAddress('0x1337fff'),
        },
        subgraphUrls: ['http://1337.mocksubgraph.com'],
        minGasPrice: '3',
      },
      1338: {
        providers: ['http://rpc-1338:8545'],
        deployments: {
          everclear: mkAddress('0x1338ccc'),
          gateway: mkAddress('0x1338fff'),
        },
        subgraphUrls: ['http://1338.mocksubgraph.com'],
        minGasPrice: '3',
        gasMultiplier: 2,
      },
    },
    hub: {
      domain: '6398',
      providers: ['http://rpc-6398:8545'],
      deployments: {
        everclear: mkAddress('0x1339ccc'),
        gateway: mkAddress('0x1339fff'),
        gauge: mkAddress('0x1339eee'),
        rewardDistributor: mkAddress('0x1339bbb'),
        tokenomicsHubGateway: mkAddress('0x1339aaa'),
      },
      subgraphUrls: ['http://1339.mocksubgraph.com'],
      minGasPrice: '3',
      gasMultiplier: 2,
    },
    abis: {
      hub: {
        everclear: [],
        gateway: [],
        gauge: [],
        rewardDistributor: [],
        tokenomicsHubGateway: [],
      },
      spoke: {
        everclear: [],
        gateway: [],
      },
    },
    web3SignerUrl: 'http://web3-signer:8080',
    logLevel: 'debug',
    network: 'testnet',
    environment: 'staging',
    server: MOCK_SERVER,
    database: MOCK_DATABASE,
    redis: MOCK_REDIS,
    reloadConfigInterval: 100000,
    assetCheckInterval: 500_000,
    discordHookUrl: MOCK_DISCORD_URL,
    twilio: MOCK_TWILLIO,
    telegram: MOCK_TELEGRAM,
    betterUptime: MOCK_BETTERUPTIME,
    failedCheckRetriesLimit: 1,
    ...overrides,
  };
  return config;
};

export const createProcessEnv = (overrides: Partial<WatcherConfig> = {}) => {
  return {
    WATCHTOWER_CONFIG: JSON.stringify(createWatcherConfig(overrides)),
    EVERCLEAR_CONFIG: 'https://raw.githubusercontent.com/connext/chaindata/main/everclear.testnet.json',
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

export const createAppContext = (overrides: Partial<WatcherConfig> = {}): AppContext => {
  mockLogger = createStubInstance(Logger);
  mockLogger.child = stub(Logger.prototype, 'child').returns(mockLogger);
  mockLogger.debug = stub(Logger.prototype, 'debug').returns();
  mockLogger.info = stub(Logger.prototype, 'info').returns();
  mockLogger.warn = stub(Logger.prototype, 'warn').returns();
  mockLogger.error = stub(Logger.prototype, 'error').returns();

  return {
    logger: mockLogger,
    config: createWatcherConfig({
      ...overrides,
    }) as WatcherConfig,
    adapters: {
      wallet: createStubInstance(Wallet),
      chainservice: createStubInstance(ChainService),
      cache: {
        tasks: createStubInstance(TasksCache),
      },
      subgraph: createStubInstance(SubgraphReader),
    },
    chainData: chainDataToMap(mockChainData),
  };
};

export const TEST_REPORT: Report = {
  severity: Severity.Informational,
  type: 'test',
  domains: ['test'],
  timestamp: Date.now(),
  reason: 'test',
  logger: new Logger({ name: 'mock', level: 'silent' }),
  env: 'staging',
};
