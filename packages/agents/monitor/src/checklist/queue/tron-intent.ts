import { QueueType, createLoggingContext, getNtpTimeSeconds } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { Severity } from '../../types';
import { resolveAlerts, sendAlerts } from '../../mockable';

/**
 * Tron-specific intent queue monitoring
 * Provides 1-1 parity with EVM intent queue checks but for Tron chains
 */

export const checkTronFillQueueCount = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronFillQueueCount.name);

  // Filter for Tron chains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  const intentsByDomain = await database.getMessageQueueContents(QueueType.Fill, tronDomains);
  const countsByDomain = new Map<string, number>(
    tronDomains.map((domain) => [domain, intentsByDomain.get(domain)?.length ?? 0]),
  );

  await Promise.allSettled(
    tronDomains.map(async (domain) => {
      const count = countsByDomain.get(domain) ?? 0;
      const threshold = config.thresholds.maxExecutionQueueCount ?? 0;
      const report = {
        severity: Severity.Warning,
        type: 'TronExecutionQueueCountExceeded',
        ids: [domain],
        reason: `${requestContext.origin}, Tron execution queue count ${count} exceeds threshold ${config.thresholds.maxExecutionQueueCount} for domain ${domain}`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };
      if (count > threshold) {
        // Send alerts
        logger.warn(`Tron execution queue count for ${domain} exceeds threshold`, requestContext, methodContext, {
          count,
          threshold: config.thresholds.maxExecutionQueueCount,
        });
        return sendAlerts(report, logger, config, requestContext);
      } else {
        logger.info(`Tron execution queue count for ${domain} within threshold`, requestContext, methodContext, {
          count,
          threshold: config.thresholds.maxExecutionQueueCount,
        });
        return resolveAlerts(report, logger, config, requestContext);
      }
    }),
  );

  logger.debug('Tron execution queue counts', requestContext, methodContext, {
    countsByDomain: Object.fromEntries([...countsByDomain.entries()]),
  });

  return countsByDomain;
};

export const checkTronFillQueueLatency = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronFillQueueLatency.name);

  // Filter for Tron chains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  const intentsByDomain = await database.getMessageQueueContents(QueueType.Fill, tronDomains);

  const latencyByDomain = new Map<string, number>();
  const curTimestamp = getNtpTimeSeconds();
  await Promise.allSettled(
    tronDomains.map(async (domain) => {
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
          type: 'TronExecutionQueueLatencyExceeded',
          ids: [domain],
          reason: `${requestContext.origin}, Tron pending queue latency ${age} exceeds threshold ${config.thresholds.maxExecutionQueueLatency} for domain ${domain}`,
          timestamp: Date.now(),
          logger: logger,
          env: config.environment,
        };
        if (age > config.thresholds.maxExecutionQueueLatency!) {
          // Send alerts
          logger.warn(
            `Tron pending execution queue age for domain-${domain} exceeds threshold`,
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
            `Tron pending execution queue age for domain-${domain} within threshold`,
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

  logger.debug('Tron execution queue latency', requestContext, methodContext, {
    latencyByDomain: Object.fromEntries([...latencyByDomain.entries()]),
  });

  return latencyByDomain;
};

export const checkTronIntentQueueCount = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronIntentQueueCount.name);

  // Filter for Tron chains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  const intentsByDomain = await database.getMessageQueueContents(QueueType.Intent, tronDomains);
  const countsByDomain = new Map<string, number>(
    tronDomains.map((domain) => [domain, intentsByDomain.get(domain)?.length ?? 0]),
  );

  await Promise.allSettled(
    tronDomains.map(async (domain) => {
      const count = countsByDomain.get(domain) ?? 0;
      const threshold = config.thresholds.maxIntentQueueCount ?? 0;
      const report = {
        severity: Severity.Warning,
        type: 'TronIntentQueueCountExceeded',
        ids: [domain],
        reason: `${requestContext.origin}, Tron intent queue count ${count} exceeds threshold ${config.thresholds.maxIntentQueueCount} for domain ${domain}`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };
      if (count > threshold) {
        // Send alerts
        logger.warn(`Tron intent queue count for ${domain} exceeds threshold`, requestContext, methodContext, {
          count,
          threshold: config.thresholds.maxIntentQueueCount,
        });
        return sendAlerts(report, logger, config, requestContext);
      } else {
        logger.info(`Tron intent queue count for ${domain} within threshold`, requestContext, methodContext, {
          count,
          threshold: config.thresholds.maxIntentQueueCount,
        });
        await resolveAlerts(report, logger, config, requestContext);
      }
    }),
  );

  logger.debug('Tron intent queue counts', requestContext, methodContext, {
    countsByDomain: Object.fromEntries([...countsByDomain.entries()]),
  });

  return countsByDomain;
};

export const checkTronIntentQueueLatency = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronIntentQueueLatency.name);

  // Filter for Tron chains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  const intentsByDomain = await database.getMessageQueueContents(QueueType.Intent, tronDomains);

  const latencyByDomain = new Map<string, number>();
  const curTimestamp = getNtpTimeSeconds();
  await Promise.allSettled(
    tronDomains.map(async (domain) => {
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
          type: 'TronIntentQueueLatencyExceeded',
          ids: [domain],
          reason: `${requestContext.origin}, Tron pending queue latency ${age.toString()} exceeds threshold ${config.thresholds.maxIntentQueueLatency} for domain ${domain}`,
          timestamp: Date.now(),
          logger: logger,
          env: config.environment,
        };
        if (age > config.thresholds.maxIntentQueueLatency!) {
          // Send alerts
          logger.warn(
            `Tron pending intent queue age for domain-${domain} exceeds threshold`,
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

  logger.debug('Tron intent queue counts', requestContext, methodContext, {
    latencyByDomain: Object.fromEntries([...latencyByDomain.entries()]),
  });

  return latencyByDomain;
};