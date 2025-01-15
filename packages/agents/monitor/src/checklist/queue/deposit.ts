import {
  createLoggingContext,
  getConfiguredTickerHashes,
  getNtpTimeSeconds,
  HubDeposit,
} from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { Severity } from '../../types';
import { resolveAlerts, sendAlerts } from '../../mockable';

export const checkDepositQueueCount = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkDepositQueueCount.name);

  const domains = Object.keys(config.chains);
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
  };

  if (!aboveThreshold.length) {
    await resolveAlerts(report, logger, config, requestContext);
    logger.info(`Deposit queue counts are within threshold`, requestContext, methodContext, { threshold });
    return queueCountByKey;
  }

  logger.warn(`Deposit queue counts exceed threshold`, requestContext, methodContext, {
    threshold,
    queues: aboveThreshold,
  });

  await sendAlerts(report, logger, config, requestContext);

  return queueCountByKey;
};

export const checkDepositQueueLatency = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkDepositQueueLatency.name);

  const domains = Object.keys(config.chains);
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
          };
          return resolveAlerts(report, logger, config, requestContext);
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
      };

      if (!latencyByDomainTicker.has(key)) {
        // Resolve report
        await resolveAlerts(report, logger, config, requestContext);
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
        await sendAlerts(report, logger, config, requestContext);
      } else {
        logger.info(`Pending queue age for ${key} within threshold`, requestContext, methodContext, {
          age: age.toString(),
          threshold: config.thresholds.maxDepositQueueLatency,
        });
        await resolveAlerts(report, logger, config, requestContext);
      }
    }),
  );
  return latencyByDomainTicker;
};
