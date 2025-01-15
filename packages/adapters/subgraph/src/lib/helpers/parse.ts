import {
  Asset,
  DepositorEvent,
  DestinationIntent,
  HubIntent,
  HubMessage,
  HubInvoice,
  Message,
  OriginIntent,
  Queue,
  TIntentStatus,
  TMessageType,
  QueueType,
  Token,
  TSettlementMessageType,
  HubDeposit,
  DepositQueue,
  SettlementIntent,
  HyperlaneStatus,
} from '@chimera-monorepo/utils';
import {
  SettlementQueueEntity,
  SpokeAddIntentEventEntity,
  SpokeFillIntentEventEntity,
  SpokeQueueEntity,
  MessageEntity,
  SettlementMessageEntity,
  AssetEntity,
  TokensEntity,
  HubAddIntentEventEntity,
  HubFillIntentEventEntity,
  SettlementEnqueuedEventEntity,
  InvoiceEnqueuedEventEntity,
  DepositorEventEntity,
  DepositorEventType,
  DepositProcessedEventEntity,
  DepositEnqueuedEventEntity,
  DepositQueueEntity,
  IntentSettlementEventEntity,
  IntentStatus,
} from '../operations/entities';
import { BigNumber } from 'ethers';

export const StringToNumber = (num: number | string): number => {
  return BigNumber.from(num).toNumber();
};

export const originIntent = (entity: SpokeAddIntentEventEntity): OriginIntent => {
  return {
    id: entity.intent.id,
    queueIdx: StringToNumber(entity.intent.queueIdx),
    messageId: entity.intent.message?.id ?? undefined,
    status: entity.intent.message?.id ? TIntentStatus.Dispatched : TIntentStatus.Added,
    receiver: entity.intent.receiver,
    inputAsset: entity.intent.inputAsset,
    outputAsset: entity.intent.outputAsset,
    amount: entity.intent.amount,
    maxFee: +entity.intent.maxFee,
    destinations: entity.intent.destinations,
    origin: entity.intent.origin,
    nonce: entity.intent.nonce,
    initiator: entity.intent.initiator,
    data: entity.intent.data,
    ttl: StringToNumber(entity.intent.ttl),

    transactionHash: entity.transactionHash,
    timestamp: StringToNumber(entity.timestamp),
    blockNumber: StringToNumber(entity.blockNumber),
    gasLimit: entity.gasLimit,
    gasPrice: entity.gasPrice,
    txOrigin: entity.txOrigin,
    txNonce: StringToNumber(entity.txNonce),
  };
};

export const destinationIntent = (domain: string, entity: SpokeFillIntentEventEntity): DestinationIntent => {
  return {
    id: entity.intent.id,
    queueIdx: StringToNumber(entity.intent.queueIdx),
    messageId: entity.intent.message?.id ?? undefined,
    status: entity.intent.message?.id ? TIntentStatus.Dispatched : TIntentStatus.Added,
    initiator: entity.intent.initiator,
    receiver: entity.intent.receiver,
    solver: entity.solver,
    inputAsset: entity.intent.inputAsset,
    outputAsset: entity.intent.outputAsset,
    amount: entity.intent.amount,
    fee: entity.fee,
    destinations: entity.intent.destinations,
    origin: entity.intent.origin,
    nonce: StringToNumber(entity.intent.nonce),
    maxFee: StringToNumber(entity.intent.maxFee),
    data: entity.intent.data,
    ttl: StringToNumber(entity.intent.ttl),
    destination: domain,
    returnData: entity.intent.calldataExecutedEvent?.returnData ?? undefined,

    transactionHash: entity.transactionHash,
    timestamp: StringToNumber(entity.timestamp),
    blockNumber: StringToNumber(entity.blockNumber),
    gasLimit: entity.gasLimit,
    gasPrice: entity.gasPrice,
    txOrigin: entity.txOrigin,
    txNonce: StringToNumber(entity.txNonce),
  };
};

export const settlementIntent = (domain: string, entity: IntentSettlementEventEntity): SettlementIntent => {
  return {
    intentId: entity.intentId,
    amount: entity.settlement.amount,
    asset: entity.settlement.asset,
    recipient: entity.settlement.recipient,
    domain: domain,
    status: entity.settlement.status as IntentStatus,
    returnData: entity.settlement.calldataExecutedEvent?.returnData ?? undefined,

    transactionHash: entity.transactionHash,
    timestamp: StringToNumber(entity.timestamp),
    blockNumber: StringToNumber(entity.blockNumber),
    gasLimit: entity.gasLimit,
    gasPrice: entity.gasPrice,
    txOrigin: entity.txOrigin,
    txNonce: StringToNumber(entity.txNonce),
  };
};

// NOTE: there are cases where the fill event would be created before the add event
// in this case, the reader would not be able to pull the add event from the subgraph,
// despite the hub intent existing. This should be okay, as the only time these reader
// methods are consumed is when trying to settle, which requires both the add and fill
// events to exist.
export const hubIntentFromAdded = (domain: string, entity: HubAddIntentEventEntity): HubIntent => {
  return {
    addedTimestamp: StringToNumber(entity.timestamp),
    addedTxNonce: StringToNumber(entity.txNonce),
    id: entity.intent.id,
    domain,

    status: entity.intent.message?.id ? TIntentStatus.Dispatched : (entity.intent.status as TIntentStatus),
    queueIdx: entity.intent.settlement?.queueIdx ? StringToNumber(entity.intent.settlement?.queueIdx) : undefined,

    messageId: entity.intent.message?.id ?? undefined,

    settlementDomain: entity.intent.settlement?.domain ?? undefined,
    settlementAmount: entity.intent.settlement?.amount ?? undefined,
    settlementEpoch: entity.intent.settlement?.entryEpoch ?? undefined,

    updateVirtualBalance: entity.intent.settlement?.updateVirtualBalance ?? undefined,
  };
};

export const hubIntentFromFilled = (domain: string, entity: HubFillIntentEventEntity): HubIntent => {
  return {
    filledTimestamp: StringToNumber(entity.timestamp),
    filledTxNonce: StringToNumber(entity.txNonce),
    id: entity.intent.id,
    domain,

    status: entity.intent.message?.id ? TIntentStatus.Dispatched : (entity.intent.status as TIntentStatus),
    queueIdx: entity.intent.settlement?.queueIdx ? StringToNumber(entity.intent.settlement?.queueIdx) : undefined,

    messageId: entity.intent.message?.id ?? undefined,
    settlementDomain: entity.intent.settlement?.domain ?? undefined,
    settlementAmount: entity.intent.settlement?.amount ?? undefined,
    settlementEpoch: entity.intent.settlement?.entryEpoch ?? undefined,

    updateVirtualBalance: entity.intent.settlement?.updateVirtualBalance ?? undefined,
  };
};

export const hubIntentFromSettleEnqueued = (domain: string, entity: SettlementEnqueuedEventEntity): HubIntent => {
  return {
    settlementEnqueuedTimestamp: StringToNumber(entity.timestamp),
    settlementEnqueuedTxNonce: StringToNumber(entity.txNonce),
    settlementEnqueuedBlockNumber: StringToNumber(entity.blockNumber),
    id: entity.intent.id,
    domain,

    status: entity.intent.message?.id ? TIntentStatus.Dispatched : (entity.intent.status as TIntentStatus),
    queueIdx: entity.intent.settlement?.queueIdx ? StringToNumber(entity.intent.settlement?.queueIdx) : undefined,

    messageId: entity.intent.message?.id ?? undefined,
    settlementDomain: entity.intent.settlement?.domain ?? undefined,
    settlementAmount: entity.intent.settlement?.amount ?? undefined,
    settlementEpoch: entity.intent.settlement?.entryEpoch ?? undefined,

    updateVirtualBalance: entity.intent.settlement?.updateVirtualBalance ?? undefined,
  };
};

export const hubIntentFromInvoiceEnqueued = (domain: string, entity: InvoiceEnqueuedEventEntity): HubIntent => {
  return {
    id: entity.intent.id,
    domain,

    status: entity.intent.message?.id ? TIntentStatus.Dispatched : (entity.intent.status as TIntentStatus),
  };
};

export const hubInvoiceFromInvoiceEnqueued = (domain: string, entity: InvoiceEnqueuedEventEntity): HubInvoice => {
  return {
    id: entity.invoice.id,
    intentId: entity.intent.id,
    amount: entity.invoice.amount,
    tickerHash: entity.invoice.tickerHash,
    owner: entity.invoice.owner,
    entryEpoch: entity.invoice.entryEpoch,

    enqueuedTimestamp: StringToNumber(entity.timestamp),
    enqueuedTxNonce: StringToNumber(entity.txNonce),
    enqueuedBlockNumber: StringToNumber(entity.blockNumber),
    enqueuedTransactionHash: entity.transactionHash,
  };
};

export const spokeQueue = (domain: string, entity: SpokeQueueEntity): Queue => {
  return {
    id: `${domain}-${entity.id}`,
    domain: domain,
    lastProcessed: entity.lastProcessed ? StringToNumber(entity.lastProcessed) : undefined,
    size: StringToNumber(entity.size),
    first: StringToNumber(entity.first),
    last: StringToNumber(entity.last),
    type: entity.type as QueueType,
  };
};

export const settlementQueue = (entity: SettlementQueueEntity): Queue => {
  return {
    id: entity.id,
    domain: entity.domain,
    lastProcessed: entity.lastProcessed ? StringToNumber(entity.lastProcessed) : undefined,
    size: StringToNumber(entity.size),
    first: StringToNumber(entity.first),
    last: StringToNumber(entity.last),
    type: QueueType.Settlement,
  };
};

export const spokeMessage = (domain: string, entity: MessageEntity): Message => {
  return {
    id: entity.id,
    domain: domain,
    originDomain: domain,
    type: entity.type as unknown as TMessageType,
    quote: entity.quote,
    first: StringToNumber(entity.firstIdx),
    last: StringToNumber(entity.lastIdx),
    intentIds: entity.intentIds,
    status: HyperlaneStatus.none,
    txOrigin: entity.txOrigin,
    transactionHash: entity.transactionHash,
    timestamp: StringToNumber(entity.timestamp),
    blockNumber: StringToNumber(entity.blockNumber),
    txNonce: StringToNumber(entity.txNonce),
    gasLimit: entity.gasLimit,
    gasPrice: entity.gasPrice,
  };
};

export const settlementMessage = (domain: string, entity: SettlementMessageEntity): HubMessage => {
  return {
    id: entity.id,
    domain: domain,
    originDomain: domain,
    destinationDomain: entity.domain,
    type: TMessageType.Settlement,
    quote: entity.quote,
    first: 0,
    last: 0,
    intentIds: entity.intentIds,
    settlementDomain: entity.domain,
    settlementType: entity.type as unknown as TSettlementMessageType,
    status: HyperlaneStatus.none,

    txOrigin: entity.txOrigin,
    transactionHash: entity.transactionHash,
    timestamp: StringToNumber(entity.timestamp),
    blockNumber: StringToNumber(entity.blockNumber),
    txNonce: StringToNumber(entity.txNonce),
    gasLimit: entity.gasLimit,
    gasPrice: entity.gasPrice,
  };
};

export const token = (entity: TokensEntity): Token => {
  return {
    id: entity.id,
    feeAmounts: entity.feeAmounts,
    feeRecipients: entity.feeRecipients,
    maxDiscountBps: StringToNumber(entity.maxDiscountBps),
    discountPerEpoch: StringToNumber(entity.discountPerEpoch),
    prioritizedStrategy: entity.prioritizedStrategy,
  };
};

export const asset = (tokenId: string, entity: Omit<AssetEntity, 'token' | 'decimals'>): Asset => {
  return {
    id: `${entity.domain}-${tokenId}`,
    token: tokenId,
    domain: entity.domain,
    adopted: entity.adopted,
    approval: entity.approval,
    strategy: entity.strategy,
  };
};

export const depositorEvents = (entity: DepositorEventEntity): DepositorEvent => {
  return {
    id: entity.id,
    depositor: entity.depositor.id,
    type: entity.type === DepositorEventType.DEPOSIT ? 'DEPOSIT' : 'WITHDRAW',
    asset: entity.asset,
    amount: entity.amount,
    balance: entity.balance,
    transactionHash: entity.transactionHash,
    timestamp: StringToNumber(entity.timestamp),
    blockNumber: StringToNumber(entity.blockNumber),
    txOrigin: entity.txOrigin,
    txNonce: StringToNumber(entity.txNonce),
    gasLimit: entity.gasLimit,
    gasPrice: entity.gasPrice,
  };
};

export const hubDepositFromEnqueued = (entity: DepositEnqueuedEventEntity): HubDeposit & { status: TIntentStatus } => {
  return {
    id: entity.deposit.id,
    intentId: entity.intent.id,
    epoch: StringToNumber(entity.deposit.epoch),
    domain: entity.deposit.domain,
    amount: entity.deposit.amount,
    tickerHash: entity.deposit.tickerHash,
    enqueuedTimestamp: StringToNumber(entity.timestamp),
    enqueuedTxNonce: StringToNumber(entity.txNonce),
    status: (entity.intent.message?.id ? TIntentStatus.Dispatched : entity.intent.status) as TIntentStatus,
    processedTimestamp: entity.deposit.processedEvent?.timestamp
      ? StringToNumber(entity.deposit.processedEvent?.timestamp)
      : undefined,
    processedTxNonce: entity.deposit.processedEvent?.txNonce
      ? StringToNumber(entity.deposit.processedEvent?.txNonce)
      : undefined,
  };
};

export const hubDepositFromProcessed = (
  entity: DepositProcessedEventEntity,
): HubDeposit & { status: TIntentStatus } => {
  return {
    id: entity.deposit.id,
    intentId: entity.intent.id,
    epoch: StringToNumber(entity.deposit.epoch),
    domain: entity.deposit.domain,
    amount: entity.deposit.amount,
    tickerHash: entity.deposit.tickerHash,
    enqueuedTimestamp: StringToNumber(entity.deposit.enqueuedEvent?.timestamp || 0),
    enqueuedTxNonce: StringToNumber(entity.deposit.enqueuedEvent?.txNonce || 0),
    processedTimestamp: StringToNumber(entity.timestamp),
    processedTxNonce: StringToNumber(entity.txNonce),
    status: (entity.intent.message?.id ? TIntentStatus.Dispatched : entity.intent.status) as TIntentStatus,
  };
};

export const depositQueue = (entity: DepositQueueEntity): DepositQueue => {
  return {
    id: entity.id,
    domain: entity.domain,
    lastProcessed: entity.lastProcessed ? StringToNumber(entity.lastProcessed) : undefined,
    size: StringToNumber(entity.size),
    first: StringToNumber(entity.first),
    last: StringToNumber(entity.last),
    type: QueueType.Deposit,
    tickerHash: entity.tickerHash,
    epoch: StringToNumber(entity.epoch),
  };
};
