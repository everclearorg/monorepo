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

/**
 * Encodes a sponsoredCallV2 call to the Gelato relay contract.
 * This wraps the inner calldata so that the relay contract forwards the call,
 * making msg.sender at the target = relay contract address (e.g. 0xceA8...).
 *
 * sponsoredCallV2(address _target, bytes _data, bytes32 _correlationId, bytes32 _feeToken, bytes32 _oneBalanceChainId)
 * selector: 0xad718d2a
 */
export const encodeSponsoredCallV2 = (target: string, innerData: string): string => {
  const selector = '0xad718d2a';
  const targetPadded = target.toLowerCase().replace('0x', '').padStart(64, '0');
  const zeroBytes32 = '0'.repeat(64);

  // ABI encode: (address, bytes, bytes32, bytes32, bytes32)
  // Offsets: address at 0x00, bytes pointer at 0x20, bytes32s at 0x40/0x60/0x80
  // bytes is dynamic, so we use an offset pointer
  const dataWithout0x = innerData.replace('0x', '');
  const dataLength = (dataWithout0x.length / 2).toString(16).padStart(64, '0');

  // Pad data to 32-byte boundary
  const dataPadded = dataWithout0x + '0'.repeat((64 - (dataWithout0x.length % 64)) % 64);

  // Layout:
  // [0x00]  target (address, padded to 32 bytes)
  // [0x20]  offset to bytes _data (= 0xa0 = 160, after 5 slots of 32 bytes)
  // [0x40]  _correlationId (bytes32)
  // [0x60]  _feeToken (bytes32)
  // [0x80]  _oneBalanceChainId (bytes32)
  // [0xa0]  length of bytes _data
  // [0xc0+] bytes _data (padded)
  const dataOffset = 'a0'.padStart(64, '0'); // 5 * 32 = 160 = 0xa0

  return (
    selector +
    targetPadded +
    dataOffset +
    zeroBytes32 + // correlationId
    zeroBytes32 + // feeToken
    zeroBytes32 + // oneBalanceChainId
    dataLength +
    dataPadded
  );
};

export const gelatoSDKSend = async (
  chainId: number,
  to: string,
  data: string,
  relayContractAddress?: string,
): Promise<string> => {
  try {
    // If a relay contract address is provided, wrap the call through sponsoredCallV2.
    // This makes msg.sender at the target = relay contract address, which is required
    // for spoke contracts that check _relayer == msg.sender.
    const actualTo = relayContractAddress || to;
    const actualData = relayContractAddress ? encodeSponsoredCallV2(to, data) : data;

    const taskId = await gelatoRelay.sendTransaction({
      chainId,
      to: actualTo as `0x${string}`,
      data: actualData as `0x${string}`,
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
  return Promise.resolve(getGelatoRelayerAddress(chainIdToDomain(_chainId).toString()));
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

  logger.info('Sending via Gelato sponsoredCallV2', requestContext, methodContext, {
    relayContract: relayerAddress,
    target: destinationAddress,
    domain,
    chainId,
    gas: gas.toString(),
    funcSig,
  });

  // Send through the relay contract's sponsoredCallV2 so that msg.sender
  // at the target contract = relay contract address (required for spoke
  // contracts that check _relayer == msg.sender).
  const taskId = await gelatoSDKSend(chainId, destinationAddress, encodedData, relayerAddress);

  if (!taskId) {
    throw new RelayerSendFailed({ taskId });
  } else {
    logger.info('Gelato task submitted via sponsoredCallV2', requestContext, methodContext, {
      taskId,
      chainId,
      domain,
      relayContract: relayerAddress,
      target: destinationAddress,
      funcSig,
    });
    return taskId;
  }
};
