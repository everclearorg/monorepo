import { createLoggingContext, jsonifyError, EverclearError } from '@chimera-monorepo/utils';
import { updateHubInvoices, updateHubDeposits, AppContext } from '@chimera-monorepo/cartographer-core';

export const bindInvoices = async (context: AppContext) => {
  const {
    logger,
    adapters: { database },
  } = context;
  const { requestContext, methodContext } = createLoggingContext(bindInvoices.name);
  try {
    logger.debug('Bind Invoices polling loop start', requestContext, methodContext);
    await updateHubInvoices(context);
    await updateHubDeposits(context);

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
