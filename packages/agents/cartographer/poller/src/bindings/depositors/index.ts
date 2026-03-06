import { createLoggingContext, jsonifyError, EverclearError } from '@chimera-monorepo/utils';
import { updateAssets, updateDepositors, AppContext } from '@chimera-monorepo/cartographer-core';

export const bindDepositors = async (context: AppContext) => {
  const { logger } = context;
  const { requestContext, methodContext } = createLoggingContext(bindDepositors.name);
  try {
    logger.debug('Bind depositors polling loop start', requestContext, methodContext);
    await updateAssets(context);
    await updateDepositors(context);
    logger.debug('Bind depositors polling loop complete', requestContext, methodContext);
  } catch (err: unknown) {
    logger.error(
      'Error getting data, waiting for next loop',
      requestContext,
      methodContext,
      jsonifyError(err as EverclearError),
    );
  }
};
