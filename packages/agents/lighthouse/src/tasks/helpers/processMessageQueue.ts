/* eslint-disable @typescript-eslint/no-explicit-any */
import { createLoggingContext, getNtpTimeSeconds, Queue, QueueType } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { MissingThresholds, UnknownQueueType } from '../../errors';
import { dispatchMessageQueueViaRelayers } from './dispatchMessageQueueViaRelayers';
import { Interface } from 'ethers/lib/utils';

interface OnchainQueueState {
  first: number;
  last: number;
  size: number;
}

/**
 * Check onchain queue state to prevent duplicate processing
 * @param domain The domain to check
 * @param queueType The type of queue (INTENT, FILL, SETTLEMENT)
 * @param everclearAddress The contract address
 * @param abi The contract ABI
 * @returns Onchain queue state or null if check fails
 */
async function getOnchainQueueState(
  domain: string,
  queueType: QueueType,
  everclearAddress: string,
  abi: any,
): Promise<OnchainQueueState | null> {
  const {
    logger,
    adapters: { chainservice },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext('getOnchainQueueState');

  try {
    const iface = new Interface(abi);

    // Determine which queue to check based on a queue type
    let queueMethodName: string;
    let isSettlementQueue = false;
    switch (queueType) {
      case 'INTENT':
        queueMethodName = 'intentQueue';
        break;
      case 'FILL':
        queueMethodName = 'fillQueue';
        break;
      case 'SETTLEMENT':
        queueMethodName = 'settlements';
        isSettlementQueue = true;
        break;
      default:
        logger.warn('Unknown queue type for onchain check', requestContext, methodContext, {
          domain,
          queueType,
        });
        return null;
    }

    let queueData: string;
    if (isSettlementQueue) {
      queueData = iface.encodeFunctionData(queueMethodName, [parseInt(domain)]);
    } else {
      queueData = iface.encodeFunctionData(queueMethodName, []);
    }

    const result = await chainservice.readTx(
      {
        domain: parseInt(domain),
        to: everclearAddress,
        data: queueData,
        funcSig: iface.getFunction(queueMethodName).format(),
      },
      'latest',
    );

    // Decode the result (returns first, last)
    const decoded = iface.decodeFunctionResult(queueMethodName, result);
    const first = decoded[0];
    const last = decoded[1];
    const size = last >= first ? last - first + 1 : 0;

    logger.debug('Onchain queue state retrieved', requestContext, methodContext, {
      domain,
      queueType,
      first: first.toString(),
      last: last.toString(),
      size: size.toString(),
    });

    return { first, last, size };
  } catch (error) {
    logger.warn('Failed to check onchain queue state', requestContext, methodContext, {
      domain,
      queueType,
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

/**
 * A message queue holds references to all hyperlane messages pending dispatch onchain.
 *
 * There are three separate message queues:
 * 1 - Fill queue: Holds solver fill messages that are pending dispatch from spoke to the clearing chain.
 * 2 - Intent queue: Holds intent creation messages that are pending dispatch from spoke to the clearing chain.
 * 3 - Settlement queue: Holds settlements that are pending dispatch from clearing chain to the settlement domain (spokes).
 * @param type Queue Type (Intent, Settlement, Fill)
 */
export const processMessageQueue = async (type: QueueType) => {
  // Get the config
  const {
    logger,
    config: { chains, thresholds, hub, abis },
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(processMessageQueue.name);

  // Get the spoke domains
  const domains = Object.keys(chains);
  const spokes = domains.filter((d) => d !== hub.domain);

  logger.debug('Method start', requestContext, methodContext, {
    type,
    spokes,
    domains,
    hubDomain: hub.domain,
  });

  // Throw if the type is not a message queue (i.e. deposit)
  if (type === 'DEPOSIT') {
    throw new UnknownQueueType(type, { details: 'Deposit queues are not message queues.' });
  }

  logger.info('Processing message queues for all domains', requestContext, methodContext, {
    type,
    spokes,
    totalSpokes: spokes.length,
  });

  // Use database queries for all queue types, processing all spoke domains
  const queues = await database.getMessageQueues(type, spokes);
  const queueContents = await database.getMessageQueueContents(type, spokes);

  logger.info('Retrieved queue data from database', requestContext, methodContext, {
    type,
    queuesCount: queues.length,
    queueContentsSize: queueContents.size,
    domains: spokes,
  });

  // Determine the message queues to dispatch:
  // - If message queue is full, dispatch.
  // - If the oldest message in the queue is older than the max age, dispatch.
  // - Skip if onchain state differs from the database state (prevents duplicate processing)
  const toDispatch: Queue[] = [];

  for (const queue of queues) {
    const { size, lastProcessed, domain } = queue;
    const age = getNtpTimeSeconds() - (lastProcessed ?? 0);
    const { maxAge, size: maxSize } = thresholds[domain] ?? {};

    if (maxAge == undefined && maxSize == undefined) {
      throw new MissingThresholds(type, domain, thresholds);
    }

    const shouldDispatch = size >= maxSize || (age >= maxAge && size > 0);

    logger.debug('Dispatch decision for queue', requestContext, methodContext, {
      domain,
      size,
      maxSize,
      age,
      maxAge,
      shouldDispatch,
      reason: shouldDispatch ? (size >= maxSize ? 'size threshold' : 'age threshold') : 'no dispatch needed',
    });

    // If we should dispatch, check onchain state to prevent duplicate processing
    if (shouldDispatch) {
      const transactionDomain = type === 'SETTLEMENT' ? hub.domain : domain;
      const { everclear } =
        transactionDomain === hub.domain ? hub.deployments : chains[transactionDomain].deployments ?? {};

      if (everclear) {
        const abi = transactionDomain === hub.domain ? abis.hub.everclear : abis.spoke.everclear;

        // Check onchain queue state
        // For settlement queues, we need to check the hub domain, not the spoke domain
        const checkDomain = type === 'SETTLEMENT' ? hub.domain : domain;
        const onchainState = await getOnchainQueueState(checkDomain, type, everclear, abi);

        if (onchainState) {
          // Compare database size with onchain size
          const onchainSize = onchainState.size;

          logger.debug('Queue state comparison', requestContext, methodContext, {
            domain,
            queueType: type,
            dbSize: size,
            onchainSize: onchainSize.toString(),
            dbFirst: queue.first?.toString(),
            dbLast: queue.last?.toString(),
            onchainFirst: onchainState.first.toString(),
            onchainLast: onchainState.last.toString(),
          });

          // If onchain size is smaller than database size, the queue has been processed
          if (onchainSize !== size) {
            logger.info(
              'Skipping queue dispatch - onchain state indicates queue already processed',
              requestContext,
              methodContext,
              {
                domain,
                queueType: type,
                dbSize: size,
                onchainSize: onchainSize.toString(),
                reason: 'onchain_queue_already_processed',
              },
            );
            continue;
          }
        } else {
          logger.warn('Could not check onchain queue state, proceeding with dispatch', requestContext, methodContext, {
            domain,
            queueType: type,
            transactionDomain,
          });
        }
      } else {
        logger.warn('Missing contract address for onchain check', requestContext, methodContext, {
          domain,
          queueType: type,
          transactionDomain,
        });
      }

      // Add to the dispatch list if we reach here
      toDispatch.push(queue);
    }
  }

  const toLog = queues.map((queue: Queue) => {
    return {
      size: queue.size,
      age: getNtpTimeSeconds() - (queue.lastProcessed ?? 0),
      domain: queue.domain,
      lastProcessed: queue.lastProcessed,
    };
  });

  // Exit if no message queues to dispatch
  if (toDispatch.length === 0) {
    logger.info('No queues to dispatch', requestContext, methodContext, {
      type,
      queue: toLog,
      thresholds,
      domains: spokes,
    });
    logger.debug('Method complete', requestContext, methodContext);
    return;
  }

  logger.info('Dispatching queues', requestContext, methodContext, {
    type,
    queue: toLog ?? [],
    domains: spokes,
  });

  // Dispatch the message queues via relayers
  const results = await Promise.allSettled(
    toDispatch.map(async (queue) => {
      // Get the contents associated with that domain
      const domainQueue = queueContents.get(queue.domain) ?? [];
      const sorted = domainQueue.sort((a, b) => {
        const aQueueIdx = 'queueIdx' in a ? (a as { queueIdx: number }).queueIdx : 0;
        const bQueueIdx = 'queueIdx' in b ? (b as { queueIdx: number }).queueIdx : 0;
        return aQueueIdx - bQueueIdx;
      });

      logger.info('About to dispatch queue contents', requestContext, methodContext, {
        type,
        domain: queue.domain,
        queueSize: domainQueue.length,
        sortedItemsCount: sorted.length,
      });

      // Get the associated contents
      const taskIds = await dispatchMessageQueueViaRelayers(type, queue, sorted, requestContext);
      logger.info('Submitted relayer tasks', requestContext, methodContext, { type, taskIds, queue });
    }),
  );

  const successful = results.filter((r) => r.status === 'fulfilled');
  const rejected = results.filter((r) => r.status === 'rejected');

  logger.info('Dispatched queues', requestContext, methodContext, {
    type,
    attempted: toDispatch.length,
    successful: successful.length,
    rejected: rejected.length,
    domains: spokes,
    errors: rejected.map((value: unknown) => (value as PromiseRejectedResult).reason),
  });
};
