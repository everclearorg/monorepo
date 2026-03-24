import { Queue, Worker, Job, ConnectionOptions, QueueOptions, WorkerOptions } from 'bullmq';
import { jsonifyError, Logger } from '@chimera-monorepo/utils';

export { Queue, Worker, Job } from 'bullmq';

export const LIGHTHOUSE_QUEUES = {
  INTENT: 'lighthouse-intent',
  FILL: 'lighthouse-fill',
  SETTLEMENT: 'lighthouse-settlement',
  SOLANA: 'lighthouse-solana',
  EXPIRED: 'lighthouse-expired',
  INVOICE: 'lighthouse-invoice',
} as const;

export const parseRedisUrl = (redisUrl: string): ConnectionOptions => {
  const url = new URL(redisUrl);
  // When connecting via PrivateLink, the endpoint DNS differs from the Redis
  // certificate hostname. Use ?tlsServername=<real-redis-host> in the URL to
  // set the correct SNI value for TLS verification.
  const tlsServername = url.searchParams.get('tlsServername');
  return {
    host: url.hostname,
    port: parseInt(url.port || '6379', 10),
    ...(url.password ? { password: url.password } : {}),
    ...(url.username ? { username: url.username } : {}),
    ...(url.protocol === 'rediss:' ? { tls: tlsServername ? { servername: tlsServername } : {} } : {}),
    connectTimeout: 17_000,
    maxRetriesPerRequest: null,
    retryStrategy: (times: number) => Math.min(times * 50, 5_000),
    keepAlive: 30_000,
  };
};

export const pingRedis = async (queueOrWorker: Queue | Worker, timeoutMs = 3_000): Promise<boolean> => {
  const pingPromise = queueOrWorker.client.then((client) => client.ping());
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(() => reject(new Error('timeout')), timeoutMs);
  });

  try {
    const result = await Promise.race([pingPromise, timeoutPromise]);
    clearTimeout(timeoutId);
    return result === 'PONG';
  } catch {
    clearTimeout(timeoutId);
    void pingPromise.catch(() => {});
    return false;
  }
};

export const createProducer = (
  redisUrl: string,
  queueName: string,
  logger: Logger,
  opts?: Partial<QueueOptions>,
): Queue => {
  const connection = parseRedisUrl(redisUrl);
  const queue = new Queue(queueName, {
    connection,
    defaultJobOptions: {
      attempts: 3,
      backoff: { type: 'exponential', delay: 5_000 },
      removeOnComplete: { count: 100 },
      removeOnFail: { count: 1000 },
    },
    ...opts,
  });
  queue.on('error', (err) =>
    logger.error(`Queue "${queueName}" Redis connection error`, undefined, undefined, jsonifyError(err), {
      queueName,
      role: 'producer',
    }),
  );
  return queue;
};

export const createWorker = (
  redisUrl: string,
  queueName: string,
  processor: (job: Job) => Promise<void>,
  logger: Logger,
  opts?: Partial<WorkerOptions>,
): Worker => {
  const connection = parseRedisUrl(redisUrl);
  const worker = new Worker(queueName, processor, {
    connection,
    concurrency: 1,
    lockDuration: 300_000, // 5 minutes — prevents stale-lock re-processing for long tasks
    ...opts,
  });
  worker.on('ready', () =>
    logger.info(`Worker "${queueName}" Redis connected`, undefined, undefined, {
      queueName,
      role: 'worker',
    }),
  );
  worker.on('error', (err) =>
    logger.error(`Worker "${queueName}" Redis connection error`, undefined, undefined, jsonifyError(err), {
      queueName,
      role: 'worker',
    }),
  );
  return worker;
};
