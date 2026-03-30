import {
  DEPOSITOR_EVENT_ENTITY,
  HUB_ADD_INTENT_EVENT_ENTITY,
  HUB_FILL_INTENT_EVENT_ENTITY,
  HUB_META_ENTITY,
  MESSAGE_ENTITY,
  META_ENTITY,
  META_UPDATE_ENTITY,
  SPOKE_QUEUE_ENTITY,
  SPOKE_ADD_INTENT_EVENT_ENTITY,
  SPOKE_FILL_INTENT_EVENT_ENTITY,
  SPOKE_META_ENTITY,
  TOKENS_ENTITY,
  SETTLEMENT_QUEUE_ENTITY,
  SETTLEMENT_MESSAGE_ENTITY,
  SETTLEMENT_ENQUEUED_EVENT_ENTITY,
  INVOICE_ENQUEUED_EVENT_ENTITY,
  DEPOSIT_ENQUEUED_EVENT_ENTITY,
  DEPOSIT_PROCESSED_EVENT_ENTITY,
  DEPOSIT_QUEUE_ENTITY,
  INTENT_SETTLEMENT_EVENT_ENTITY,
  ORDER_ENTITY,
  HUB_TOKEN_UPDATE_ENTITY,
  HUB_ASSET_UPDATE_ENTITY,
} from './entities';

export const getBlockNumberQuery = (): string => {
  return `
    _meta {
        ${META_ENTITY}
    }
  `;
};

export const getOriginIntentAddedQuery = (
  fromNonce: number,
  destinationDomains: string[],
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'asc',
  limit?: number,
): string => {
  return `
    intentAddEvents(
      where: {
        txNonce_gt: ${fromNonce}
        ${destinationDomains.length ? `,intent_: {destination_in: [${destinationDomains}]}` : ''}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${SPOKE_ADD_INTENT_EVENT_ENTITY}
    }
  `;
};

export const getSettlementIntentEventQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'asc',
  limit?: number,
): string => {
  return `
    intentSettleEvents(
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${INTENT_SETTLEMENT_EVENT_ENTITY}
    }
  `;
};

export const getOriginIntentByIdQuery = (intentId: string): string => {
  return `
    intentAddEvents(
      where: {
        intent_: {id: "${intentId}"}
      },
      first: 1
    ){
      ${SPOKE_ADD_INTENT_EVENT_ENTITY}
    }
  `;
};

export const getSpokeMessagesQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'asc',
  limit?: number,
): string => {
  return `
    messages (
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${MESSAGE_ENTITY}
    }
  `;
};

export const getDestinationIntentsByIdsQuery = (ids: string[]): string => {
  return `
    intentFillEvents(
      ${
        ids.length
          ? `where: {
        intent_: {id_in: ["${ids.join('","')}"] }}`
          : ''
      }
    ){
      ${SPOKE_FILL_INTENT_EVENT_ENTITY}
    }
  `;
};

export const getDestinationIntentFilledQuery = (
  fromNonce: number,
  originDomains: string[],
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'desc',
  limit?: number,
): string => {
  return `
    intentFillEvents(
      where: {
        txNonce_gt: ${fromNonce}
        ${originDomains.length ? `,intent_: {origin_in: [${originDomains}]}` : ''}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${SPOKE_FILL_INTENT_EVENT_ENTITY}
    }
  `;
};

export const getSpokeQueueQuery = (type?: string): string => {
  return `
    queues (
      first: 5
      ${
        type
          ? `,where: {
                type: ${type}
              }`
          : ''
      } 
    ){
      ${SPOKE_QUEUE_ENTITY}
    }
  `;
};

export const getSpokeMetaQuery = (): string => {
  // SPOKE_META_ID is a bytes32 value, so we need to convert it to a string
  return `
    meta(id: "0x53504f4b455f4d4554415f4944"){
      ${SPOKE_META_ENTITY}
    }
  `;
};

export const getDepositorEventsQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'desc',
  limit?: number,
): string => {
  return `
    depositorEvents(
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${DEPOSITOR_EVENT_ENTITY}
    }
  `;
};

export const getTokensQuery = (): string => {
  return `
    tokens(
      first: 100
    ){
      ${TOKENS_ENTITY}
    }
  `;
};

export const getHubIntentByIdQuery = (intentId: string): string => {
  return `
    hubIntents(where: { id: "${intentId.toLowerCase()}" }) {
      id
      status
      addEvent {      
        ${HUB_ADD_INTENT_EVENT_ENTITY}
      }
    }
  `;
};

export const getHubIntentAddedQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'asc',
  limit?: number,
): string => {
  return `
    intentAddEvents(
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${HUB_ADD_INTENT_EVENT_ENTITY}
    }
  `;
};

export const getHubIntentFilledQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'asc',
  limit?: number,
): string => {
  return `
    intentFillEvents(
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${HUB_FILL_INTENT_EVENT_ENTITY}
    }
  `;
};

export const getSettlementEnqueuedQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'asc',
  limit?: number,
): string => {
  return `
    settlementEnqueuedEvents(
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${SETTLEMENT_ENQUEUED_EVENT_ENTITY}
    }
  `;
};

export const getInvoiceEnqueuedQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'asc',
  limit?: number,
): string => {
  return `
    invoiceEnqueuedEvents(
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${INVOICE_ENQUEUED_EVENT_ENTITY}
    }
  `;
};

export const getInvoiceEnqueuedByIntentId = (intentId: string): string => {
  return `
    invoiceEnqueuedEvents(
      where: {
        intent_: {id: "${intentId}"}
      },
      first: 1
    ){
      ${INVOICE_ENQUEUED_EVENT_ENTITY}
    }
  `;
};

export const getSettlementIntentByIdQuery = (intentId: string): string => {
  return `
    intentSettleEvents(
      where: {
        intentId: "${intentId.toLowerCase()}"
      },
      first: 1
    ){
      ${INTENT_SETTLEMENT_EVENT_ENTITY}
    }
  `;
};

export const getDepositEnqueuedByIntentIdQuery = (intentId: string): string => {
  return `
    depositEnqueuedEvents(
      where: {
        intent_: {id: "${intentId.toLowerCase()}"}
      },
      first: 1
    ){
      ${DEPOSIT_ENQUEUED_EVENT_ENTITY}
    }
  `;
};

export const getDepositProcessedByIntentIdQuery = (intentId: string): string => {
  return `
    depositProcessedEvents(
      where: {
        intent_: {id: "${intentId.toLowerCase()}"}
      },
      first: 1
    ){
      ${DEPOSIT_PROCESSED_EVENT_ENTITY}
    }
  `;
};

export const getDepositsEnqueuedQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  limit = 200,
  orderDirection: 'asc' | 'desc' = 'asc',
): string => {
  return `
    depositEnqueuedEvents(
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ) {
      ${DEPOSIT_ENQUEUED_EVENT_ENTITY}
    }
  `;
};

export const getDepositsProcessedQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  limit = 200,
  orderDirection: 'asc' | 'desc' = 'asc',
): string => {
  return `
    depositProcessedEvents(
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ) {
      ${DEPOSIT_PROCESSED_EVENT_ENTITY}
    }
  `;
};

export const getDepositQueuesQuery = (
  fromBlock: number,
  maxBlockNumber?: number,
  limit = 200,
  orderDirection: 'asc' | 'desc' = 'asc',
): string => {
  return `
    depositQueues(
      where: {
        blockNumber_gte: ${fromBlock}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit},
      orderBy: blockNumber,
      orderDirection: ${orderDirection}
    ) {
      ${DEPOSIT_QUEUE_ENTITY}
    }
  `;
};

export const getSettlementQueuesQuery = (limit = 100): string => {
  return `
    settlementQueues (first: ${limit}) {
      ${SETTLEMENT_QUEUE_ENTITY}
    }
  `;
};

export const getSettlementMessagesQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'asc',
  limit?: number,
): string => {
  return `
    settlementMessages (
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${SETTLEMENT_MESSAGE_ENTITY}
    }
  `;
};

export const getHubMetaUpdatesQuery = (
  fromBlock: number,
  limit = 200,
  orderDirection: 'asc' | 'desc' = 'asc',
): string => {
  return `
    hubMetaUpdates(
      where: {
        blockNumber_gte: ${fromBlock}
      },
      first: ${limit},
      orderBy: blockNumber,
      orderDirection: ${orderDirection}
    ) {
      ${META_UPDATE_ENTITY}
    }
  `;
};

export const getSpokeMetaUpdatesQuery = (
  fromBlock: number,
  limit = 200,
  orderDirection: 'asc' | 'desc' = 'asc',
): string => {
  return `
    spokeMetaUpdates(
      where: {
        blockNumber_gte: ${fromBlock}
      },
      first: ${limit},
      orderBy: blockNumber,
      orderDirection: ${orderDirection}
    ) {
      ${META_UPDATE_ENTITY}
    }
  `;
};

export const getHubTokenUpdatesQuery = (
  fromBlock: number,
  limit = 200,
  orderDirection: 'asc' | 'desc' = 'asc',
): string => {
  return `
    hubTokenUpdates(
      where: {
        blockNumber_gte: ${fromBlock}
      },
      first: ${limit},
      orderBy: blockNumber,
      orderDirection: ${orderDirection}
    ) {
      ${HUB_TOKEN_UPDATE_ENTITY}
    }
  `;
};

export const getHubAssetUpdatesQuery = (
  fromBlock: number,
  limit = 200,
  orderDirection: 'asc' | 'desc' = 'asc',
): string => {
  return `
    hubAssetUpdates(
      where: {
        blockNumber_gte: ${fromBlock}
      },
      first: ${limit},
      orderBy: blockNumber,
      orderDirection: ${orderDirection}
    ) {
      ${HUB_ASSET_UPDATE_ENTITY}
    }
  `;
};

export const getHubMetaQuery = (): string => {
  // HUB_META_ID is a bytes32 value, so we need to convert it to a string
  return `
    meta (id: "0x4855425f4d4554415f4944"){
      ${HUB_META_ENTITY}
    }
  `;
};

export const getOrdersByNonce = (
  fromNonce: number,
  maxBlockNumber?: number,
  orderDirection: 'asc' | 'desc' = 'asc',
  limit?: number,
): string => {
  return `
    orderCreateds(
      where: {
        txNonce_gt: ${fromNonce}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit ?? 200},
      orderBy: txNonce,
      orderDirection: ${orderDirection}
    ){
      ${ORDER_ENTITY}
    }
  `;
};

export const ENVIO_INTENT_ENTITY = `
  id
  intentId
  queueIdx
  initiator
  receiver
  inputAsset
  outputAsset
  maxFee
  amountOutMin
  origin
  nonce
  timestamp
  ttl
  originAmount
  destinations
  data
  chainId
  blockNumber
  blockTimestamp
  transactionHash
  sender
  receiveBlockNumber
  isFastPath
  tokenFee
  nativeFee
  status
  fills {
    id
    intentId
    solver
    totalFeeDBPS
    queueIdx
    initiator
    receiver
    inputAsset
    outputAsset
    maxFee
    origin
    nonce
    timestamp
    ttl
    originAmount
    fillAmount
    destinations
    data
    chainId
    blockNumber
    blockTimestamp
    transactionHash
  }
`;

/**
 * Get intents query for Envio
 * @param orderBy - Field to order by (default: blockTimestamp)
 * @param orderDirection - Order direction (default: desc)
 */
export const getEnvioIntentsQuery = (
  orderBy: string = 'blockTimestamp',
  orderDirection: 'asc' | 'desc' = 'desc',
): string => {
  return `
    query GetIntents($where: Intent_bool_exp!, $limit: Int, $offset: Int, $orderBy: [Intent_order_by!]) {
      Intent(
        where: $where
        order_by: $orderBy
        limit: $limit
        offset: $offset
      ) {
        ${ENVIO_INTENT_ENTITY}
      }
    }
  `;
};

export const getEnvioIntentByIdQuery = (): string => {
  return `
    query GetIntentById($intentId: String!) {
      Intent(where: { intentId: { _eq: $intentId } }) {
        ${ENVIO_INTENT_ENTITY}
      }
    }
  `;
};

// ============================================================================
// ENVIO ENTITY FIELD STRINGS
// ============================================================================

export const ENVIO_HUB_INTENT_FIELDS = `
  id
  status
  settlementId
  messageId
  addEventTransactionHash
  addEventTimestamp
  addEventBlockNumber
  addEventTxNonce
  fillEventTransactionHash
  fillEventTimestamp
  fillEventBlockNumber
  fillEventTxNonce
`;

export const ENVIO_HUB_SETTLEMENT_FIELDS = `
  id
  intentId
  queueIdx
  amount
  asset
  updateVirtualBalance
  recipient
  domain
  entryEpoch
  enqueuedTransactionHash
  enqueuedTimestamp
  enqueuedBlockNumber
  enqueuedTxOrigin
  enqueuedTxNonce
`;

export const ENVIO_INVOICE_FIELDS = `
  id
  intentId
  tickerHash
  amount
  owner
  entryEpoch
  transactionHash
  timestamp
  blockNumber
  txOrigin
  txNonce
`;

export const ENVIO_SETTLEMENT_INTENT_FIELDS = `
  id
  status
  recipient
  asset
  amount
  settlementTransactionHash
  settlementTimestamp
  settlementBlockNumber
  settlementTxOrigin
  settlementTxNonce
  settlementGasPrice
  settlementGasLimit
`;

export const ENVIO_DEPOSIT_FIELDS = `
  id
  intentId
  epoch
  domain
  amount
  tickerHash
  enqueuedTransactionHash
  enqueuedTimestamp
  enqueuedBlockNumber
  enqueuedTxNonce
  processedTransactionHash
  processedTimestamp
  processedBlockNumber
  processedTxNonce
`;

export const ENVIO_DEPOSIT_QUEUE_FIELDS = `
  id
  epoch
  domain
  tickerHash
  lastProcessed
  size
  first
  last
  blockNumber
`;

export const ENVIO_DEPOSITOR_EVENT_FIELDS = `
  id
  depositor
  eventType
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
  chainId
`;

export const ENVIO_TOKEN_FIELDS = `
  id
  feeRecipients
  feeAmounts
  maxDiscountBps
  discountPerEpoch
  prioritizedStrategy
`;

export const ENVIO_HUB_ASSET_FIELDS = `
  id
  tickerHash
  domain
  adopted
  approval
  strategy
`;

export const ENVIO_QUEUE_FIELDS = `
  id
  queueType
  lastProcessed
  size
  first
  last
  chainId
`;

export const ENVIO_SETTLEMENT_QUEUE_FIELDS = `
  id
  domain
  lastProcessed
  size
  first
  last
`;

export const ENVIO_MESSAGE_FIELDS = `
  id
  messageType
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
  chainId
`;

export const ENVIO_SETTLEMENT_MESSAGE_FIELDS = `
  id
  quote
  domain
  intentIds
  messageType
  txOrigin
  transactionHash
  timestamp
  blockNumber
  txNonce
  gasPrice
  gasLimit
`;

export const ENVIO_HUB_META_FIELDS = `
  id
  domain
  paused
  owner
  proposedOwner
  proposedOwnershipTimestamp
  gateway
  watchtower
  mailbox
  securityModule
  acceptanceDelay
  minSolverSupportedDomains
  epochLength
  expiryTimeBuffer
  supportedDomains
`;

export const ENVIO_DOMAIN_FIELDS = `
  id
  domain
  blockGasLimit
`;

export const ENVIO_SPOKE_META_FIELDS = `
  id
  domain
  paused
  gateway
  lighthouse
  messageReceiver
  watchtower
  messageGasLimit
  feeAdapter
  fillSigner
`;

export const ENVIO_ORDER_FIELDS = `
  id
  initiator
  intentIds
  tokenFee
  nativeFee
  transactionHash
  timestamp
  blockNumber
  txOrigin
  txNonce
  gasPrice
  gasLimit
  chainId
`;

// ============================================================================
// ENVIO QUERY GENERATORS
// ============================================================================

export const getEnvioHubIntentByIdQuery = (): string => `
  query GetHubIntentById($intentId: String!) {
    HubIntent(where: { id: { _eq: $intentId } }) {
      ${ENVIO_HUB_INTENT_FIELDS}
    }
    HubSettlement(where: { id: { _eq: $intentId } }) {
      ${ENVIO_HUB_SETTLEMENT_FIELDS}
    }
  }
`;

export const getEnvioHubIntentsAddedQuery = (): string => `
  query GetHubIntentsAdded($where: HubIntent_bool_exp!, $limit: Int, $offset: Int) {
    HubIntent(where: $where, order_by: { addEventBlockNumber: asc }, limit: $limit, offset: $offset) {
      ${ENVIO_HUB_INTENT_FIELDS}
    }
  }
`;

export const getEnvioHubIntentsFilledQuery = (): string => `
  query GetHubIntentsFilled($where: HubIntent_bool_exp!, $limit: Int, $offset: Int) {
    HubIntent(where: $where, order_by: { fillEventBlockNumber: asc }, limit: $limit, offset: $offset) {
      ${ENVIO_HUB_INTENT_FIELDS}
    }
  }
`;

export const getEnvioHubSettlementsQuery = (): string => `
  query GetHubSettlements($where: HubSettlement_bool_exp!, $limit: Int, $offset: Int) {
    HubSettlement(where: $where, order_by: { enqueuedBlockNumber: asc }, limit: $limit, offset: $offset) {
      ${ENVIO_HUB_SETTLEMENT_FIELDS}
    }
  }
`;

export const getEnvioInvoiceByIntentIdQuery = (): string => `
  query GetInvoiceByIntentId($intentId: String!) {
    Invoice(where: { intentId: { _eq: $intentId } }, limit: 1) {
      ${ENVIO_INVOICE_FIELDS}
    }
    HubIntent(where: { id: { _eq: $intentId } }) {
      ${ENVIO_HUB_INTENT_FIELDS}
    }
  }
`;

export const getEnvioInvoicesQuery = (): string => `
  query GetInvoices($where: Invoice_bool_exp!, $limit: Int, $offset: Int) {
    Invoice(where: $where, order_by: { blockNumber: asc }, limit: $limit, offset: $offset) {
      ${ENVIO_INVOICE_FIELDS}
    }
  }
`;

export const getEnvioSettlementIntentByIdQuery = (): string => `
  query GetSettlementIntentById($intentId: String!) {
    SettlementIntent(where: { id: { _eq: $intentId } }) {
      ${ENVIO_SETTLEMENT_INTENT_FIELDS}
    }
  }
`;

export const getEnvioSettlementIntentsQuery = (): string => `
  query GetSettlementIntents($where: SettlementIntent_bool_exp!, $limit: Int, $offset: Int) {
    SettlementIntent(where: $where, order_by: { settlementBlockNumber: asc }, limit: $limit, offset: $offset) {
      ${ENVIO_SETTLEMENT_INTENT_FIELDS}
    }
  }
`;

export const getEnvioDepositByIntentIdQuery = (): string => `
  query GetDepositByIntentId($intentId: String!) {
    Deposit(where: { id: { _eq: $intentId } }) {
      ${ENVIO_DEPOSIT_FIELDS}
    }
    HubIntent(where: { id: { _eq: $intentId } }) {
      ${ENVIO_HUB_INTENT_FIELDS}
    }
  }
`;

export const getEnvioDepositsQuery = (): string => `
  query GetDeposits($where: Deposit_bool_exp!, $limit: Int, $offset: Int, $orderBy: [Deposit_order_by!]) {
    Deposit(where: $where, order_by: $orderBy, limit: $limit, offset: $offset) {
      ${ENVIO_DEPOSIT_FIELDS}
    }
  }
`;

export const getEnvioDepositQueuesQuery = (): string => `
  query GetDepositQueues($where: DepositQueue_bool_exp!, $limit: Int, $offset: Int) {
    DepositQueue(where: $where, order_by: { blockNumber: asc }, limit: $limit, offset: $offset) {
      ${ENVIO_DEPOSIT_QUEUE_FIELDS}
    }
  }
`;

export const getEnvioDepositorEventsQuery = (): string => `
  query GetDepositorEvents($where: DepositorEvent_bool_exp!, $limit: Int, $offset: Int) {
    DepositorEvent(where: $where, order_by: { blockNumber: asc }, limit: $limit, offset: $offset) {
      ${ENVIO_DEPOSITOR_EVENT_FIELDS}
    }
  }
`;

export const getEnvioTokensQuery = (): string => `
  query GetTokens {
    Token(limit: 100) {
      ${ENVIO_TOKEN_FIELDS}
    }
    HubAsset(limit: 500) {
      ${ENVIO_HUB_ASSET_FIELDS}
    }
  }
`;

export const getEnvioSpokeQueuesQuery = (): string => `
  query GetSpokeQueues($where: Queue_bool_exp!) {
    Queue(where: $where) {
      ${ENVIO_QUEUE_FIELDS}
    }
  }
`;

export const getEnvioSettlementQueuesQuery = (): string => `
  query GetSettlementQueues {
    SettlementQueue(limit: 100) {
      ${ENVIO_SETTLEMENT_QUEUE_FIELDS}
    }
  }
`;

export const getEnvioSpokeMessagesQuery = (): string => `
  query GetSpokeMessages($where: Message_bool_exp!, $limit: Int, $offset: Int) {
    Message(where: $where, order_by: { blockNumber: asc }, limit: $limit, offset: $offset) {
      ${ENVIO_MESSAGE_FIELDS}
    }
  }
`;

export const getEnvioSettlementMessagesQuery = (): string => `
  query GetSettlementMessages($where: SettlementMessage_bool_exp!, $limit: Int, $offset: Int) {
    SettlementMessage(where: $where, order_by: { blockNumber: asc }, limit: $limit, offset: $offset) {
      ${ENVIO_SETTLEMENT_MESSAGE_FIELDS}
    }
  }
`;

export const getEnvioHubMetaQuery = (): string => `
  query GetHubMeta {
    HubMeta(where: { id: { _eq: "HUB_META" } }) {
      ${ENVIO_HUB_META_FIELDS}
    }
    Domain {
      ${ENVIO_DOMAIN_FIELDS}
    }
  }
`;

export const getEnvioSpokeMetaQuery = (): string => `
  query GetSpokeMeta($chainId: String!) {
    SpokeMeta(where: { id: { _eq: $chainId } }) {
      ${ENVIO_SPOKE_META_FIELDS}
    }
  }
`;

export const getEnvioOrdersQuery = (): string => `
  query GetOrders($where: Order_bool_exp!, $limit: Int, $offset: Int) {
    Order(where: $where, order_by: { blockNumber: asc }, limit: $limit, offset: $offset) {
      ${ENVIO_ORDER_FIELDS}
    }
  }
`;
