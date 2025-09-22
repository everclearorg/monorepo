import { Logger, MethodContext, RequestContext, createMethodContext } from '../logging';
import { jsonifyError } from '../types';
import { BetterUptimeConfig, Severity, Report } from '../helpers';
import { axiosPost, axiosGet } from './mockable';
import { AxiosError } from 'axios';

// Create a uniquely serialized and searchable ids for matching reports.
export const createUniqueIds = (ids: string[]): string => {
  return `<ids: ${ids.join(',')}>`;
};

export const BETTERUPTIME_INCIDENTS_URL = 'https://uptime.betterstack.com/api/v3/incidents';

type BetteruptimeIncidentAttributes = {
  name: string;
  http_method?: string;
  cause: string;
  url?: string;
  incident_group_id?: string;
  started_at: string;
  acknowledged_at?: string;
  acknowledged_by?: string;
  resolved_at?: string;
  resolved_by?: string;
  status: 'Started' | 'Acknowledged' | 'Resolved';
  team_name: string;
  response_content?: string;
  response_options?: string;
  regions?: string;
  response_url?: string;
  screenshot_url?: string;
  origin_url?: string;
  escalation_policy_id?: string;
  call: boolean;
  sms: boolean;
  email: boolean;
  push: boolean;
  critical_alert: boolean;
  metadata: BetteruptimeHeartbeatMetadata | BetteruptimeTypedMetadata;
};

type Metadata = { type: string; value: string };
type BetteruptimeHeartbeatMetadata = { Group: Metadata[] };
type BetteruptimeTypedMetadata = {
  affected_ids: Metadata[];
  everclear_env: Metadata[];
  report_type: Metadata[];
  severity_level: Metadata[];
  timestamp: Metadata[];
  unique_identifier: Metadata[];
};

type BetteruptimeIncidentRelationships = {
  heartbeat: { data: { id: string; type: 'heartbeat ' } };
};
type BetteruptimeIncident = {
  id: string;
  type: string;
  attributes: BetteruptimeIncidentAttributes;
  relationships: Partial<BetteruptimeIncidentRelationships>;
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

export const getMatchingIncidents = async (
  report: Report,
  betterUptime: BetterUptimeConfig,
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

  // NOTE: only returns max 50 incidents. can improve this logic by tracking the incident

  // Use v3 API enhanced filtering - only get unresolved incidents
  // Also filter by environment and report type for more precise matching
  const queryParams = new URLSearchParams({
    resolved: 'false',
    per_page: '50',
  });

  // Add metadata filtering for better incident matching in v3
  if (report.ids.length > 0) {
    // Filter by unique identifier metadata for exact matching
    queryParams.append(`metadata[unique_identifier][][value]`, createUniqueIds(report.ids));
  }
  queryParams.append(`metadata[everclear_env][][value]`, report.env);
  queryParams.append(`metadata[report_type][][value]`, report.type);

  const {
    data: { data: _incidents },
  } = await axiosGet(`${BETTERUPTIME_INCIDENTS_URL}?${queryParams.toString()}`, {
    headers: {
      Authorization: `Bearer ${betterUptime!.apiKey}`,
    },
  });
  const incidents = _incidents as BetteruptimeIncident[];
  const uniqueIds = createUniqueIds(report.ids);

  // Enhanced filtering with v3 API - metadata filtering is already applied in the query
  // but we still need client-side filtering for additional safety
  return incidents.filter((i: BetteruptimeIncident) => {
    if (!['Started', 'Acknowledged'].includes(i.attributes.status)) {
      return false;
    }
    if (i.attributes.name !== name) {
      return false;
    }
    // incident active, shares a name
    const uids = (i.attributes.metadata as BetteruptimeTypedMetadata)?.unique_identifier ?? [];
    const values = uids.map((i) => i.value);
    if (!values.includes(uniqueIds)) {
      return false;
    }
    return true;
  });
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
  const matching = await getMatchingIncidents(report, betterUptime, requestContext, methodContext);
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
        call: severity === Severity.Critical,
        sms: false,
        email: true,
        critical_alert: severity === Severity.Critical,
        requester_email: betterUptime!.requesterEmail,
        // Enhanced v3 metadata for better incident categorization and filtering
        metadata: {
          everclear_env: [env],
          report_type: [type],
          severity_level: [severity.toString()],
          affected_ids: ids.length > 0 ? ids : ['none'],
          timestamp: [timestamp.toString()],
          unique_identifier: [createUniqueIds(ids)],
        },
      },
      {
        headers: { Authorization: `Bearer ${betterUptime!.apiKey}` },
      },
    );
    return response;
  } catch (e) {
    const error = e as unknown as AxiosError;
    // Enhanced error handling for v3 API responses
    if (error.response?.status === 422) {
      logger.error(`BetterUptime v3 validation error`, requestContext, methodContext, jsonifyError(e as Error), {
        status: error.response.status,
        data: error.response.data,
        report: loggableReport,
      });
    } else if (error.response?.status === 429) {
      logger.error(`BetterUptime v3 rate limit exceeded`, requestContext, methodContext, jsonifyError(e as Error), {
        status: error.response.status,
        retryAfter: error.response.headers?.['retry-after'],
        report: loggableReport,
      });
    } else {
      logger.error(`Error sending betterUptime alert`, requestContext, methodContext, jsonifyError(e as Error), {
        report: loggableReport,
      });
    }
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
  const matching = await getMatchingIncidents(report, betterUptime, requestContext, methodContext);
  if (!matching.length) {
    logger.info('No matching incidents found to resolve', requestContext, methodContext, { report: loggableReport });
    return;
  }

  // Resolve all matched incidents
  const resolveResults = await Promise.allSettled(
    matching.map(async (incident) => {
      try {
        const response = await axiosPost(
          `${BETTERUPTIME_INCIDENTS_URL}/${incident.id}/resolve`,
          {
            resolved_by: betterUptime!.requesterEmail,
          },
          {
            headers: { Authorization: `Bearer ${betterUptime!.apiKey}`, ['Content-Type']: `application/json` },
          },
        );
        return { incidentId: incident.id, status: 'resolved', response };
      } catch (e) {
        const error = e as unknown as AxiosError;
        // Handle v3 specific responses
        if (error.response?.status === 409) {
          logger.info(`Incident ${incident.id} was already resolved`, requestContext, methodContext);
          return { incidentId: incident.id, status: 'already_resolved' };
        } else if (error.response?.status === 404) {
          logger.warn(`Incident ${incident.id} not found`, requestContext, methodContext);
          return { incidentId: incident.id, status: 'not_found' };
        } else {
          logger.error(`Error resolving incident ${incident.id}`, requestContext, methodContext, jsonifyError(error));
          return { incidentId: incident.id, status: 'error', error: jsonifyError(error) };
        }
      }
    }),
  );

  // Log resolution results
  const successfulResolutions = resolveResults.filter(
    (result) => result.status === 'fulfilled' && ['resolved', 'already_resolved'].includes(result.value.status),
  );

  logger.info(`Resolved ${successfulResolutions.length}/${matching.length} incidents`, requestContext, methodContext, {
    report: loggableReport,
    results: resolveResults.map((r) => (r.status === 'fulfilled' ? r.value : r.reason)),
  });
};
