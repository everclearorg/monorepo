import { AppContext } from '@chimera-monorepo/cartographer-core';
import { LIGHTHOUSE_QUEUES } from '@chimera-monorepo/mqclient';
import { TRON_CHAINID } from '@chimera-monorepo/utils';
import { notifyLighthouse } from '../notify';

/** Map of topic[0] hash → lighthouse queue name. */
const TOPIC_QUEUE_MAP: Record<string, string> = {
  '0x80eb6c87e9da127233fe2ecab8adf29403109adc6bec90147df35eeee0745991': LIGHTHOUSE_QUEUES.INTENT, // IntentAdded
  '0x4cc03dfa265ccd4670a5059498b2551525947958b26b5e70f6a6dc62a950fd4e': LIGHTHOUSE_QUEUES.INTENT, // IntentWithFeesAdded
  '0xc5929cfdbbc98a41855839bee1396d17ee4a149e40d5c324b6f4332655f5cffd': LIGHTHOUSE_QUEUES.INTENT, // OrderCreated
  '0xe3bc4b05ac625e8c55084d86f8bb9a4c1ff02777dccc7ec0f3b3b7e7468cf383': LIGHTHOUSE_QUEUES.FILL, // IntentFilled
  '0x4190759d37d5cfe7a1a70e06ec7508a05d12fd9cb76f353da1c9e028e5a48dcf': LIGHTHOUSE_QUEUES.SETTLEMENT, // Settled
  '0x43a52e9a77f317a192970b363b14ece56df243fe0dd94f459f63029d657efec3': LIGHTHOUSE_QUEUES.SETTLEMENT, // IntentQueueProcessed
  '0x5e3a5b80dcf8e0fb984fe128ed0db507a86cc0674c4f5980f83b129b2cfdc69e': LIGHTHOUSE_QUEUES.SETTLEMENT, // FillQueueProcessed
};

/**
 * Process a raw Tron log payload from the Goldsky webhook.
 *
 * Extracts the first topic (event signature hash) from the `topics` field,
 * matches it against known event hashes, and notifies the appropriate
 * lighthouse queue.
 */
export async function processTronLog(payload: Record<string, unknown>, context: AppContext): Promise<void> {
  const { logger } = context;
  const topics = payload.topics as string | undefined;

  if (!topics) {
    logger.debug('Tron log payload missing topics field, skipping');
    return;
  }

  // topics is a text field; extract the first 66 characters (0x + 64 hex chars)
  const topicHash = topics.slice(0, 66).toLowerCase();
  const queueName = TOPIC_QUEUE_MAP[topicHash];

  if (!queueName) {
    logger.debug('Unknown Tron event topic, skipping', undefined, undefined, {
      topicHash,
    });
    return;
  }

  logger.info('Processing Tron log event', undefined, undefined, {
    topicHash,
    queueName,
    domain: TRON_CHAINID,
  });

  await notifyLighthouse(queueName);
}
