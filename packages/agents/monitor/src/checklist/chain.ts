import { createLoggingContext } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { ChainStatusResponse, Severity } from '../types';
import { resolveAlerts, sendAlerts } from '../mockable';

export const checkChains = async (shouldAlert = true): Promise<ChainStatusResponse> => {
  const {
    config,
    logger,
    adapters: { subgraph, chainreader },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkChains.name);

  const chainStatus = [];
  const domains = [
    ...Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'evm'),
    config.hub.domain,
  ];
  const subgraphBlockNumbers = await subgraph.getLatestBlockNumber(domains);

  for (const domainId of domains) {
    // Get chain-specific threshold or fall back to global default
    const chainConfig = domainId === config.hub.domain ? config.hub : config.chains[domainId];
    const threshold = chainConfig.maxDelayedSubgraphBlock ?? config.thresholds.maxDelayedSubgraphBlock ?? 0;

    const subgraphBlockNumber = subgraphBlockNumbers.has(domainId) ? subgraphBlockNumbers.get(domainId)! : 0;
    const rpcBlock = await chainreader.getBlock(+domainId, 'latest');

    const diff = rpcBlock.number - subgraphBlockNumber;

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
      type: 'SubgraphDelayed',
      ids: [domainId],
      reason: `${requestContext.origin}, The subgraph of ${domainId} is behind by ${diff} blocks (threshold: ${threshold})`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };

    if (shouldAlert && threshold > 0 && diff > threshold) {
      // Send alerts
      logger.warn(`The subgraph of ${domainId} is behind by a threshold of blocks`, requestContext, methodContext, {
        diff,
        threshold,
      });

      await sendAlerts(report, logger, config, requestContext);
    } else {
      // Resolve any alerts
      await resolveAlerts(report, logger, config, requestContext);
    }
  }

  logger.info('Overall chain status', requestContext, methodContext, chainStatus);

  return chainStatus;
};
