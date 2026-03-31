import { createProducer, pingRedis, Queue } from '@chimera-monorepo/mqclient';
import { jsonifyError, Logger, LIGHTHOUSE_QUEUES } from '@chimera-monorepo/utils';

let queues: Map<string, Queue> | null = null;
let notifyLogger: Logger | undefined;

export const initNotify = async (redisUrl: string, logger: Logger): Promise<void> => {
  notifyLogger = logger;
  queues = new Map();
  for (const queueName of Object.values(LIGHTHOUSE_QUEUES)) {
    queues.set(queueName, createProducer(redisUrl, queueName, logger));
  }
  logger.info('BullMQ notification queues initialized');

  // Verify Redis connectivity at startup
  const anyQueue = queues.values().next().value!;
  const ok = await pingRedis(anyQueue);
  if (ok) {
    logger.info('BullMQ Redis connection verified');
  } else {
    logger.error('BullMQ Redis connection failed — queues will retry in the background');
  }
};

export const notifyLighthouse = async (queueName: string): Promise<void> => {
  if (!queues) {
    notifyLogger?.warn('BullMQ notification queues not initialized', undefined, undefined);
    return;
  }

  const queue = queues.get(queueName);
  if (!queue) {
    notifyLogger?.warn('BullMQ notification queue not found', undefined, undefined, { queueName });
    return;
  }

  try {
    // Use a content-based jobId for deduplication within a 30s window
    const timeBucket = Math.floor(Date.now() / 30_000);
    const jobId = `${queueName}-${timeBucket}`;

    await queue.add(queueName, {}, { jobId });
    notifyLogger?.debug('Enqueued lighthouse job', undefined, undefined, { queueName, jobId });
  } catch (error) {
    // Fire-and-forget: log but never fail the webhook response
    notifyLogger?.error('Failed to enqueue lighthouse job', undefined, undefined, jsonifyError(error as Error), {
      queueName,
    });
  }
};

export const getNotifyHealth = async (): Promise<{ redis: 'ok' | 'error'; detail?: string }> => {
  if (!queues || queues.size === 0) {
    return { redis: 'ok', detail: 'redis not configured' };
  }
  const anyQueue = queues.values().next().value!;
  const ok = await pingRedis(anyQueue);
  return ok ? { redis: 'ok' } : { redis: 'error', detail: 'ping failed' };
};

export const closeNotify = async (): Promise<void> => {
  if (!queues) return;
  await Promise.all([...queues.values()].map((q) => q.close()));
  queues = null;
};
