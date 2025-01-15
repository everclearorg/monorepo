import { QueueType, createLoggingContext, getNtpTimeSeconds } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { Severity } from '../../types';
import { resolveAlerts, sendAlerts } from '../../mockable';

export const checkFillQueueCount = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkFillQueueCount.name);

  const domains = Object.keys(config.chains);
  const intentsByDomain = await database.getMessageQueueContents(QueueType.Fill, domains);
  const countsByDomain = new Map<string, number>(
    domains.map((domain) => [domain, intentsByDomain.get(domain)?.length ?? 0]),
  );

  await Promise.allSettled(
    domains.map(async (domain) => {
      const count = countsByDomain.get(domain) ?? 0;
      const threshold = config.thresholds.maxExecutionQueueCount ?? 0;
      const report = {
        severity: Severity.Warning,
        type: 'ExecutionQueueCountExceeded',
        ids: [domain],
        reason: `${requestContext.origin}, Execution queue count ${count} exeeds threshold ${config.thresholds.maxExecutionQueueCount} for domain ${domain}`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };
      if (count > threshold) {
        // Send alerts
        logger.warn(`Execution queue count for ${domain} exceeds threshold`, requestContext, methodContext, {
          count,
          threshold: config.thresholds.maxExecutionQueueCount,
        });
        return sendAlerts(report, logger, config, requestContext);
      } else {
        logger.info(`Execution queue count for ${domain} within threshold`, requestContext, methodContext, {
          count,
          threshold: config.thresholds.maxExecutionQueueCount,
        });
        return resolveAlerts(report, logger, config, requestContext);
      }
    }),
  );

  logger.debug('Execution queue counts', requestContext, methodContext, {
    countsByDomain: Object.fromEntries([...countsByDomain.entries()]),
  });

  return countsByDomain;
};

export const checkFillQueueLatency = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkFillQueueLatency.name);

  const domains = Object.keys(config.chains);
  const intentsByDomain = await database.getMessageQueueContents(QueueType.Fill, domains);

  const latencyByDomain = new Map<string, number>();
  const curTimestamp = getNtpTimeSeconds();
  await Promise.allSettled(
    domains.map(async (domain) => {
      if (intentsByDomain.has(domain)) {
        const intents = intentsByDomain.get(domain)!;
        intents.forEach((intent) => {
          const _oldest = latencyByDomain.get(domain) || 0;
          const _addedTimestamp = intent.timestamp;

          if (_oldest === 0 || _addedTimestamp < _oldest) {
            latencyByDomain.set(domain, _addedTimestamp);
          }
        });

        const age = curTimestamp - latencyByDomain.get(domain)!;
        const report = {
          severity: Severity.Warning,
          type: 'ExecutionQueueLatencyExceeded',
          ids: [domain],
          reason: `${requestContext.origin}, Pending queue latency ${age} exceeds threshold ${config.thresholds.maxExecutionQueueLatency} for domain ${domain}`,
          timestamp: Date.now(),
          logger: logger,
          env: config.environment,
        };
        if (age > config.thresholds.maxExecutionQueueLatency!) {
          // Send alerts
          logger.warn(
            `Pending execution queue age for domain-${domain} exceeds threshold`,
            requestContext,
            methodContext,
            {
              age: age,
              threshold: config.thresholds.maxExecutionQueueLatency,
            },
          );
          await sendAlerts(report, logger, config, requestContext);
        } else {
          logger.info(
            `Pending execution queue age for domain-${domain} within threshold`,
            requestContext,
            methodContext,
            {
              age: age,
              threshold: config.thresholds.maxExecutionQueueLatency,
            },
          );
          await resolveAlerts(report, logger, config, requestContext);
        }
      }
    }),
  );

  logger.debug('Execution queue latency', requestContext, methodContext, {
    latencyByDomain: Object.fromEntries([...latencyByDomain.entries()]),
  });

  return latencyByDomain;
};

export const checkIntentQueueCount = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkIntentQueueCount.name);

  const domains = Object.keys(config.chains);
  const intentsByDomain = await database.getMessageQueueContents(QueueType.Intent, domains);
  const countsByDomain = new Map<string, number>(
    domains.map((domain) => [domain, intentsByDomain.get(domain)?.length ?? 0]),
  );

  await Promise.allSettled(
    domains.map(async (domain) => {
      const count = countsByDomain.get(domain) ?? 0;
      const threshold = config.thresholds.maxIntentQueueCount ?? 0;
      const report = {
        severity: Severity.Warning,
        type: 'IntentQueueCountExceeded',
        ids: [domain],
        reason: `${requestContext.origin}, Intent queue count ${count} exeeds threshold ${config.thresholds.maxIntentQueueCount} for domain ${domain}`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };
      if (count > threshold) {
        // Send alerts
        logger.warn(`Intent queue count for ${domain} exceeds threshold`, requestContext, methodContext, {
          count,
          threshold: config.thresholds.maxIntentQueueCount,
        });
        return sendAlerts(report, logger, config, requestContext);
      } else {
        logger.info(`Intent queue count for ${domain} within threshold`, requestContext, methodContext, {
          count,
          threshold: config.thresholds.maxIntentQueueCount,
        });
        await resolveAlerts(report, logger, config, requestContext);
      }
    }),
  );

  logger.debug('Intent queue counts', requestContext, methodContext, {
    countsByDomain: Object.fromEntries([...countsByDomain.entries()]),
  });

  return countsByDomain;
};

export const checkIntentQueueLatency = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkIntentQueueLatency.name);

  const domains = Object.keys(config.chains);
  const intentsByDomain = await database.getMessageQueueContents(QueueType.Intent, domains);

  const latencyByDomain = new Map<string, number>();
  const curTimestamp = getNtpTimeSeconds();
  await Promise.allSettled(
    domains.map(async (domain) => {
      if (intentsByDomain.has(domain)) {
        const intents = intentsByDomain.get(domain)!;
        intents.forEach((intent) => {
          const _oldest = latencyByDomain.get(domain) || 0;
          const _addedTimestamp = intent.timestamp;

          if (_oldest === 0 || _addedTimestamp < _oldest) {
            latencyByDomain.set(domain, _addedTimestamp);
          }
        });

        const age = curTimestamp - latencyByDomain.get(domain)!;
        const report = {
          severity: Severity.Warning,
          type: 'IntentQueueLatencyExceeded',
          ids: [domain],
          reason: `${requestContext.origin}, Pending queue latency ${age.toString()} exceeds threshold ${config.thresholds.maxIntentQueueLatency} for domain ${domain}`,
          timestamp: Date.now(),
          logger: logger,
          env: config.environment,
        };
        if (age > config.thresholds.maxIntentQueueLatency!) {
          // Send alerts
          logger.warn(
            `Pending intent queue age for domain-${domain} exceeds threshold`,
            requestContext,
            methodContext,
            {
              age: age,
              threshold: config.thresholds.maxIntentQueueLatency,
            },
          );
          await sendAlerts(report, logger, config, requestContext);
        } else {
          await resolveAlerts(report, logger, config, requestContext);
        }
      }
    }),
  );

  logger.debug('Intent queue counts', requestContext, methodContext, {
    latencyByDomain: Object.fromEntries([...latencyByDomain.entries()]),
  });

  return latencyByDomain;
};
