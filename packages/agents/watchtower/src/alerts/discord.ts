// Internal imports
import { RequestContext, createMethodContext } from '@chimera-monorepo/utils';
import { Severity, Report } from '../lib/entities';
import { axiosPost } from '../mockable';

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
  // Create method context for the logger
  const methodContext = createMethodContext(alertDiscord.name);
  const { timestamp, reason, domains, logger, type, severity, env } = report;

  logger.info('Sending message to discord channel', requestContext, methodContext, {
    timestamp,
    reason,
    domains,
  });

  const content =
    severity !== Severity.Informational
      ? `@OnCall Severity: ${severity.toLocaleUpperCase()} - ${
          severity == Severity.Warning ? ':warning:' : ':rotating_light:'
        }`
      : `Severity: Informational - :information_source:`;

  // This is the params that will be sent to discord
  const params = {
    content: content, // This will be the regular message above the embed
    username: 'Watcher Alerter',
    avatar_url: '',
    allowed_mentions: {
      parse: ['everyone'],
    },
    embeds: [
      {
        color: 0xff3827,
        timestamp: new Date(timestamp).toISOString(),
        title: 'Reason',
        description: '',
        fields: [
          {
            name: 'Type',
            value: report.type,
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
            name: 'Domains',
            value: domains.length ? domains.join('\n') : 'None',
          },
          {
            name: 'Type',
            value: type || 'Default',
          },
        ],
        url: '', //This will set an URL for the title
      },
    ],
  };

  try {
    await axiosPost(discordHookUrl, JSON.parse(JSON.stringify(params)));
  } catch (e) {
    logger.error(`Error sending discord alert because of error: ${e}`, requestContext, methodContext);
  }
};
