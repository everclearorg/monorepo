import { constants } from 'ethers';
import {
  RequestContext,
  createLoggingContext,
  RelayerApiPostTaskRequestParams,
  ajv,
  RelayerApiPostTaskRequestParamsSchema,
} from '@chimera-monorepo/utils';

import { getContext } from '../../make';
import { ChainNotSupported, ParamsInvalid, UnsupportedFeeToken } from '../errors/tasks';

/**
 * Creates a task based on passed-in params (assuming task doesn't already exist), and returns the taskId.
 * @param chain
 * @param params
 * @param _requestContext
 * @returns
 */
export const createTask = async (
  chain: number,
  params: RelayerApiPostTaskRequestParams,
  _requestContext: RequestContext,
): Promise<string> => {
  const {
    logger,
    adapters: { cache },
    config,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(createTask.name, _requestContext);
  logger.info('Method start', requestContext, methodContext, { chain, params });

  // Validate execute arguments.
  const validateInput = ajv.compile(RelayerApiPostTaskRequestParamsSchema);
  const validInput = validateInput(params);
  if (!validInput) {
    const msg = validateInput.errors?.map((err: any) => `${err.instancePath} - ${err.message}`).join(',');
    throw new ParamsInvalid({
      paramsError: msg,
      params,
    });
  }

  const { apiKey, ...sanitized } = params;

  const { data, fee, to } = sanitized;

  if (fee.token !== constants.AddressZero) {
    throw new UnsupportedFeeToken(fee.token, { chain, params: sanitized });
  }

  if (!Object.keys(config.chains).includes(chain.toString()) && config.hub.domain != chain.toString()) {
    throw new ChainNotSupported(chain, { supported: Object.keys(config.chains) });
  }

  const taskId: string = await cache.tasks.createTask({
    chain,
    to,
    data,
    fee,
  });
  logger.info('Created a new task.', requestContext, methodContext, { taskId });
  return taskId;
};
