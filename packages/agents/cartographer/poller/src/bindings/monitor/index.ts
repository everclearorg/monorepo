import { createLoggingContext, jsonifyError, EverclearError } from '@chimera-monorepo/utils';
import {
  updateMessages,
  updateQueues,
  updateMessageStatus,
  updateProtocolUpdateLogs,
  updateHubSpokeMeta,
  AppContext,
} from '@chimera-monorepo/cartographer-core';

export const bindMonitor = async (context: AppContext) => {
  const { logger } = context;
  const { requestContext, methodContext } = createLoggingContext(bindMonitor.name);
  try {
    logger.debug('Bind monitor polling loop start', requestContext, methodContext);
    await updateMessages(context);
    await updateQueues(context);
    await updateHubSpokeMeta(context);
    await updateProtocolUpdateLogs(context);
    await updateMessageStatus(context);
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
