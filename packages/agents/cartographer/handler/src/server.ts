import fastify, { FastifyInstance } from 'fastify';
import { Logger, jsonifyError } from '@chimera-monorepo/utils';
import { AppContext } from '@chimera-monorepo/cartographer-core';

import { verifyWebhookSecret, routeWebhook } from './webhooks/webhookHandler';

export interface ServerState {
  appContext: AppContext | null;
  isPaused: boolean;
  webhookSecret: string;
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
  server.post('/pause', async (_, res) => {
    state.isPaused = true;
    logger.info('Webhook processing paused');
    return res.status(200).send({ message: 'Webhook processing paused', paused: true });
  });

  // Resume webhook processing
  server.post('/resume', async (_, res) => {
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
      if (state.isPaused) {
        return res.status(200).send({ message: 'Server paused, skipping webhook', processed: false, webhookId: '' });
      }

      if (!state.appContext) {
        return res.status(503).send({ error: 'Handler not initialized' });
      }

      const webhookName = req.params.webhookName;
      const domain = req.query.domain;
      const webhookSecretHeader =
        (req.headers['goldsky-webhook-secret'] as string) || (req.headers['Goldsky-Webhook-Secret'] as string);

      if (!verifyWebhookSecret(webhookSecretHeader, state.webhookSecret)) {
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
