import { createLoggingContext, getNtpTimeSeconds, Queue, QueueType } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { MissingThresholds, UnknownQueueType } from '../../errors';
import { dispatchMessageQueueViaRelayers } from './dispatchMessageQueueViaRelayers';

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
  logger.debug('Method start', requestContext, methodContext, { type, spokes, domains, hubDomain: hub.domain });

  // Throw if the type is not a message queue (i.e. deposit)
  if (type === 'DEPOSIT') {
    throw new UnknownQueueType(type, { details: 'Deposit queues are not message queues.' });
  }

  // Get the message queue sizes of all spokes
  const queues = await database.getMessageQueues(type, spokes);

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
    return size >= maxSize || (age >= maxAge && size > 0);
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
    });
    logger.debug('Method complete', requestContext, methodContext);
    return;
  }
  logger.info('Dispatching queues', requestContext, methodContext, {
    type,
    queue: toLog ?? [],
  });

  // Each message queue requires different dispatch inputs:
  // - intent: Full intent object
  // - fill: IntentId, Solver
  // - settlement: Settlement object
  const queueContents = await database.getMessageQueueContents(type, spokes);

  // Dispatch the message queues via relayers
  const results = await Promise.allSettled(
    toDispatch.map(async (queue) => {
      // Get the contents associated with that domain
      const domainQueue = queueContents.get(queue.domain) ?? [];
      const sorted = domainQueue.sort((a, b) => a.queueIdx! - b.queueIdx!);
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
    errors: rejected.map((value: unknown) => (value as PromiseRejectedResult).reason),
  });
};
