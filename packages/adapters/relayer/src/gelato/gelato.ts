import {
  createLoggingContext,
  Logger,
  RequestContext,
  jsonifyError,
  EverclearError,
  RelayerTaskStatus,
  getGelatoRelayerAddress,
  chainIdToDomain,
} from '@chimera-monorepo/utils';
import { StatusCode } from '@gelatocloud/gasless';
import interval from 'interval-promise';

import {
  RelayerSendFailed,
  TransactionHashTimeout,
  UnableToGetGelatoSupportedChains,
  UnableToGetTaskStatus,
  UnableToGetTransactionHash,
} from '../errors';

import { ChainReader } from '@chimera-monorepo/chainservice';
import { gelatoRelay } from '.';

/// MARK - Gelato Gasless SDK
/// Docs: https://docs.gelato.cloud/gasless-with-relay

export const isChainSupportedByGelato = async (chainId: number): Promise<boolean> => {
  try {
    const capabilities = await gelatoRelay.getCapabilities();
    return chainId in capabilities;
  } catch (error: unknown) {
    throw new UnableToGetGelatoSupportedChains(chainId, { err: jsonifyError(error as Error) });
  }
};

export const getGelatoRelayChains = async (): Promise<string[]> => {
  try {
    const capabilities = await gelatoRelay.getCapabilities();
    return Object.keys(capabilities);
  } catch (error: unknown) {
    throw new UnableToGetGelatoSupportedChains(0, { err: jsonifyError(error as Error) });
  }
};

/**
 * Gets the task status for a given taskId from gelato api
 * @param taskId - The task Id we want to get the status for
 * @returns - RelayerTaskStatus
 */
export const getTaskStatus = async (taskId: string): Promise<RelayerTaskStatus> => {
  try {
    const result = await gelatoRelay.getStatus({ id: taskId });
    switch (result.status) {
      case StatusCode.Pending: {
        return RelayerTaskStatus.CheckPending;
      }
      case StatusCode.Submitted: {
        return RelayerTaskStatus.ExecPending;
      }
      case StatusCode.Success: {
        return RelayerTaskStatus.ExecSuccess;
      }
      case StatusCode.Rejected: {
        return RelayerTaskStatus.Cancelled;
      }
      case StatusCode.Reverted: {
        return RelayerTaskStatus.ExecReverted;
      }
      default: {
        return RelayerTaskStatus.NotFound;
      }
    }
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
        logger.debug('Task status from Gelato relayer', requestContext, methodContext, { taskStatus, taskId });
        const finalTaskStatuses = [
          RelayerTaskStatus.ExecSuccess,
          RelayerTaskStatus.ExecReverted,
          RelayerTaskStatus.Cancelled,
          RelayerTaskStatus.Blacklisted,
        ];

        if (finalTaskStatuses.includes(taskStatus)) {
          stop();
          res(undefined);
        }
      } catch (error: unknown) {
        logger.error(
          'Error getting gelato task status, waiting for next loop',
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
export const getTransactionHash = async (taskId: string): Promise<string | undefined> => {
  try {
    const result = await gelatoRelay.getStatus({ id: taskId });
    if (result.status === StatusCode.Success || result.status === StatusCode.Reverted) {
      return result.receipt?.transactionHash;
    }
    if (result.status === StatusCode.Submitted) {
      return result.hash;
    }
    return undefined;
  } catch (error: unknown) {
    throw new UnableToGetTransactionHash(taskId, { err: jsonifyError(error as Error) });
  }
};

export const gelatoSDKSend = async (chainId: number, to: string, data: string): Promise<string> => {
  try {
    const taskId = await gelatoRelay.sendTransaction({
      chainId,
      to: to as `0x${string}`,
      data: data as `0x${string}`,
    });
    return taskId;
  } catch (error: unknown) {
    throw new RelayerSendFailed({
      error: jsonifyError(error as Error),
      chainId,
      to,
      data,
    });
  }
};

export const getRelayerAddress = async (_chainId: number): Promise<string> => {
  const domain = chainIdToDomain(_chainId).toString();
  const address = getGelatoRelayerAddress(domain);
  return Promise.resolve(address);
};

export const send = async (
  chainId: number,
  domain: string,
  destinationAddress: string,
  encodedData: string,
  value: string,
  funcSig: string,
  _gelatoApiKey: string,
  chainReader: ChainReader,
  logger: Logger,
  _requestContext?: RequestContext,
): Promise<string> => {
  const { requestContext, methodContext } = createLoggingContext(send.name, _requestContext);

  const relayerAddress = await getRelayerAddress(chainId);

  logger.info('Gelato relayer address resolved', requestContext, methodContext, {
    chainId,
    domain,
    relayerAddress,
    envOverride: process.env.GELATO_RELAYER_ADDRESS || 'none',
    funcSig,
  });

  logger.debug('Getting gas estimate', requestContext, methodContext, {
    chainId,
    to: destinationAddress,
    data: encodedData,
    from: relayerAddress,
    value,
  });

  const gas = await chainReader.getGasEstimateWithRevertCode({
    domain: +domain,
    to: destinationAddress,
    data: encodedData,
    from: relayerAddress,
    value: '0',
    funcSig,
  });

  logger.info('Gas estimate passed, sending to Gelato', requestContext, methodContext, {
    relayer: relayerAddress,
    everclear: destinationAddress,
    domain,
    chainId,
    gas: gas.toString(),
    funcSig,
  });

  const taskId = await gelatoSDKSend(chainId, destinationAddress, encodedData);

  if (!taskId) {
    throw new RelayerSendFailed({ taskId });
  } else {
    logger.info('Gelato task submitted', requestContext, methodContext, {
      taskId,
      chainId,
      domain,
      relayerAddress,
      to: destinationAddress,
      funcSig,
    });
    return taskId;
  }
};
