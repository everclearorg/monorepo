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
  Order,
  ProtocolUpdateLog,
  HubMeta,
  SpokeMeta,
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
  OrderEntity,
  MetaUpdateEntity,
  HubMetaEntity,
  SpokeMetaEntity,
} from '../operations/entities';

export const StringToNumber = (num: number | string): number => {
  return Number(BigInt(num));
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
    amountOutMin: entity.intent.amountOutMin,
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

    tokenFee: entity.intent.fees?.tokenFee ?? undefined,
    nativeFee: entity.intent.fees?.nativeFee ?? undefined,
    feeAdapterInitiator: entity.intent.fees?.initiator ?? undefined,
    orderId: entity.intent.order?.id ?? undefined,
    isSwap: undefined, // Will be computed by cartographer based on ticker hash comparison
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
    fee: '0',
    amountOut: entity.amountOut,
    destinations: entity.intent.destinations,
    origin: entity.intent.origin,
    nonce: StringToNumber(entity.intent.nonce),
    amountOutMin: entity.intent.amountOutMin,
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

export const protocolUpdateLog = (domain: string, entity: MetaUpdateEntity): ProtocolUpdateLog => {
  let chainId = domain;
  let updated: string = "";

  switch (entity.kind) {
    // Hub events
    case "HUB_CHAIN_GATEWAY_ADDED":
    case "HUB_CHAIN_GATEWAY_REMOVED":
      updated = entity.valueBytes ? bytes32ToAddress(entity.valueBytes) : "";
      chainId = entity.valueBigInt ? entity.valueBigInt.toString() : chainId;
      break;
    case "HUB_GATEWAY_MAILBOX_UPDATED":
    case "HUB_GATEWAY_SECURITY_MODULE_UPDATED":
    case "OWNERSHIP_PROPOSED":
    case "OWNERSHIP_TRANSFERRED":
    case "GATEWAY_UPDATED":
    case "SETTLEMENT_MODULE_UPDATED":
    case "MANAGER_MODULE_UPDATED":
      updated = entity.valueBytes ? bytes32ToAddress(entity.valueBytes) : "";
      break;
    case "SUPPORTED_DOMAINS_REMOVED":
    case "SUPPORTED_DOMAINS_ADDED":
      updated = entity.valueBytes ? BigInt(entity.valueBytes).toString() : "";
      break;
    case "ACCEPTANCE_DELAY_UPDATED":
    case "MIN_SOLVER_SUPPORTED_DOMAINS_UPDATED":
    case "EPOCH_LENGTH_UPDATED":
    case "EXPIRY_TIME_BUFFER_UPDATED":
    case "LAST_EPOCH_PROCESSED_SET":
    case "GAS_CONFIG_UPDATED":
      updated = entity.valueBigInt ? entity.valueBigInt.toString() : "";
      break;
    case "ROLE_ASSIGNED":
      updated = `${entity.valueBytes ? bytes32ToAddress(entity.valueBytes) : ""} - Role: ${entity.valueBigInt ? entity.valueBigInt.toString() : ""}`;
      break;
    case "CLOSED_EPOCHS_PROCESSED":
      updated = `${entity.valueBytes ? entity.valueBytes : ""} - Last Closed: ${entity.valueBigInt ? entity.valueBigInt.toString() : ""}`;
      break;
    case "PAUSED": 
    case "UNPAUSED":
      updated = "True"; break;
    
    // Spoke events
    case "LIGHTHOUSE_UPDATED":
    case "MESSAGE_RECEIVER_UPDATED":
    case "FEE_RECIPIENT_UPDATED":
    case "FEE_ADAPTER_UPDATED":
    case "WATCHTOWER_UPDATED":
    case "FILL_SIGNER_UPDATED":
    case "FEE_SIGNER_UPDATED":
    case "SPOKE_GATEWAY_MAILBOX_UPDATED":
    case "SPOKE_GATEWAY_SECURITY_MODULE_UPDATED":
      updated = entity.valueBytes ? bytes32ToAddress(entity.valueBytes) : "";
      break;
    case "STRATEGY_SET_FOR_ASSET":
      updated = `${entity.valueBytes ? bytes32ToAddress(entity.valueBytes) : ""} - Strategy: ${entity.valueBigInt ? entity.valueBigInt.toString() : ""}`;
      break;
    case "MESSAGE_GAS_LIMIT_UPDATED":
      updated = entity.valueBigInt ? entity.valueBigInt.toString() : "";
      break;
  }

  return {
    id: entity.id,
    domain,
    event: entity.kind,
    key: entity.key,
    chainId,
    updated,
    transactionHash: entity.transactionHash,
    timestamp: StringToNumber(entity.timestamp),
    blockNumber: StringToNumber(entity.blockNumber),
    txOrigin: entity.txOrigin,
    txNonce: StringToNumber(entity.txNonce),
  };
};

export const hubMeta = (entity: HubMetaEntity): HubMeta => {
  return {
    id: entity.id,
    domain: entity.domain,
    paused: entity.paused ?? undefined,
    owner: entity.owner ?? undefined,
    proposedOwner: entity.proposedOwner ?? undefined,
    proposedOwnershipTimestamp: entity.proposedOwnershipTimestamp ?? undefined,
    gateway: entity.gateway ?? undefined,
    watchtower: entity.watchtower ?? undefined,
    manager: entity.manager ?? undefined,
    settler: entity.settler ?? undefined,
    minSolverSupportedDomains: entity.minSolverSupportedDomains ?? undefined,
    expiryTimeBuffer: entity.expiryTimeBuffer ?? undefined,
    discountPerEpoch: entity.discountPerEpoch ?? undefined,
    epochLength: entity.epochLength ?? undefined,
    mailbox: entity.mailbox ?? undefined,
    securityModule: entity.securityModule ?? undefined,
    acceptanceDelay: entity.acceptanceDelay ?? undefined,
    supportedDomains: entity.supportedDomains?.map((domain) => ({
      domain: domain.domain,
      blockGasLimit: domain.blockGasLimit,
    })),
    chainGateways: entity.chainGateways?.map((gateway) => ({
      chainId: gateway.chainId,
      gateway: gateway.gateway,
    })),
  } as HubMeta;
};

export const spokeMeta = (entity: SpokeMetaEntity): SpokeMeta => {
  return {
    id: entity.id,
    domain: entity.domain,
    paused: entity.paused ?? undefined,
    gateway: entity.gateway ?? undefined,
    lighthouse: entity.lighthouse ?? undefined,
    messageReceiver: entity.messageReceiver ?? undefined,
    watchtower: entity.watchtower ?? undefined,
    messageGasLimit: entity.messageGasLimit ?? undefined,
    feeAdapter: entity.feeAdapter ?? undefined,
    feeAdapterRecipient: entity.feeAdapterRecipient ?? undefined,
    fillSigner: entity.fillSigner ?? undefined,
    feeSigner: entity.feeSigner ?? undefined,
    mailbox: entity.mailbox ?? undefined,
    securityModule: entity.securityModule ?? undefined,
    moduleForStrategies: entity.moduleForStrategies?.map((module) => ({
      strategy: module.strategy,
      module: module.module,
    })),
  } as SpokeMeta;
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
    blockNumber: StringToNumber(entity.blockNumber),
  };
};

export const order = (domain: string, entity: OrderEntity): Order & { domain: string } => {
  return {
    domain,
    id: entity.id,
    autoId: StringToNumber(entity.txNonce),
    intentIds: entity.intents.map((i) => i.id),
    tokenFee: entity.tokenFee,
    nativeFee: entity.nativeFee,
    initiator: entity.initiator,
    transactionHash: entity.transactionHash,
    blockNumber: StringToNumber(entity.blockNumber),
    gasLimit: entity.gasLimit,
    gasPrice: entity.gasPrice,
    txOrigin: entity.txOrigin,
    txNonce: StringToNumber(entity.txNonce),
    timestamp: StringToNumber(entity.timestamp),
  };
};

export interface EnvioIntentEntity {
  id: string;
  intentId: string;
  queueIdx: string;
  initiator: string;
  receiver: string;
  inputAsset: string;
  outputAsset: string;
  maxFee: number;
  amountOutMin: string;
  origin: number;
  nonce: string;
  timestamp: string;
  ttl: string;
  originAmount: string;
  destinations: number[];
  data: string;
  chainId: number;
  blockNumber: string;
  blockTimestamp: string;
  transactionHash: string;
  sender: string;
  receiveBlockNumber?: string;
  isFastPath: boolean;
  tokenFee?: string;
  nativeFee?: string;
  status: 'ADDED' | 'FILLED';
  fills?: EnvioFillEntity[];
}

export interface EnvioFillEntity {
  id: string;
  intentId: string;
  solver: string;
  totalFeeDBPS: string;
  queueIdx: string;
  initiator: string;
  receiver: string;
  inputAsset: string;
  outputAsset: string;
  maxFee: number;
  origin: number;
  nonce: string;
  timestamp: string;
  ttl: string;
  originAmount: string;
  fillAmount: string;
  destinations: number[];
  data: string;
  chainId: number;
  blockNumber: string;
  blockTimestamp: string;
  transactionHash: string;
}

/**
 * Convert bytes32 (32-byte padded) address to regular Ethereum address (20 bytes)
 */
const bytes32ToAddress = (bytes32: string): string => {
  if (!bytes32 || bytes32.length < 42) {
    return bytes32;
  }
  if (bytes32.length === 42) {
    return bytes32;
  }
  return '0x' + bytes32.slice(-40);
};

/**
 * Parse Envio Intent to OriginIntent
 * Envio Intent represents an intent added (origin intent)
 */
export const envioToOriginIntent = (entity: EnvioIntentEntity, domain?: string): OriginIntent => {
  const originDomain = domain || entity.origin.toString();

  return {
    id: entity.intentId,
    queueIdx: StringToNumber(entity.queueIdx),
    messageId: undefined, // Envio doesn't track messageId
    status: entity.status === 'FILLED' ? TIntentStatus.Settled : TIntentStatus.Added,
    receiver: bytes32ToAddress(entity.receiver),
    inputAsset: bytes32ToAddress(entity.inputAsset),
    outputAsset: bytes32ToAddress(entity.outputAsset),
    amount: entity.originAmount,
    amountOutMin: entity.amountOutMin,
    destinations: entity.destinations.map((d) => d.toString()),
    origin: originDomain,
    nonce: StringToNumber(entity.nonce),
    initiator: bytes32ToAddress(entity.initiator),
    data: entity.data,
    ttl: StringToNumber(entity.ttl),

    transactionHash: entity.transactionHash,
    timestamp: StringToNumber(entity.timestamp), // Use timestamp from intent struct
    blockNumber: StringToNumber(entity.blockNumber),
    gasLimit: '0', // Envio doesn't track gasLimit
    gasPrice: '0', // Envio doesn't track gasPrice
    txOrigin: bytes32ToAddress(entity.sender), // Use sender (actual user address)
    txNonce: StringToNumber(entity.nonce),

    tokenFee: entity.tokenFee,
    nativeFee: entity.nativeFee,
    feeAdapterInitiator: bytes32ToAddress(entity.sender), // Use sender (actual user address)
    orderId: undefined, // Envio doesn't track orderId
    isSwap: undefined,
  };
};

/**
 * Parse Envio Intent to DestinationIntent
 * Envio Intent with fills represents destination intent (filled intent)
 */
export const envioToDestinationIntent = (
  entity: EnvioIntentEntity,
  destinationDomain: string,
): DestinationIntent | undefined => {
  // Only return destination intent if it has fills
  if (!entity.fills || entity.fills.length === 0) {
    return undefined;
  }

  // Find fill for this destination domain
  const fill = entity.fills.find((f) => f.chainId.toString() === destinationDomain);
  if (!fill) {
    return undefined;
  }

  return {
    id: entity.intentId,
    queueIdx: StringToNumber(entity.queueIdx),
    messageId: undefined, // Envio doesn't track messageId
    status: entity.status === 'FILLED' ? TIntentStatus.Settled : TIntentStatus.Added,
    initiator: bytes32ToAddress(entity.initiator),
    receiver: bytes32ToAddress(entity.receiver),
    solver: bytes32ToAddress(fill.solver),
    inputAsset: bytes32ToAddress(entity.inputAsset),
    outputAsset: bytes32ToAddress(entity.outputAsset),
    amount: entity.originAmount,
    fee: '0', // Fee is calculated as originAmount - fillAmount
    amountOut: fill.fillAmount, // Use fillAmount from Fill entity
    destinations: entity.destinations.map((d) => d.toString()),
    origin: entity.origin.toString(),
    nonce: StringToNumber(entity.nonce),
    amountOutMin: entity.amountOutMin,
    data: entity.data,
    ttl: StringToNumber(entity.ttl),
    destination: destinationDomain,
    returnData: undefined, // Envio doesn't track returnData

    transactionHash: fill.transactionHash, // Use fill transaction hash
    timestamp: StringToNumber(fill.timestamp), // Use fill timestamp
    blockNumber: StringToNumber(fill.blockNumber), // Use fill block number
    gasLimit: '0', // Envio doesn't track gasLimit
    gasPrice: '0', // Envio doesn't track gasPrice
    txOrigin: bytes32ToAddress(fill.solver), // Use solver as txOrigin
    txNonce: StringToNumber(fill.nonce),
  };
};
