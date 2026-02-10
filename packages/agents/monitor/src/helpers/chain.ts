import { createLoggingContext, jsonifyError } from '@chimera-monorepo/utils';
import { getContext } from '../context';

/**
 * Fetches block data for all configured chains and stores it in adapters.blockMap.
 * This centralizes block fetching to avoid redundant RPC calls across multiple checks.
 * @param timeoutMs - Timeout for RPC calls in milliseconds
 */
export const getBlocks = async (timeoutMs: number = 15000): Promise<void> => {
  const {
    config,
    logger,
    adapters: { chainreader, blockMap },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(getBlocks.name);

  // Clear the block data map to ensure fresh data for this check cycle
  blockMap.clear();

  const allDomains = [...Object.keys(config.chains), config.hub.domain];

  logger.debug('Fetching blocks for all chains', requestContext, methodContext, {
    domains: allDomains,
    count: allDomains.length,
  });

  const fetchStart = Date.now();
  await Promise.all(
    allDomains.map(async (domainId) => {
      const domainStart = Date.now();
      let timeout: NodeJS.Timeout | undefined;
      try {
        const rpcBlock = await Promise.race([
          chainreader.getBlock(+domainId, 'latest'),
          new Promise<never>((_, reject) => {
            timeout = setTimeout(() => {
              logger.warn('Getting block timed out', requestContext, methodContext, {
                chain: domainId,
                delay: timeoutMs,
              });
              reject(new Error('Request timed out'));
            }, timeoutMs);
          }),
        ]);

        // Clear timeout if RPC call completed successfully
        if (timeout) {
          clearTimeout(timeout);
        }

        blockMap.set(domainId, { number: rpcBlock.number, timestamp: rpcBlock.timestamp });

        logger.debug('Fetched block for chain', requestContext, methodContext, {
          chain: domainId,
          number: rpcBlock.number,
          timestamp: rpcBlock.timestamp,
          elapsed: Date.now() - domainStart,
        });
      } catch (e) {
        // Clear timeout if error occurred (including timeout)
        if (timeout) {
          clearTimeout(timeout);
        }
        logger.warn('Failed to fetch block for chain', requestContext, methodContext, {
          chain: domainId,
          error: jsonifyError(e as Error),
          elapsed: Date.now() - domainStart,
        });
        // Store error state (0 block number) so checks can handle it
        blockMap.set(domainId, { number: 0, timestamp: Math.floor(Date.now() / 1000) });
      }
    }),
  );

  logger.info('Finished fetching blocks for all chains', requestContext, methodContext, {
    domains: allDomains,
    count: allDomains.length,
    elapsed: Date.now() - fetchStart,
  });
};
