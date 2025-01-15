import { getContext } from '../../watcher';

import {
  BalanceResponse,
  BalanceResponseSchema,
  PauseRequest,
  PauseRequestSchema,
  PauseResponse,
  PauseResponseSchema,
  WatcherApiErrorResponse,
  WatcherApiErrorResponseSchema,
} from './schema';
import {
  EverclearError,
  createLoggingContext,
  createMethodContext,
  createRequestContext,
  jsonifyError,
} from '@chimera-monorepo/utils';
import { formatEther } from 'ethers/lib/utils';
import { pauseProtocol } from '../../helpers';
import { Severity } from '../../lib/entities';
import { getFastifyInstance } from '../../mockable';

export const bindServer = async (): Promise<void> => {
  const {
    config,
    logger,
    adapters: { wallet, chainservice },
  } = getContext();
  const server = getFastifyInstance();

  server.get('/ping', async (_, res) => {
    return res.status(200).send('pong\n');
  });

  server.get<{ Reply: BalanceResponse | WatcherApiErrorResponse }>(
    '/balance',
    {
      schema: {
        response: {
          200: BalanceResponseSchema,
          500: WatcherApiErrorResponseSchema,
        },
      },
    },
    async (_, res) => {
      try {
        const address = await wallet.getAddress();
        const allChains = Object.keys(config.chains).concat(config.hub.domain);
        const nativeBalances = await Promise.all(
          allChains.map((chain: string) => {
            return chainservice.getBalance(Number(chain), address);
          }),
        );
        const balances: Record<string, string> = {};
        nativeBalances.forEach((balance, index) => {
          balances[allChains[index]] = formatEther(balance);
        });
        return res.status(200).send({ address, balances });
      } catch (err: unknown) {
        return res.status(500).send({ error: jsonifyError(err as EverclearError), message: 'Error getting balance' });
      }
    },
  );

  server.post<{
    Body: PauseRequest;
    Reply: PauseResponse | WatcherApiErrorResponse;
  }>(
    '/pause',
    {
      schema: {
        body: PauseRequestSchema,
        response: {
          200: PauseResponseSchema,
          500: WatcherApiErrorResponseSchema,
        },
      },
    },
    async (req, res) => {
      const { requestContext, methodContext } = createLoggingContext('POST /pause endpoint');
      try {
        const { adminToken, reason } = req.body;
        if (adminToken !== config.server.adminToken) {
          logger.error(`Unauthorized pause request`, requestContext, methodContext);
          return res.status(401).send({ message: 'Unauthorized to perform this operation' });
        }
        const domainIds = Object.keys(config.chains).concat(config.hub.domain);
        const report = {
          severity: Severity.Warning,
          type: 'API pause',
          domains: domainIds,
          reason: reason,
          timestamp: Date.now(),
          logger: logger,
          env: config.environment,
        };
        const results = await pauseProtocol(report, requestContext);
        return res.status(200).send(results);
      } catch (err: unknown) {
        return res.status(500).send({ error: jsonifyError(err as EverclearError), message: 'Error pausing' });
      }
    },
  );

  try {
    await server.listen({ port: config.server.port, host: config.server.host });
  } catch (err: unknown) {
    logger.error(
      'Error starting server',
      createRequestContext(''),
      createMethodContext(''),
      jsonifyError(err as EverclearError),
    );
  }
};
