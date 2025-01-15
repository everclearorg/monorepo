import {
  DestinationIntent,
  OriginIntent,
  QueueType,
  mkAddress,
  mkBytes32,
  mkHash,
  TIntentStatus,
} from '@chimera-monorepo/utils';
import {
  AssetEntity,
  DepositorEventEntity,
  DepositorEventType,
  HubAddIntentEventEntity,
  HubFillIntentEventEntity,
  IntentSettlementEventEntity,
  IntentStatus,
  MessageEntity,
  MessageType,
  SettlementEnqueuedEventEntity,
  SettlementMessageEntity,
  SettlementMessageType,
  SettlementQueueEntity,
  SpokeAddIntentEventEntity,
  SpokeDestinationIntentEntity,
  SpokeFillIntentEventEntity,
  SpokeOriginIntentEntity,
  SpokeQueueEntity,
  TokensEntity,
} from '../src/lib/operations/entities';
import { SubgraphReader } from '../';
import { createStubInstance } from 'sinon';

export const createMeta = (blockNumber = 123) => ({
  _meta: { block: { number: blockNumber } },
});

export const createSpokeAddIntentEventEntity = (
  overrides: Partial<SpokeAddIntentEventEntity> = {},
): SpokeAddIntentEventEntity => ({
  id: mkBytes32('0x1'),
  intent: createSpokeOriginIntentEntity(),
  transactionHash: mkHash('0x1'),
  timestamp: Math.floor(Date.now() / 1000),
  gasPrice: '100000',
  gasLimit: '10000',
  blockNumber: 123,
  txOrigin: mkAddress('0x1'),
  txNonce: 1,
  ...overrides,
});

export const createIntentSettlementEventEntity = (
  overrides: Partial<IntentSettlementEventEntity> = {},
): IntentSettlementEventEntity => ({
  id: mkBytes32('0x1'),
  intentId: mkBytes32('0x1'),
  settlement: {
    id: mkBytes32('0x1'),
    amount: '1000000000',
    asset: mkAddress('0xa'),
    recipient: mkAddress('0x2'),
  },
  transactionHash: mkHash('0x2'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 123,
  txOrigin: mkAddress('0x1'),
  txNonce: 1,
  gasPrice: '100000',
  gasLimit: '10000',
  ...overrides,
});

export const createSpokeOriginIntentEntity = (
  overrides: Partial<SpokeOriginIntentEntity> = {},
): SpokeOriginIntentEntity => ({
  id: mkBytes32('0x1'),
  queueIdx: 1,
  message: undefined,
  status: IntentStatus.ADDED,
  receiver: mkAddress('0x2'),
  inputAsset: mkAddress('0xa'),
  outputAsset: mkAddress('0xb'),
  amount: '1000000000',
  maxFee: 500,
  destinations: ['1338'],
  ttl: 1000,
  timestamp: Math.floor(Date.now() / 1000),
  initiator: mkAddress('0x1'),
  origin: '1337',
  nonce: 1,
  data: '0x',
  ...overrides,
});

export const createSpokeFillIntentEventEntity = (
  overrides: Partial<SpokeFillIntentEventEntity> = {},
): SpokeFillIntentEventEntity => ({
  id: mkBytes32('0x1'),
  intent: createSpokeDestinationIntentEntity(),
  solver: mkAddress('0x2'),
  fee: '100000',

  transactionHash: mkHash('0x2'),
  timestamp: Math.floor(Date.now() / 1000),
  gasPrice: '100000',
  gasLimit: '10000',
  blockNumber: 123,
  txOrigin: mkAddress('0x1'),
  txNonce: 1,
  ...overrides,
});

export const createSpokeDestinationIntentEntity = (
  overrides: Partial<SpokeDestinationIntentEntity> = {},
): SpokeDestinationIntentEntity => ({
  id: mkBytes32('0x1'),
  queueIdx: 1,
  message: undefined,
  status: IntentStatus.ADDED,
  initiator: mkAddress('0x1'),
  receiver: mkAddress('0x2'),
  inputAsset: mkAddress('0xa'),
  outputAsset: mkAddress('0xb'),
  amount: '1000000000',
  origin: '1337',
  destinations: ['1338'],
  nonce: 1,
  data: '0x',
  ttl: 1000,
  timestamp: Math.floor(Date.now() / 1000),
  maxFee: 500,
  calldataExecutedEvent: undefined,
  ...overrides,
});

export const createSpokeQueueEntity = (overrides: Partial<SpokeQueueEntity> = {}): SpokeQueueEntity => ({
  id: mkBytes32('0x0a'),
  type: QueueType.Fill,
  lastProcessed: Math.floor(Date.now() / 1000),
  size: 2,
  first: 1,
  last: 2,
  ...overrides,
});

export const createSettlementQueueEntity = (overrides: Partial<SettlementQueueEntity> = {}): SettlementQueueEntity => ({
  id: mkBytes32('0x0a'),
  lastProcessed: Math.floor(Date.now() / 1000),
  size: 2,
  first: 1,
  last: 2,
  domain: '1337',
  ...overrides,
});

export const createSpokeMessageEntity = (overrides: Partial<MessageEntity> = {}): MessageEntity => ({
  id: mkBytes32('0xa'),
  type: MessageType.INTENT,
  quote: '23423',

  firstIdx: 1,
  lastIdx: 3,

  intentIds: [mkBytes32('0xa'), mkBytes32('0xb')],

  txOrigin: mkAddress('0xc'),
  transactionHash: mkHash('0x2'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 123,
  txNonce: 1,
  gasPrice: '100000',
  gasLimit: '10000',
  ...overrides,
});

export const createSettlementMessageEntity = (
  overrides: Partial<SettlementMessageEntity> = {},
): SettlementMessageEntity => ({
  id: mkBytes32('0xa'),
  quote: '23423',
  domain: '1337',
  intentIds: [mkBytes32('0xa'), mkBytes32('0xb')],
  type: SettlementMessageType.SETTLED,

  txOrigin: mkAddress('0xc'),
  transactionHash: mkHash('0x2'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 123,
  txNonce: 1,
  gasPrice: '100000',
  gasLimit: '10000',
  ...overrides,
});

export const createTokenEntity = (overrides: Partial<TokensEntity> = {}): TokensEntity => ({
  id: mkBytes32('0x1'),
  feeRecipients: [mkAddress('0xa'), mkAddress('b')],
  feeAmounts: ['1', '1'],
  assets: [],
  maxDiscountBps: '100',
  discountPerEpoch: '100',
  prioritizedStrategy: '0x',
  ...overrides,
});

export const createAssetEntity = (overrides: Partial<AssetEntity> = {}): AssetEntity => ({
  id: mkBytes32('0x1'),
  token: createTokenEntity(overrides.token),
  domain: '1337',
  adopted: mkAddress('0xa'),
  approval: true,
  strategy: '0x',
  ...overrides,
});

export const createHubAddIntentEventEntity = (
  overrides: Partial<HubAddIntentEventEntity> = {},
): HubAddIntentEventEntity => ({
  id: mkBytes32('0x1'),
  intent: {
    id: mkBytes32('0xintent'),
    status: TIntentStatus.Added,
    ...(overrides.intent ?? {}),
  },
  status: TIntentStatus.Added,

  transactionHash: mkHash('0x2'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 123,
  txOrigin: mkAddress('0x1'),
  txNonce: 1,
  ...overrides,
});

export const createHubFillIntentEventEntity = (
  overrides: Partial<HubFillIntentEventEntity> = {},
): HubFillIntentEventEntity => ({
  id: mkBytes32('0x1'),
  intent: {
    id: mkBytes32('0xintent'),
    status: TIntentStatus.Filled,
    ...(overrides.intent ?? {}),
  },
  status: TIntentStatus.Filled,

  transactionHash: mkHash('0x2'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 123,
  txOrigin: mkAddress('0x1'),
  txNonce: 1,
  ...overrides,
});

export const createSettlementEnqueuedEventEntity = (
  overrides: Partial<SettlementEnqueuedEventEntity> = {},
): SettlementEnqueuedEventEntity => ({
  id: mkBytes32('0x1'),
  intent: {
    id: mkBytes32('0xintent'),
    status: TIntentStatus.Settled,
    ...(overrides.intent ?? {}),
  },
  queue: {
    id: mkBytes32('0xdai'),
    lastProcessed: 0,
    size: 2,
    first: 1,
    last: 2,
    domain: '1337',
    ...(overrides.queue ?? {}),
  },

  transactionHash: mkHash('0x2'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 123,
  txOrigin: mkAddress('0x1'),
  txNonce: 1,
  ...overrides,
});

export const createDepositorEventEntity = (overrides: Partial<DepositorEventEntity> = {}): DepositorEventEntity => ({
  id: mkHash('0x1'),
  depositor: {
    id: mkAddress('0x1'),
  },
  type: DepositorEventType.DEPOSIT,
  asset: mkAddress('0x1'),
  amount: '1000',
  balance: '1000000000',

  transactionHash: mkHash('0x2'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 123,
  txOrigin: mkAddress('0x1'),
  txNonce: 1,
  gasPrice: '100000',
  gasLimit: '10000',
  ...overrides,
});

export const createTokensEntity = (overrides: Partial<TokensEntity> = {}): TokensEntity => {
  const { token, ...asset } = createAssetEntity();
  return {
    assets: [asset],
    ...token,
    ...overrides,
  };
};

export const mockQueryResponse = undefined;
export const mockBlockNumber = new Map<string, number>();
export const mockOriginTransfer = {};
export const mockOriginIntent = {} as OriginIntent;
export const mockOriginTransfers = [];
export const mockDestinationTransfer = {};
export const mockDestinationIntent = {} as DestinationIntent;
export const mockOriginXCalls = [];
export const mockTransferStatus = {};
export const mockDepositorEvents = [];
export const mockTokens = [];
export const mockSpokeQueues = [];
export const mockHubQueues = [];
export const mockSpokeMessages = [];
export const mockHubMessages = [];
export const mockOriginIntents = [];
export const mockDestinationIntents = [];
export const mockHubIntents = [];
export const mockHubInvoices = [];

export const mockSubgraph = () =>
  createStubInstance(SubgraphReader, {
    query: Promise.resolve(undefined),
    getLatestBlockNumber: Promise.resolve(mockBlockNumber),
    getOriginIntentById: Promise.resolve(mockOriginIntent),
    getDestinationIntentById: Promise.resolve(mockDestinationIntent),
    // getTransferStatus: Promise.resolve(mockTransferStatus),
    getDepositorEvents: Promise.resolve(mockDepositorEvents),
    // getTokens: Promise.resolve(mockTokens),
    getSpokeQueues: Promise.resolve(mockSpokeQueues),
    getDepositQueues: Promise.resolve(mockHubQueues),
    getSpokeMessages: Promise.resolve(mockSpokeMessages),
    getHubMessages: Promise.resolve(mockHubMessages),
    getOriginIntentsByNonce: Promise.resolve(mockOriginIntents),
    getDestinationIntentsByNonce: Promise.resolve(mockDestinationIntents),
    getHubIntentsByNonce: Promise.resolve(mockHubIntents),
    getHubInvoicesByNonce: Promise.resolve(mockHubInvoices),
  });
