import {
  Asset,
  DepositorEvent,
  DestinationIntent,
  HubDeposit,
  HubIntent,
  HubInvoice,
  HubMessage,
  HyperlaneStatus,
  Invoice,
  Message,
  OriginIntent,
  Queue,
  SettlementIntent,
  TSettlementMessageType,
  Token,
  mkAddress,
  mkBytes32,
  mkHash,
  ShadowEvent,
  TokenomicsEvent,
  MerkleTree,
  NewLockPositionEvent,
  LockPosition,
} from '@chimera-monorepo/utils';
import { stub } from 'sinon';
import { Database, IntentMessageUpdate } from '../src';

export const createMockDatabase = (): Database => {
  return {
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
    getMessageQueueContents: stub().resolves(new Map()),
    getAllQueuedSettlements: stub().resolves({}),
    getOriginIntentsByStatus: stub().resolves([]),
    getDestinationIntentsByStatus: stub().resolves([]),
    getMessagesByIntentIds: stub().resolves([]),
    getOpenTransfers: stub().resolves([]),
    getAllEnqueuedDeposits: stub().resolves([]),
    getMessagesByStatus: stub().resolves([]),
    getOriginIntentsById: stub().resolves(undefined),
    getLatestInvoicesByTickerHash: stub().resolves(new Map()),
    getLatestHubInvoicesByTickerHash: stub().resolves(new Map()),
    getTokens: stub().resolves([]),
    getHubIntentsByStatus: stub().resolves([]),
    getHubInvoicesByIntentIds: stub().resolves([]),
    saveHubInvoices: stub().resolves(),
    saveHubDeposits: stub().resolves(),
    getMessagesByIds: stub().resolves([]),
    updateMessageStatus: stub().resolves(),
    getExpiredIntents: stub().resolves([]),
    getAssets: stub().resolves([]),
    getHubInvoices: stub().resolves([]),
    refreshIntentsView: stub().resolves(),
    refreshInvoicesView: stub().resolves(),
    getInvoicesByStatus: stub().resolves([]),
    getLatestTimestamp: stub().resolves(Date.UTC(2024, 0)),
    getShadowEvents: stub().resolves([]),
    getVotes: stub().resolves([]),
    getTokenomicsEvents: stub().resolves([]),
    getSettledIntentsInEpoch: stub().resolves([]),
    getNewLockPositionEvents: stub().resolves([]),
    getMerkleTrees: stub().resolves([]),
    getLatestMerkleTree: stub().resolves([]),
    saveMerkleTrees: stub().resolves(),
    saveRewards: stub().resolves(),
    saveEpochResults: stub().resolves(),
    getLockPositions: stub().resolves([]),
    saveLockPositions: stub().resolves(),
  };
};

export const createOriginIntents = (num: number, overrides: Partial<OriginIntent>[] = []) => {
  return Array(num)
    .fill(0)
    .map((_, i) => createOriginIntent({ id: mkBytes32(`0x${i + 1}`), ...overrides[i] }));
};

export const createOriginIntent = (overrides: Partial<OriginIntent> = {}): OriginIntent => ({
  id: mkBytes32('0x1'),
  queueIdx: 1,
  messageId: undefined,
  status: 'ADDED',
  receiver: mkAddress('0x123'),
  inputAsset: mkAddress('0x456'),
  outputAsset: mkAddress('0x789'),
  amount: '100',
  maxFee: 100,
  destinations: ['1338'],
  ttl: 10000,
  origin: '1337',
  nonce: 1,
  data: '0x',
  initiator: mkAddress('0x123'), // same as tx_origin (msg.sender in contract)
  transactionHash: mkHash('0xdef'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 1,
  gasLimit: '1231243',
  gasPrice: '12234234',
  txOrigin: mkAddress('0x123'),
  txNonce: 1,
  ...overrides,
});

export const createDestinationIntents = (num: number, overrides: Partial<DestinationIntent>[] = []) => {
  return Array(num)
    .fill(0)
    .map((_, i) => createDestinationIntent({ id: mkBytes32(`0x${i + 1}`), ...overrides[i] }));
};

export const createDestinationIntent = (overrides: Partial<DestinationIntent> = {}): DestinationIntent => ({
  id: mkBytes32('0x1'),
  queueIdx: 1,
  messageId: undefined,
  status: 'ADDED',
  receiver: mkAddress('0x123'),
  inputAsset: mkAddress('0x456'),
  outputAsset: mkAddress('0x789'),
  amount: '100',
  destination: '1338',
  origin: '1337',
  nonce: 1,
  solver: mkAddress('0xfffffff'),
  initiator: mkAddress('0x11111'),
  fee: '100',
  data: '0x',
  maxFee: 500,
  destinations: ['1338'],
  ttl: 10000,
  returnData: '0x',

  transactionHash: mkHash('0xdef'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 1,
  gasLimit: '1231243',
  gasPrice: '12234234',
  txOrigin: mkAddress('0x123'),
  txNonce: 1,
  ...overrides,
});

export const createSettlementIntents = (num: number, overrides: Partial<OriginIntent>[] = []) => {
  return Array(num)
    .fill(0)
    .map((_, i) => createSettlementIntent({ intentId: mkBytes32(`0x${i + 1}`), ...overrides[i] }));
};

export const createSettlementIntent = (overrides: Partial<SettlementIntent> = {}): SettlementIntent => ({
  intentId: mkBytes32('0x1'),
  amount: '1000',
  asset: mkBytes32('0x2'),
  recipient: mkAddress('0x123'),
  domain: '1337',
  status: 'SETTLED',
  returnData: undefined,
  transactionHash: mkHash('0xdef'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 1,
  gasLimit: '1231243',
  gasPrice: '12234234',
  txOrigin: mkAddress('0x123'),
  txNonce: 1,
  ...overrides,
});

export const createHubIntents = (num: number, overrides: Partial<HubIntent>[] = []): HubIntent[] => {
  return Array(num)
    .fill(0)
    .map((_, i) =>
      createHubIntent({ id: mkBytes32(`0x${i + 1}`), messageId: mkBytes32(`0x${i + 1}`), ...overrides[i] }),
    );
};

export const createHubIntent = (overrides: Partial<HubIntent> = {}): HubIntent => ({
  id: mkBytes32('0x1'),
  status: 'ADDED',
  domain: '1339',
  queueIdx: 1,
  messageId: mkBytes32('0xhub-settlement'),
  addedTimestamp: Math.floor(Date.now() / 1000),
  addedTxNonce: 1,
  filledTimestamp: Math.floor(Date.now() / 1000),
  filledTxNonce: 1,
  settlementEnqueuedTimestamp: Math.floor(Date.now() / 1000),
  settlementEnqueuedTxNonce: 1,
  settlementDomain: undefined,
  settlementEnqueuedBlockNumber: undefined,
  settlementAmount: undefined,
  settlementEpoch: undefined,
  updateVirtualBalance: false,
  ...overrides,
});

export const createMessages = (num: number, overrides: Partial<Message>[] = []): Message[] => {
  return Array(num)
    .fill(0)
    .map((_, i) => createMessage({ id: mkBytes32(`0x${i + 1}`), ...overrides[i] }));
};

export const createMessage = (overrides: Partial<Message> = {}): Message => ({
  id: mkBytes32('0x1'),
  type: 'INTENT',
  domain: '1337',
  originDomain: '1337',
  destinationDomain: '1338',
  quote: '100',
  first: 1,
  last: 2,
  intentIds: [mkBytes32('0x1')],
  status: HyperlaneStatus.none,
  txOrigin: mkAddress('0x123'),
  transactionHash: mkHash('0x456'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 1,
  txNonce: 1,
  gasPrice: '100000',
  gasLimit: '10000',
  ...overrides,
});

export const createHubMessages = (num: number, overrides: Partial<Message>[] = []): HubMessage[] => {
  return Array(num)
    .fill(0)
    .map((_, i) => createHubMessage({ id: mkBytes32(`0x${i + 1}`), ...overrides[i] }));
};

export const createHubMessage = (overrides: Partial<Message> = {}): HubMessage => ({
  ...createMessage(overrides),
  type: 'SETTLEMENT',
  settlementDomain: '1337',
  settlementType: TSettlementMessageType.Settled,
});

export const createIntentMessageUpdate = (overrides: Partial<IntentMessageUpdate> = {}): IntentMessageUpdate => ({
  id: mkBytes32('0x1'),
  messageId: mkBytes32('0x2'),
  status: 'DISPATCHED',
  ...overrides,
});

export const createDepositEvents = (num: number, overrides: Partial<DepositorEvent>[] = []): DepositorEvent[] => {
  return Array(num)
    .fill(0)
    .map((_, i) => createDepositorEvent({ depositor: mkAddress(`0x${i + 1}`), ...overrides[i] }));
};

export const createDepositorEvent = (overrides: Partial<DepositorEvent> = {}): DepositorEvent => ({
  id: mkAddress('0x1'),
  depositor: mkAddress('0xdd'),
  type: 'DEPOSIT',
  asset: mkAddress('0xaa'),
  amount: '1000',
  balance: '2000',
  transactionHash: mkHash('0x123'),
  timestamp: Math.floor(Date.now() / 1000),
  blockNumber: 1,
  txOrigin: mkAddress('0x123'),
  txNonce: 1,
  gasPrice: '100000',
  gasLimit: '10000',
  ...overrides,
});

export const createAssets = (num: number, overrides: Partial<Asset>[] = []): Asset[] => {
  return Array(num)
    .fill(0)
    .map((_, i) =>
      createAsset({
        id: mkBytes32(`0x${i + 1}${i + 1}${i + 1}`),
        token: mkAddress(`0x${i + 1}`),
        adopted: mkAddress(`0x${i + 1}`),
        ...overrides[i],
      }),
    );
};

export const createInvoices = (num: number, overrides: Partial<Invoice>[] = []): Invoice[] => {
  let a = overrides[0].originIntent;
  return Array(num)
    .fill(0)
    .map((_, i) => 
      createInvoice({
        id: mkBytes32(`0xaa`),
        originIntent: createOriginIntent(overrides[i].originIntent),
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
        ...overrides[i],
      }),
    );
};

export const createHubInvoices = (num: number, overrides: Partial<HubInvoice>[] = []): HubInvoice[] => {
  return Array(num)
    .fill(0)
    .map((_, i) =>
      createHubInvoice({
        id: mkBytes32(`0x${i + 1}${i + 1}${i + 1}`),
        intentId: mkBytes32(`0x${i + 1}${i + 2}${i + 3}`),
        tickerHash: mkBytes32(`0x${i + 1}`),
        owner: mkBytes32(`0x${i + 1}`),
        entryEpoch: i + 1,
        amount: `${i + 100}`,
        enqueuedTimestamp: Math.floor(Date.now() + i / 1000),
        enqueuedTxNonce: i + 1,
        enqueuedBlockNumber: i + 2,
        enqueuedTransactionHash: mkHash(`0x${i + 1}`),
        ...overrides[i],
      }),
    );
};

export const createAsset = (overrides: Partial<Asset> = {}): Asset => ({
  id: mkBytes32(`0xaa`),
  token: mkAddress(`0xee`),
  domain: '1337',
  adopted: mkAddress(`0xad`),
  approval: true,
  strategy: 'DEFAULT',
  ...overrides,
});


export const createInvoice = (overrides: Partial<Invoice> = {}): Invoice => ({
  id: mkBytes32(`0xaa`),
  originIntent: createOriginIntent(),
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
});

export const createHubInvoice = (overrides: Partial<HubInvoice> = {}): HubInvoice => ({
  id: mkBytes32(`0xaa`),
  intentId: mkBytes32(`0xbb`),
  tickerHash: mkBytes32(`0xee`),
  amount: '100',
  owner: mkBytes32(`0xad`),
  entryEpoch: 1,
  enqueuedTimestamp: Math.floor(Date.now() / 1000),
  enqueuedTxNonce: 1,
  enqueuedBlockNumber: 1,
  enqueuedTransactionHash: mkHash(`0x123`),
  ...overrides,
});

export const createTokens = (num: number, overrides: Partial<Token>[] = []): Token[] => {
  return Array(num)
    .fill(0)
    .map((_, i) =>
      createToken({
        id: mkBytes32(`0x${i + 1}${i + 1}${i + 1}`),
        ...overrides[i],
      }),
    );
};

export const createToken = (overrides: Partial<Token> = {}): Token => ({
  id: mkBytes32(`0xee`),
  feeRecipients: [mkAddress(`0xfee`)],
  feeAmounts: ['100'],
  maxDiscountBps: 100,
  discountPerEpoch: 100,
  prioritizedStrategy: 'DEFAULT',
  ...overrides,
});

export const createQueues = (num: number, overrides: Partial<Queue>[] = []): Queue[] => {
  return Array(num)
    .fill(0)
    .map((_, i) => createQueue({ id: mkBytes32(`0x${i + 1}`), ...overrides[i] }));
};

export const createQueue = (overrides: Partial<Queue> = {}): Queue => ({
  id: mkBytes32('0x1'),
  domain: '1337',
  lastProcessed: 1,
  size: 1,
  first: 1,
  last: 1,
  type: 'INTENT',
  ...overrides,
});

export const createHubDeposits = (num: number, overrides: Partial<HubDeposit>[] = []): HubDeposit[] => {
  return Array(num)
    .fill(0)
    .map((_, i) =>
      createHubDeposit({ id: mkBytes32(`0x${i + 1}`), intentId: mkBytes32(`0x${i + 1}`), ...overrides[i] }),
    );
};

export const createHubDeposit = (overrides: Partial<HubDeposit> = {}): HubDeposit => ({
  id: mkBytes32('0x1'),
  intentId: mkBytes32('0x1'),
  domain: '1337',
  epoch: 1,
  amount: '100',
  tickerHash: mkBytes32('0x123'),
  enqueuedTimestamp: Math.floor(Date.now() / 1000),
  enqueuedTxNonce: 12,
  processedTimestamp: undefined,
  processedTxNonce: undefined,
  ...overrides,
});

export const createShadowEvent = (overrides: Partial<ShadowEvent> = {}): ShadowEvent => ({
  address: mkBytes32('0x1'),
  blockHash: mkBytes32('0x1'),
  blockNumber: 1,
  blockTimestamp: new Date(),
  chain: 'Everclear',
  network: '25327',
  topic0: mkBytes32('0x1'),
  transactionHash: mkBytes32('0x1'),
  transactionIndex: 0,
  transactionLogIndex: 0,
  ...overrides,
});

export const createTokenomicsEvent = (overrides: Partial<TokenomicsEvent> = {}): TokenomicsEvent => ({
  blockNumber: 1,
  blockTimestamp: Date.now() / 1000,
  transactionHash: mkBytes32('0x1'),
  ...overrides,
});

export const createMerkleTree = (overrides: Partial<MerkleTree> = {}): MerkleTree => ({
  asset: mkAddress(),
  epochEndTimestamp: new Date(100000000),
  merkleTree: '{}',
  root: mkBytes32('0x1'),
  proof: mkBytes32('0x1'),
  ...overrides,
});

export const createNewLockPositionEvent = (overrides: Partial<NewLockPositionEvent> = {}): NewLockPositionEvent => ({
  vid: 1,
  user: mkBytes32('0x1'),
  newTotalAmountLocked: '12345',
  blockTimestamp: 1633405000,
  expiry: 1635997000,
  ...overrides,
});

export const createLockPosition = (overrides: Partial<LockPosition> = {}): LockPosition => ({
  user: mkBytes32('0x1'),
  amountLocked: '98765',
  start: 1733405000,
  expiry: 1735990000,
  ...overrides,
});
