import { timingSafeEqual } from 'crypto';
import { Logger, jsonifyError, createLoggingContext, QueueType } from '@chimera-monorepo/utils';
import { createWorker, createProducer, LIGHTHOUSE_QUEUES, Worker, Queue, Job } from '@chimera-monorepo/mqclient';
import fastify, { FastifyInstance } from 'fastify';

import { getConfig } from './config';
import { initializeLighthouseContext } from './context';
import { processMessageQueue } from './tasks/helpers';
import { processExpiredIntents } from './tasks/clearing';
import { processDepositsAndInvoices } from './tasks/invoice';
import { processSolanaTransactions } from './tasks/solana';

let isShuttingDown = false;
let server: FastifyInstance | undefined;
const workers: Worker[] = [];
const queues: Queue[] = [];

let logger = new Logger({
  level: 'info',
  name: 'lighthouse-handler',
  formatters: {
    level: (label) => ({ level: label.toUpperCase() }),
  },
});

function verifyAdminToken(authHeader: string | string[] | undefined, expectedToken: string): boolean {
  const header = Array.isArray(authHeader) ? authHeader[0] : authHeader;
  if (!header) return false;
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) return false;

  try {
    const provided = Buffer.from(token);
    const expected = Buffer.from(expectedToken);
    if (provided.length !== expected.length) return false;
    return timingSafeEqual(provided, expected);
  } catch {
    return false;
  }
}

const createServer = async (port: number, adminToken: string): Promise<FastifyInstance> => {
  const app = fastify({ logger: false });

  app.get('/health', async () => {
    return { status: 'ok', workers: workers.length, isShuttingDown };
  });

  const triggerHandlers: Record<string, () => Promise<void>> = {
    intent: () => processMessageQueue(QueueType.Intent),
    fill: () => processMessageQueue(QueueType.Fill),
    settlement: () => processMessageQueue(QueueType.Settlement),
    solana: () => processSolanaTransactions(),
    expired: () => processExpiredIntents(),
    invoice: () => processDepositsAndInvoices(),
  };

  app.post<{ Params: { task: string } }>('/trigger/:task', async (request, reply) => {
    if (!verifyAdminToken(request.headers.authorization, adminToken)) {
      return reply.status(401).send({ error: 'Unauthorized' });
    }

    const { task } = request.params;
    const handler = triggerHandlers[task];
    if (!handler) {
      return reply.status(404).send({ status: 'error', error: `Unknown task: ${task}` });
    }
    try {
      await handler();
      return { status: 'ok', task };
    } catch (error) {
      logger.error(`Manual trigger failed for ${task}`, undefined, undefined, jsonifyError(error as Error));
      return reply.status(500).send({ status: 'error', task, error: (error as Error).message });
    }
  });

  await app.listen({ port, host: '0.0.0.0' });
  logger.info(`Health server listening on port ${port}`);

  return app;
};

const wrapProcessor = (name: string, fn: () => Promise<void>) => {
  return async (job: Job): Promise<void> => {
    const { requestContext, methodContext } = createLoggingContext(`worker:${name}`);
    logger.info(`Processing job on ${name} (id: ${job.id})`, requestContext, methodContext);
    try {
      await fn();
      logger.info(`Job completed on ${name} (id: ${job.id})`, requestContext, methodContext);
    } catch (error) {
      logger.error(
        `Job failed on ${name} (id: ${job.id})`,
        requestContext,
        methodContext,
        jsonifyError(error as Error),
      );
      throw error;
    }
  };
};

const registerRepeatableJobs = async (redisUrl: string): Promise<void> => {
  const { requestContext, methodContext } = createLoggingContext('registerRepeatableJobs');

  // Create producer queues for repeatable job scheduling
  const expiredQueue = createProducer(redisUrl, LIGHTHOUSE_QUEUES.EXPIRED);
  const invoiceQueue = createProducer(redisUrl, LIGHTHOUSE_QUEUES.INVOICE);
  queues.push(expiredQueue, invoiceQueue);

  await expiredQueue.upsertJobScheduler(
    'expired-periodic',
    { every: 600_000 }, // 10 minutes
    { data: {}, opts: { attempts: 3, backoff: { type: 'exponential', delay: 5_000 } } },
  );
  logger.info('Registered expired repeatable job (every 10 min)', requestContext, methodContext);

  await invoiceQueue.upsertJobScheduler(
    'invoice-periodic',
    { every: 900_000 }, // 15 minutes
    { data: {}, opts: { attempts: 3, backoff: { type: 'exponential', delay: 5_000 } } },
  );
  logger.info('Registered invoice repeatable job (every 15 min)', requestContext, methodContext);
};

async function gracefulShutdown(): Promise<void> {
  if (isShuttingDown) return;
  isShuttingDown = true;

  const { requestContext, methodContext } = createLoggingContext('gracefulShutdown');
  logger.info('Starting graceful shutdown', requestContext, methodContext);

  try {
    // Close workers (drain in-progress jobs)
    await Promise.all(workers.map((w) => w.close()));
    logger.info('All workers closed', requestContext, methodContext);

    // Close producer queues
    await Promise.all(queues.map((q) => q.close()));
    logger.info('All queues closed', requestContext, methodContext);

    // Close health server
    if (server) {
      await server.close();
      logger.info('Health server closed', requestContext, methodContext);
    }

    logger.info('Graceful shutdown completed', requestContext, methodContext);
    process.exit(0);
  } catch (error) {
    logger.error('Error during graceful shutdown', requestContext, methodContext, jsonifyError(error as Error));
    process.exit(1);
  }
}

async function main(): Promise<void> {
  const { requestContext, methodContext } = createLoggingContext('main');

  try {
    const config = await getConfig();
    const redisUrl = config.redisUrl;

    if (!redisUrl) {
      throw new Error('Redis URL is required but not set');
    }

    logger = new Logger({
      level: config.logLevel,
      name: 'lighthouse-handler',
      formatters: {
        level: (label) => ({ level: label.toUpperCase() }),
      },
    });

    logger.info('Initializing lighthouse context', requestContext, methodContext);
    await initializeLighthouseContext(config, logger);

    logger.info('Creating workers', requestContext, methodContext);

    // Event-driven workers (triggered by carto handler)
    workers.push(
      createWorker(
        redisUrl,
        LIGHTHOUSE_QUEUES.INTENT,
        wrapProcessor('intent', () => processMessageQueue(QueueType.Intent)),
      ),
      createWorker(
        redisUrl,
        LIGHTHOUSE_QUEUES.FILL,
        wrapProcessor('fill', () => processMessageQueue(QueueType.Fill)),
      ),
      createWorker(
        redisUrl,
        LIGHTHOUSE_QUEUES.SETTLEMENT,
        wrapProcessor('settlement', () => processMessageQueue(QueueType.Settlement)),
      ),
      createWorker(
        redisUrl,
        LIGHTHOUSE_QUEUES.SOLANA,
        wrapProcessor('solana', () => processSolanaTransactions()),
      ),
    );

    // Periodic workers (repeatable jobs)
    workers.push(
      createWorker(
        redisUrl,
        LIGHTHOUSE_QUEUES.EXPIRED,
        wrapProcessor('expired', () => processExpiredIntents()),
      ),
      createWorker(
        redisUrl,
        LIGHTHOUSE_QUEUES.INVOICE,
        wrapProcessor('invoice', () => processDepositsAndInvoices()),
      ),
    );

    // Register repeatable jobs for periodic tasks
    await registerRepeatableJobs(redisUrl);

    // Set up worker event handlers
    for (const worker of workers) {
      worker.on('error', (err) => {
        logger.error(`Worker error on ${worker.name}`, requestContext, methodContext, jsonifyError(err));
      });
    }

    // Start the health check server
    const port = parseInt(process.env.PORT || '8080', 10);
    server = await createServer(port, config.adminToken);

    logger.info('Lighthouse handler started successfully', requestContext, methodContext, {
      workers: workers.map((w) => w.name),
      port,
    });

    // Graceful shutdown handlers
    process.on('SIGTERM', gracefulShutdown);
    process.on('SIGINT', gracefulShutdown);
  } catch (error) {
    logger.error('Failed to start lighthouse handler', requestContext, methodContext, jsonifyError(error as Error));
    process.exit(1);
  }
}

main().catch((error) => {
  logger.error('Fatal error starting lighthouse handler', undefined, undefined, jsonifyError(error as Error));
  process.exit(1);
});
