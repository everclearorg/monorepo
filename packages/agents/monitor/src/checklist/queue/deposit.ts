import {
  createLoggingContext,
  getConfiguredTickerHashes,
  getNtpTimeSeconds,
  HubDeposit,
} from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { Severity } from '../../types';
import { resolveAlerts, sendAlerts } from '../../mockable';
import { getCurrentEpoch } from '../../helpers';

export const checkDepositQueueCount = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkDepositQueueCount.name);

  const domains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'evm');
  const enqueuedDepositsByDomain = await database.getAllEnqueuedDeposits(domains);

  const queueCountByKey: Map<string, number> = new Map();
  for (const deposit of enqueuedDepositsByDomain) {
    const queueKey = `${deposit.epoch}-${deposit.domain}-${deposit.tickerHash}`;
    if (queueCountByKey.has(queueKey)) {
      const queueCount = queueCountByKey.get(queueKey)!;
      queueCountByKey.set(queueKey, queueCount + 1);
    } else {
      queueCountByKey.set(queueKey, 1);
    }
  }
  logger.debug('Deposit queue counts', requestContext, methodContext, {
    countsByKey: Object.fromEntries([...queueCountByKey.entries()]),
  });

  const threshold = config.thresholds.maxDepositQueueCount ?? 0;
  const aboveThreshold = [];
  for (const queueKey of queueCountByKey.keys()) {
    const queueCount = queueCountByKey.get(queueKey)!;
    if (queueCount < threshold) continue;

    // Log warning
    logger.warn(`Deposit queue count for ${queueKey} exceeds threshold`, requestContext, methodContext, {
      queueCount,
      threshold,
    });

    aboveThreshold.push({ queueKey, queueCount });
  }

  const report = {
    severity: Severity.Warning,
    type: 'DepositQueueCountExceeded',
    ids: aboveThreshold.map((it) => it.queueKey),
    reason: `Deposit queue counts exeed threshold (${threshold}). \nQueues: ${aboveThreshold.map((q) => `key: ${q.queueKey}, count: ${q.queueCount}`).join(`\n\t`)}`,
    timestamp: Date.now(),
    logger: logger,
    env: config.environment,
    network: config.network || 'unknown',
  };

  if (!aboveThreshold.length) {
    // Generate keys for recent epochs to resolve any stuck alerts
    // This is necessary because once deposits are processed, their queue keys
    // disappear from the database query, so we must explicitly construct
    // possible alert keys to ensure BetterUptime can match and resolve them.
    const tickerHashes = getConfiguredTickerHashes(config.chains);
    const keysToResolve: string[] = [];

    try {
      // Get current epoch from hub contract
      const currentEpoch = await getCurrentEpoch();
      
      // Generate keys for recent epochs (last 200 epochs covers ~8-16 hours depending on epoch length)
      // This ensures we catch and resolve alerts that were triggered recently
      const RECENT_EPOCHS_LOOKBACK = 200;
      
      for (let i = 0; i < RECENT_EPOCHS_LOOKBACK; i++) {
        const epoch = currentEpoch - i;
        if (epoch < 0) break; // Don't go negative
        
        for (const domain of domains) {
          for (const tickerHash of tickerHashes) {
            keysToResolve.push(`${epoch}-${domain}-${tickerHash}`);
          }
        }
      }
      
      logger.debug('Generated resolution keys for recent epochs', requestContext, methodContext, {
        currentEpoch,
        lookback: RECENT_EPOCHS_LOOKBACK,
        totalKeys: keysToResolve.length,
        domains: domains.length,
        tickers: tickerHashes.length,
      });
    } catch (error) {
      // If we can't get current epoch, fall back to current queue keys only
      logger.warn('Failed to get current epoch for resolution, using current queue keys only', requestContext, methodContext, {
        error: error instanceof Error ? error.message : String(error),
      });
      keysToResolve.push(...queueCountByKey.keys());
    }

    report.ids = keysToResolve;
    await resolveAlerts(report, logger, { ...config, network: config.network || 'unknown' }, requestContext);
    logger.info('Deposit queue counts are within threshold, resolved alerts for recent epochs', requestContext, methodContext, {
      threshold,
      keysResolved: keysToResolve.length,
    });
    return queueCountByKey;
  }

  logger.warn(`Deposit queue counts exceed threshold`, requestContext, methodContext, {
    threshold,
    queues: aboveThreshold,
  });

  await sendAlerts(report, logger, { ...config, network: config.network || 'unknown' }, requestContext);

  return queueCountByKey;
};

export const checkDepositQueueLatency = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkDepositQueueLatency.name);

  const domains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'evm');
  logger.debug('Method start', requestContext, methodContext, {
    domains,
    hubDomain: config.hub.domain,
  });

  const enqueuedDepositsByDomain = await database.getAllEnqueuedDeposits(domains);

  const queueByKey: Map<string, HubDeposit[]> = new Map();
  for (const deposit of enqueuedDepositsByDomain) {
    const queueKey = `${deposit.domain}-${deposit.tickerHash}`;
    if (!queueByKey.has(queueKey)) {
      queueByKey.set(queueKey, [deposit]);
    } else {
      queueByKey.set(queueKey, [...queueByKey.get(queueKey)!, deposit]);
    }
  }

  if (queueByKey.size === 0) {
    // Resolve reports. Need to get the key by looking at all domains and registered ticker hashes
    const tickerHashes = getConfiguredTickerHashes(config.chains);
    await Promise.all(
      domains.map((domain) => {
        return tickerHashes.map((tickerHash) => {
          const key = `${domain}-${tickerHash}`;
          const report = {
            severity: Severity.Warning,
            type: 'DepositQueueLatencyExceeded',
            ids: [key],
            reason: `${requestContext.origin}, Pending queue latency exceeds threshold ${config.thresholds.maxDepositQueueLatency} for domain-tickerHash ${key}`,
            timestamp: Date.now(),
            logger: logger,
            env: config.environment,
            network: config.network || 'unknown',
          };
          return resolveAlerts(report, logger, { ...config, network: config.network || 'unknown' }, requestContext);
        });
      }),
    );
    return new Map();
  }

  const curTimestamp = getNtpTimeSeconds();
  const latencyByDomainTicker = new Map<string, number>();
  await Promise.all(
    [...queueByKey].map(async (_record) => {
      const [key, deposits] = _record;
      deposits.forEach((deposit) => {
        const _oldest = latencyByDomainTicker.get(key) || 0;
        const _enqueuedTimestamp = +deposit.enqueuedTimestamp;

        if (_oldest === 0 || _enqueuedTimestamp < _oldest) {
          latencyByDomainTicker.set(key, _enqueuedTimestamp);
        }
      });

      const report = {
        severity: Severity.Warning,
        type: 'DepositQueueLatencyExceeded',
        ids: [key],
        reason: `${requestContext.origin}, Pending queue latency exceeds threshold ${config.thresholds.maxDepositQueueLatency} for domain-tickerHash ${key}`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
        network: config.network || 'unknown',
      };

      if (!latencyByDomainTicker.has(key)) {
        // Resolve report
        await resolveAlerts(report, logger, { ...config, network: config.network || 'unknown' }, requestContext);
        return;
      }

      // Send alert if the queue age exceeds the threshold
      const age = curTimestamp - latencyByDomainTicker.get(key)!;
      if (age > config.thresholds.maxDepositQueueLatency!) {
        logger.warn(`Pending queue age for ${key} exceeds threshold`, requestContext, methodContext, {
          age: age.toString(),
          threshold: config.thresholds.maxDepositQueueLatency,
        });
        report.reason = `${report.reason}. (age: ${age})`;
        await sendAlerts(report, logger, { ...config, network: config.network || 'unknown' }, requestContext);
      } else {
        logger.info(`Pending queue age for ${key} within threshold`, requestContext, methodContext, {
          age: age.toString(),
          threshold: config.thresholds.maxDepositQueueLatency,
        });
        await resolveAlerts(report, logger, { ...config, network: config.network || 'unknown' }, requestContext);
      }
    }),
  );
  return latencyByDomainTicker;
};
