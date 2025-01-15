// Internal imports
import { alertViaBetterUptime, alertDiscord, alertTelegram, alertSMS } from '../alerts';

// External imports
import { Logger, RequestContext, createMethodContext } from '@chimera-monorepo/utils';
import { Report, WatcherConfig } from '../lib/entities';

/**
 * Sends all alerts at once
 * @param report The report that will be sent in the alert
 * @param logger The logger that will be used to log that the alerts have been sent
 * @param config The watcher config
 * @param requestContext The request context for the logger
 */
export async function sendAlerts(
  report: Report,
  logger: Logger,
  config: WatcherConfig,
  requestContext: RequestContext,
): Promise<void> {
  const methodContext = createMethodContext(sendAlerts.name);

  const alertPromises = [];

  if (config.discordHookUrl) {
    alertPromises.push(alertDiscord(report, config.discordHookUrl, requestContext));
  }
  if (
    config.twilio.number &&
    config.twilio.accountSid &&
    config.twilio.authToken &&
    config.twilio.toPhoneNumbers.length
  ) {
    alertPromises.push(alertSMS(report, config.twilio, requestContext));
  }
  if (config.telegram.apiKey && config.telegram.chatId) {
    alertPromises.push(alertTelegram(report, config.telegram, requestContext));
  }
  if (config.betterUptime.apiKey && config.betterUptime.requesterEmail) {
    alertPromises.push(alertViaBetterUptime(report, config.betterUptime, requestContext));
  }

  await Promise.allSettled(alertPromises);

  const { logger: _, ...toLog } = report;

  logger.warn('Alerts sent!!!', requestContext, methodContext, { report: toLog });
}
