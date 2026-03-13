import { Queue, Worker, Job, ConnectionOptions, QueueOptions, WorkerOptions } from 'bullmq';

export { Queue, Worker, Job } from 'bullmq';

export const LIGHTHOUSE_QUEUES = {
  INTENT: 'lighthouse:intent',
  FILL: 'lighthouse:fill',
  SETTLEMENT: 'lighthouse:settlement',
  SOLANA: 'lighthouse:solana',
  EXPIRED: 'lighthouse:expired',
  INVOICE: 'lighthouse:invoice',
} as const;

export const parseRedisUrl = (redisUrl: string): ConnectionOptions => {
  const url = new URL(redisUrl);
  return {
    host: url.hostname,
    port: parseInt(url.port || '6379', 10),
    ...(url.password ? { password: url.password } : {}),
    ...(url.username ? { username: url.username } : {}),
    ...(url.protocol === 'redis:' ? { tls: {} } : {}),
  };
};

export const createProducer = (redisUrl: string, queueName: string, opts?: Partial<QueueOptions>): Queue => {
  const connection = parseRedisUrl(redisUrl);
  return new Queue(queueName, {
    connection,
    defaultJobOptions: {
      attempts: 3,
      backoff: { type: 'exponential', delay: 5_000 },
      removeOnComplete: { count: 100 },
      removeOnFail: { count: 1000 },
    },
    ...opts,
  });
};

export const createWorker = (
  redisUrl: string,
  queueName: string,
  processor: (job: Job) => Promise<void>,
  opts?: Partial<WorkerOptions>,
): Worker => {
  const connection = parseRedisUrl(redisUrl);
  return new Worker(queueName, processor, {
    connection,
    concurrency: 1,
    lockDuration: 300_000, // 5 minutes — prevents stale-lock re-processing for long tasks
    ...opts,
  });
};
