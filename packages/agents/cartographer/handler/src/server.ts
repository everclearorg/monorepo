import fastify, { FastifyInstance } from 'fastify';
import { Logger, jsonifyError } from '@chimera-monorepo/utils';
import { AppContext } from '@chimera-monorepo/cartographer-core';

import { verifySecret, routeWebhook } from './webhooks/webhookHandler';

export const PAUSE_CHECKPOINT_KEY = 'cartographer_handler_paused';

function verifyAdminToken(authHeader: string | string[] | undefined, expectedToken: string): boolean {
  const header = Array.isArray(authHeader) ? authHeader[0] : authHeader;
  if (!header) return false;
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  return verifySecret(token, expectedToken);
}

export interface ServerState {
  appContext: AppContext | null;
  isPaused: boolean;
  webhookSecret: string;
  adminToken: string;
}

export function createServer(state: ServerState, logger: Logger): FastifyInstance {
  const server = fastify();

  // Health check
  server.get('/health', async (_, res) => {
    return res.status(200).send({
      status: 'ok',
      mode: 'cartographer-handler',
      paused: state.isPaused,
    });
  });

  // Pause webhook processing (useful during pipeline backfill)
  server.post('/pause', async (req, res) => {
    if (!verifyAdminToken(req.headers.authorization, state.adminToken)) {
      return res.status(401).send({ error: 'Unauthorized' });
    }
    if (!state.appContext) {
      return res.status(503).send({ error: 'Handler not initialized' });
    }
    await state.appContext.adapters.database.saveCheckPoint(PAUSE_CHECKPOINT_KEY, 1);
    state.isPaused = true;
    logger.info('Webhook processing paused');
    return res.status(200).send({ message: 'Webhook processing paused', paused: true });
  });

  // Resume webhook processing
  server.post('/resume', async (req, res) => {
    if (!verifyAdminToken(req.headers.authorization, state.adminToken)) {
      return res.status(401).send({ error: 'Unauthorized' });
    }
    if (!state.appContext) {
      return res.status(503).send({ error: 'Handler not initialized' });
    }
    await state.appContext.adapters.database.saveCheckPoint(PAUSE_CHECKPOINT_KEY, 0);
    state.isPaused = false;
    logger.info('Webhook processing resumed');
    return res.status(200).send({ message: 'Webhook processing resumed', paused: false });
  });

  // Webhook endpoint
  server.post<{
    Params: { webhookName: string };
    Querystring: { domain?: string };
    Body: unknown;
    Reply: { message?: string; processed?: boolean; webhookId?: string; error?: string };
  }>(
    '/webhooks/:webhookName',
    {
      schema: {
        params: {
          type: 'object',
          properties: { webhookName: { type: 'string' } },
          required: ['webhookName'],
        },
        querystring: {
          type: 'object',
          properties: { domain: { type: 'string' } },
        },
        body: { type: 'object' },
        response: {
          200: {
            type: 'object',
            properties: {
              message: { type: 'string' },
              processed: { type: 'boolean' },
              webhookId: { type: 'string' },
            },
          },
          401: {
            type: 'object',
            properties: { error: { type: 'string' } },
            required: ['error'],
          },
          500: {
            type: 'object',
            properties: { error: { type: 'string' } },
            required: ['error'],
          },
          503: {
            type: 'object',
            properties: { error: { type: 'string' } },
            required: ['error'],
          },
        },
      },
    },
    async (req, res) => {
      const webhookName = req.params.webhookName;
      const domain = req.query.domain;
      if (state.isPaused) {
        logger.info('Webhook processing is paused, skipping', undefined, undefined, {
          webhookName,
          domain,
        });
        return res.status(200).send({ message: 'Server paused, skipping webhook', processed: false, webhookId: '' });
      }

      if (!state.appContext) {
        logger.error('Cannot process webhook: handler not initialized');
        return res.status(503).send({ error: 'Handler not initialized' });
      }

      const webhookSecretHeader =
        (req.headers['goldsky-webhook-secret'] as string) || (req.headers['Goldsky-Webhook-Secret'] as string);

      if (!verifySecret(webhookSecretHeader, state.webhookSecret)) {
        return res.status(401).send({ error: 'Invalid webhook secret' });
      }

      const payload = req.body as Record<string, unknown>;

      try {
        const result = await routeWebhook(payload, webhookName, state.appContext, domain);
        return res.status(200).send(result);
      } catch (error) {
        logger.error('Failed to handle webhook request', undefined, undefined, jsonifyError(error as Error), {
          webhookName,
        });
        return res.status(500).send({ error: 'Internal server error' });
      }
    },
  );

  return server;
}
