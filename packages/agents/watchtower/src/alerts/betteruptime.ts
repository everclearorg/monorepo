// Internal imports
import { RequestContext, createMethodContext } from '@chimera-monorepo/utils';
import { BetterUptimeConfig, Severity, Report } from '../lib/entities';
import { axiosPost } from '../mockable';

/**
 * Helper function to send alerts with better uptime api using axiosPost
 * @param report The report that will be sent in the alert
 * @param betterUptime The better uptime config
 * @param requestContext The request context for the logger
 * @returns The response from better uptime
 */
export const alertViaBetterUptime = async (
  report: Report,
  betterUptime: BetterUptimeConfig,
  requestContext: RequestContext,
) => {
  // Create method context for the logger
  const methodContext = createMethodContext(alertViaBetterUptime.name);

  const { timestamp, reason, domains, logger, type, severity, env } = report;
  if (!betterUptime) {
    logger.warn('Better uptime config not set', requestContext, methodContext);
    return;
  }

  if (!betterUptime.apiKey || !betterUptime.requesterEmail) {
    logger.warn('Better uptime api key or requester email not set', requestContext, methodContext);
    return;
  }

  logger.info('Sending message to better uptime', requestContext, methodContext, {
    timestamp,
    reason,
    domains,
  });
  try {
    const response = await axiosPost(
      'https://betteruptime.com/api/v2/incidents',
      {
        name: `Everclear ${env} Watcher - ${type}`,
        summary: `Everclear ${env} Watcher Alert - ${reason}`,
        description: JSON.stringify({
          severity: severity.toString(),
          timestamp,
          reason,
          domains,
          env,
        }),
        push: true,
        sms: false,
        call: severity === Severity.Critical,
        email: true,
        team_wait: 1,
        requester_email: betterUptime.requesterEmail,
      },
      {
        headers: { Authorization: `Bearer ${betterUptime.apiKey}` },
      },
    );
    return response;
  } catch (e) {
    logger.error(`Error sending betterUptime alert because of error: ${e}`, requestContext, methodContext);
    return;
  }
};
