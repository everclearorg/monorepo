import {
  createLoggingContext,
  jsonifyError,
  Logger,
  EverclearError,
  RelayerTaskStatus,
  RelayerType,
  RequestContext,
} from '@chimera-monorepo/utils';
import { ChainReader, TransactionReverted } from '@chimera-monorepo/chainservice';

import { setupRelayer as _setupGelatoRelayer } from './gelato';
import { setupRelayer as _setupEverclearRelayer } from './everclear';
import { RelayerSendFailed } from './errors';

export type Relayer = {
  getRelayerAddress: (chainId: number) => Promise<string>;
  send: (
    chainId: number,
    domain: string,
    destinationAddress: string,
    encodedData: string,
    value: string,
    gelatoApiKey: string,
    chainReader: ChainReader,
    logger: Logger,
    _requestContext?: RequestContext,
  ) => Promise<string>;
  getTaskStatus: (taskId: string) => Promise<RelayerTaskStatus>;
  waitForTaskCompletion: (
    taskId: string,
    logger: Logger,
    _requestContext: RequestContext,
    _timeout?: number,
    _pollInterval?: number,
  ) => Promise<RelayerTaskStatus>;
};

export const setupGelatoRelayer = _setupGelatoRelayer;
export const setupEverclearRelayer = _setupEverclearRelayer;

export const sendWithRelayerWithBackup = async (
  chainId: number,
  domain: string,
  destinationAddress: string,
  data: string,
  value: string,
  relayers: { instance: Relayer; apiKey: string; type: RelayerType }[],
  chainReader: ChainReader,
  logger: Logger,
  _requestContext: RequestContext,
): Promise<{ taskId: string; relayerType: RelayerType }> => {
  const { methodContext, requestContext } = createLoggingContext(sendWithRelayerWithBackup.name, _requestContext);

  let error_msg = '';
  for (const relayer of relayers) {
    logger.info(`Sending tx with ${relayer.type} relayer`, requestContext, methodContext, {
      chainId,
      domain,
      destinationAddress,
      data,
    });
    try {
      const taskId = await relayer.instance.send(
        chainId,
        domain,
        destinationAddress,
        data,
        value,
        relayer.apiKey,
        chainReader,
        logger,
        requestContext,
      );
      return { taskId, relayerType: relayer.type };
    } catch (err: unknown) {
      const jsonError = jsonifyError(err as EverclearError);
      error_msg = jsonError.context?.message ?? jsonError.message;
      logger.error(`Failed to send data with ${relayer.type}`, requestContext, methodContext, jsonError);

      if (jsonError.type == TransactionReverted.type) {
        // If relayer failed with tx reverted error, don't need to attempt another
        logger.info(
          `Tx will be reverted with ${error_msg} on chain, Skip other relayers`,
          requestContext,
          methodContext,
          jsonError,
        );
        break;
      }
    }
  }

  throw new RelayerSendFailed({
    requestContext,
    methodContext,
    message: error_msg,
    chainId,
    domain,
    data,
    destinationAddress,
    relayers: relayers.map((relayer) => relayer.type),
  });
};
