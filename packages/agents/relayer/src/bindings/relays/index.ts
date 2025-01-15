import { BigNumber } from 'ethers';
import {
  chainIdToDomain,
  createLoggingContext,
  createRequestContext,
  jsonifyError,
  RelayerTaskStatus,
  sendHeartbeat,
  getNtpTimeSeconds,
} from '@chimera-monorepo/utils';
import interval from 'interval-promise';
import { CachedTaskData } from '@chimera-monorepo/adapters-cache';
import { FastifyInstance, FastifyReply } from 'fastify';

import { getContext } from '../../make';
import { WriteTransaction } from '@chimera-monorepo/chainservice';
import { getFastifyInstance } from '../../mockable';

export const MIN_GAS_LIMIT = BigNumber.from(4_000_000);
export const MIN_HEART_INTERVAL_SECONDS = 60; // 1min
let cachedHeartbeatSent = 0;

export const bindRelays = async () => {
  const { config, logger } = getContext();
  const pollInterval = config.poller.interval;
  interval(async (_, stop) => {
    if (config.mode.cleanup) {
      stop();
    } else {
      await pollCache();
      if (config.healthUrls.poller && getNtpTimeSeconds() - cachedHeartbeatSent > MIN_HEART_INTERVAL_SECONDS) {
        await sendHeartbeat(config.healthUrls.poller, logger);
        cachedHeartbeatSent = getNtpTimeSeconds();
      }
    }
  }, pollInterval);
};

export const pollCache = async () => {
  const {
    adapters: { cache, wallet, chainservice },
    config,
    logger,
  } = getContext();
  const { requestContext: _requestContext, methodContext } = createLoggingContext(pollCache.name);

  // Retrieve all pending tasks.
  const pending = await cache.tasks.getPending(0, 100);
  logger.debug('Retrieved pending tasks', _requestContext, methodContext, { pending: pending.length });
  if (pending.length === 0) {
    return;
  }

  // Organize pending tasks by chain property.
  const tasksByChain: { [chainId: number]: (CachedTaskData & { id: string })[] } = {};
  for (const taskId of pending) {
    const requestContext = createRequestContext(pollCache.name, taskId);
    const task: CachedTaskData | undefined = await cache.tasks.getTask(taskId);
    if (!task) {
      // Sanity: task should exist.
      logger.warn('Task entry not found for task ID', requestContext, methodContext, { taskId });
      continue;
    }
    const { chain } = task;
    if (!tasksByChain[chain]) {
      tasksByChain[chain] = [];
    }
    tasksByChain[chain].push({
      ...task,
      id: taskId,
    });
  }

  // TODO: Promise.all with map for each chain.
  for (const chainIdKey of Object.keys(tasksByChain)) {
    // Set up context for this chain: get domain, provider, and connect a signer.
    const chain = Number(chainIdKey);
    const domain = chainIdToDomain(chain)!;

    const rpcProvider = chainservice.getProvider(domain).leadProvider;
    if (!rpcProvider) {
      logger.debug('Bad rpcs', _requestContext, methodContext, { domain, providers: config.chains[domain].providers });
      continue;
    }

    for (const task of tasksByChain[chain]) {
      // TODO: Sanity check: should have enough balance to pay for gas on the specified chain.
      const taskId = task.id;
      const requestContext = createRequestContext(pollCache.name, taskId);
      const status = await cache.tasks.getStatus(taskId);

      if (status !== RelayerTaskStatus.ExecPending) {
        // Sanity: task should be pending.
        // Possible in the event of a race while updating the cache.
        logger.debug('Task status was not pending task ID', requestContext, methodContext, { taskId });
        continue;
      }

      const { data, to, fee } = task;
      const transaction: WriteTransaction = {
        domain,
        to,
        data,
        from: await wallet.getAddress(),
        value: fee.amount ?? '0',
      };
      logger.debug(`Attempting to submit transaction`, requestContext, methodContext, {
        transaction,
        taskId,
        domain,
      });

      // TODO: Queue up fee claiming for this transfer after this (assuming transaction is successful)!
      try {
        // Estimate gas limit.
        // TODO: For `proveAndProcess` calls, we should be providing:
        // gas limit = expected gas cost + PROCESS_GAS + RESERVE_GAS
        // We need to read those values from on-chain IFF this is a `proveAndProcess` call.
        const gasPrice = await chainservice.getGasPrice(domain, requestContext);
        logger.debug(`Got the gasPrice for domain: ${domain}`, requestContext, methodContext, {
          gasPrice: gasPrice.toString(),
        });

        let gasLimit = await chainservice.getGasEstimate(+domain, transaction);
        logger.debug(`Got the gasLimit for domain: ${domain}`, requestContext, methodContext, {
          gasLimit: gasLimit.toString(),
        });
        gasLimit = BigNumber.from(gasLimit).lt(MIN_GAS_LIMIT) ? MIN_GAS_LIMIT.toString() : gasLimit;

        let bumpedGasPrice = BigNumber.from(gasPrice).mul(130).div(100);
        const bumpedGasLimit = BigNumber.from(gasLimit).mul(120).div(100);

        const minGasPrice = config.chains[domain]?.minGasPrice;
        if (minGasPrice) {
          bumpedGasPrice = bumpedGasPrice.lt(minGasPrice) ? BigNumber.from(minGasPrice) : bumpedGasPrice;
        }

        // Get Nonce
        const nonce = await rpcProvider.getTransactionCount(await wallet.getAddress(), 'latest');

        // Execute the calldata.
        logger.info('Sending tx', requestContext, methodContext, {
          from: wallet.address,
          chain,
          taskId,
          data,
          gasPrice: bumpedGasPrice.toString(),
          gasLimit: bumpedGasLimit.toString(),
          nonce,
        });

        const receipt = await chainservice.sendTx(
          {
            ...transaction,
            gasLimit: bumpedGasLimit.toString(),
            gasPrice: bumpedGasPrice.toString(),
          },
          requestContext,
        );
        await cache.tasks.setHash(taskId, receipt.transactionHash);
        logger.info('Transaction confirmed.', requestContext, methodContext, {
          chain,
          taskId,
          hash: receipt.transactionHash,
        });
      } catch (error: unknown) {
        // Save the error to the cache for this transfer. If the error was not previously recorded, log it.
        await cache.tasks.setError(taskId, JSON.stringify(error));
        logger.error('Error executing task', requestContext, methodContext, jsonifyError(error as Error), {
          chain,
          taskId,
          data,
        });
      }
    }
  }
};

export const bindHealthServer = async (): Promise<FastifyInstance> => {
  const { config, logger } = getContext();

  const server = getFastifyInstance();

  server.get('/ping', (_, res) => api.get.ping(res));

  const address = await server.listen({ port: config.poller.port, host: config.poller.host });
  logger.info(`Server listening at ${address}`);
  return server;
};

export const api = {
  get: {
    ping: async (res: FastifyReply) => {
      return res.status(200).send('pong\n');
    },
  },
};
