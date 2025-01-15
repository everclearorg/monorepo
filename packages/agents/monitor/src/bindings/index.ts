import fastify, { FastifyInstance, FastifyReply } from 'fastify';
import {
  MonitorApiErrorResponse,
  MonitorApiErrorResponseSchema,
  TokenPriceResponse,
  TokenPriceResponseSchema,
  SelfRelayRequest,
  SelfRelaySchema,
  SelfRelayResponse,
  SelfRelayResponseSchema,
  IntentReportResponseSchema,
  IntentReportResponse,
  ChainStatusResponse,
  ChainStatusResponseSchema,
  CheckGasResponseSchema,
  CheckGasResponse,
  HyperlaneMessageSummary,
  HyperlaneMessageSummarySchema,
} from '../types/api';
import { createLoggingContext, jsonifyError } from '@chimera-monorepo/utils';
import { getIntentStatus } from '../checklist/queue';
import { getContext } from '../context';
import { getAssetConfig, getTokenPrice, selfRelayHyperlaneMessages } from '../libs';
import { checkIntentLiquidity, checkIntentStatus } from '../checklist/intent';
import { checkChains } from '../checklist/chain';
import { checkGas } from '../checklist/gas';
import { getMessageStatus } from '../helpers';

export const bindServer = async (): Promise<FastifyInstance> => {
  const { config, logger } = getContext();
  const server = fastify();

  server.get('/ping', (_, res) => api.get.ping(res));

  server.get<{
    Params: {
      intentId: string;
      originDomain: string;
      destinationDomains: string;
    };
    Reply: IntentReportResponse | MonitorApiErrorResponse;
  }>(
    '/intent-status/:intentId/:originDomain/:destinationDomains',
    {
      schema: {
        response: {
          200: IntentReportResponseSchema,
          500: MonitorApiErrorResponseSchema,
        },
      },
    },
    async (request, response) => {
      const { requestContext, methodContext } = createLoggingContext('GET /intent-status/:intentId endpoint');
      try {
        const { originDomain, destinationDomains, intentId } = request.params;
        const messages = await getIntentStatus(
          originDomain,
          destinationDomains.split(',').filter((d) => d !== originDomain),
          intentId,
        );
        logger.debug('Retrieved message status for intent', requestContext, methodContext, { intentId, messages });
        const status = await checkIntentStatus(originDomain, destinationDomains.split(','), intentId);
        logger.debug('Retrieved status for intent', requestContext, methodContext, { intentId, status });
        const liquidity = await checkIntentLiquidity(originDomain, intentId);
        logger.debug('Retrieved liquidity for intent', requestContext, methodContext, { intentId, liquidity });
        return response.code(200).send({ intentId, status, messages, liquidity });
      } catch (err: unknown) {
        logger.debug('Intent Status by IntentId Get Error', requestContext, methodContext, jsonifyError(err as Error));
        return response
          .code(500)
          .send({ message: 'Intent Status by IntentId Get Error', error: jsonifyError(err as Error) });
      }
    },
  );

  server.get<{
    Params: {
      messageId: string;
    };
    Reply: HyperlaneMessageSummary | MonitorApiErrorResponse;
  }>(
    '/message-status/:messageId',
    {
      schema: {
        response: {
          200: HyperlaneMessageSummarySchema,
          500: MonitorApiErrorResponseSchema,
        },
      },
    },
    async (request, response) => {
      const { requestContext, methodContext } = createLoggingContext('GET /message-status/:messageId endpoint');
      try {
        const { messageId } = request.params;
        const { status } = await getMessageStatus(messageId, false);
        return response.code(200).send({ messageId, status });
      } catch (err: unknown) {
        logger.debug(
          'Message Status by MessageId Get Error',
          requestContext,
          methodContext,
          jsonifyError(err as Error),
        );
        return response
          .code(500)
          .send({ message: 'Message Status by MessageId Get Error', error: jsonifyError(err as Error) });
      }
    },
  );

  server.get<{
    Params: {
      domain: string;
      asset: string;
    };
    Reply: TokenPriceResponse | MonitorApiErrorResponse;
  }>(
    '/price/:domain/:asset',
    {
      schema: {
        response: {
          200: TokenPriceResponseSchema,
          500: MonitorApiErrorResponseSchema,
        },
      },
    },
    async (request, response) => {
      const { requestContext, methodContext } = createLoggingContext('GET /price/:domain/:asset endpoint');
      try {
        const { domain, asset } = request.params;
        const assetConfig = getAssetConfig(domain, asset);
        const tokenPriceInUsd = await getTokenPrice(domain, assetConfig);
        return response.code(200).send({ price: tokenPriceInUsd });
      } catch (err: unknown) {
        logger.debug('Token Price Get Error', requestContext, methodContext, jsonifyError(err as Error));
        return response.code(500).send({ message: 'Token Price Get Error', error: jsonifyError(err as Error) });
      }
    },
  );

  server.post<{
    Body: SelfRelayRequest;
    Reply: SelfRelayResponse[] | MonitorApiErrorResponse;
  }>(
    '/self-relay',
    {
      schema: {
        body: SelfRelaySchema,
        response: {
          200: SelfRelayResponseSchema,
          401: MonitorApiErrorResponseSchema,
          500: MonitorApiErrorResponseSchema,
        },
      },
    },
    async (request, response) => {
      const { requestContext, methodContext } = createLoggingContext('POST /self-relay endpoint');
      const { config } = getContext();
      try {
        const { adminToken, messageIds } = request.body;
        if (adminToken !== config.server.adminToken) {
          logger.error(`Unauthorized self-relay request`, requestContext, methodContext);
          return response.status(401).send({ message: 'Unauthorized' });
        }
        const results = await selfRelayHyperlaneMessages(messageIds ?? [], requestContext, methodContext);
        return response.status(200).send(results);
      } catch (err: unknown) {
        return response.status(500).send({ error: jsonifyError(err as Error), message: 'Error self-relay' });
      }
    },
  );

  server.get<{
    Reply: ChainStatusResponse | MonitorApiErrorResponse;
  }>(
    '/chain-status',
    {
      schema: {
        response: {
          200: ChainStatusResponseSchema,
          500: MonitorApiErrorResponseSchema,
        },
      },
    },
    async (_, response) => {
      const { requestContext, methodContext } = createLoggingContext('GET /chain-status endpoint');
      try {
        const res = await checkChains();
        return response.code(200).send(res);
      } catch (err: unknown) {
        logger.debug('Chain Status Get Error', requestContext, methodContext, jsonifyError(err as Error));
        return response.code(500).send({ message: 'Chain Status Get Error', error: jsonifyError(err as Error) });
      }
    },
  );

  server.get<{
    Reply: CheckGasResponse | MonitorApiErrorResponse;
  }>(
    '/check-gas',
    {
      schema: {
        response: {
          200: CheckGasResponseSchema,
          500: MonitorApiErrorResponseSchema,
        },
      },
    },
    async (_, response) => {
      const { requestContext, methodContext } = createLoggingContext('GET /check-gas endpoint');
      try {
        const res = await checkGas();
        return response.code(200).send(res);
      } catch (err: unknown) {
        logger.debug('Check Gas Get Error', requestContext, methodContext, jsonifyError(err as Error));
        return response.code(500).send({ message: 'Check Gas Get Error', error: jsonifyError(err as Error) });
      }
    },
  );

  const address = await server.listen({
    host: config.server.host,
    port: config.server.port,
  });

  logger.info(`Server listening at ${address}`);

  return server;
};

export const api = {
  get: {
    ping: async (res: FastifyReply) => {
      return res.status(200).send('pong\n');
    },
  },
};
