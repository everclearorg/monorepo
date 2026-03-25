import { createLoggingContext, jsonifyError, sendHeartbeat } from '@chimera-monorepo/utils';
import {
  AppContext,
  updateHubInvoices,
  updateHubDeposits,
  updateOriginIntents,
  updateDestinationIntents,
  updateHubIntents,
  updateSettlementIntents,
  updateOrders,
  updateMessages,
  updateQueues,
  updateHubSpokeMeta,
  updateProtocolUpdateLogs,
  updateMessageStatus,
  updateAssets,
  updateDepositors,
} from '@chimera-monorepo/cartographer-core';
import { LIGHTHOUSE_QUEUES } from '@chimera-monorepo/mqclient';
import { notifyLighthouse } from '../notify';

/**
 * Run all backfill operations using core operations with the handler's context.
 * This catches any events missed by webhooks and also runs periodic-only operations
 * like updateMessageStatus (which checks on-chain Hyperlane delivery status).
 *
 * When an operation pulls new data from subgraphs, the corresponding lighthouse
 * queue is notified so the lighthouse can process it.
 */
export const runBackfill = async (context: AppContext): Promise<void> => {
  const { logger } = context;
  const { requestContext, methodContext } = createLoggingContext('runBackfill');

  logger.debug('Starting backfill maintenance cycle', requestContext, methodContext);

  // Operations that don't notify lighthouse (no return value needed)
  const plainOperations = [
    { name: 'updateOrders', fn: updateOrders },
    { name: 'updateAssets', fn: updateAssets },
    { name: 'updateDepositors', fn: updateDepositors },
    { name: 'updateQueues', fn: updateQueues },
    { name: 'updateHubSpokeMeta', fn: updateHubSpokeMeta },
    { name: 'updateProtocolUpdateLogs', fn: updateProtocolUpdateLogs },
    { name: 'updateMessageStatus', fn: updateMessageStatus },
  ];

  // Operations that notify lighthouse when new data is found
  const notifyOperations: { name: string; fn: (ctx: AppContext) => Promise<number>; queues: string[] }[] = [
    { name: 'updateOriginIntents', fn: updateOriginIntents, queues: [LIGHTHOUSE_QUEUES.INTENT] },
    { name: 'updateDestinationIntents', fn: updateDestinationIntents, queues: [LIGHTHOUSE_QUEUES.FILL] },
    { name: 'updateHubIntents', fn: updateHubIntents, queues: [LIGHTHOUSE_QUEUES.INTENT, LIGHTHOUSE_QUEUES.FILL] },
    { name: 'updateSettlementIntents', fn: updateSettlementIntents, queues: [LIGHTHOUSE_QUEUES.SETTLEMENT] },
    { name: 'updateHubInvoices', fn: updateHubInvoices, queues: [LIGHTHOUSE_QUEUES.INVOICE] },
    { name: 'updateHubDeposits', fn: updateHubDeposits, queues: [LIGHTHOUSE_QUEUES.INVOICE] },
    {
      name: 'updateMessages',
      fn: updateMessages,
      queues: [LIGHTHOUSE_QUEUES.SETTLEMENT, LIGHTHOUSE_QUEUES.FILL],
    },
  ];

  // Collect which queues need notification (deduplicated)
  const queuesToNotify = new Set<string>();

  for (const op of notifyOperations) {
    try {
      const count = await op.fn(context);
      if (count > 0) {
        for (const q of op.queues) queuesToNotify.add(q);
      }
    } catch (error) {
      logger.error(`Backfill error in ${op.name}`, requestContext, methodContext, jsonifyError(error as Error));
    }
  }

  for (const op of plainOperations) {
    try {
      await op.fn(context);
    } catch (error) {
      logger.error(`Backfill error in ${op.name}`, requestContext, methodContext, jsonifyError(error as Error));
    }
  }

  // Notify lighthouse for all queues that had new data
  for (const queueName of queuesToNotify) {
    await notifyLighthouse(queueName);
  }

  // Full materialized view refresh (non-debounced)
  try {
    await context.adapters.database.refreshIntentsView();
    await context.adapters.database.refreshInvoicesView();
  } catch (error) {
    logger.error(
      'Backfill error refreshing materialized views',
      requestContext,
      methodContext,
      jsonifyError(error as Error),
    );
  }

  // Send heartbeat if configured
  const healthUrl = context.config.healthUrls[context.config.service];
  if (healthUrl) {
    await sendHeartbeat(healthUrl, logger);
  }

  logger.debug('Backfill maintenance cycle complete', requestContext, methodContext);
};
