import { createLoggingContext, getNtpTimeSeconds, Queue, QueueType } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { MissingThresholds, UnknownQueueType } from '../../errors';
import { dispatchMessageQueueViaRelayers } from './dispatchMessageQueueViaRelayers';

// Tron domain constants
const TRON_MAINNET_DOMAIN = '728126428';
const TRON_DOMAINS = [TRON_MAINNET_DOMAIN];

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
    config: { chains, thresholds, hub },
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(processMessageQueue.name);

  // Get the spoke domains
  const domains = Object.keys(chains);
  const spokes = domains.filter((d) => d !== hub.domain);

  // Filter to only process Tron domains
  const tronSpokes = spokes.filter((domain) => TRON_DOMAINS.includes(domain));

  logger.debug('Method start', requestContext, methodContext, {
    type,
    allSpokes: spokes,
    tronSpokes,
    domains,
    hubDomain: hub.domain,
  });

  // Throw if the type is not a message queue (i.e. deposit)
  if (type === 'DEPOSIT') {
    throw new UnknownQueueType(type, { details: 'Deposit queues are not message queues.' });
  }

  // Exit early if no Tron domains are configured
  if (tronSpokes.length === 0) {
    logger.info('No Tron domains configured, skipping message queue processing', requestContext, methodContext, {
      type,
      configuredDomains: spokes,
      tronDomains: TRON_DOMAINS,
    });
    return;
  }

  logger.info('Processing message queues for Tron domains only', requestContext, methodContext, {
    type,
    tronSpokes,
    totalConfiguredSpokes: spokes.length,
  });

  // Use database queries for all queue types, filtering to Tron domains only
  const queues = await database.getMessageQueues(type, tronSpokes);
  const queueContents = await database.getMessageQueueContents(type, tronSpokes);

  logger.info('Retrieved queue data from database', requestContext, methodContext, {
    type,
    queuesCount: queues.length,
    queueContentsSize: queueContents.size,
    tronDomains: tronSpokes,
  });

  // Determine the message queues to dispatch:
  // - If message queue is full, dispatch.
  // - If the oldest message in the queue is older than the max age, dispatch.
  const toDispatch = queues.filter((queue: Queue) => {
    const { size, lastProcessed } = queue;
    const age = getNtpTimeSeconds() - (lastProcessed ?? 0);
    const { maxAge, size: maxSize } = thresholds[queue.domain] ?? {};

    if (maxAge == undefined && maxSize == undefined) {
      throw new MissingThresholds(type, queue.domain, thresholds);
    }

    const shouldDispatch = size >= maxSize || (age >= maxAge && size > 0);

    logger.debug('Dispatch decision for queue', requestContext, methodContext, {
      domain: queue.domain,
      size,
      maxSize,
      age,
      maxAge,
      shouldDispatch,
      reason: shouldDispatch ? (size >= maxSize ? 'size threshold' : 'age threshold') : 'no dispatch needed',
    });

    return shouldDispatch;
  });

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
      tronDomains: tronSpokes,
    });
    logger.debug('Method complete', requestContext, methodContext);
    return;
  }

  logger.info('Dispatching queues', requestContext, methodContext, {
    type,
    queue: toLog ?? [],
    tronDomains: tronSpokes,
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
        isTronDomain: TRON_DOMAINS.includes(queue.domain),
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
    tronDomains: tronSpokes,
    errors: rejected.map((value: unknown) => (value as PromiseRejectedResult).reason),
  });
};
