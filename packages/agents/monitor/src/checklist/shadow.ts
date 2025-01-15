import { createLoggingContext, ShadowEvent } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { Severity, DataExportStatus, DataExportLatency } from '../types';
import { resolveAlerts, sendAlerts } from '../mockable';

export const checkShadowExportStatus = async (shouldAlert = true): Promise<DataExportStatus | null> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkShadowExportStatus.name);

  if (!config.shadowTables) {
    logger.warn('Shadow tables list is empty', requestContext, methodContext);
    return null;
  }

  const lastSavedTimestamp = await database.getCheckPoint('shadow_export_timestamp');
  const latestTimestamp = await database.getLatestTimestamp(config.shadowTables, 'timestamp');
  const now = new Date();
  const diff = (now.getTime() - latestTimestamp.getTime()) / 1000;

  const dataExportStatus: DataExportStatus = {
    latestTimestamp,
    now,
    diff,
  };

  if (lastSavedTimestamp === latestTimestamp.getTime()) {
    logger.debug('Shadow data export status has not changed', requestContext, methodContext, dataExportStatus);
    return dataExportStatus;
  }

  await database.saveCheckPoint('shadow_export_timestamp', latestTimestamp.getTime());

  logger.debug('Checking shadow data export status', requestContext, methodContext, dataExportStatus);

  if (shouldAlert) {
    const report = {
      severity: Severity.Warning,
      type: 'ShadowDataExportDelayed',
      ids: [],
      reason: `The shadow data export is behind by ${diff} seconds`,
      timestamp: Date.now(),
      logger: logger,
      env: config.environment,
    };
    const threshold = config.thresholds.maxShadowExportDelay ?? 0;
    if (threshold > 0 && diff > threshold) {
      logger.warn('The shadow data export is behind by a threshold of seconds', requestContext, methodContext, {
        diff,
        threshold,
      });

      await sendAlerts(report, logger, config, requestContext);
    } else {
      await resolveAlerts(report, logger, config, requestContext, true);
    }
  }

  return dataExportStatus;
};

export const checkShadowExportLatency = async (shouldAlert = true): Promise<DataExportLatency> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkShadowExportLatency.name);

  const dataExportHighLatency: DataExportLatency = [];
  if (!config.shadowTables) {
    logger.warn('Shadow tables list is empty', requestContext, methodContext);
    return dataExportHighLatency;
  }

  const threshold = config.thresholds.maxShadowExportLatency;
  if (!threshold) {
    logger.warn('Shadow data export latency threshold not set', requestContext, methodContext);
    return dataExportHighLatency;
  }

  logger.debug('Checking shadow data export latency', requestContext, methodContext);

  const results = await Promise.all(
    config.shadowTables.map(async (table) => {
      let from = await database.getCheckPoint(`${table}_latency`);
      if (from === 0) from = Date.now();
      const events = await database.getShadowEvents(table, new Date(from), 100);
      const delayedEvents: ShadowEvent[] = [];
      if (events.length) {
        await database.saveCheckPoint(`${table}_latency`, events[events.length - 1].timestamp.getTime());
        for (const event of events) {
          const latency = (event.timestamp.getTime() - event.blockTimestamp.getTime()) / 1000;
          if (latency > threshold) delayedEvents.push(event);
        }
      }

      return { table, delayedEvents };
    }),
  );

  for (const result of results) {
    for (const event of result.delayedEvents) {
      dataExportHighLatency.push({
        name: result.table,
        latency: (event.timestamp.getTime() - event.blockTimestamp.getTime()) / 1000,
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash,
      });
    }
  }

  const report = {
    severity: Severity.Warning,
    type: 'ShadowDataExportHighLatency',
    ids: [],
    reason: JSON.stringify({ info: 'The shadow data export high latency detected', data: dataExportHighLatency }),
    timestamp: Date.now(),
    logger: logger,
    env: config.environment,
  };

  if (shouldAlert && dataExportHighLatency.length) {
    logger.warn('The shadow data export high latency detected', requestContext, methodContext, dataExportHighLatency);
    await sendAlerts(report, logger, config, requestContext);
  } else {
    // No auto resolving because latency spikes should be investigated even if they don't repeat.
  }

  return dataExportHighLatency;
};
