import { createLoggingContext, jsonifyError } from '@chimera-monorepo/utils';
import { axiosGet } from '../mockable';
import { getContext } from '../context';

/**
 * Check whether the agents are operational or not
 */
export const checkAgents = async () => {
  const { config, logger } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkAgents.name);
  logger.info('Checking off-chain agents', requestContext, methodContext);

  const status: Record<string, boolean> = {};
  try {
    const agentNames = Object.keys(config.agents);
    await Promise.all(
      agentNames.map(async (agent) => {
        try {
          const res = await axiosGet(config.agents[agent]);
          if (res.status == 200) {
            status[agent] = true;
          } else {
            status[agent] = false;
          }
        } catch (e) {
          logger.error(`Agent ${agent} is down`, requestContext, methodContext, jsonifyError(e as Error));
          throw e;
        }
      }),
    );
  } catch (err: unknown) {
    logger.error('Checking off-chain agents failed', requestContext, methodContext, jsonifyError(err as Error));
  }

  logger.info('Agent status', requestContext, methodContext, status);
};
