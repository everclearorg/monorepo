import { createLoggingContext, getNtpTimeSeconds } from '@chimera-monorepo/utils';
import { BigNumber, utils } from 'ethers';
import { getContext } from '../../context';
import { Severity } from '../../types';
import { resolveAlerts, sendAlerts } from '../../mockable';

/**
 * Tron-specific settlement queue monitoring
 * Provides 1-1 parity with EVM settlement queue checks but for Tron chains
 */

export const checkTronSettlementQueueStatusCount = async (): Promise<Map<string, Map<string, number>>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronSettlementQueueStatusCount.name);

  // Filter for Tron chains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  logger.debug('Tron settlement queue status check start', requestContext, methodContext, {
    tronDomains,
    hubDomain: config.hub.domain,
  });

  // Get all of the queued settlements
  const queuedSettlements = await database.getAllQueuedSettlements(config.hub.domain);
  const statusCountByTicker = new Map<string, Map<string, number>>();
  
  // Ensure queuedSettlements is a Map and handle empty case
  if (!queuedSettlements || !(queuedSettlements instanceof Map) || queuedSettlements.size === 0) {
    return statusCountByTicker;
  }
  
  await Promise.all(
    [...queuedSettlements].map(async (_record) => {
      const [settlementDomain, settlements] = _record;
      
      // Only process if it's a Tron domain
      if (!tronDomains.includes(settlementDomain)) {
        return;
      }
      
      const statusCounts = statusCountByTicker.get(settlementDomain) || new Map<string, number>();
      settlements.forEach((settlement) => {
        // Increment the status count
        const _current = statusCountByTicker.get(settlementDomain)?.get(settlement.status) || 0;
        statusCounts.set(settlement.status, _current + 1);
      });
      statusCountByTicker.set(settlementDomain, statusCounts);
      const addedCount = statusCounts.get('SETTLED') || 0;

      // Send alert if the queue count exceeds the threshold
      const report = {
        severity: Severity.Warning,
        type: 'TronSettlementQueueCountExceeded',
        ids: [settlementDomain],
        reason: `${requestContext.origin}, Tron pending queue count ${addedCount} exceeds threshold ${config.thresholds.maxSettlementQueueCount} for settlementDomain: ${settlementDomain}`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };
      if (addedCount > config.thresholds.maxSettlementQueueCount!) {
        logger.warn(`Tron pending queue count for ${settlementDomain} exceeds threshold`, requestContext, methodContext, {
          addedCount,
          threshold: config.thresholds.maxSettlementQueueCount,
        });
        await sendAlerts(report, logger, config, requestContext);
      } else {
        await resolveAlerts(report, logger, config, requestContext);
      }
    }),
  );
  return statusCountByTicker;
};

export const checkTronSettlementQueueAmount = async (): Promise<Map<string, BigNumber> | undefined> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronSettlementQueueAmount.name);

  // Filter for Tron chains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  logger.debug('Tron settlement queue amount check start', requestContext, methodContext, {
    tronDomains,
    hubDomain: config.hub.domain,
  });

  // Get all of the queued settlements
  const queuedSettlements = await database.getAllQueuedSettlements(config.hub.domain);
  const amountByDomain = new Map<string, BigNumber>();

  // Ensure queuedSettlements is a Map and handle empty case
  if (!queuedSettlements || !(queuedSettlements instanceof Map) || queuedSettlements.size === 0) {
    return amountByDomain;
  }

  // Set up a map of decimals by ticker for Tron chains
  const decimalsByAsset = new Map<string, number>();
  for (const domain of tronDomains) {
    const chainConfig = config.chains[domain];
    for (const [, assetConfig] of Object.entries(chainConfig.assets!)) {
      decimalsByAsset.set(assetConfig.address.toLowerCase(), assetConfig.decimals);
    }
  }

  await Promise.all(
    [...queuedSettlements].map(async (_record) => {
      const [destinationDomain, settlements] = _record;
      
      // Only process if it's a Tron domain
      if (!tronDomains.includes(destinationDomain)) {
        return;
      }
      
      await Promise.all(
        settlements.map(async (settlement) => {
          // Aggregate amount by tickerhash
          if (settlement.status == 'DISPATCHED') return; // Only count the amount for unsettled settlements
          // Get the output asset
          const originIntent = await database.getOriginIntentsById(settlement.id);
          if (!originIntent) return;
          let _amount = amountByDomain.get(destinationDomain);
          const _decimals = decimalsByAsset.get(originIntent.outputAsset.toLowerCase());
          if (_amount && _decimals) {
            _amount = utils.parseUnits(_amount.toString(), _decimals);
          } else {
            _amount = BigNumber.from(0);
          }

          amountByDomain.set(destinationDomain, _amount.add(BigNumber.from(settlement.settlementAmount)));
        }),
      );

      // Send alert if the queue amount exceeds the threshold
      if (!config.thresholds.maxSettlementQueueAssetAmounts[destinationDomain]) {
        logger.warn('No threshold set for Tron maxSettlementQueueAssetAmount', requestContext, methodContext, {
          destinationDomain,
          maxSettlementQueueAssetAmounts: config.thresholds.maxSettlementQueueAssetAmounts,
        });
        return;
      }
      const report = {
        severity: Severity.Warning,
        type: 'TronSettlementQueueAmountExceeded',
        ids: [destinationDomain],
        reason: `${requestContext.origin}, Tron pending queue amount ${amountByDomain.get(destinationDomain)?.toString()} exceeds threshold ${config.thresholds.maxSettlementQueueAssetAmounts} for domain: ${destinationDomain}`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };
      if (
        amountByDomain
          .get(destinationDomain)
          ?.gt(BigNumber.from(config.thresholds.maxSettlementQueueAssetAmounts[destinationDomain]))
      ) {
        logger.warn(`Tron pending queue amount for ${destinationDomain} exceeds threshold`, requestContext, methodContext, {
          amount: amountByDomain.get(destinationDomain)?.toString(),
          threshold: config.thresholds.maxSettlementQueueAssetAmounts,
        });
        await sendAlerts(report, logger, config, requestContext);
      } else {
        await resolveAlerts(report, logger, config, requestContext);
      }
    }),
  );

  return amountByDomain;
};

export const checkTronSettlementQueueLatency = async (): Promise<Map<string, number>> => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(checkTronSettlementQueueLatency.name);

  // Filter for Tron chains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  logger.debug('Tron settlement queue latency check start', requestContext, methodContext, {
    tronDomains,
    hubDomain: config.hub.domain,
  });

  // Get all of the queued settlements
  const queuedSettlements = await database.getAllQueuedSettlements(config.hub.domain);
  const curTimestamp = getNtpTimeSeconds();
  const latencyByTicker = new Map<string, number>();

  // Ensure queuedSettlements is a Map and handle empty case
  if (!queuedSettlements || !(queuedSettlements instanceof Map) || queuedSettlements.size === 0) {
    // resolve all alerts. each alert has to include a settlement domain.
    // assume all registered Tron chains are valid settlement domains
    await Promise.all(
      tronDomains.map(async (settlementDomain) => {
        const report = {
          severity: Severity.Warning,
          type: 'TronSettlementQueueLatencyExceedsThreshold',
          ids: [settlementDomain],
          reason: `${requestContext.origin}, Tron settlement latency exceeds threshold ${config.thresholds.maxSettlementQueueLatency} for settlementDomain: ${settlementDomain}`,
          timestamp: Date.now(),
          logger: logger,
          env: config.environment,
        };
        return resolveAlerts(report, logger, config, requestContext);
      }),
    );
    return latencyByTicker;
  }

  // Filter for Tron domains from the queued settlements
  const tronSettlements = [...queuedSettlements].filter(([domain]) => tronDomains.includes(domain));

  if (tronSettlements.length === 0) {
    return latencyByTicker;
  }

  await Promise.all(
    tronSettlements.map(async (_record) => {
      const [settlementDomain, settlements] = _record;
      
      settlements.forEach((settlement) => {
        // Identify latency by tickerhash
        if (settlement.status == 'DISPATCHED') return; // Only check latency for unsettled settlements
        const _oldest = latencyByTicker.get(settlementDomain) || 0;
        const _settlementTimestamp = settlement.settlementEnqueuedTimestamp!;

        if (_oldest === 0 || _settlementTimestamp < _oldest) {
          latencyByTicker.set(settlementDomain, _settlementTimestamp);
        }
      });

      const report = {
        severity: Severity.Warning,
        type: 'TronSettlementQueueLatencyExceedsThreshold',
        ids: [settlementDomain],
        reason: `${requestContext.origin}, Tron settlement latency exceeds threshold ${config.thresholds.maxSettlementQueueLatency} for settlementDomain: ${settlementDomain}`,
        timestamp: Date.now(),
        logger: logger,
        env: config.environment,
      };

      if (!latencyByTicker.has(settlementDomain)) {
        await resolveAlerts(report, logger, config, requestContext);
        return;
      }

      // Send alert if the settlement queue exceeds the threshold
      const age = curTimestamp - latencyByTicker.get(settlementDomain)!;
      if (age > config.thresholds.maxSettlementQueueLatency!) {
        logger.warn(`Tron settlement latency for ${settlementDomain} exceeds threshold`, requestContext, methodContext, {
          latency: age.toString(),
          threshold: config.thresholds.maxSettlementQueueLatency,
        });
        report.reason = `${report.reason}. (age: ${age})`;
        await sendAlerts(report, logger, config, requestContext);
      } else {
        await resolveAlerts(report, logger, config, requestContext);
      }
    }),
  );
  return latencyByTicker;
};