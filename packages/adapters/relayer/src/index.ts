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
    funcSig: string,
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
  isChainSupported: (chainId: number) => Promise<boolean>;
};

export const setupGelatoRelayer = _setupGelatoRelayer;
export const setupEverclearRelayer = _setupEverclearRelayer;

export const sendWithRelayerWithBackup = async (
  chainId: number,
  domain: string,
  destinationAddress: string,
  data: string,
  value: string,
  funcSig: string,
  relayers: { instance: Relayer; apiKey: string; type: RelayerType }[],
  chainReader: ChainReader,
  logger: Logger,
  _requestContext: RequestContext,
): Promise<{ taskId: string; relayerType: RelayerType }> => {
  const { methodContext, requestContext } = createLoggingContext(sendWithRelayerWithBackup.name, _requestContext);

  let error_msg = '';
  const relayerTypes = relayers.map((r) => r.type);
  logger.info('Attempting to send with relayer(s)', requestContext, methodContext, {
    chainId,
    domain,
    funcSig,
    destinationAddress,
    relayerCount: relayers.length,
    relayerTypes,
  });

  for (let idx = 0; idx < relayers.length; idx++) {
    const relayer = relayers[idx];
    const supported = await relayer.instance.isChainSupported(chainId);
    if (!supported) {
      error_msg = `Chain ${chainId} not supported by ${relayer.type}`;
      logger.warn(`Relayer ${relayer.type} does not support chain`, requestContext, methodContext, {
        chainId,
        domain,
        relayerIndex: idx,
        totalRelayers: relayers.length,
      });
      continue;
    }

    const relayerAddress = await relayer.instance.getRelayerAddress(chainId);
    logger.info(`Sending tx with ${relayer.type} relayer`, requestContext, methodContext, {
      chainId,
      domain,
      destinationAddress,
      relayerAddress,
      relayerIndex: idx,
      totalRelayers: relayers.length,
      funcSig,
    });
    try {
      const taskId = await relayer.instance.send(
        chainId,
        domain,
        destinationAddress,
        data,
        value,
        funcSig,
        relayer.apiKey,
        chainReader,
        logger,
        requestContext,
      );
      logger.info(`Successfully submitted via ${relayer.type}`, requestContext, methodContext, {
        taskId,
        chainId,
        domain,
        relayerAddress,
        funcSig,
      });
      return { taskId, relayerType: relayer.type };
    } catch (err: unknown) {
      const jsonError = jsonifyError(err as EverclearError);
      error_msg = jsonError.context?.message ?? jsonError.message;
      logger.error(`Failed to send data with ${relayer.type}`, requestContext, methodContext, jsonError, {
        chainId,
        domain,
        relayerAddress,
        relayerIndex: idx,
        totalRelayers: relayers.length,
        funcSig,
      });

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

      logger.info(`Will try next relayer (${idx + 1}/${relayers.length} attempted)`, requestContext, methodContext, {
        failedRelayer: relayer.type,
        remainingRelayers: relayerTypes.slice(idx + 1),
      });
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
