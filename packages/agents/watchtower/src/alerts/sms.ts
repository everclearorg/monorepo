// Internal imports
import { RequestContext, createMethodContext } from '@chimera-monorepo/utils';
import { Report, TwillioConfig } from '../lib/entities';
import { MessageInstance } from 'twilio/lib/rest/api/v2010/account/message';
import { sendMessageViaTwilio } from '../mockable';

/**
 * Sends alerts to SMS via twilio
 * @param report The report that will be sent in the alert
 * @param twilio The twilio config
 * @param requestContext The request context for the logger
 * @returns The messages
 */
export const alertSMS = async (
  report: Report,
  twilio: TwillioConfig,
  requestContext: RequestContext,
): Promise<MessageInstance[]> => {
  const methodContext = createMethodContext(alertSMS.name);

  const { timestamp, reason, logger, domains, type, env } = report;
  if (!twilio.number || !twilio.toPhoneNumbers.length || !twilio.accountSid || !twilio.authToken) {
    logger.warn('Twilio informatio is missing', requestContext, methodContext);
    return [];
  }

  logger.info('Sending message via twilio', requestContext, methodContext, {
    timestamp,
    reason,
    domains,
  });

  const messages: MessageInstance[] = [];
  // Send SMS to each phone number provided in the config
  for (const phoneNumber of twilio.toPhoneNumbers ?? []) {
    try {
      const textContent = {
        body: `Watcher Alert!. Reason: ${reason}, type: ${type}, env: ${env}, domains: ${domains.join(',')}`,
        to: phoneNumber,
        from: twilio.number ?? '',
      };
      const message = await sendMessageViaTwilio(twilio.accountSid ?? '', twilio.authToken ?? '', textContent);
      messages.push(message);
    } catch (e) {
      logger.error(`Failed to send SMS alert because of error: ${e}`, requestContext, methodContext);
    }
  }

  return messages;
};
