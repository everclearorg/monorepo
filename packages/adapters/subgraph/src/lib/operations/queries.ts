import {
  DEPOSITOR_EVENT_ENTITY,
  HUB_ADD_INTENT_EVENT_ENTITY,
  HUB_FILL_INTENT_EVENT_ENTITY,
  HUB_META_ENTITY,
  MESSAGE_ENTITY,
  META_ENTITY,
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
        txNonce_gte: ${fromNonce}
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
        txNonce_gte: ${fromNonce}
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
        txNonce_gte: ${fromNonce}
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
        txNonce_gte: ${fromNonce}
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
  return `
    meta(id: "SPOKE_META_ID"){
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
        txNonce_gte: ${fromNonce}
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
        txNonce_gte: ${fromNonce}
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
        txNonce_gte: ${fromNonce}
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
        txNonce_gte: ${fromNonce}
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
        txNonce_gte: ${fromNonce}
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

export const getDepositsEnqueuedQuery = (
  fromNonce: number,
  maxBlockNumber?: number,
  limit = 200,
  orderDirection: 'asc' | 'desc' = 'asc',
): string => {
  return `
    depositEnqueuedEvents(
      where: {
        txNonce_gte: ${fromNonce}
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
        txNonce_gte: ${fromNonce}
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
  fromEpoch: number,
  maxBlockNumber?: number,
  limit = 200,
  orderDirection: 'asc' | 'desc' = 'asc',
): string => {
  return `
    depositQueues(
      where: {
        epoch_gte: ${fromEpoch}
        ${maxBlockNumber ? `, blockNumber_lte: ${maxBlockNumber}` : ''}
      },
      first: ${limit},
      orderBy: epoch,
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
        txNonce_gte: ${fromNonce}
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

export const getHubMetaQuery = (): string => {
  return `
    meta (id: "HUB_META_ID"){
      ${HUB_META_ENTITY}
    }
  `;
};
