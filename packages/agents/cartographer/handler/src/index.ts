import { FastifyInstance } from 'fastify';
import { Logger, jsonifyError, createLoggingContext } from '@chimera-monorepo/utils';
import { AppContext } from '@chimera-monorepo/cartographer-core';

import { getHandlerConfig, initializeContext, HandlerConfig } from './init';
import { createServer, ServerState, PAUSE_CHECKPOINT_KEY } from './server';
import { runBackfill } from './maintenance/backfill';
import { initNotify, closeNotify } from './notify';

let server: FastifyInstance | null = null;
let appContext: AppContext | null = null;
let isShuttingDown = false;
let backfillTimeout: NodeJS.Timeout | null = null;
let handlerConfig: HandlerConfig;

const logger = new Logger({
  level: process.env.CARTOGRAPHER_LOG_LEVEL || 'info',
  name: 'cartographer-handler',
  formatters: {
    level: (label) => ({ level: label.toUpperCase() }),
  },
});

function startBackfillLoop(): void {
  const { requestContext, methodContext } = createLoggingContext('backfillLoop');
  logger.info('Starting backfill maintenance loop', requestContext, methodContext, {
    intervalMs: handlerConfig.pollInterval,
  });

  scheduleNextBackfill(0);
}

function scheduleNextBackfill(delayMs: number): void {
  backfillTimeout = setTimeout(async () => {
    if (!appContext || isShuttingDown) return;

    try {
      await runBackfill(appContext);
    } catch (error) {
      logger.error('Error in backfill maintenance loop', undefined, undefined, jsonifyError(error as Error));
    }

    if (!isShuttingDown) {
      scheduleNextBackfill(handlerConfig.pollInterval);
    }
  }, delayMs);
}

async function gracefulShutdown(): Promise<void> {
  if (isShuttingDown) return;
  isShuttingDown = true;

  logger.info('Starting graceful shutdown');

  try {
    if (backfillTimeout) {
      clearTimeout(backfillTimeout);
      backfillTimeout = null;
      logger.info('Backfill loop stopped');
    }

    await closeNotify();
    logger.info('BullMQ notification queues closed');

    if (server) {
      await server.close();
      logger.info('HTTP server closed');
    }

    logger.info('Graceful shutdown completed');
    process.exit(0);
  } catch (error) {
    logger.error('Error during graceful shutdown', undefined, undefined, jsonifyError(error as Error));
    process.exit(1);
  }
}

async function startServer(): Promise<void> {
  const { requestContext, methodContext } = createLoggingContext('startServer');
  logger.info('Starting cartographer handler server', requestContext, methodContext);

  try {
    handlerConfig = await getHandlerConfig();

    if (!handlerConfig.adminToken) {
      logger.error('Cartographer admin token is not set');
    }

    appContext = await initializeContext(handlerConfig, logger);

    const pauseCheckpoint = await appContext.adapters.database.getCheckPoint(PAUSE_CHECKPOINT_KEY);
    const isPaused = pauseCheckpoint === 1;

    const state: ServerState = {
      appContext,
      isPaused,
      webhookSecret: handlerConfig.goldskyWebhookSecret,
      adminToken: handlerConfig.adminToken,
    };

    server = createServer(state, logger);

    await server.listen({ port: handlerConfig.handlerPort, host: '0.0.0.0' });
    logger.info('Cartographer handler server started', requestContext, methodContext, {
      port: handlerConfig.handlerPort,
    });

    // Initialize BullMQ notification queues if REDIS_URL is configured
    if (handlerConfig.redisUrl) {
      initNotify(handlerConfig.redisUrl, logger);
    }

    startBackfillLoop();

    process.on('SIGTERM', gracefulShutdown);
    process.on('SIGINT', gracefulShutdown);
  } catch (error) {
    logger.error('Failed to start server', requestContext, methodContext, jsonifyError(error as Error));
    process.exit(1);
  }
}

startServer().catch((error) => {
  logger.error('Fatal error starting server', undefined, undefined, jsonifyError(error as Error));
  process.exit(1);
});
