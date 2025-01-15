import { providers } from 'ethers';
import { createLoggingContext, Logger } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { Report, Severity } from '../types';
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

export const checkRpcs = async () => {
  const { config, logger } = getContext();

  const { requestContext, methodContext } = createLoggingContext(checkRpcs.name);
  const badRpcs: RpcError[] = [];
  const goodRpcs = [];
  for (const domainId of Object.keys(config.chains)) {
    const chainConfig = config.chains[domainId];
    const rpcUrls = chainConfig.providers;
    for (const rpcUrl of rpcUrls) {
      const rpcOrigin = URL.canParse(rpcUrl) ? new URL(rpcUrl).origin : 'malformed URL';
      try {
        const provider = new providers.JsonRpcProvider(rpcUrl);
        const blockNumber = await provider.getBlockNumber();
        goodRpcs.push({ rpcOrigin, blockNumber, domain: domainId });
      } catch (error: unknown) {
        (error as Error).message = (error as Error).message.replace(rpcUrl, rpcOrigin);
        badRpcs.push({ rpcOrigin, error: (error as Error).message, domain: domainId });
        logger.debug(`Error connecting to provider at ${rpcOrigin}: ${error}`, requestContext, methodContext);
      }
    }
  }

  for (const badRpc of badRpcs) {
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
