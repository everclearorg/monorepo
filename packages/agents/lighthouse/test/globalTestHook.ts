import { reset, restore, createStubInstance, SinonStubbedInstance, stub, StubbableType, SinonStub } from 'sinon';
import { LighthouseContext } from '../src/context';
import {
  DestinationIntent,
  HubIntent,
  LogLevel,
  Logger,
  OriginIntent,
  SettlementIntent,
  Queue,
  RelayerType,
  RewardConfig,
  createRequestContext,
  mkAddress,
  mkBytes32,
  mkHash,
  RequestContext,
  SafeConfig,
} from '@chimera-monorepo/utils';
import { ChainService, ReadTransaction, WriteTransaction } from '@chimera-monorepo/chainservice';
import { Environment, LighthouseConfig, LighthouseService } from '../src/config';
import { Database } from '@chimera-monorepo/database';
import * as ChimeraDatabase from '@chimera-monorepo/database';
import * as LighthouseContextFunctions from '../src/context';
import { Wallet } from 'ethers';
import { HistoricPrice } from '../src/tasks/reward/historicPrice';

let mockChainService: SinonStubbedInstance<ChainService>;
let mockLogger: SinonStubbedInstance<Logger>;
let mockDatabase: Database;
let mockHistoricPrice: HistoricPrice;
export let getContextStub: SinonStub;

const MOCK_WALLET = Wallet.createRandom();

const MOCK_ASSETS = {
  ETH: {
    symbol: 'ETH',
    address: mkAddress('0x456'),
    decimals: 18,
    isNative: false,
    price: {
      isStable: false,
      priceFeed: '0x694AA1769357215DE4FAC081bf1f309aDC325306',
      coingeckoId: 'ethereum',
    },
    tickerHash: '',
  },
  WETH: {
    symbol: 'WETH',
    address: mkAddress('0x567'),
    decimals: 18,
    isNative: false,
    price: {
      isStable: false,
      priceFeed: '0x694AA1769357215DE4FAC081bf1f309aDC325306',
      coingeckoId: 'ethereum',
    },
    tickerHash: '',
  },
  CLEAR: {
    symbol: 'CLEAR',
    address: mkAddress('0x678'),
    decimals: 18,
    isNative: false,
    price: {
      isStable: false,
      priceFeed: '0x694AA1769357215DE4FAC081bf1f309aDC325306',
      coingeckoId: 'ethereum',
    },
    tickerHash: '',
  },
}

const MOCK_CHAINS = {
  '6398': {
    providers: ['http://localhost:8080'],
    subgraphUrls: ['http://6398.mocksubgraph.com'],
    deployments: {
      everclear: mkAddress('0xabc'),
      gateway: mkAddress('0xdef'),
    },
    assets: MOCK_ASSETS,
    gasLimit: 30_000_000,
  },
  '1337': {
    providers: ['http://localhost:8080'],
    subgraphUrls: ['http://1337.mocksubgraph.com'],
    deployments: {
      everclear: mkAddress('0xabc'),
      gateway: mkAddress('0xdef'),
    },
    assets: MOCK_ASSETS,
    gasLimit: 30_000_000,
  },
  '1338': {
    providers: ['http://localhost:8081'],
    subgraphUrls: ['http://1338.mocksubgraph.com'],
    deployments: {
      everclear: mkAddress('0xabc'),
      gateway: mkAddress('0xdef'),
    },
    assets: MOCK_ASSETS,
    gasLimit: 30_000_000,
  },
};

const MOCK_THRESHOLDS = {
  '1337': {
    maxAge: 0,
    size: 1,
  },
  '1338': {
    maxAge: 0,
    size: 1,
  },
  '6398': {
    maxAge: 0,
    size: 1,
  },
};

const MOCK_HUB = {
  domain: '6398',
  // NOTE: changing ^^ will require updating the `getDefaultABIConfig`
  // function, or its invocation within the config.ts file.
  providers: ['http://localhost:8082'],
  subgraphUrls: ['http://6398.mocksubgraph.com'],
  deployments: {
    everclear: mkAddress('0xccc'),
    gateway: mkAddress('0xbbbb'),
    gauge: mkAddress('0xaaaa'),
    rewardDistributor: mkAddress('0xdddd'),
    tokenomicsHubGateway: mkAddress('0xeeee'),
  },
  assets: MOCK_ASSETS,
};

const MOCK_HEALTH_URLS = {
  intent: 'http://localhost:8383',
  settlement: 'http://localhost:8383',
  fill: 'http://localhost:8383',
};

const MOCK_RELAYERS = [
  {
    url: 'http://127.0.0.1:8080',
    type: 'Everclear',
    apiKey: 'blahblah',
  },
];

const MOCK_DATABASE = { url: 'postgres.com' };

const MOCK_SAFE: SafeConfig = {
  txService: 'blahblah',
  safeAddress: mkAddress('0xffff'),
  signer: mkBytes32('0x1111'),
  masterCopyAddress: mkBytes32('0xaaaa'),
  fallbackHandlerAddress: mkBytes32('0xbbbb'),
};

const MOCK_ENV = {
  LIGHTHOUSE_LOG_LEVEL: 'info',
  LIGHTHOUSE_ENVIRONMENT: 'staging',
  LIGHTHOUSE_NETWORK: 'testnet',
  LIGHTHOUSE_SERVICE: 'intent',
  LIGHTHOUSE_CONFIG: JSON.stringify({
    chains: MOCK_CHAINS,
    healthUrls: MOCK_HEALTH_URLS,
    hub: MOCK_HUB,
    database: MOCK_DATABASE,
    relayers: MOCK_RELAYERS,
    safe: MOCK_SAFE,
  }),
  EVERCLEAR_CONFIG: 'https://raw.githubusercontent.com/connext/chaindata/main/everclear.testnet.json',
};

const MOCK_QUEUE: Queue = {
  lastProcessed: undefined,
  last: 15,
  first: 0,
  domain: '1337',
  type: 'INTENT',
  id: 'mock-queue-1337',
  size: 15,
};

const MOCK_REWARDS: RewardConfig = {
  clearAssetAddress: mkAddress('0x678'),
  volume: {
    tokens: [
      {
        address: mkAddress('0x678'),
        epochVolumeReward: '750000000000000000000000',
        baseRewardDbps: 12,
        maxBpsUsdVolumeCap: 250000000,
      },
    ],
  },
  staking: {
    tokens: [
      {
        address: mkAddress('0x678'),
        apy: [
          { term: 3,  apyBps: 400 },
          { term: 12, apyBps: 600 },
          { term: 15, apyBps: 800 },
          { term: 18, apyBps: 1000 },
          { term: 21, apyBps: 1200 },
          { term: 24, apyBps: 1400 },
        ],
      },
      {
        address: mkAddress('0x567'),
        apy: [
          { term: 3,  apyBps: 200 },
          { term: 6,  apyBps: 400 },
          { term: 9,  apyBps: 600 },
        ],
      },
    ],
  },
};

const MOCK_COINGECKO = 'blahblah';

export const createIntentQueues = (chains = Object.keys(mock.chains())): Queue[] => {
  const queues = chains
    .filter((c) => c !== '6398') // filter out hub, included in mock
    .map((chain) => {
      return mock.queue({
        type: 'INTENT',
        domain: chain,
        size: 1000,
      });
    });
  return queues;
};

export const mock = {
  requestContext: () => createRequestContext('test'),
  chains: (overrides: Partial<LighthouseConfig['chains']> = {}): LighthouseConfig['chains'] => {
    return { ...MOCK_CHAINS, ...overrides };
  },
  hub: (overrides: Partial<LighthouseConfig['hub']> = {}): LighthouseConfig['hub'] => {
    return { ...MOCK_HUB, ...overrides };
  },
  env: (overrides: object = {}) => {
    return { ...MOCK_ENV, ...overrides };
  },
  health: (overrides: Partial<LighthouseConfig['healthUrls']> = {}): LighthouseConfig['healthUrls'] => {
    return { ...MOCK_HEALTH_URLS, ...overrides };
  },
  database: (overrides: Partial<LighthouseConfig['database']> = {}): LighthouseConfig['database'] => {
    return { ...MOCK_DATABASE, ...overrides };
  },
  config: (overrides: Partial<LighthouseConfig> = {}): LighthouseConfig => {
    return {
      logLevel: MOCK_ENV.LIGHTHOUSE_LOG_LEVEL as LogLevel,
      environment: MOCK_ENV.LIGHTHOUSE_ENVIRONMENT as Environment,
      network: MOCK_ENV.LIGHTHOUSE_NETWORK,
      hub: mock.hub(),
      relayers: [],
      chains: mock.chains(),
      service: MOCK_ENV.LIGHTHOUSE_SERVICE as LighthouseService,
      healthUrls: mock.health(),
      database: mock.database(),
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
      signer: MOCK_WALLET.privateKey,
      thresholds: { ...MOCK_THRESHOLDS },
      rewards: MOCK_REWARDS,
      coingecko: MOCK_COINGECKO,
      safe: MOCK_SAFE,
      ...overrides,
    };
  },
  context: (overrides: Partial<LighthouseContext> = {}): LighthouseContext => {
    const { config, ...remainder } = overrides;
    const mockConfig = mock.config(config);
    return {
      config: mockConfig,
      logger: mockLogger,
      historicPrice: mockHistoricPrice,
      adapters: {
        wallet: MOCK_WALLET,
        database: mockDatabase as unknown as Database,
        chainservice: mockChainService,
        relayers: (mockConfig.relayers.length > 0
          ? mockConfig.relayers
          : [{ type: RelayerType.Everclear, apiKey: 'foo' }]
        ).map((r) => {
          return {
            type: r.type as RelayerType,
            apiKey: r.apiKey,
            instance: {
              getRelayerAddress: stub().resolves(mkAddress('0x1234')),
            } as any,
          };
        }),
      },
      ...remainder,
    };
  },
  instances: {
    database: () => mockDatabase,
    logger: () => mockLogger,
    chainservice: () => mockChainService,
    historicPrice: () => mockHistoricPrice,
  },
  queue: (overrides: Partial<Queue> = {}): Queue => ({
    ...MOCK_QUEUE,
    ...overrides,
  }),
  originIntent: (overrides: Partial<OriginIntent> = {}): OriginIntent => ({
    id: mkBytes32('0x1'),
    queueIdx: 1,
    messageId: undefined,
    status: 'ADDED',
    receiver: mkAddress('0x123'),
    inputAsset: mkAddress('0x456'),
    outputAsset: mkAddress('0x789'),
    amount: '100',
    maxFee: '100',
    destination: '1338',
    origin: '1337',
    nonce: 1,
    data: '0x',
    initiator: mkAddress('0xabc'),
    caller: mkAddress('0xabc'),
    transactionHash: mkHash('0xdef'),
    timestamp: Math.floor(Date.now() / 1000),
    blockNumber: 1,
    gasLimit: '1231243',
    gasPrice: '12234234',
    txOrigin: mkAddress('0x123'),
    txNonce: 1,
    ...overrides,
  }),
  settlementIntent: (overrides: Partial<SettlementIntent> = {}): SettlementIntent => ({
    intentId: mkBytes32('0x1'),
    amount: '10000000000000000000',
    asset: mkAddress('0x456'),
    recipient: mkAddress('0x123'),
    domain: '1338',
    status: 'SETTLED',
    transactionHash: mkHash('0xdef'),
    timestamp: Math.floor(Date.now() / 1000),
    blockNumber: 1,
    gasLimit: '1231243',
    gasPrice: '12234234',
    txOrigin: mkAddress('0x123'),
    txNonce: 1,
    ...overrides,
  }),
  hubIntent: (overrides: Partial<HubIntent> = {}): HubIntent => ({
    id: mkBytes32('0x1'),
    status: 'ADDED',
    domain: '1339',
    queueId: mkBytes32('0xhub-queue-id'),
    queueNode: mkBytes32(''),
    messageId: mkBytes32('0xhub-settlement'),
    addedTimestamp: Math.floor(Date.now() / 1000),
    addedTxNonce: 1,
    filledTimestamp: Math.floor(Date.now() / 1000),
    filledTxNonce: 1,
    enqueuedTimestamp: Math.floor(Date.now() / 1000),
    enqueuedTxNonce: 1,
    settlementDomain: undefined,
    ...overrides,
  }),
  destinationIntent: (overrides: Partial<DestinationIntent> = {}): DestinationIntent => ({
    fee: '1',
    id: mkBytes32('0x123'),
    queueIdx: 1,
    messageId: mkBytes32('0x456'),
    status: 'FILLED',
    solver: mkAddress('0xf11134'),
    initiator: mkAddress('0xaaaa'),
    receiver: mkAddress('0xbbbb'),
    inputAsset: mkAddress('0xccc'),
    outputAsset: mkAddress('0xddd'),
    amount: '123123123123',
    origin: '1337',
    destination: '1338',
    nonce: 1,
    data: '0x',
    caller: mkAddress('0x1234'),
    transactionHash: mkHash('0x1234'),
    timestamp: Math.floor(Date.now() / 1000),
    blockNumber: 1234,
    txOrigin: mkAddress('0x6543'),
    txNonce: 4,
    maxFee: 500,
    gasLimit: '1012031023103',
    gasPrice: '111111111111',
    ...overrides,
  }),
  // TODO: remove?
  solver: (overrides: Partial<any> = {}): any => ({
    supportedDomains: ['1337', '1338'],
    address: mkAddress('0xf11134'),
    owner: mkAddress('0xaaaa'),
    ...overrides,
  }),
};

export const mochaHooks = {
  beforeEach() {
    // Create stubbed instance
    mockChainService = createStubInstance(ChainService, {
      readTx: stub<[ReadTransaction, number | string]>().resolves('0x'),
      sendTx: stub<[WriteTransaction, RequestContext]>().resolves({
        status: 1,
      }),
    });
    mockLogger = createStubInstance(Logger);
    mockDatabase = {
      getMessageQueues: stub().resolves([MOCK_QUEUE]),
      getOriginIntentsByStatus: stub().resolves([]),
      getDestinationIntentsByStatus: stub().resolves([]),
      getMessagesByIntentIds: stub().resolves([]),
      getQueuedSettlements: stub().resolves(new Map()),
      getExpiredIntents: stub().resolves(new Map()),
      getQueuedIntents: stub().resolves([]),
      getAssets: stub().resolves([]),
      getCheckPoint: stub().resolves(0),
      getNewLockPositionEvents: stub(),
      getLockPositions: stub(),
      saveLockPositions: stub(),
      getVotes: stub(),
      getSettledIntentsInEpoch: stub(),
      getMerkleTrees: stub(),
      getLatestMerkleTree: stub(),
      saveMerkleTrees: stub().resolves(),
      saveEpochResults: stub().resolves(),
      saveRewards: stub().resolves(),
      saveCheckPoint: stub().resolves(),
    } as unknown as Database;
    mockHistoricPrice = {
      getHistoricTokenPrice: stub(),
    } as unknown as HistoricPrice;

    // Stub call to get database
    stub(ChimeraDatabase, 'getDatabase').resolves(mockDatabase);

    // Stub call to logger
    mockLogger.child = stub(Logger.prototype, 'child').returns(mockLogger);
    mockLogger.debug = stub(Logger.prototype, 'debug').returns();
    mockLogger.info = stub(Logger.prototype, 'info').returns();
    mockLogger.warn = stub(Logger.prototype, 'warn').returns();
    mockLogger.error = stub(Logger.prototype, 'error').returns();

    // Stub call to get context
    getContextStub = stub(LighthouseContextFunctions, 'getContext').returns(mock.context());
  },

  afterEach() {
    restore();
    reset();
  },
};
