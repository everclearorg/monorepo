import { createLoggingContext, jsonifyError, EverclearError } from '@chimera-monorepo/utils';

import { AppContext } from '../../shared';
import { updateMessages, updateQueues, updateMessageStatus } from '../../lib/operations';

export const bindMonitor = async (context: AppContext) => {
  const { logger } = context;
  const { requestContext, methodContext } = createLoggingContext(bindMonitor.name);
  try {
    logger.debug('Bind monitor polling loop start', requestContext, methodContext);
    await updateMessages();
    await updateQueues();
    await updateMessageStatus();
    logger.debug('Bind monitor polling loop complete', requestContext, methodContext);
  } catch (err: unknown) {
    logger.error(
      'Error getting data, waiting for next loop',
      requestContext,
      methodContext,
      jsonifyError(err as EverclearError),
    );
  }
};
