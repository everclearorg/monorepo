import {
  createLoggingContext,
  getNtpTimeSeconds,
  Queue,
  QueueType,
  OriginIntent,
  TIntentStatus,
} from '@chimera-monorepo/utils';
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

  let queues: Queue[];
  let queueContents: Map<string, unknown[]>;

  // HARDCODED TEST DATA FOR INTENT TYPE
  if (type === 'INTENT') {
    logger.info('🧪 USING HARDCODED TEST DATA FOR INTENT PROCESSING', requestContext, methodContext);

    // Hardcoded queue data based on parsed values - TESTING WITH 1 INTENT ONLY
    queues = [
      {
        id: '728126428-0x494e54454e54',
        domain: '728126428',
        lastProcessed: 0, // Old timestamp to trigger age-based dispatch
        size: 1, // Testing with 1 intent only to avoid queue validation issues
        first: 1,
        last: 1,
        type: 'INTENT' as QueueType,
      },
    ];

    // Hardcoded origin intents based on parsed data from actual transactions
    const hardcodedOriginIntent1: OriginIntent = {
      id: '0x8a4dc5747b9c1ba052d83ce34c859f79ea09e0739a965a6f8e4fe15253e18f87',
      queueIdx: 1,
      messageId: undefined, // Not yet dispatched
      status: TIntentStatus.Added,
      receiver: '0x000000000000000000000000c0d710e4afc4b2e675300895124f220951f6ba18',
      inputAsset: '0x000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c',
      outputAsset: '0x000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c',
      amount: '1000000', // 1 USDT (6 decimals)
      maxFee: 10000,
      ttl: 0,
      destinations: ['8453'], // Base chain
      origin: '728126428',
      nonce: 1,
      transactionHash: '0x10b3a32ee218106b6c20029656f832d35d007fb2e050dbb97169779bb67b3a9f',
      timestamp: 1749772254,
      blockNumber: 73038616,
      txOrigin: '0x000000000000000000000000c0d710e4afc4b2e675300895124f220951f6ba18',
      txNonce: 0,
      initiator: '0x000000000000000000000000c0d710e4afc4b2e675300895124f220951f6ba18',
      data: '0x',
      gasLimit: '0',
      gasPrice: '1',
    };

    const hardcodedOriginIntent2: OriginIntent = {
      id: '0x3c1225f120511439d20ca4ceaebe302ef0eb27060806a457fd9562cee60888c4',
      queueIdx: 2,
      messageId: undefined, // Not yet dispatched
      status: TIntentStatus.Added,
      receiver: '0x000000000000000000000000c0d710e4afc4b2e675300895124f220951f6ba18',
      inputAsset: '0x000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c',
      outputAsset: '0x000000000000000000000000a614f803b6fd780986a42c78ec9c7f77e6ded13c',
      amount: '1000000', // 1 USDT (6 decimals)
      maxFee: 10000,
      ttl: 0,
      destinations: ['8453'], // Base chain
      origin: '728126428',
      nonce: 1,
      transactionHash: '0xc90cbcb4b9831158670d468fe0a11dfa9ea85a92baec658dfd276f94407ed95b',
      timestamp: 1750477569,
      blockNumber: 73273648,
      txOrigin: '0x000000000000000000000000c0d710e4afc4b2e675300895124f220951f6ba18',
      txNonce: 0,
      initiator: '0x000000000000000000000000c0d710e4afc4b2e675300895124f220951f6ba18',
      data: '0x',
      gasLimit: '0',
      gasPrice: '1',
    };

    // Map domain to intent contents - TESTING WITH 1 INTENT ONLY
    queueContents = new Map();
    queueContents.set('728126428', [hardcodedOriginIntent1]); // Only process first intent

    logger.info('🧪 Hardcoded test data created', requestContext, methodContext, {
      queuesCount: queues.length,
      queueContentsSize: queueContents.size,
      intent1Id: hardcodedOriginIntent1.id,
      intent2Id: hardcodedOriginIntent2.id,
      domain: '728126428',
      totalIntents: 2,
    });
  } else {
    // Normal database calls for non-INTENT types
    queues = await database.getMessageQueues(type, spokes);
    queueContents = await database.getMessageQueueContents(type, spokes);
  }

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

    // For testing, log dispatch decision
    if (type === 'INTENT') {
      logger.info('🧪 Dispatch decision for test queue', requestContext, methodContext, {
        domain: queue.domain,
        size,
        maxSize,
        age,
        maxAge,
        shouldDispatch,
        reason: shouldDispatch ? (size >= maxSize ? 'size threshold' : 'age threshold') : 'no dispatch needed',
      });
    }

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
    });
    logger.debug('Method complete', requestContext, methodContext);
    return;
  }
  logger.info('Dispatching queues', requestContext, methodContext, {
    type,
    queue: toLog ?? [],
  });

  // Dispatch the message queues via relayers
  const results = await Promise.allSettled(
    toDispatch.map(async (queue) => {
      // Get the contents associated with that domain
      const domainQueue = queueContents.get(queue.domain) ?? [];
      const sorted = domainQueue.sort((a, b) => (a as OriginIntent).queueIdx! - (b as OriginIntent).queueIdx!);

      // For testing, log what we're about to dispatch
      if (type === 'INTENT') {
        logger.info('🧪 About to dispatch test intents', requestContext, methodContext, {
          domain: queue.domain,
          queueSize: domainQueue.length,
          sortedIntents: sorted.map((intent) => ({
            id: (intent as OriginIntent).id,
            queueIdx: (intent as OriginIntent).queueIdx,
            amount: (intent as OriginIntent).amount,
            destinations: (intent as OriginIntent).destinations,
          })),
        });
      }

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
