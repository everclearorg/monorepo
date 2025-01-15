import { Logger, MethodContext, RequestContext, createMethodContext } from '../logging';
import { jsonifyError } from '../types';
import { BetterUptimeConfig, Severity, Report } from '../helpers';
import { axiosPost, axiosGet } from './mockable';

// Create a uniquely serialized and searchable ids for matching reports.
export const createUniqueIds = (ids: string[]): string => {
  return `<ids: ${ids.join(',')}>`;
};

export const BETTERUPTIME_INCIDENTS_URL = 'https://uptime.betterstack.com/api/v2/incidents';

type BetteruptimeIncident = {
  id: string;
  type: string;
  attributes: { status: string; name: string; cause: string; started_at: string };
};

const createAlertName = (report: Report): string => {
  const { env, type } = report;
  return `Everclear ${env} Monitor - ${type}`;
};

const validateBetterUptimeConfig = (
  betterUptime: BetterUptimeConfig,
  logger: Logger,
  requestContext: RequestContext,
  methodContext: MethodContext,
): boolean => {
  // Validate betterUptime config
  if (!betterUptime) {
    logger.warn('Better uptime config not set', requestContext, methodContext);
    return false;
  }

  if (!betterUptime.apiKey || !betterUptime.requesterEmail) {
    logger.warn('Better uptime api key or requester email not set', requestContext, methodContext);
    return false;
  }

  return true;
};

const getMatchingIncidents = async (
  report: Report,
  betterUptime: BetterUptimeConfig,
  byName: boolean,
  requestContext: RequestContext,
  methodContext: MethodContext,
): Promise<BetteruptimeIncident[]> => {
  // Create incident name
  const name = createAlertName(report);

  const { timestamp, reason, ids, logger, type, severity, env } = report;
  const loggableReport = {
    timestamp,
    reason,
    ids,
    severity,
    env,
    type,
  };

  logger.info('Checking for matching incidents', requestContext, methodContext, {
    report: loggableReport,
    name,
  });

  // NOTE: only returns max 50 incidents from last 24h. can improve this logic by tracking the incident
  // ids to report in the cache.
  const from = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const formattedDate = from.toISOString().split('T')[0];
  const {
    data: { data: incidents },
  } = await axiosGet(`${BETTERUPTIME_INCIDENTS_URL}?per_page=50&from=${formattedDate}`, {
    headers: {
      Authorization: `Bearer ${betterUptime!.apiKey}`,
    },
  });

  const uniqueIds = createUniqueIds(report.ids);

  return incidents.filter(
    (i: BetteruptimeIncident) =>
      ['Started', 'Acknowledged'].includes(i.attributes.status) &&
      (byName ? i.attributes.name === name : i.attributes.name === name && i.attributes.cause.includes(uniqueIds)),
  );
};

/**
 * Helper function to send alerts to create incidents if one doesnt already exist
 * in the last 50 incidents from the last 24h.
 * @dev If the IDs cannot be found in the `reason`, or there are no ids on the report,
 * existing incidents wont be detected properly and alerts will be sent.
 * @param report The report that will be sent in the alert
 * @param betterUptime The better uptime config
 * @param requestContext The request context for the logger
 * @param byName Choose if the alert should be grouped by name
 */
export const alertViaBetterUptimeIfNeeded = async (
  report: Report,
  betterUptime: BetterUptimeConfig,
  requestContext: RequestContext,
  byName: boolean = false,
) => {
  // Create method context for the logger
  const methodContext = createMethodContext(alertViaBetterUptime.name);

  const { timestamp, reason, ids, logger, type, severity, env } = report;
  const loggableReport = {
    timestamp,
    reason,
    ids,
    severity,
    env,
    type,
  };

  // Validate betterUptime config
  if (!validateBetterUptimeConfig(betterUptime, logger, requestContext, methodContext)) {
    return;
  }

  // If there are no IDs on the report, we cannot safely eliminate any incidents
  // (same report type can be issued for multiple different IDs)
  if (report.ids.length === 0) {
    return alertViaBetterUptime(report, betterUptime, requestContext);
  }

  // Get matching reports
  const matching = await getMatchingIncidents(report, betterUptime, byName, requestContext, methodContext);
  if (matching.length) {
    logger.warn('Matching incidents found, not creating another.', requestContext, methodContext, {
      report: loggableReport,
      incidents: matching,
    });
    return;
  }
  return alertViaBetterUptime(report, betterUptime, requestContext);
};

/**
 * Helper function to send alerts with better uptime api using axiosPost
 * @param report The report that will be sent in the alert
 * @param betterUptime The better uptime config
 * @param requestContext The request context for the logger
 */
export const alertViaBetterUptime = async (
  report: Report,
  betterUptime: BetterUptimeConfig,
  requestContext: RequestContext,
) => {
  // Create method context for the logger
  const methodContext = createMethodContext(alertViaBetterUptime.name);

  const { timestamp, reason, ids, logger, severity, env, type } = report;
  const loggableReport = {
    timestamp,
    reason,
    ids,
    severity,
    env,
    type,
  };

  // Validate betterUptime config
  if (!validateBetterUptimeConfig(betterUptime, logger, requestContext, methodContext)) {
    return;
  }

  logger.info('Sending message to better uptime', requestContext, methodContext, { report: loggableReport });

  try {
    const response = await axiosPost(
      BETTERUPTIME_INCIDENTS_URL,
      {
        name: createAlertName(report),
        summary: `Everclear ${env} Alert - ${reason}`,
        description: JSON.stringify({
          severity: severity.toString(),
          timestamp,
          reason,
          ids,
          env,
        }),
        push: true,
        sms: false,
        call: severity === Severity.Critical,
        email: true,
        team_wait: 1,
        requester_email: betterUptime!.requesterEmail,
      },
      {
        headers: { Authorization: `Bearer ${betterUptime!.apiKey}` },
      },
    );
    return response;
  } catch (e) {
    logger.error(`Error sending betterUptime alert`, requestContext, methodContext, jsonifyError(e as Error), {
      report: loggableReport,
    });
    return;
  }
};

/**
 * Resolves any matching incidents.
 * @param report The report that will be sent in the alert
 * @param betterUptime The better uptime config
 * @param requestContext The request context for the logger
 * @param byName Choose if the alert should be grouped by name
 */
export const resolveAlertViaBetterUptime = async (
  report: Report,
  betterUptime: BetterUptimeConfig,
  requestContext: RequestContext,
  byName: boolean = false,
) => {
  // Create method context for the logger
  const methodContext = createMethodContext(resolveAlertViaBetterUptime.name);

  const { timestamp, reason, ids, logger, type, severity, env } = report;
  const loggableReport = {
    timestamp,
    reason,
    ids,
    severity,
    env,
    type,
  };

  // Validate betterUptime config
  if (!validateBetterUptimeConfig(betterUptime, logger, requestContext, methodContext)) {
    return;
  }

  // If there are no IDs on the report and there is no intention to resolve all incidents of the type,
  // we cannot safely eliminate any incidents (same report type can be issued for multiple different IDs)
  if (report.ids.length === 0 && !byName) {
    logger.warn('No ids in report, cannot safely resolve incidents', requestContext, methodContext, {
      report: loggableReport,
    });
    return;
  }

  // Get matching alerts
  // TODO: should ideally pull _all_ incidents, not only the latest 50 in last 24h
  const matching = await getMatchingIncidents(report, betterUptime, byName, requestContext, methodContext);
  if (!matching.length) {
    logger.info('No matching incidents found to resolve', requestContext, methodContext, { report: loggableReport });
    return;
  }

  // Resolve all matched incidents
  await Promise.allSettled(
    matching.map(async (incident) => {
      const response = await axiosPost(
        `${BETTERUPTIME_INCIDENTS_URL}/${incident.id}/resolve`,
        {
          resolved_by: betterUptime!.requesterEmail,
        },
        {
          headers: { Authorization: `Bearer ${betterUptime!.apiKey}`, ['Content-Type']: `application/json` },
        },
      );
      return response;
    }),
  );

  logger.info('Resolved all incidents', requestContext, methodContext, { report: loggableReport, matching });
};
