import {
  createLoggingContext,
  jsonifyError,
  Logger,
  EverclearError,
  RelayerApiPostTaskRequestParams,
  RelayerApiPostTaskResponse,
  RelayerTaskStatus,
  RequestContext,
} from '@chimera-monorepo/utils';
import { ChainReader } from '@chimera-monorepo/chainservice';
import { constants } from 'ethers';
import interval from 'interval-promise';

import {
  RelayerSendFailed,
  TransactionHashTimeout,
  UnableToGetTaskStatus,
  UnableToGetTransactionHash,
} from '../errors';
import { axiosGet, axiosPost } from '../mockable';

import { url } from '.';

export const everclearRelayerSend = async (
  chainId: number,
  domain: string,
  destinationAddress: string,
  encodedData: string,
  value: string,
  apiKey: string,
  chainReader: ChainReader,
  logger: Logger,
  _requestContext?: RequestContext,
): Promise<string> => {
  const { requestContext, methodContext } = createLoggingContext(everclearRelayerSend.name, _requestContext);
  let output;
  const params: RelayerApiPostTaskRequestParams = {
    apiKey,
    data: encodedData,
    fee: { amount: value, chain: chainId, token: constants.AddressZero },
    to: destinationAddress,
  };

  // Validate the call will succeed on chain.
  const relayerAddress = await getRelayerAddress();

  logger.debug('Getting gas estimate', requestContext, methodContext, {
    chainId,
    to: destinationAddress,
    data: encodedData,
    from: relayerAddress,
    fee: params.fee,
    value,
  });

  // const gas = await chainReader.getGasEstimateWithRevertCode({
  //   domain: +domain,
  //   to: destinationAddress,
  //   data: encodedData,
  //   from: relayerAddress,
  //   value,
  // });
  // TODO: Remove this line once chainReader issue is resolved
  const gas = 100000000000000;

  logger.info('Sending tx to Everclear relayer', requestContext, methodContext, {
    relayer: relayerAddress,
    everclear: destinationAddress,
    domain,
    gas: gas.toString(),
  });

  try {
    const res = await axiosPost<RelayerApiPostTaskResponse>(`${url}/relays/${chainId}`, params);
    logger.info('Sent tx to Everclear relayer', requestContext, methodContext, {
      relayer: relayerAddress,
      everclear: destinationAddress,
      domain,
      response: res.data,
    });
    output = res.data?.taskId;
  } catch (error: unknown) {
    throw new RelayerSendFailed({ error: jsonifyError(error as Error) });
  }
  return output;
};

export const getRelayerAddress = async (): Promise<string> => {
  try {
    const res = await axiosGet(`${url}/address`);
    return res.data;
  } catch (error: unknown) {
    throw new RelayerSendFailed({ error: jsonifyError(error as Error) });
  }
};

/**
 * Gets the task status for a given taskId from gelato api
 * @param taskId - The task Id we want to get the status for
 * @returns - RelayerTaskStatus
 */
export const getTaskStatus = async (taskId: string): Promise<RelayerTaskStatus> => {
  try {
    const apiEndpoint = `${url}/tasks/status/${taskId}`;
    const res = await axiosGet(apiEndpoint);
    return res.data.taskState ?? RelayerTaskStatus.NotFound;
  } catch (error: unknown) {
    throw new UnableToGetTaskStatus(taskId, { err: jsonifyError(error as Error) });
  }
};

export const waitForTaskCompletion = async (
  taskId: string,
  logger: Logger,
  _requestContext: RequestContext,
  _timeout = 600_000,
  _pollInterval = 5_000,
): Promise<RelayerTaskStatus> => {
  const { requestContext, methodContext } = createLoggingContext(waitForTaskCompletion.name, _requestContext);
  let taskStatus: RelayerTaskStatus | undefined;
  const startTime = Date.now();
  await new Promise((res) => {
    interval(async (_, stop) => {
      if (Date.now() - startTime > _timeout) {
        stop();
        res(undefined);
      }
      try {
        taskStatus = await getTaskStatus(taskId);
        logger.debug('Task status from everclear relayer', requestContext, methodContext, { taskStatus, taskId });
        const finalTaskStatuses = [
          RelayerTaskStatus.ExecSuccess,
          RelayerTaskStatus.ExecReverted,
          RelayerTaskStatus.Cancelled,
          RelayerTaskStatus.Blacklisted,
        ];
        if (finalTaskStatuses.includes(taskStatus)) {
          logger.debug('Received finalized task status', requestContext, methodContext, { taskStatus, taskId });
          stop();
          res(undefined);
        }
      } catch (error: unknown) {
        logger.error(
          'Error getting everclear task status, waiting for next loop',
          requestContext,
          methodContext,
          jsonifyError(error as EverclearError),
        );
      }
    }, _pollInterval);
  });

  if (!taskStatus) {
    throw new TransactionHashTimeout(taskId);
  }

  return taskStatus;
};

/**
 * Gets the transactionHash for a given taskId from gelato api
 * @param taskId - The task Id we want to get the status for
 * @returns - transactionHash
 */
export const getTransactionHash = async (taskId: string): Promise<string> => {
  let result;
  try {
    const apiEndpoint = `${url}/tasks/status/${taskId}`;
    const res = await axiosGet(apiEndpoint);
    result = res.data.data[0]?.transactionHash;
  } catch (error: unknown) {
    throw new UnableToGetTransactionHash(taskId, { err: jsonifyError(error as Error) });
  }

  return result;
};
