import { createLoggingContext, jsonifyError, EverclearError } from '@chimera-monorepo/utils';

import { AppContext } from '../../shared';
import { updateAssets, updateDepositors } from '../../lib/operations';

export const bindDepositors = async (context: AppContext) => {
  const { logger } = context;
  const { requestContext, methodContext } = createLoggingContext(bindDepositors.name);
  try {
    logger.debug('Bind depositors polling loop start', requestContext, methodContext);
    await updateAssets();
    await updateDepositors();
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
