import { RequestContext, createMethodContext } from '@chimera-monorepo/utils';
import { TelegramConfig, Severity, Report } from '../lib/entities';
import { axiosPost } from '../mockable';

/**
/**
 * Sends alerts to telegram using axiosPost
 * @param report The report that will be sent in the alert
 * @param telegram The telegram config
 * @param requestContext The request context for the logger
 * @returns The response from telegram api
 */
export const alertTelegram = async (report: Report, telegram: TelegramConfig, requestContext: RequestContext) => {
  const methodContext = createMethodContext(alertTelegram.name);
  const { timestamp, reason, domains, logger, type, severity, env } = report;
  if (!telegram) {
    logger.warn('Telegram config not set', requestContext, methodContext);
    return;
  }

  if (!telegram.apiKey || !telegram.chatId) {
    logger.warn('Telegram api key or chat id not set', requestContext, methodContext);
    return;
  }

  const _severity = severity ? severity : Severity.Informational;

  logger.info('Sending message via telegram', requestContext, methodContext, {
    timestamp,
    reason,
    domains,
    severity,
  });

  const message = `
    <b>Watcher ${env} ${_severity} Alert!</b>
    <strong>Reason: </strong><code>${reason}</code>
    <strong>Type: </strong><code>${type}</code>
    <strong>Environment: </strong><code>${env}</code>
    <strong>Timestamp: </strong><code>${new Date(timestamp).toISOString()}</code>
    <strong>Domains: </strong> <code>${domains.join(', ')}</code>
    <strong>Rpcs: </strong> 
    `;
  try {
    return await axiosPost(`https://api.telegram.org/bot${telegram.apiKey}/sendMessage`, {
      chat_id: telegram.chatId,
      text: message,
      parse_mode: 'Html',
    });
  } catch (e) {
    logger.error(`Error sending telegram alert because of error: ${e}`, requestContext, methodContext);
    return;
  }
};
