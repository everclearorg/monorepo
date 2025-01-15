import { createLoggingContext, jsonifyError, EverclearError } from '@chimera-monorepo/utils';

import { AppContext } from '../../shared';
import {
  updateOriginIntents,
  updateDestinationIntents,
  updateSettlementIntents,
  updateHubIntents,
} from '../../lib/operations';

export const bindIntents = async (context: AppContext) => {
  const {
    logger,
    adapters: { database },
  } = context;
  const { requestContext, methodContext } = createLoggingContext(bindIntents.name);
  try {
    logger.debug('Bind intents polling loop start', requestContext, methodContext);
    await updateOriginIntents();
    await updateDestinationIntents();
    await updateHubIntents();
    await updateSettlementIntents();

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
