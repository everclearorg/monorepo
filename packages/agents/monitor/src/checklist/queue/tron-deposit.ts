import {
  createLoggingContext,
  getConfiguredTickerHashes,
  getNtpTimeSeconds,
  HubDeposit,
} from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { Severity } from '../../types';
import { resolveAlerts, sendAlerts } from '../../mockable';

/**
 * Tron-specific deposit queue monitoring
 * Provides 1-1 parity with EVM deposit queue checks but for Tron chains
 */

export const checkTronDepositQueueCount = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronDepositQueueCount.name);

  // Filter for Tron chains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  const enqueuedDepositsByDomain = await database.getAllEnqueuedDeposits(tronDomains);

  const queueCountByKey: Map<string, number> = new Map();
  for (const deposit of enqueuedDepositsByDomain) {
    const queueKey = `tron-${deposit.epoch}-${deposit.domain}-${deposit.tickerHash}`;
    if (queueCountByKey.has(queueKey)) {
      const queueCount = queueCountByKey.get(queueKey)!;
      queueCountByKey.set(queueKey, queueCount + 1);
    } else {
      queueCountByKey.set(queueKey, 1);
    }
  }
  logger.debug('Tron deposit queue counts', requestContext, methodContext, {
    countsByKey: Object.fromEntries([...queueCountByKey.entries()]),
  });

  const threshold = config.thresholds.maxDepositQueueCount ?? 0;
  const aboveThreshold = [];
  for (const queueKey of queueCountByKey.keys()) {
    const queueCount = queueCountByKey.get(queueKey)!;
    if (queueCount < threshold) continue;

    // Log warning
    logger.warn(`Tron deposit queue count for ${queueKey} exceeds threshold`, requestContext, methodContext, {
      queueCount,
      threshold,
    });

    aboveThreshold.push({ queueKey, queueCount });
  }

  const report = {
    severity: Severity.Warning,
    type: 'TronDepositQueueCountExceedsThreshold',
    ids: aboveThreshold.map((it) => it.queueKey),
    reason: `Tron deposit queue counts exceed threshold (${threshold}). \nQueues: ${aboveThreshold.map((q) => `key: ${q.queueKey}, count: ${q.queueCount}`).join(`\n\t`)}`,
    timestamp: Date.now(),
    logger: logger,
    env: config.environment,
    network: config.network || 'unknown',
  };

  if (!aboveThreshold.length) {
    const keys = [...queueCountByKey.keys()];
    report.ids = keys;
    await resolveAlerts(report, logger, { ...config, network: config.network || 'unknown' }, requestContext);
    logger.info(`Tron deposit queue counts are within threshold`, requestContext, methodContext, { threshold, keys });
    return queueCountByKey;
  }

  logger.warn(`Tron deposit queue counts exceed threshold`, requestContext, methodContext, {
    threshold,
    queues: aboveThreshold,
  });

  await sendAlerts(report, logger, { ...config, network: config.network || 'unknown' }, requestContext);

  return queueCountByKey;
};

export const checkTronDepositQueueLatency = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronDepositQueueLatency.name);

  // Filter for Tron chains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  logger.debug('Tron deposit queue latency check start', requestContext, methodContext, {
    tronDomains,
    hubDomain: config.hub.domain,
  });

  const enqueuedDepositsByDomain = await database.getAllEnqueuedDeposits(tronDomains);

  const queueByKey: Map<string, HubDeposit[]> = new Map();
  for (const deposit of enqueuedDepositsByDomain) {
    const queueKey = `tron-${deposit.domain}-${deposit.tickerHash}`;
    if (!queueByKey.has(queueKey)) {
      queueByKey.set(queueKey, [deposit]);
    } else {
      queueByKey.set(queueKey, [...queueByKey.get(queueKey)!, deposit]);
    }
  }

  if (queueByKey.size === 0) {
    // Resolve reports. Need to get the key by looking at all Tron domains and registered ticker hashes
    const tickerHashes = getConfiguredTickerHashes(config.chains);
    await Promise.all(
      tronDomains.map((domain) => {
        return tickerHashes.map((tickerHash) => {
          const key = `tron-${domain}-${tickerHash}`;
          const report = {
            severity: Severity.Warning,
            type: 'TronDepositQueueLatencyExceedsThreshold',
            ids: [key],
            reason: `${requestContext.origin}, Tron pending queue latency exceeds threshold ${config.thresholds.maxDepositQueueLatency} for domain-tickerHash ${key}`,
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
        type: 'TronDepositQueueLatencyExceedsThreshold',
        ids: [key],
        reason: `${requestContext.origin}, Tron pending queue latency exceeds threshold ${config.thresholds.maxDepositQueueLatency} for domain-tickerHash ${key}`,
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
        logger.warn(`Tron pending queue age for ${key} exceeds threshold`, requestContext, methodContext, {
          age: age.toString(),
          threshold: config.thresholds.maxDepositQueueLatency,
        });
        report.reason = `${report.reason}. (age: ${age})`;
        await sendAlerts(report, logger, { ...config, network: config.network || 'unknown' }, requestContext);
      } else {
        logger.info(`Tron pending queue age for ${key} within threshold`, requestContext, methodContext, {
          age: age.toString(),
          threshold: config.thresholds.maxDepositQueueLatency,
        });
        await resolveAlerts(report, logger, { ...config, network: config.network || 'unknown' }, requestContext);
      }
    }),
  );
  return latencyByDomainTicker;
};