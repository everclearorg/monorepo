import { DepositQueue, Intent, OnchainTransactionContext, TIntentStatus } from '@chimera-monorepo/utils';

export type MetaEntity = {
  block: {
    number: number;
  };
  hasIndexingErrors: boolean;
};
export const META_ENTITY = `
    block {
        number
    }
    hasIndexingErrors
`;

export const INTENT_FIELDS = `
    initiator
    receiver
    inputAsset
    outputAsset
    maxFee
    origin
    timestamp
    destinations
    nonce
    amount
    data
    ttl
`;

export enum MessageType {
  INTENT = 'INTENT',
  FILL = 'FILL',
  SETTLEMENT = 'SETTLEMENT',
  MAILBOX_UPDATE = 'MAILBOX_UPDATE',
  SECURITY_MODULE_UPDATE = 'SECURITY_MODULE_UPDATE',
  GATEWAY_UPDATE = 'GATEWAY_UPDATE',
  LIGHTHOUSE_UPDATE = 'LIGHTHOUSE_UPDATE',
}
export type MessageEntity = {
  id: string;
  type: MessageType;
  quote: string;

  firstIdx: number;
  lastIdx: number;

  intentIds: string[];

  txOrigin: string;
  transactionHash: string;
  gasPrice: string;
  gasLimit: string;
  timestamp: number;
  blockNumber: number;
  txNonce: number;
};
export const MESSAGE_ENTITY = `
    id
    type
    quote

    firstIdx
    lastIdx

    intentIds

    txOrigin
    transactionHash
    timestamp
    blockNumber
    txNonce
    gasPrice
    gasLimit
`;

export type CalldataExecutedEventEntity = {
  id: string;
  returnData: string;

  txOrigin: string;
  transactionHash: string;
  gasPrice: string;
  gasLimit: string;
  timestamp: number;
  blockNumber: number;
  txNonce: number;
};
export const CALLDATA_EXECUTE_ENTITY = `
    id
    returnData

    txOrigin
    transactionHash
    timestamp
    blockNumber
    txNonce
    gasPrice
    gasLimit
`;

export type SpokeOriginIntentEntity = Intent & {
  id: string;
  queueIdx: number;
  message?: MessageEntity;
  status: IntentStatus;
};

export const SPOKE_ORIGIN_INTENT_ENTITY = `
    id
    queueIdx
    message {
      ${MESSAGE_ENTITY}
    }
    status
    ${INTENT_FIELDS}
`;

export type SpokeAddIntentEventEntity = {
  id: string;
  intent: SpokeOriginIntentEntity;
  transactionHash: string;
  timestamp: number;
  gasPrice: string;
  gasLimit: string;
  blockNumber: number;
  txOrigin: string;
  txNonce: number;
};

export const SPOKE_ADD_INTENT_EVENT_ENTITY = `
    id
    intent {
        ${SPOKE_ORIGIN_INTENT_ENTITY}
    }

    transactionHash
    timestamp
    gasPrice
    gasLimit
    blockNumber
    txOrigin
    txNonce
`;

export enum IntentStatus {
  NONE = 'NONE',
  ADDED = 'ADDED', // signifies added to the message queue
  DISPATCHED = 'DISPATCHED', // signifies the batch containing the message has been sent
  SETTLED = 'SETTLED', // signifies settlement has arrived on spoke domain for intent
  SETTLED_AND_MANUALLY_EXECUTED = 'SETTLED_AND_MANUALLY_EXECUTED', // settlement has arrived & calldata executed
}
export type SpokeDestinationIntentEntity = Intent & {
  id: string;
  queueIdx: number;
  message?: MessageEntity;
  calldataExecutedEvent?: CalldataExecutedEventEntity;
  status: IntentStatus;
};
export const SPOKE_DESTINATION_INTENT_ENTITY = `
    id
    queueIdx
    message {
      ${MESSAGE_ENTITY}
    }
    calldataExecutedEvent {
      ${CALLDATA_EXECUTE_ENTITY}
    }
    status
    ${INTENT_FIELDS}
`;

export type SpokeFillIntentEventEntity = {
  id: string;
  intent: SpokeDestinationIntentEntity;
  solver: string;
  fee: string;

  transactionHash: string;
  timestamp: number;
  gasPrice: string;
  gasLimit: string;
  blockNumber: number;
  txOrigin: string;
  txNonce: number;
};
export const SPOKE_FILL_INTENT_EVENT_ENTITY = `
    id
    intent {
      ${SPOKE_DESTINATION_INTENT_ENTITY}
    }
    solver
    fee

    transactionHash
    timestamp
    gasPrice
    gasLimit
    blockNumber
    txOrigin
    txNonce
`;

export type DepositorEntity = {
  id: string;
};
export const DEPOSITOR_ENTITY = `
    id
`;

export enum DepositorEventType {
  DEPOSIT = 'DEPOSIT',
  WITHDRAW = 'WITHDRAW',
}
export type DepositorEventEntity = {
  id: string;
  depositor: DepositorEntity;
  type: DepositorEventType;
  asset: string;
  amount: string;
  balance: string;

  txOrigin: string;
  transactionHash: string;
  timestamp: number;
  blockNumber: number;
  txNonce: number;
  gasPrice: string;
  gasLimit: string;
};
export const DEPOSITOR_EVENT_ENTITY = `
    id
    depositor {
        ${DEPOSITOR_ENTITY}
    }
    type
    asset
    amount
    balance

    txOrigin
    transactionHash
    timestamp
    blockNumber
    txNonce
    gasPrice
    gasLimit
`;

export type UnclaimedBalanceEntity = {
  id: string;
  amount: string;
};
export const UNCLAIMED_BALANCE_ENTITY = `
    id
    amount
`;

export type SpokeQueueEntity = {
  id: string;
  type: string;
  lastProcessed: number;
  size: number;
  first: number;
  last: number;
};
export const SPOKE_QUEUE_ENTITY = `
    id
    type
    lastProcessed
    size
    first
    last
`;

export type SpokeMetaEntity = {
  id: string;
  domain: string;
  paused: boolean;
  gateway: string;
  lighthouse: string;
};
export const SPOKE_META_ENTITY = `
    id
    domain
    paused
    gateway
    lighthouse
`;

export type SettlementQueueEntity = {
  id: string;
  domain: string; // settlement domain
  lastProcessed: number;
  size: number;
  first: number;
  last: number;
};
export const SETTLEMENT_QUEUE_ENTITY = `
    id
    domain
    lastProcessed
    size
    first
    last
`;

export enum SettlementMessageType {
  SETTLED = 'SETTLED',
  RETURN_UNSUPPORTED = 'RETURN_UNSUPPORTED',
}

export type HubSettlementEntity = {
  id: string;
  // intent: HubIntentEntity; // type matches query, which doesnt include intent
  queueIdx: number;

  amount: string;
  asset: string;
  updateVirtualBalance: boolean;
  recipient: string;
  domain: string;
  entryEpoch: number;
};
export const HUB_SETTLEMENT = `
  id
  queueIdx
  amount
  asset
  updateVirtualBalance
  recipient
  domain
  entryEpoch
`;

export type SettlementMessageEntity = {
  id: string;
  quote: string;
  domain: string;
  intentIds: string[];
  type: SettlementMessageType;

  txOrigin: string;
  gasLimit: string;
  gasPrice: string;
  transactionHash: string;
  timestamp: number;
  blockNumber: number;
  txNonce: number;
};

export const SETTLEMENT_MESSAGE_ENTITY = `
    id
    quote
    domain
    type

    intentIds

    txOrigin
    transactionHash
    timestamp
    blockNumber
    txNonce
    gasLimit
    gasPrice
`;

export type HubIntentEntity = {
  id: string;
  status: Omit<TIntentStatus, 'DISPATCHED'>;
  settlement?: HubSettlementEntity;
  message?: SettlementMessageEntity;
  fillEvent?: {
    txNonce: number;
    timestamp: number;
  };
  addEvent?: {
    txNonce: number;
    timestamp: number;
  };
};
export const HUB_INTENT_ENTITY = `
    id
    status

    settlement {
      ${HUB_SETTLEMENT}
    }
    message {
      ${SETTLEMENT_MESSAGE_ENTITY} 
    }
    fillEvent {
      txNonce
      timestamp
    }
    addEvent {
      txNonce
      timestamp
    }
`;

export type HubAddIntentEventEntity = {
  id: string;
  intent: HubIntentEntity;
  status: Omit<TIntentStatus, 'DISPATCHED'>;

  transactionHash: string;
  timestamp: number;
  blockNumber: number;
  txOrigin: string;
  txNonce: number;
};

export const HUB_ADD_INTENT_EVENT_ENTITY = `
    id
    intent {
      ${HUB_INTENT_ENTITY}
    }
    status

    transactionHash
    timestamp
    blockNumber
    txOrigin
    txNonce
`;

export type HubFillIntentEventEntity = {
  id: string;
  intent: HubIntentEntity;
  status: Omit<TIntentStatus, 'DISPATCHED'>;

  transactionHash: string;
  timestamp: number;
  blockNumber: number;
  txOrigin: string;
  txNonce: number;
};
export const HUB_FILL_INTENT_EVENT_ENTITY = `
    id
    intent {
      ${HUB_INTENT_ENTITY}
    }
    status

    transactionHash
    timestamp
    blockNumber
    txOrigin
    txNonce
`;

export type DepositEntity = {
  id: string;
  epoch: number;
  domain: string;
  amount: string;
  tickerHash: string;
};
export const DEPOSIT_ENTITY = `
  id
  epoch
  domain
  amount
  tickerHash
`;

export type DepositEnqueuedEventEntity = OnchainTransactionContext & {
  id: string;
  deposit: DepositEntity & { processedEvent: { timestamp: number; txNonce: number } };
  intent: HubIntentEntity;
};
export const DEPOSIT_ENQUEUED_EVENT_ENTITY = `
    id
    deposit {
      ${DEPOSIT_ENTITY}
      processedEvent {
        timestamp
        txNonce
      }
    }
    intent {
      ${HUB_INTENT_ENTITY}
    }
    transactionHash
    timestamp
    blockNumber
    txOrigin
    txNonce
`;

export type DepositProcessedEventEntity = OnchainTransactionContext & {
  id: string;
  deposit: DepositEntity & { enqueuedEvent: { timestamp: number; txNonce: number } };
  intent: HubIntentEntity;
};
export const DEPOSIT_PROCESSED_EVENT_ENTITY = `
    id
    deposit {
      ${DEPOSIT_ENTITY}
      enqueuedEvent {
        timestamp
        txNonce
      }
    }
    intent {
      ${HUB_INTENT_ENTITY}
    }
    transactionHash
    timestamp
    blockNumber
    txOrigin
    txNonce
`;

export type DepositQueueEntity = Omit<DepositQueue, 'type'>;
export const DEPOSIT_QUEUE_ENTITY = `
    id
    epoch
    domain
    tickerHash
    lastProcessed
    size
    first
    last
`;

export type HubInvoiceEntity = {
  id: string;
  intent: HubIntentEntity;
  amount: string;
  tickerHash: string;
  owner: string;
  entryEpoch: number;

  blockNumber: number;
  timestamp: number;
  transactionHash: string;
  txOrigin: string;
  txNonce: number;
};

export const HUB_INVOICE_ENTITY = `
    id
    intent {
        ${HUB_INTENT_ENTITY}
    }
    amount
    tickerHash
    owner
    entryEpoch
`;

export type InvoiceEnqueuedEventEntity = {
  id: string;
  invoice: HubInvoiceEntity;
  intent: HubIntentEntity;

  transactionHash: string;
  timestamp: number;
  blockNumber: number;
  txOrigin: string;
  txNonce: number;
};

export const INVOICE_ENQUEUED_EVENT_ENTITY = `
    id
    invoice {
        ${HUB_INVOICE_ENTITY}
    }
    intent {
        ${HUB_INTENT_ENTITY}
    }

    transactionHash
    timestamp
    blockNumber
    txOrigin
    txNonce
`;

export type SettlementEnqueuedEventEntity = {
  id: string;
  intent: HubIntentEntity;

  queue: SettlementQueueEntity;

  transactionHash: string;
  timestamp: number;
  blockNumber: number;
  txOrigin: string;
  txNonce: number;
};
export const SETTLEMENT_ENQUEUED_EVENT_ENTITY = `
    id
    intent {
      ${HUB_INTENT_ENTITY}
    }
    queue {
      ${SETTLEMENT_QUEUE_ENTITY}
    }

    transactionHash
    timestamp
    blockNumber
    txOrigin
    txNonce
`;

export type TokenEntity = {
  id: string;
  feeRecipients: string[];
  feeAmounts: string[];
  maxDiscountBps: string;
  discountPerEpoch: string;
  prioritizedStrategy: string;
};
export const TOKEN_ENTITY = `
    id
    feeRecipients
    feeAmounts
    maxDiscountBps
    discountPerEpoch
    prioritizedStrategy
`;

export type AssetEntity = {
  id: string;
  token: TokenEntity;
  domain: string;
  adopted: string;
  approval: boolean;
  strategy: string;
};
export const ASSET_ENTITY = `
    id
    token {
        ${TOKEN_ENTITY}
    }
    domain
    adopted
    approval
    strategy
`;

export type TokensEntity = {
  id: string;
  feeRecipients: string[];
  feeAmounts: string[];
  assets: Omit<AssetEntity, 'token' | 'decimals'>[];
  maxDiscountBps: string;
  discountPerEpoch: string;
  prioritizedStrategy: string;
};
export const TOKENS_ENTITY = `
    id
    feeRecipients
    feeAmounts
    maxDiscountBps
    discountPerEpoch
    prioritizedStrategy
    assets (first: 50) {
        id
        domain
        adopted
        approval
        strategy
    }
`;

export type HubMetaEntity = {
  id: string;
  domain: string;
  paused: boolean;
  owner: string;
  proposedOwner: string;
  maxFee: string;
  lighthouse: string;
  supportedDomains: { domain: string; blockGasLimit: string }[];
  acceptanceDelay: number;
};
export const HUB_META_ENTITY = `
    id
    domain
    paused
    owner
    proposedOwner
    maxFee
    lighthouse
    supportedDomains {
      domain
      blockGasLimit
    }
`;

export type SettlementIntentEntity = {
  id: string;
  amount: string;
  asset: string;
  recipient: string;
  status: IntentStatus;
  calldataExecutedEvent?: CalldataExecutedEventEntity;
};

export type IntentSettlementEventEntity = {
  id: string;
  intentId: string;
  settlement: SettlementIntentEntity;

  transactionHash: string;
  timestamp: number;
  blockNumber: number;
  txOrigin: string;
  txNonce: number;
  gasPrice: string;
  gasLimit: string;
};

export const SETTLEMENT_INTENT_ENTITY = `
    id
    recipient
    asset
    amount
    status 

    calldataExecutedEvent {
      ${CALLDATA_EXECUTE_ENTITY}
    }
`;

export const INTENT_SETTLEMENT_EVENT_ENTITY = `
    id
    intentId
		settlement {
      ${SETTLEMENT_INTENT_ENTITY}
    }

    transactionHash
    timestamp
    blockNumber
    txOrigin
    txNonce
    gasPrice
    gasLimit
`;
