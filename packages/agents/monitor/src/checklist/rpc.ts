import { createLoggingContext, Logger, Severity, SOLANA_CHAINID } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { Report } from '../types';
import { resolveAlerts, sendAlerts } from '../mockable';

interface RpcError {
  rpcOrigin: string;
  domain: string;
  error?: string;
  blockNumber?: number;
}

const makeReport = (e: RpcError, logger: Logger, env: string): Report => ({
  severity: Severity.Warning,
  type: 'BadRpcDetected',
  ids: [e.domain, e.rpcOrigin],
  reason: `Bad Rpcs:\n domain: ${e.domain}, url: ${e.rpcOrigin}, error: ${e.error}`,
  timestamp: Date.now(),
  logger,
  env,
});

export const checkRpcs = async (timeoutMs: number = 5000) => {
  const {
    config,
    logger,
    adapters: { blockMap },
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(checkRpcs.name);
  const badRpcs: RpcError[] = [];
  const goodRpcs: { blockNumber: number; domain: string; rpcOrigin: string }[] = [];
  await Promise.all(
    Object.keys(config.chains).map(async (domainId) => {
      const chainConfig = config.chains[domainId];
      const rpcUrls = chainConfig.providers;

      // For Solana, only check the first provider URL since ChainService only uses urls[0]
      // For other chains, check all providers
      const urlsToCheck = chainConfig.network === 'svm' ? (rpcUrls.length > 0 ? [rpcUrls[0]] : []) : rpcUrls;

      // Filter valid URLs and report malformed URLs as bad RPCs
      const validUrls = urlsToCheck.filter((rpcUrl) => {
        if (!URL.canParse(rpcUrl)) {
          // Extract origin if possible, otherwise use a safe placeholder
          // Don't expose full URL as it may contain secrets
          let rpcOrigin = 'malformed URL';
          try {
            // Try to extract just the hostname/origin if it's partially valid
            // Only extract if it looks like it has a protocol or valid hostname structure
            const match = rpcUrl.match(/^(https?:\/\/)([^\/\?#@]+)/);
            if (match && match[2]) {
              // Extract hostname (part after @ if present, otherwise the matched part)
              rpcOrigin = match[2].split('@').pop() || 'malformed URL';
            } else {
              // For truly malformed URLs without protocol, use placeholder
              rpcOrigin = 'malformed URL';
            }
          } catch {
            // If extraction fails, use placeholder
            rpcOrigin = 'malformed URL';
          }

          badRpcs.push({
            rpcOrigin,
            error: 'Invalid URL format',
            domain: domainId,
          });
          logger.debug(`Malformed URL detected`, requestContext, methodContext, {
            chain: domainId,
            origin: rpcOrigin,
          });
          return false;
        }
        return true;
      });

      // Skip RPC check if all URLs are malformed
      if (validUrls.length === 0) {
        return;
      }

      try {
        if (!blockMap.has(domainId)) {
          logger.warn('Block data not found for chain', requestContext, methodContext, {
            domain: domainId,
          });
          throw new Error('Block data not found');
        }

        const blockNumber = blockMap.get(domainId)!.number;
        logger.debug('Retrieved block number for chain', requestContext, methodContext, {
          number: blockNumber,
          chain: domainId,
        });

        // Mark valid providers as good
        // For Solana, only report the first provider
        // For EVM/Tron, report all valid providers
        validUrls.forEach((rpcUrl) => {
          const rpcOrigin = new URL(rpcUrl).origin;
          goodRpcs.push({ rpcOrigin, blockNumber, domain: domainId });
        });
      } catch (error: unknown) {
        // If ChainService fails, mark valid providers as bad
        validUrls.forEach((rpcUrl) => {
          const rpcOrigin = new URL(rpcUrl).origin;
          const errorMessage = (error as Error).message.replace(rpcUrl, rpcOrigin);
          badRpcs.push({ rpcOrigin, error: errorMessage, domain: domainId });
          logger.debug(`Error connecting to provider at ${rpcOrigin}: ${error}`, requestContext, methodContext);
        });
      }
    }),
  );

  for (const badRpc of badRpcs) {
    // Skip alerts for Solana 429 errors
    if (String(badRpc.domain) === String(SOLANA_CHAINID) && badRpc.error?.includes('429')) {
      continue;
    }

    const report = makeReport(badRpc, logger, config.environment);
    await sendAlerts(report, logger, config, requestContext);
  }

  for (const goodRpc of goodRpcs) {
    const report = makeReport(goodRpc, logger, config.environment);
    await resolveAlerts(report, logger, config, requestContext);
  }

  logger.info('Overall rpc status', requestContext, methodContext, {
    badRpcs,
    goodRpcs,
  });
};
