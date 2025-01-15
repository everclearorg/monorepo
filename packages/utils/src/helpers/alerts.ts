// Internal imports
import {
  alertViaBetterUptimeIfNeeded,
  createUniqueIds,
  resolveAlertViaBetterUptime,
  alertDiscord,
  alertTelegram,
} from '../alerts';
import { AlertConfig, Report } from './config';
// External imports
import { Logger, RequestContext, createMethodContext } from '../logging';

const preprocessReport = (report: Report, config: AlertConfig): Report => ({
  ...report,
  // prepend unique ids to reason to make it searchable
  reason: `${report.reason}#${createUniqueIds(report.ids)}`,
  env: `${report.env} - ${config.network}`,
});

/**
 * Sends all alerts at once
 * @param report The report that will be sent in the alert
 * @param logger The logger that will be used to log that the alerts have been sent
 * @param config The watcher config
 * @param requestContext The request context for the logger
 * @param byName Choose if the alert should be grouped by name
 */
export async function sendAlerts(
  report: Report,
  logger: Logger,
  config: AlertConfig,
  requestContext: RequestContext,
  byName: boolean = false,
): Promise<void> {
  const methodContext = createMethodContext(sendAlerts.name);

  const alertReport = preprocessReport(report, config);
  const alertPromises = [];

  //TODO: Choose channels based on severity
  if (config.discord) {
    alertPromises.push(alertDiscord(alertReport, config.discord.url, requestContext));
  }
  if (config.telegram) {
    alertPromises.push(alertTelegram(alertReport, config.telegram, requestContext));
  }
  if (config.betterUptime) {
    alertPromises.push(alertViaBetterUptimeIfNeeded(alertReport, config.betterUptime, requestContext, byName));
  }

  await Promise.allSettled(alertPromises);

  logger.warn('Alerts sent!!!', requestContext, methodContext, alertReport);
}

/**
 * Resolves all alerts at once
 * @param report The report that will be used to resolve the alert
 * @param logger The logger that will be used to log that the alerts have been resolved
 * @param config The watcher config
 * @param requestContext The request context for the logger
 * @param byName Choose if the alert should be grouped by name
 */
export async function resolveAlerts(
  report: Report,
  logger: Logger,
  config: AlertConfig,
  requestContext: RequestContext,
  byName: boolean = false,
): Promise<void> {
  const methodContext = createMethodContext(resolveAlerts.name);

  const alertReport = preprocessReport(report, config);

  const resolvePromises = [];

  // //TODO: Implement report tracking in cache
  // if (config.discord) {
  //   resolvePromises.push(resolveDiscordAlert(alertReport, config.discord.url, requestContext));
  // }
  // if (config.telegram) {
  //   resolvePromises.push(resolveTelegramAlert(alertReport, config.telegram, requestContext));
  // }
  if (config.betterUptime) {
    resolvePromises.push(resolveAlertViaBetterUptime(alertReport, config.betterUptime, requestContext, byName));
  }

  await Promise.allSettled(resolvePromises);

  logger.info('Alerts resolved!!!', requestContext, methodContext, alertReport);
}
