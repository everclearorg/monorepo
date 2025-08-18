import { providers } from 'ethers';
import { createLoggingContext, Logger, Severity, SOLANA_CHAINID } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { Report } from '../types';
import { resolveAlerts, sendAlerts } from '../mockable';
import { Connection } from '@solana/web3.js';
import { getLatestBlockFromBlockMap } from '../helpers/chain';

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

export const checkRpcs = async () => {
  const { config, logger } = getContext();

  const { requestContext, methodContext } = createLoggingContext(checkRpcs.name);
  const badRpcs: RpcError[] = [];
  const goodRpcs: { blockNumber: number; domain: string; rpcOrigin: string }[] = [];
  await Promise.all(
    Object.keys(config.chains).map(async (domainId) => {
      const chainConfig = config.chains[domainId];
      const rpcUrls = chainConfig.providers;
      for (const rpcUrl of rpcUrls) {
        const rpcOrigin = URL.canParse(rpcUrl) ? new URL(rpcUrl).origin : 'malformed URL';
        try {
          let blockNumber: number;
          const delay = 5_000;
          const start = Date.now();
          await Promise.race([
            (async () => {
              const cached = getLatestBlockFromBlockMap(domainId, rpcOrigin);
              if (cached) {
                blockNumber = cached.number;
                return;
              }
              if (chainConfig.network === 'svm') {
                const connection = new Connection(rpcUrl);
                blockNumber = await connection.getBlockHeight();
              } else {
                const provider = new providers.JsonRpcProvider(rpcUrl);
                blockNumber = await provider.getBlockNumber();
              }
              goodRpcs.push({ rpcOrigin, blockNumber, domain: domainId });
            })().then((ret) => {
              logger.debug('Retrieved block number for rpc', requestContext, methodContext, {
                number: ret,
                rpcOrigin,
                chain: domainId,
                elapsed: Date.now() - start,
              });
              return ret;
            }),
            (async () => {
              logger.warn('Getting block number timed out for rpc', requestContext, methodContext, {
                rpcOrigin,
                chain: domainId,
                delay,
              });
              throw new Error('Request timed out');
            })(),
          ]);
        } catch (error: unknown) {
          (error as Error).message = (error as Error).message.replace(rpcUrl, rpcOrigin);
          badRpcs.push({ rpcOrigin, error: (error as Error).message, domain: domainId });
          logger.debug(`Error connecting to provider at ${rpcOrigin}: ${error}`, requestContext, methodContext);
        }
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
