import { createLoggingContext, delay, jsonifyError } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { ChainStatusResponse, Severity } from '../types';
import { resolveAlerts, sendAlerts } from '../mockable';
import { getLatestBlockFromBlockMap } from '../helpers/chain';

const CALL_DELAY = 15_000;

export const checkChains = async (shouldAlert = true): Promise<ChainStatusResponse> => {
  const {
    config,
    logger,
    adapters: { subgraph, chainreader },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkChains.name);

  const chainStatus: ChainStatusResponse = [];
  const domains = [
    ...Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'evm'),
    config.hub.domain,
  ];
  const subgraphStart = Date.now();
  const subgraphBlockNumbers = await Promise.race([
    subgraph
      .getLatestBlockNumber(domains)
      .then((ret) => {
        logger.info('Getting block from subgraphs complete', requestContext, methodContext, {
          chains: domains,
          elapsed: Date.now() - subgraphStart,
          ret,
        });
        return ret;
      })
      .catch((e) => {
        logger.warn('Failed to get block number from subgraph', requestContext, methodContext, {
          chains: domains,
          elapsed: Date.now() - subgraphStart,
          error: jsonifyError(e),
        });
        throw e;
      }),
    (async () => {
      await delay(CALL_DELAY);
      logger.warn('Subgraph took longer than tolerated to resolve latest block', requestContext, methodContext, {
        chains: domains,
        delay: CALL_DELAY,
      });
      return new Map();
    })(),
  ]);

  await Promise.all(
    domains.map(async (domainId) => {
      // Get chain-specific threshold or fall back to global default
      const chainConfig = domainId === config.hub.domain ? config.hub : config.chains[domainId];
      const threshold = chainConfig.maxDelayedSubgraphBlock ?? config.thresholds.maxDelayedSubgraphBlock ?? 0;

      const subgraphBlockNumber = subgraphBlockNumbers.has(domainId) ? subgraphBlockNumbers.get(domainId)! : 0;
      const rpcStart = Date.now();
      const cached = getLatestBlockFromBlockMap(domainId);
      const rpcBlock =
        cached ??
        (await Promise.race([
          chainreader
            .getBlock(+domainId, 'latest')
            .then((ret) => {
              logger.info('Getting block from chain complete', requestContext, methodContext, {
                chain: +domainId,
                elapsed: Date.now() - rpcStart,
                ret,
              });
              return ret;
            })
            .catch((e) => {
              logger.warn('Failed to get block from chain', requestContext, methodContext, {
                chain: +domainId,
                elapsed: Date.now() - rpcStart,
                error: jsonifyError(e),
              });
              throw e;
            }),
          (async () => {
            await delay(CALL_DELAY);
            logger.warn('Chain took longer than tolerated to resolve latest block', requestContext, methodContext, {
              chain: +domainId,
              delay: CALL_DELAY,
            });
            return { number: 0, timestamp: Math.floor(Date.now() / 1000) };
          })(),
        ]));

      // Automatically increase the diff to size of threshold + 10
      const diff =
        rpcBlock.number === 0 && subgraphBlockNumber === 0 ? threshold + 10 : rpcBlock.number - subgraphBlockNumber;

      logger.debug(`Checking chain status: ${domainId}`, requestContext, methodContext, {
        rpc: rpcBlock.number,
        subgraph: subgraphBlockNumber,
        diff,
        threshold, // Log the threshold being used
      });

      chainStatus.push({
        domain: domainId,
        rpc: {
          blockNumber: rpcBlock.number,
          timestamp: rpcBlock.timestamp,
        },
        subgraphBlockNumber,
      });

      // Create report
      const report = {
        severity: Severity.Warning,
        type: 'ChainDelayed',
        ids: [domainId],
        reason: `${requestContext.origin}, The subgraph or chain of ${domainId} is behind by ${rpcBlock.number - subgraphBlockNumber} blocks (threshold: ${threshold}). Check rpcs and subgraph.`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };

      if (shouldAlert && threshold > 0 && diff > threshold) {
        // Send alerts
        logger.warn(
          `The subgraph or chain of ${domainId} is behind by a threshold of blocks`,
          requestContext,
          methodContext,
          {
            diff: rpcBlock.number - subgraphBlockNumber,
            threshold,
            rpcBlock,
            subgraphBlockNumber,
          },
        );

        const alertStart = Date.now();
        await sendAlerts(report, logger, config, requestContext);
        logger.debug('Sent all alerts', requestContext, methodContext, { elapsed: Date.now() - alertStart });
      } else {
        // Resolve any alerts
        const alertStart = Date.now();
        await resolveAlerts(report, logger, config, requestContext);
        logger.debug('Resolved all alerts', requestContext, methodContext, { elapsed: Date.now() - alertStart });
      }
    }),
  );
  logger.info('Overall chain status', requestContext, methodContext, chainStatus);

  return chainStatus;
};
