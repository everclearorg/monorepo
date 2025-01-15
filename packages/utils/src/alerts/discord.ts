// Internal imports
import { Logger, MethodContext, RequestContext, createMethodContext } from '../logging';
import { jsonifyError } from '../types';
import { Severity, Report } from '../helpers';
import { axiosPost } from './mockable';

/**
 * Creates the content for the Discord message based on severity
 */
const createDiscordContent = (severity: Severity, isResolved: boolean): string => {
  const prefix = isResolved ? 'Resolved Alert! ' : '';
  if (severity !== Severity.Informational) {
    return `@OnCall ${prefix}Severity: ${severity.toLocaleUpperCase()} - ${
      severity === Severity.Warning ? ':warning:' : ':rotating_light:'
    }`;
  }
  return `${prefix}Severity: Informational - :information_source:`;
};

/**
 * Creates the params object for the Discord message
 */
const createDiscordParams = (report: Report, isResolved: boolean) => {
  const { timestamp, reason, ids, type, severity, env } = report;
  return {
    content: createDiscordContent(severity, isResolved),
    username: 'Alert',
    avatar_url: '',
    allowed_mentions: {
      parse: ['everyone'],
    },
    embeds: [
      {
        color: isResolved ? 0x78fc6e : 0xff3827,
        timestamp: new Date(timestamp).toISOString(),
        title: isResolved ? 'Resolved!' : 'Reason',
        description: '',
        fields: [
          {
            name: 'Type',
            value: type,
          },
          {
            name: 'Environment',
            value: env,
          },
          {
            name: 'Reason',
            value: reason || 'No Reason',
          },
          {
            name: 'Identifiers',
            value: ids.length ? ids.join('\n') : 'None',
          },
          {
            name: 'Type',
            value: type || 'Default',
          },
        ],
        url: '',
      },
    ],
  };
};

/**
 * Sends a Discord message
 */
const sendDiscordMessage = async (
  webhookUrl: string,
  params: object,
  logger: Logger,
  requestContext: RequestContext,
  methodContext: MethodContext,
) => {
  try {
    await axiosPost(webhookUrl, JSON.parse(JSON.stringify(params)));
    logger.info('Discord message sent successfully', requestContext, methodContext);
  } catch (error) {
    logger.error('Failed to send Discord message', requestContext, methodContext, jsonifyError(error as Error));
  }
};

/**
 * Sends alert to discord using axiosPost
 * @param report The report that will be sent in the alert
 * @param discordHookUrl The discord webhook url
 * @param requestContext The request context for the logger
 * @returns The response from discord
 */
export const alertDiscord = async (
  report: Report,
  discordHookUrl: string,
  requestContext: RequestContext,
): Promise<void> => {
  const methodContext = createMethodContext(alertDiscord.name);
  const { timestamp, reason, ids, logger } = report;

  logger.info('Sending message to discord channel', requestContext, methodContext, {
    timestamp,
    reason,
    ids,
  });

  const params = createDiscordParams(report, false);
  await sendDiscordMessage(discordHookUrl, params, logger, requestContext, methodContext);
};

/**
 * Sends a resolution alert to Discord using axiosPost
 * @param report The report that will be sent in the resolution alert
 * @param webhookUrl The Discord webhook URL
 * @param requestContext The request context for the logger
 * @returns A Promise that resolves when the Discord message is sent
 */
export async function resolveDiscordAlert(
  report: Report,
  webhookUrl: string | undefined,
  requestContext: RequestContext,
): Promise<void> {
  const methodContext = createMethodContext(resolveDiscordAlert.name);
  const { timestamp, reason, ids, logger } = report;

  if (!webhookUrl) {
    logger.warn('Discord webhook url not set', requestContext, methodContext);
    return;
  }

  logger.info('Sending resolution message to discord channel', requestContext, methodContext, {
    timestamp,
    reason,
    ids,
  });

  const params = createDiscordParams(report, true);
  await sendDiscordMessage(webhookUrl, params, logger, requestContext, methodContext);
}
