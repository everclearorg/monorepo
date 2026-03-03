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

/**
 * Run all backfill operations using core operations with the handler's context.
 * This catches any events missed by webhooks and also runs periodic-only operations
 * like updateMessageStatus (which checks on-chain Hyperlane delivery status).
 */
export const runBackfill = async (context: AppContext): Promise<void> => {
  const { logger } = context;
  const { requestContext, methodContext } = createLoggingContext('runBackfill');

  logger.debug('Starting backfill maintenance cycle', requestContext, methodContext);

  const operations = [
    { name: 'updateOrders', fn: updateOrders },
    { name: 'updateOriginIntents', fn: updateOriginIntents },
    { name: 'updateDestinationIntents', fn: updateDestinationIntents },
    { name: 'updateHubIntents', fn: updateHubIntents },
    { name: 'updateSettlementIntents', fn: updateSettlementIntents },
    { name: 'updateHubInvoices', fn: updateHubInvoices },
    { name: 'updateHubDeposits', fn: updateHubDeposits },
    { name: 'updateAssets', fn: updateAssets },
    { name: 'updateDepositors', fn: updateDepositors },
    { name: 'updateMessages', fn: updateMessages },
    { name: 'updateQueues', fn: updateQueues },
    { name: 'updateHubSpokeMeta', fn: updateHubSpokeMeta },
    { name: 'updateProtocolUpdateLogs', fn: updateProtocolUpdateLogs },
    { name: 'updateMessageStatus', fn: updateMessageStatus },
  ];

  for (const op of operations) {
    try {
      await op.fn(context);
    } catch (error) {
      logger.error(`Backfill error in ${op.name}`, requestContext, methodContext, jsonifyError(error as Error));
    }
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
