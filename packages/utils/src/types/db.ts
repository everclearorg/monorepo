import { Static, Type } from '@sinclair/typebox';
import { TAddress, TIntegerString, TDomainId, TBytes32 } from './primitives';
import { HyperlaneStatus } from '../helpers/hyperlane';

export const TIntentStatus = {
  None: 'NONE',
  // hub, spoke -> does not exist  Unsupported: 'UNSUPPORTED',
  Added: 'ADDED',
  // hub -> added intent arrived on the hub and can be used to purchase invoices
  DepositProcessed: 'DEPOSIT_PROCESSED',
  // hub, spoke -> Added record exists on either origin or hub
  Filled: 'FILLED',
  // hub, spoke -> Fill record exists on either destination or hub
  AddedAndFilled: 'ADDED_AND_FILLED',
  // hub -> Added to the invoice queue
  Invoiced: 'INVOICED',
  // hub -> Invoice is ready to be settled to a spoke
  Settled: 'SETTLED',
  // spoke -> Settled intent had the calldata executed
  SettledAndManuallyExecuted: 'SETTLED_AND_MANUALLY_EXECUTED',
  // hub -> settlement is marked as unsupported when received by the hub
  Unsupported: 'UNSUPPORTED',
  // hub -> settlement is enqueued with a forced domain after the intent has expired.
  UnsupportedReturned: 'UNSUPPORTED_RETURNED',
  Dispatched: 'DISPATCHED',
  SettledAndCompleted: 'SETTLED_AND_COMPLETED',
  // NOTE: These below statuses do _not_ exist on chain.
  DispatchedHub: 'DISPATCHED_HUB',
  DispatchedSpoke: 'DISPATCHED_SPOKE',
  DispatchedUnsupported: 'DISPATCHED_UNSUPPORTED',
  // hub -> added intent arrived on the hub and can be used to purchase invoices
  AddedSpoke: 'ADDED_SPOKE',
  // intent has been added on spoke
  AddedHub: 'ADDED_HUB',
  // hub -> settlement message sent, or unsupported intent returned via hyperlane
  // origin -> intent message sent
  // destination -> fill message sent (optional)
} as const;
export type TIntentStatus = (typeof TIntentStatus)[keyof typeof TIntentStatus];

export const TMessageType = {
  Intent: 'INTENT',
  Fill: 'FILL',
  Settlement: 'SETTLEMENT',
  MailboxUpdate: 'MAILBOX_UPDATE',
  SecurityModuleUpdate: 'SECURITY_MODULE_UPDATE',
  GatewayUpdate: 'GATEWAY_UPDATE',
  LighthouseUpdate: 'LIGHTHOUSE_UPDATE',
} as const;
export type TMessageType = (typeof TMessageType)[keyof typeof TMessageType];

export const TSettlementMessageType = {
  Settled: 'SETTLED',
  UnsupportedReturned: 'UNSUPPORTED_RETURNED',
} as const;
export type TSettlementMessageType = (typeof TSettlementMessageType)[keyof typeof TSettlementMessageType];

export const TDepositorEventType = {
  Deposit: 'DEPOSIT',
  Withdraw: 'WITHDRAW',
} as const;
export type TDepositorEventType = (typeof TDepositorEventType)[keyof typeof TDepositorEventType];

export const SettlementSchema = Type.Object({
  intentId: Type.String({ maxLength: 66 }),
  amount: TIntegerString,
  asset: TBytes32,
  recipient: TBytes32,
  // updateVirtualBalance: Type.Boolean(), FIXME: types are not consistent
});
export type Settlement = Static<typeof SettlementSchema>;

export const IntentSchema = Type.Object({
  initiator: TBytes32,
  receiver: TBytes32,
  inputAsset: TBytes32,
  outputAsset: TBytes32,
  amount: TIntegerString,
  origin: TDomainId,
  destinations: Type.Array(TDomainId),
  nonce: Type.Integer(),
  timestamp: Type.Integer(),
  data: Type.String(),
  maxFee: Type.Integer(),
  ttl: Type.Integer(),
});
export type Intent = Static<typeof IntentSchema>;

export const OnchainTransactionContextSchema = Type.Object({
  transactionHash: Type.String({ maxLength: 66 }),
  blockNumber: Type.Integer(),
  gasLimit: TIntegerString,
  gasPrice: TIntegerString,
  txOrigin: TAddress,
  txNonce: Type.Number(),
  timestamp: Type.Number(),
});
export type OnchainTransactionContext = Static<typeof OnchainTransactionContextSchema>;

export const SettlementIntentSchema = Type.Intersect([
  SettlementSchema,
  OnchainTransactionContextSchema,
  Type.Object({
    domain: TDomainId,
    returnData: Type.Optional(Type.String({ maxLength: 66 })),
    status: Type.Enum(TIntentStatus),
  }),
]);
export type SettlementIntent = Static<typeof SettlementIntentSchema>;

export const OriginIntentSchema = Type.Intersect([
  IntentSchema,
  OnchainTransactionContextSchema,
  Type.Object({
    id: Type.String({ maxLength: 66 }),
    queueIdx: Type.Integer(),
    messageId: Type.Optional(Type.String({ maxLength: 66 })),
    status: Type.Enum(TIntentStatus),
  }),
]);
export type OriginIntent = Static<typeof OriginIntentSchema>;

export const DestinationIntentSchema = Type.Intersect([
  IntentSchema,
  OnchainTransactionContextSchema,
  Type.Object({
    id: Type.String({ maxLength: 66 }),
    queueIdx: Type.Integer(),
    messageId: Type.Optional(Type.String({ maxLength: 66 })),
    returnData: Type.Optional(Type.String({ maxLength: 66 })),
    status: Type.Enum(TIntentStatus),
    solver: TAddress,
    fee: TIntegerString,
    destination: TDomainId, // where intent calldata is executed / dispatched to
  }),
]);
export type DestinationIntent = Static<typeof DestinationIntentSchema>;

export const HubIntentSchema = Type.Object({
  id: Type.String({ maxLength: 66 }),
  status: Type.Enum(TIntentStatus),
  domain: TDomainId, // this is hub domain

  // Added once the intent is turned into a settlement
  queueIdx: Type.Optional(Type.Integer()),
  messageId: Type.Optional(Type.String({ maxLength: 66 })),
  settlementDomain: Type.Optional(TDomainId),
  settlementAmount: Type.Optional(TIntegerString),
  updateVirtualBalance: Type.Optional(Type.Boolean()),

  addedTimestamp: Type.Optional(Type.Integer()), // timestamp of add event
  addedTxNonce: Type.Optional(Type.Integer()), // add event
  filledTimestamp: Type.Optional(Type.Integer()), // timestamp of fill event
  filledTxNonce: Type.Optional(Type.Integer()), // fill event
  settlementEnqueuedTimestamp: Type.Optional(Type.Integer()), // timestamp of enqueue event
  settlementEnqueuedTxNonce: Type.Optional(Type.Integer()), // enqueue event
  settlementEnqueuedBlockNumber: Type.Optional(Type.Integer()), // enqueue block number
  settlementEpoch: Type.Optional(Type.Integer()), // settlement epoch
  // NOTE: pending reward events are not included
});
export type HubIntent = Static<typeof HubIntentSchema>;

export const HubInvoiceSchema = Type.Object({
  id: Type.String({ maxLength: 66 }),
  intentId: Type.String({ maxLength: 66 }),
  amount: TIntegerString,
  tickerHash: Type.String({ maxLength: 66 }),
  owner: Type.String({ maxLength: 66 }),
  entryEpoch: Type.Number(),

  enqueuedTimestamp: Type.Integer(), // timestamp of enqueue event
  enqueuedTxNonce: Type.Number(), // enqueue event
  enqueuedBlockNumber: Type.Number(), // enqueue event block
  enqueuedTransactionHash: Type.String({ maxLength: 66 }), // enqueue event hash
});
export type HubInvoice = Static<typeof HubInvoiceSchema>;

export const InvoiceSchema = Type.Object({
  id: Type.String({ maxLength: 66 }),
  originIntent: OriginIntentSchema,

  hubInvoiceId: Type.String({ maxLength: 66 }),
  hubInvoiceIntentId: Type.String({ maxLength: 66 }),
  hubInvoiceAmount: TIntegerString,
  hubInvoiceTickerHash: Type.String({ maxLength: 66 }),
  hubInvoiceOwner: Type.String({ maxLength: 66 }),
  hubInvoiceEntryEpoch: Type.Number(),
  hubInvoiceEnqueuedTimestamp: Type.Integer(), // timestamp of enqueue event
  hubInvoiceEnqueuedTxNonce: Type.Number(), // enqueue event

  hubStatus: Type.Enum(TIntentStatus),
  hubSettlementEpoch: Type.Optional(Type.Integer()), // settlement epoch
});
export type Invoice = Static<typeof InvoiceSchema>;

export const QueueType = {
  Intent: 'INTENT',
  Fill: 'FILL',
  Settlement: 'SETTLEMENT',
  Deposit: 'DEPOSIT',
} as const;
export type QueueType = (typeof QueueType)[keyof typeof QueueType];

// Settlement, fill, and intent queues are message queues
export const MessageQueueSchema = Type.Object({
  id: Type.String(),
  domain: TDomainId,
  lastProcessed: Type.Optional(Type.Integer()),
  size: Type.Integer(),
  first: Type.Integer(),
  last: Type.Integer(),
  type: Type.Enum(QueueType),
});
export type MessageQueue = Static<typeof MessageQueueSchema>;

export const HubDepositSchema = Type.Object({
  id: Type.String({ maxLength: 66 }),
  intentId: Type.String({ maxLength: 66 }),
  epoch: Type.Integer(),
  domain: TDomainId,
  amount: TIntegerString,
  tickerHash: TBytes32,

  enqueuedTimestamp: Type.Integer(), // timestamp of enqueue event
  enqueuedTxNonce: Type.Number(), // enqueue event

  processedTimestamp: Type.Optional(Type.Integer()), // timestamp of process event
  processedTxNonce: Type.Optional(Type.Number()), // process event
});
export type HubDeposit = Static<typeof HubDepositSchema>;

export const DepositQueueSchema = Type.Intersect([
  MessageQueueSchema,
  Type.Object({
    type: Type.Literal(QueueType.Deposit),
    tickerHash: TBytes32,
    epoch: Type.Integer(),
  }),
]);
export type DepositQueue = Static<typeof DepositQueueSchema>;

export const QueueSchema = Type.Union([MessageQueueSchema, DepositQueueSchema]);
export type Queue = Static<typeof QueueSchema>;

export interface QueueContents {
  [QueueType.Intent]: OriginIntent;
  [QueueType.Fill]: DestinationIntent;
  [QueueType.Settlement]: HubIntent;
  // NOTE: Technically message queue should hold the
  // `Settlement` structs, but we're using `HubIntent` for now.
  [QueueType.Deposit]: HubDeposit;
}

export const MessageSchema = Type.Intersect([
  OnchainTransactionContextSchema,
  Type.Object({
    id: Type.String({ maxLength: 66 }),
    type: Type.Enum(TMessageType),
    domain: TDomainId,
    originDomain: TDomainId,
    destinationDomain: Type.Optional(TDomainId),
    quote: Type.Optional(TIntegerString),
    first: Type.Optional(Type.Integer()),
    last: Type.Optional(Type.Integer()),
    intentIds: Type.Array(Type.String({ maxLength: 66 })),
    status: Type.Enum(HyperlaneStatus),
  }),
]);
export type Message = Static<typeof MessageSchema>;

export const HubMessageSchema = Type.Intersect([
  MessageSchema,
  Type.Object({
    settlementDomain: Type.String(),
    settlementType: Type.Enum(TSettlementMessageType),
  }),
]);
export type HubMessage = Static<typeof HubMessageSchema>;

export const FeeSchema = Type.Object({
  recipient: TAddress,
  fee: TIntegerString,
});
export type Fee = Static<typeof FeeSchema>;

export const IntentFeeSchema = Type.Object({
  solverFee: TIntegerString,
  totalProtocolFee: TIntegerString,
  protocolFees: Type.Array(FeeSchema),
});
export type IntentFee = Static<typeof IntentFeeSchema>;

export const AssetSchema = Type.Object({
  id: Type.String({ maxLength: 66 }),
  token: Type.String(),
  domain: TDomainId,
  adopted: Type.String({ maxLength: 66 }),
  approval: Type.Boolean(),
  strategy: Type.String(),
});
export type Asset = Static<typeof AssetSchema>;

export const TokenSchema = Type.Object({
  id: Type.String({ maxLength: 66 }),
  feeRecipients: Type.Array(Type.String()),
  feeAmounts: Type.Array(TIntegerString),
  maxDiscountBps: Type.Integer({ minimum: 0 }),
  discountPerEpoch: Type.Integer({ minimum: 0 }),
  prioritizedStrategy: Type.String(),
});
export type Token = Static<typeof TokenSchema>;

export const DepositorSchema = Type.Object({
  id: Type.String({ maxLength: 66 }),
});
export type Depositor = Static<typeof DepositorSchema>;

export const BalanceSchema = Type.Object({
  id: Type.String({ maxLength: 66 }),
  account: Type.String({ maxLength: 66 }),
  asset: Type.String({ maxLength: 66 }),
  amount: TIntegerString,
});
export type Balance = Static<typeof BalanceSchema>;

export const TickerAmountSchema = Type.Object({
  tickerHash: TBytes32,
  amount: Type.Number(),
  // NOTE: amount here represents the number of queue items to be
  // iterated through, regardless if they will be settled or not
});
export type TickerAmount = Static<typeof TickerAmountSchema>;

export const DepoitorEventSchema = Type.Intersect([
  OnchainTransactionContextSchema,
  Type.Object({
    id: Type.String({ maxLength: 66 }),
    depositor: TAddress,
    type: Type.Enum(TDepositorEventType),
    asset: TAddress,
    amount: TIntegerString,
    balance: TIntegerString,
  }),
]);
export type DepositorEvent = Static<typeof DepoitorEventSchema>;

export const ShadowEventSchema = Type.Object({
  address: Type.String({ maxLength: 66 }),
  blockHash: Type.String({ maxLength: 66 }),
  blockNumber: Type.Number(),
  blockTimestamp: Type.Date(),
  chain: Type.String({ maxLength: 20 }),
  network: Type.String({ maxLength: 20 }),
  topic0: Type.String({ maxLength: 66 }),
  transactionHash: Type.String({ maxLength: 66 }),
  transactionIndex: Type.Number(),
  transactionLogIndex: Type.Number(),
  timestamp: Type.Date(),
  latency: Type.String(),
});
export type ShadowEvent = Static<typeof ShadowEventSchema>;

export const VoteSchema = Type.Object({
  domain: Type.Number(),
  votes: Type.String(),
});
export type Vote = Static<typeof VoteSchema>;

export const TokenomicsEventSchema = Type.Object({
  blockNumber: Type.Number(),
  blockTimestamp: Type.Number(),
  transactionHash: Type.String({ maxLength: 66 }),
  insertTimestamp: Type.Number(),
});
export type TokenomicsEvent = Static<typeof TokenomicsEventSchema>;

export const MerkleTreeSchema = Type.Object({
  asset: Type.String({ maxLength: 66 }),
  epochEndTimestamp: Type.Date(),
  merkleTree: Type.String(),
  root: Type.String(),
  proof: Type.String(),
});
export type MerkleTree = Static<typeof MerkleTreeSchema>;

export const RewardSchema = Type.Object({
  account: TAddress,
  asset: Type.String({ maxLength: 66 }),
  merkleRoot: Type.String(),
  proof: Type.Array(Type.String()),
  stakeApy: Type.String(),
  stakeRewards: Type.String(),
  totalClearStaked: Type.String(),
  protocolRewards: Type.String(),
  cumulativeRewards: Type.String(),
  epochTimestamp: Type.Date(),
});
export type Reward = Static<typeof RewardSchema>;

export const EpochResultSchema = Type.Object({
  account: TAddress,
  domain: TDomainId,
  userVolume: Type.String(),
  totalVolume: Type.String(),
  clearEmissions: Type.String(),
  cumulativeRewards: Type.String(),
  epochTimestamp: Type.Date(),
});
export type EpochResult = Static<typeof EpochResultSchema>;

export const EarlyExitEventSchema = Type.Object({
  vid: Type.Number(),
  block: Type.Number(),
  id: Type.String({ maxLength: 66 }),
  user: TAddress,
  amountUnlocked: Type.String(),
  amountReceived: Type.String(),
  blockNumber: Type.Number(),
  blockTimestamp: Type.Number(),
  transactionHash: Type.String({ maxLength: 66 }),
});
export type EarlyExitEvent = Static<typeof EarlyExitEventSchema>;

export const NewLockPositionEventSchema = Type.Object({
  vid: Type.Number(),
  user: TAddress,
  newTotalAmountLocked: TIntegerString,
  blockTimestamp: Type.Number(),
  expiry: Type.Number(),
});
export type NewLockPositionEvent = Static<typeof NewLockPositionEventSchema>;

export const LockPositionSchema = Type.Object({
  user: TAddress,
  amountLocked: TIntegerString,
  start: Type.Number(),
  expiry: Type.Number(),
});
export type LockPosition = Static<typeof LockPositionSchema>;
