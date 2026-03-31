import { HubIntentColumn } from '@chimera-monorepo/database';
import { AppContext, computeIsSwap } from '@chimera-monorepo/cartographer-core';
import {
  parseOriginIntent,
  parseDestinationIntent,
  parseHubIntent,
  parseSettlementIntent,
  parseOrder,
} from '../webhooks/parsers';
import { notifyLighthouse } from '../notify';
import { LIGHTHOUSE_QUEUES } from '@chimera-monorepo/utils';

export const processOriginIntent = async (
  payload: Record<string, unknown>,
  context: AppContext,
  domain?: string,
): Promise<void> => {
  const {
    logger,
    adapters: { database },
    config,
  } = context;

  const intent = parseOriginIntent(payload);
  const isSwap = computeIsSwap(intent, config, logger);

  logger.debug('Processing origin intent webhook', undefined, undefined, {
    intentId: intent.id,
    originDomain: domain || intent.origin,
  });

  await database.saveOriginIntents([{ ...intent, isSwap }]);
  await notifyLighthouse(LIGHTHOUSE_QUEUES.INTENT);
};

export const processDestinationIntent = async (
  payload: Record<string, unknown>,
  context: AppContext,
  domain?: string,
): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;

  const intent = parseDestinationIntent(payload);
  const fillDomain = domain || '';
  if (fillDomain) {
    intent.destination = fillDomain;
  }

  logger.debug('Processing destination intent webhook', undefined, undefined, {
    intentId: intent.id,
    fillDomain,
  });

  await database.saveDestinationIntents([intent]);
  await notifyLighthouse(LIGHTHOUSE_QUEUES.FILL);
};

export const processHubIntent = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;

  const intent = parseHubIntent(payload);

  logger.debug('Processing hub intent webhook', undefined, undefined, { intentId: intent.id });

  const updateColumns: HubIntentColumn[] = ['status'];
  if (intent.addedTimestamp !== undefined) {
    updateColumns.push('added_timestamp', 'added_tx_nonce');
  }
  if (intent.filledTimestamp !== undefined) {
    updateColumns.push('filled_timestamp', 'filled_tx_nonce');
  }
  if (intent.settlementEnqueuedTimestamp !== undefined) {
    updateColumns.push(
      'settlement_enqueued_timestamp',
      'settlement_enqueued_tx_nonce',
      'settlement_enqueued_block_number',
      'settlement_domain',
      'settlement_amount',
      'settlement_epoch',
      'queue_idx',
    );
  }

  await database.saveHubIntents([intent], updateColumns);
};

export const processSettlementIntent = async (
  payload: Record<string, unknown>,
  context: AppContext,
  domain?: string,
): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;

  const intent = parseSettlementIntent(payload);
  const settleDomain = domain || '';
  if (settleDomain) {
    intent.domain = settleDomain;
  }

  logger.debug('Processing settlement intent webhook', undefined, undefined, {
    intentId: intent.intentId,
    settleDomain,
  });

  await database.saveSettlementIntents([intent]);
};

export const processOrder = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;
  const order = parseOrder(payload);
  logger.debug('Processing order webhook', undefined, undefined, { orderId: order.id });

  await database.saveOrders([order]);
};
