import { createLoggingContext, jsonifyError, EverclearError } from '@chimera-monorepo/utils';

import { AppContext } from '../../shared';
import { updateHubInvoices, updateHubDeposits } from '../../lib/operations';

export const bindInvoices = async (context: AppContext) => {
  const {
    logger,
    adapters: { database },
  } = context;
  const { requestContext, methodContext } = createLoggingContext(bindInvoices.name);
  try {
    logger.debug('Bind Invoices polling loop start', requestContext, methodContext);
    await updateHubInvoices();
    await updateHubDeposits();

    // Refresh the materialized view
    await database.refreshInvoicesView();
    logger.debug('Bind Invoices polling loop complete', requestContext, methodContext);
  } catch (err: unknown) {
    logger.error(
      'Error getting data, waiting for next loop',
      requestContext,
      methodContext,
      jsonifyError(err as EverclearError),
    );
  }
};
