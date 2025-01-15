import { reset, restore, createStubInstance, SinonStubbedInstance, stub, SinonStub } from 'sinon';
import { AppContext } from '../src/context';
import {
  DestinationIntent,
  OriginIntent,
  HubIntent,
  HyperlaneMessageResponse,
  LogLevel,
  Logger,
  createRequestContext,
  mkAddress,
  mkBytes32,
  mkHash,
  TIntentStatus,
  HubDeposit,
  Message,
  TMessageType,
  HyperlaneStatus,
  HubInvoice,
  Invoice,
  ShadowEvent,
  TokenomicsEvent,
} from '@chimera-monorepo/utils';
import { ChainReader, ReadTransaction } from '@chimera-monorepo/chainservice';
import { MonitorConfig } from '../src/types';
import { Database } from '@chimera-monorepo/database';
import * as ChimeraDatabase from '@chimera-monorepo/database';
import * as AppContextFunctions from '../src/context';
import { mockSubgraph as createMockSubgraph } from '@chimera-monorepo/adapters-subgraph/test/mock';
import { StoreManager } from '@chimera-monorepo/adapters-cache';
import { SubgraphReader } from '@chimera-monorepo/adapters-subgraph';
import { createMockDatabase } from '@chimera-monorepo/database/test/mock';

let mockChainReader: SinonStubbedInstance<ChainReader>;
let mockLogger: SinonStubbedInstance<Logger>;
let mockDatabase: Database;
let mockRelayers: [];
let mockSubgraph: SubgraphReader;
let mockCache: StoreManager;
export let getContextStub: SinonStub;

const MOCK_CHAINS = {
  '1337': {
    providers: ['http://rpc-1337:8545', "https://1337.g.mockalchemy.com/mock_api_key"],
    subgraphUrls: ['http://1337.mocksubgraph.com'],
    deployments: {
      everclear: mkAddress('0x1337ccc'),
      gateway: mkAddress('0x1337fff'),
    },
    confirmations: 3,
    assets: {
      ETH: {
        symbol: 'ETH',
        address: '0x0000000000000000000000000000000000000000',
        decimals: 18,
        isNative: true,
        price: {
          isStable: false,
          priceFeed: '0x694AA1769357215DE4FAC081bf1f309aDC325306',
          coingeckoId: 'ethereum',
        },
        tickerHash: "0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4",
      },
      WETH: {
        'symbol': 'WETH',
        'address': '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
        'decimals': 18,
        'tickerHash': '0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8',
        'isNative': false,
        'price': {
          'isStable': false,
          'priceFeed': '0x694AA1769357215DE4FAC081bf1f309aDC325306',
          'coingeckoId': 'ethereum',
        },
      },
    },
  },
  '1338': {
    providers: ['http://rpc-1338:8545', "https://1338.mockblastapi.io/mock_api_key"],
    subgraphUrls: ['http://1338.mocksubgraph.com'],
    deployments: {
      everclear: mkAddress('0x1338ccc'),
      gateway: mkAddress('0x1338fff'),
    },
    confirmations: 3,
    assets: {
      ETH: {
        symbol: 'ETH',
        address: '0x0000000000000000000000000000000000000000',
        decimals: 18,
        isNative: true,
        price: {
          isStable: false,
          priceFeed: '0x694AA1769357215DE4FAC081bf1f309aDC325306',
          coingeckoId: 'ethereum',
        },
        tickerHash: "0xaaaebeba3810b1e6b70781f14b2d72c1cb89c0b2b320c43bb67ff79f562f5ff4",
      },
      WETH: {
        'symbol': 'WETH',
        'address': '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
        'decimals': 18,
        'tickerHash': '0x0f8a193ff464434486c0daf7db2a895884365d2bc84ba47a68fcf89c1b14b5b8',
        'isNative': false,
        'price': {
          'isStable': false,
          'priceFeed': '0x694AA1769357215DE4FAC081bf1f309aDC325306',
          'coingeckoId': 'ethereum',
        },
      },
    },
  },
};

const MOCK_THRESHOLDS = {
  maxExecutionQueueCount: 0,
  maxExecutionQueueLatency: 1,
  maxSettlementQueueCount: 0,
  maxIntentQueueCount: 100,
  maxIntentQueueLatency: 1,
  openTransferMaxTime: 86400, // Seconds
  openTransferInterval: 86400, // Seconds
  maxSettlementQueueLatency: 1, // Seconds
  maxDepositQueueCount: 0,
  maxDepositQueueLatency: 1, // Seconds
  maxSettlementQueueAssetAmounts: { '1337': 100000 },
  messageMaxDelay: 1800, // Seconds
  maxInvoiceProcessingTime: 23 * 3600,
  maxShadowExportDelay: 900,
  maxShadowExportLatency: 10,
  maxTokenomicsExportDelay: 1800,
  maxTokenomicsExportLatency: 10,
};

const MOCK_HUB = {
  domain: '6398',
  providers: ['http://rpc-1339:8545'],
  subgraphUrls: ['http://6398.mocksubgraph.com'],
  deployments: {
    everclear: mkAddress('0x1339ccc'),
    gateway: mkAddress('0x1339fff'),
    gauge: mkAddress('0x1339eee'),
    rewardDistributor: mkAddress('0x1339bbb'),
    tokenomicsHubGateway: mkAddress('0x1339aaaa'),
  },
};

const MOCK_DATABASE = { url: 'postgres.com' };
const MOCK_REDIS = { host: 'redis://localhost:6379' };
const MOCK_SERVER = { host: 'localhost', port: 7777, adminToken: 'admin' };
const MOCK_RELAYERS: { type: 'Gelato' | 'Everclear'; apiKey: string; url: string }[] = [
  {
    type: 'Gelato',
    apiKey: 'gelato',
    url: 'https://gelato.com',
  },
];
const MOCK_POLLING = { agent: 1000, config: 1000 };
const MOCK_TELEGRAM = { apiKey: '123', chatId: '456' };
const MOCK_BETTERUPTIME = { apiKey: '123', requesterEmail: 'email@mock' };
const MOCK_DISCORD = { url: 'https://discord.com' };
const MOCK_AGENTS = { router: 'http://router:8080' };
const MOCK_HEALTH_URLS = {};

const MOCK_ENV = {
  MONITOR_LOG_LEVEL: 'info',
  MONITOR_CONFIG: JSON.stringify({
    chains: MOCK_CHAINS,
    hub: MOCK_HUB,
    database: MOCK_DATABASE,
  }),
  EVERCLEAR_CONFIG: 'https://raw.githubusercontent.com/connext/chaindata/main/everclear.testnet.json',
};

const MOCK_ORIGIN_INTENT: OriginIntent = {
  id: mkBytes32('0x123'),
  queueIdx: 1,
  messageId: mkBytes32('0x456'),
  status: 'ADDED', // replace with a valid value from TIntentStatus
  receiver: mkAddress('0xbbbb'),
  inputAsset: mkAddress('0xccc'),
  outputAsset: mkAddress('0xddd'),
  amount: '123123',
  maxFee: 500,
  ttl: 100,
  destinations: ['1338'],
  origin: '1337',
  nonce: 1,

  transactionHash: mkHash('0x1234'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 1234,
  txOrigin: mkAddress('0x6543'),
  txNonce: 4,
  initiator: mkAddress('0xaaaa'),
  data: '0x',
  gasLimit: '1231231231',
  gasPrice: '12312123',
};

const MOCK_SHADOW_TABLES = [
  'table1',
  'table2',
];

const MOCK_TOKENOMICS_TABLES = [
  'table1',
  'table2',
];

export const mock = {
  requestContext: () => createRequestContext('test'),
  chains: (overrides: Partial<MonitorConfig['chains']> = {}): MonitorConfig['chains'] => {
    return { ...MOCK_CHAINS, ...overrides };
  },
  hub: (overrides: Partial<MonitorConfig['hub']> = {}): MonitorConfig['hub'] => {
    return { ...MOCK_HUB, ...overrides };
  },
  env: (overrides: object = {}) => {
    return { ...MOCK_ENV, ...overrides };
  },
  database: (overrides: Partial<MonitorConfig['database']> = {}): MonitorConfig['database'] => {
    return { ...MOCK_DATABASE, ...overrides };
  },
  thresholds: (overrides?: Partial<MonitorConfig['thresholds']>): MonitorConfig['thresholds'] => {
    return { ...MOCK_THRESHOLDS, ...overrides };
  },
  config: (overrides: Partial<MonitorConfig> = {}): MonitorConfig => {
    return {
      environment: 'staging',
      network: 'staging',
      logLevel: MOCK_ENV.MONITOR_LOG_LEVEL as LogLevel,
      agents: MOCK_AGENTS,
      polling: MOCK_POLLING,
      hub: MOCK_HUB,
      chains: MOCK_CHAINS,
      redis: MOCK_REDIS,
      server: MOCK_SERVER,
      database: MOCK_DATABASE,
      relayers: MOCK_RELAYERS,
      abis: {
        hub: {
          everclear: [],
          gateway: [],
        },
        spoke: {
          everclear: [],
          gateway: [],
        },
      },
      thresholds: MOCK_THRESHOLDS,
      telegram: MOCK_TELEGRAM,
      betterUptime: MOCK_BETTERUPTIME,
      healthUrls: MOCK_HEALTH_URLS,
      shadowTables: MOCK_SHADOW_TABLES,
      tokenomicsTables: MOCK_TOKENOMICS_TABLES,
      ...overrides,
    };
  },
  context: (overrides: Partial<AppContext> = {}): AppContext => {
    const { config, ...remainder } = overrides;
    return {
      logger: mockLogger,
      adapters: {
        database: mockDatabase as unknown as Database,
        chainreader: mockChainReader,
        subgraph: mockSubgraph as unknown as SubgraphReader,
        cache: mockCache as unknown as StoreManager,
        relayers: mockRelayers,
      },
      config: mock.config(config),
      ...remainder,
    };
  },
  instances: {
    database: () => mockDatabase,
    logger: () => mockLogger,
    chainreader: () => mockChainReader,
    subgraph: () => mockSubgraph,
    relayers: () => mockRelayers,
  },
  destinationIntent: (overrides: Partial<DestinationIntent> = {}): DestinationIntent => ({
    id: mkBytes32('0x123'),
    queueIdx: 1,
    messageId: mkBytes32('0x456'),
    status: TIntentStatus.Added,
    solver: mkAddress('0xf11134'),
    initiator: mkAddress('0xaaaa'),
    receiver: mkAddress('0xbbbb'),
    inputAsset: mkAddress('0xccc'),
    outputAsset: mkAddress('0xddd'),
    amount: '123123',
    origin: '1337',
    destinations: ['1338'],
    ttl: 100,
    destination: '1338',
    nonce: 1,
    data: '0x',
    transactionHash: mkHash('0x1234'),
    timestamp: Math.floor(Date.now() / 1000),
    blockNumber: 1234,
    txOrigin: mkAddress('0x6543'),
    txNonce: 4,
    fee: '0',
    maxFee: 500,
    gasLimit: '1231231231',
    gasPrice: '12312123',
    ...overrides,
  }),
  hubInvoice: (overrides: Partial<HubInvoice> = {}): HubInvoice => ({
    id: mkBytes32('0x123'),
    intentId: mkBytes32('0x456'),
    amount: '100',
    tickerHash: mkHash('0x1234'),
    owner: mkAddress('0x2345'),
    entryEpoch: 1,
    enqueuedTimestamp: Math.floor(Date.now() / 1000),
    enqueuedTxNonce: 1,
    enqueuedBlockNumber: 1234,
    enqueuedTransactionHash: mkHash('0x123'),
    ...overrides,
  }),
  originIntent: (overrides: Partial<OriginIntent> = {}): OriginIntent => ({
    ...MOCK_ORIGIN_INTENT,
    ...overrides,
  }),
  hubIntent: (overrides: Partial<HubIntent> = {}): HubIntent => ({
    id: mkBytes32('0x789'),
    status: 'SETTLED', // replace with a valid value from TIntentStatus
    domain: '1339', // this is hub domain

    // Added once the intent is turned into a settlement
    queueIdx: 2,
    messageId: mkBytes32('0xabc'),
    settlementDomain: '1340',
    settlementAmount: '456456',
    updateVirtualBalance: true,

    addedTimestamp: Math.floor(Date.now() / 1000), // timestamp of add event
    addedTxNonce: 5, // add event
    filledTimestamp: Math.floor(Date.now() / 1000), // timestamp of fill event
    filledTxNonce: 6, // fill event
    settlementEnqueuedTimestamp: Math.floor(Date.now() / 1000), // timestamp of enqueue event
    settlementEnqueuedTxNonce: 7, // enqueue event
    settlementEnqueuedBlockNumber: 5678, // enqueue block number
    settlementEpoch: 1, // settlement epoch
    ...overrides,
  }),
  invoice: (overrides: Partial<Invoice> = {}): Invoice => ({
    id: mkBytes32('0x123'),
    originIntent: MOCK_ORIGIN_INTENT,
    hubInvoiceId: mkBytes32('0x123'),
    hubInvoiceIntentId: mkBytes32('0x456'),
    hubInvoiceAmount: '100',
    hubInvoiceTickerHash: mkHash('0x1234'),
    hubInvoiceOwner: mkAddress('0x2345'),
    hubInvoiceEntryEpoch: 1,
    hubInvoiceEnqueuedTimestamp: Math.floor(Date.now() / 1000),
    hubInvoiceEnqueuedTxNonce: 1,
    hubStatus: "SETTLED",
    hubSettlementEpoch: 2,
    ...overrides,
  }),
  hyperlaneMessage: (overrides: Partial<HyperlaneMessageResponse> = {}): HyperlaneMessageResponse => ({
    status: 'delivered',
    destinationDomainId: 1338,
    body: 'msg',
    originDomainId: 1337,
    recipient: mkAddress('0xbbbb'),
    sender: mkAddress('0xaaaa'),
    nonce: 1,
    id: mkHash('0x23421'),
    originMailbox: mkAddress('0x1231'),
    ...overrides,
  }),
  depositQueue: (overrides: Partial<HubDeposit> = {}): HubDeposit => ({
    intentId: mkBytes32('0x123'),
    id: 'aaa',
    intentId: mkBytes32('0x123'),
    epoch: 100,
    domain: '1337',
    tickerHash: mkHash('0x1234'),
    enqueuedTimestamp: 0,
    enqueuedTxNonce: 1,
    amount: '100',
    ...overrides,
  }),
  message: (overrides: Partial<Message> = {}): Message => ({
    id: mkBytes32('0x123'),
    type: TMessageType.Intent,
    domain: '1337',
    originDomain: '1337',
    destinationDomain: '1338',
    quote: undefined,
    first: 0,
    last: 1,
    intentIds: [mkBytes32('0x111')],
    status: HyperlaneStatus.none,
    txOrigin: mkAddress('0x6543'),
    txNonce: 4,
    transactionHash: mkHash('0x1234'),
    timestamp: Math.floor(Date.now() / 1000),
    blockNumber: 1234,
    gasLimit: '1231231231',
    gasPrice: '12312123',
    ...overrides,
  }),
  shadowEvent: (overrides: Partial<ShadowEvent> = {}): ShadowEvent => ({
    address: mkBytes32('0x123'),
    blockHash: mkBytes32('0x123'),
    blockNumber: 234,
    blockTimestamp: new Date(),
    chain: '1337',
    network: '1338',
    topic0: mkBytes32('0x123'),
    transactionHash: mkBytes32('0x123'),
    transactionIndex: 1,
    transactionLogIndex: 0,
    timestamp: new Date(),
    latency: '00:00:00.00000',
    ...overrides,
  }),
  tokenomicsEvent: (overrides: Partial<TokenomicsEvent> = {}): TokenomicsEvent => ({
    blockNumber: 234,
    blockTimestamp: Date.now(),
    transactionHash: mkBytes32('0x123'),
    insertTimestamp: new Date(),
    ...overrides,
  }),
};

export const mochaHooks = {
  beforeEach() {
    // Create stubbed instance
    mockChainReader = createStubInstance(ChainReader, {
      readTx: stub<[ReadTransaction, number | string]>().resolves('0x'),
    });
    mockLogger = createStubInstance(Logger);
    mockDatabase = createMockDatabase();
    mockSubgraph = createMockSubgraph();

    // Stub call to get database
    stub(ChimeraDatabase, 'getDatabase').resolves(mockDatabase);

    // Stub call to logger
    mockLogger.child = stub(Logger.prototype, 'child').returns(mockLogger);
    mockLogger.debug = stub(Logger.prototype, 'debug').returns();
    mockLogger.info = stub(Logger.prototype, 'info').returns();
    mockLogger.warn = stub(Logger.prototype, 'warn').returns();
    mockLogger.error = stub(Logger.prototype, 'error').returns();

    // Stub call to get context
    getContextStub = stub(AppContextFunctions, 'getContext').returns(mock.context());
  },

  afterEach() {
    restore();
    reset();
  },
};
