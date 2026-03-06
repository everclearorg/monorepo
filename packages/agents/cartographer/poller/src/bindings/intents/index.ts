import { createLoggingContext, jsonifyError, EverclearError } from '@chimera-monorepo/utils';
import {
  updateOriginIntents,
  updateDestinationIntents,
  updateSettlementIntents,
  updateHubIntents,
  updateOrders,
  AppContext,
} from '@chimera-monorepo/cartographer-core';

export const bindIntents = async (context: AppContext) => {
  const {
    logger,
    adapters: { database },
  } = context;
  const { requestContext, methodContext } = createLoggingContext(bindIntents.name);
  try {
    logger.debug('Bind intents polling loop start', requestContext, methodContext);
    await updateOrders(context);
    await updateOriginIntents(context);
    await updateDestinationIntents(context);
    await updateHubIntents(context);
    await updateSettlementIntents(context);

    // Refresh the materialized view
    await database.refreshIntentsView();
    logger.debug('Bind intents polling loop complete', requestContext, methodContext);
  } catch (err: unknown) {
    logger.error(
      'Error getting data, waiting for next loop',
      requestContext,
      methodContext,
      jsonifyError(err as EverclearError),
    );
  }
};
