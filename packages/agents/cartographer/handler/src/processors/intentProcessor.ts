import { HubIntentColumn } from '@chimera-monorepo/database';
import { AppContext, computeIsSwap } from '@chimera-monorepo/cartographer-core';
import {
  parseOriginIntent,
  parseDestinationIntent,
  parseHubIntent,
  parseSettlementIntent,
  parseOrder,
} from '../webhooks/parsers';
import { base64ToHex } from '../webhooks/webhookHandler';
import { notifyLighthouse } from '../notify';
import { LIGHTHOUSE_QUEUES } from '@chimera-monorepo/mqclient';

/**
 * Safely extract an intent ID from the webhook payload.
 */
function extractIntentId(payload: Record<string, unknown>): string {
  const raw = (payload.id || payload.intent_id) as string | undefined;
  if (!raw) return '';
  if (raw.startsWith('0x')) return raw;
  try {
    return base64ToHex(raw);
  } catch {
    return raw;
  }
}

export const processOriginIntent = async (
  payload: Record<string, unknown>,
  context: AppContext,
  domain?: string,
): Promise<void> => {
  const {
    logger,
    adapters: { database, subgraph },
    config,
  } = context;
  const intentId = extractIntentId(payload);
  // Use domain from URL param, or fall back to payload's origin field
  const originDomain = domain || (payload.origin as string) || '';

  logger.debug('Processing origin intent webhook', undefined, undefined, { intentId, originDomain });

  // Query subgraph for complete data (includes tx context from IntentAddEvent)
  try {
    const fullIntent = await subgraph.getOriginIntentById(originDomain, intentId);
    if (fullIntent) {
      const isSwap = computeIsSwap(fullIntent, config, logger);
      await database.saveOriginIntents([{ ...fullIntent, isSwap }]);
      await notifyLighthouse(LIGHTHOUSE_QUEUES.INTENT);
      return;
    }
    logger.warn('Origin intent not found in subgraph, falling back to webhook data', undefined, undefined, {
      intentId,
      originDomain,
    });
  } catch (error) {
    logger.warn('Failed to query subgraph for origin intent, falling back to webhook data', undefined, undefined, {
      intentId,
      error: (error as Error).message,
    });
  }

  // Fallback: parse webhook payload (partial data, backfill will complete it)
  const intent = parseOriginIntent(payload);
  const isSwap = computeIsSwap(intent, config, logger);
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
    adapters: { database, subgraph },
  } = context;
  const intentId = extractIntentId(payload);
  const fillDomain = domain || '';

  logger.debug('Processing destination intent webhook', undefined, undefined, { intentId, fillDomain });

  if (fillDomain) {
    try {
      const fullIntent = await subgraph.getDestinationIntentById(fillDomain, intentId);
      if (fullIntent) {
        await database.saveDestinationIntents([fullIntent]);
        await notifyLighthouse(LIGHTHOUSE_QUEUES.FILL);
        return;
      }
      logger.warn('Destination intent not found in subgraph, falling back to webhook data', undefined, undefined, {
        intentId,
        fillDomain,
      });
    } catch (error) {
      logger.warn(
        'Failed to query subgraph for destination intent, falling back to webhook data',
        undefined,
        undefined,
        { intentId, error: (error as Error).message },
      );
    }
  }

  // Fallback: parse webhook payload
  const intent = parseDestinationIntent(payload);
  // Set destination from domain param if available
  if (fillDomain) {
    intent.destination = fillDomain;
  }
  await database.saveDestinationIntents([intent]);
  await notifyLighthouse(LIGHTHOUSE_QUEUES.FILL);
};

export const processHubIntent = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database, subgraph },
    config,
  } = context;
  const intentId = extractIntentId(payload);
  const hubDomain = config.hub.domain;

  logger.debug('Processing hub intent webhook', undefined, undefined, { intentId });

  // Query subgraph for complete data
  try {
    const fullIntent = await subgraph.getHubIntentById(hubDomain, intentId);
    if (fullIntent) {
      // Full upsert - update all available columns
      const updateCols: HubIntentColumn[] = ['status'];
      if (fullIntent.addedTimestamp !== undefined) updateCols.push('added_timestamp', 'added_tx_nonce');
      if (fullIntent.filledTimestamp !== undefined) updateCols.push('filled_timestamp', 'filled_tx_nonce');
      if (fullIntent.settlementEnqueuedTimestamp !== undefined) {
        updateCols.push(
          'settlement_enqueued_timestamp',
          'settlement_enqueued_tx_nonce',
          'settlement_enqueued_block_number',
          'settlement_domain',
          'settlement_amount',
          'settlement_epoch',
          'queue_idx',
        );
      }
      if (fullIntent.messageId !== undefined) updateCols.push('message_id');
      if (fullIntent.updateVirtualBalance !== undefined) updateCols.push('update_virtual_balance');
      await database.saveHubIntents([fullIntent], updateCols);
      return;
    }
    logger.warn('Hub intent not found in subgraph, falling back to webhook data', undefined, undefined, { intentId });
  } catch (error) {
    logger.warn('Failed to query subgraph for hub intent, falling back to webhook data', undefined, undefined, {
      intentId,
      error: (error as Error).message,
    });
  }

  // Fallback: parse webhook payload with selective updateColumns
  const intent = parseHubIntent(payload);

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
    adapters: { database, subgraph },
  } = context;
  const intentId = extractIntentId(payload);
  const settleDomain = domain || '';

  logger.debug('Processing settlement intent webhook', undefined, undefined, { intentId, settleDomain });

  if (settleDomain) {
    try {
      const fullIntent = await subgraph.getSettlementIntentById(settleDomain, intentId);
      if (fullIntent) {
        await database.saveSettlementIntents([fullIntent]);
        return;
      }
      logger.warn('Settlement intent not found in subgraph, falling back to webhook data', undefined, undefined, {
        intentId,
        settleDomain,
      });
    } catch (error) {
      logger.warn(
        'Failed to query subgraph for settlement intent, falling back to webhook data',
        undefined,
        undefined,
        { intentId, error: (error as Error).message },
      );
    }
  }

  // Fallback: parse webhook payload
  const intent = parseSettlementIntent(payload);
  if (settleDomain) {
    intent.domain = settleDomain;
  }
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
