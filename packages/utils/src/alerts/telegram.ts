import { Logger, MethodContext, RequestContext, createMethodContext } from '../logging';
import { jsonifyError } from '../types';
import { TelegramConfig, Report } from '../helpers';
import { axiosPost } from './mockable';

/**
 * Creates a formatted message for Telegram alerts
 * @param report The report to create the message from
 * @param isResolved Whether the alert is being resolved
 * @returns Formatted message string
 */
export const createTelegramMessage = (report: Report, isResolved: boolean): string => {
  const { timestamp, reason, ids, type, severity, env } = report;
  const status = isResolved ? 'Resolved!' : 'Alert!';
  return `
    <b>Monitor ${env} ${severity} - ${status}</b>
    <strong>Reason: </strong><code>${reason}</code>
    <strong>Type: </strong><code>${type}</code>
    <strong>Environment: </strong><code>${env}</code>
    <strong>Timestamp: </strong><code>${new Date(timestamp).toISOString()}</code>
    <strong>Identifiers: </strong> <code>${ids.join(', ')}</code>
  `;
};

/**
 * Validates Telegram configuration
 * @param telegram The telegram config
 * @param logger The logger instance
 * @param requestContext The request context
 * @param methodContext The method context
 * @returns boolean indicating if the config is valid
 */
const validateTelegramConfig = (
  telegram: TelegramConfig,
  logger: Logger,
  requestContext: RequestContext,
  methodContext: MethodContext,
): boolean => {
  if (!telegram) {
    logger.warn('Telegram config not set', requestContext, methodContext);
    return false;
  }

  if (!telegram.apiKey || !telegram.chatId) {
    logger.warn('Telegram api key or chat id not set', requestContext, methodContext);
    return false;
  }

  return true;
};

/**
 * Sends a message to Telegram
 * @param telegram The telegram config
 * @param message The message to send
 * @param logger The logger instance
 * @param requestContext The request context
 * @param methodContext The method context
 */
const sendTelegramMessage = async (
  telegram: TelegramConfig,
  message: string,
  logger: Logger,
  requestContext: RequestContext,
  methodContext: MethodContext,
) => {
  try {
    await axiosPost(`https://api.telegram.org/bot${telegram!.apiKey}/sendMessage`, {
      chat_id: telegram!.chatId,
      text: message,
      parse_mode: 'Html',
    });
    logger.info('Telegram message sent successfully', requestContext, methodContext);
  } catch (error) {
    logger.error('Failed to send Telegram message', requestContext, methodContext, jsonifyError(error as Error));
  }
};

/**
 * Sends alerts to telegram using axiosPost
 * @param report The report that will be sent in the alert
 * @param telegram The telegram config
 * @param requestContext The request context for the logger
 * @returns The response from telegram api
 */
export const alertTelegram = async (report: Report, telegram: TelegramConfig, requestContext: RequestContext) => {
  const methodContext = createMethodContext(alertTelegram.name);
  const { timestamp, reason, ids, logger, severity } = report;

  if (!validateTelegramConfig(telegram, logger, requestContext, methodContext)) {
    return;
  }

  logger.info('Sending message via telegram', requestContext, methodContext, {
    timestamp,
    reason,
    ids,
    severity,
  });

  const message = createTelegramMessage(report, false);
  await sendTelegramMessage(telegram, message, logger, requestContext, methodContext);
};

/**
 * Sends alerts to telegram using axiosPost indicating a report has been resolved
 * @param report The report that will be sent in the alert
 * @param telegram The telegram config
 * @param requestContext The request context for the logger
 * @returns The response from telegram api
 */
export async function resolveTelegramAlert(
  report: Report,
  telegram: TelegramConfig,
  requestContext: RequestContext,
): Promise<void> {
  const methodContext = createMethodContext(resolveTelegramAlert.name);
  const { timestamp, reason, ids, logger, severity } = report;

  if (!validateTelegramConfig(telegram, logger, requestContext, methodContext)) {
    return;
  }

  logger.info('Sending resolution message via telegram', requestContext, methodContext, {
    timestamp,
    reason,
    ids,
    severity,
  });

  const message = createTelegramMessage(report, true);
  await sendTelegramMessage(telegram, message, logger, requestContext, methodContext);
}
