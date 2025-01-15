import { HyperlaneStatus, createLoggingContext, getNtpTimeSeconds } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { getMessageStatus } from '../../helpers';
import { IntentMessageSummary, Severity } from '../../types';
import { resolveAlerts, sendAlerts } from '../../mockable';

export const getIntentStatus = async (
  originDomain: string,
  destinationDomains: string[],
  intentId: string,
): Promise<IntentMessageSummary> => {
  const {
    config,
    adapters: { subgraph },
  } = getContext();

  // Retrieve intent records from subgraph.
  const [originIntent, hubIntent, ...destinationIntents] = await Promise.all([
    subgraph.getOriginIntentById(originDomain, intentId),
    subgraph.getHubIntentById(config.hub.domain, intentId),
    ...destinationDomains.map((domain) => subgraph.getDestinationIntentById(domain, intentId)),
  ]);

  // Get the hyperlane message status from the sdk, if not already delivered.
  const [originMessageStatus, hubMessageStatus, ...destinationMessageStatuses] = await Promise.all([
    originIntent?.messageId ? getMessageStatus(originIntent.messageId) : { status: 'N/A' },
    hubIntent?.messageId ? getMessageStatus(hubIntent.messageId) : { status: 'N/A' },
    ...destinationIntents.map((d) => (d?.messageId ? getMessageStatus(d.messageId) : { status: 'N/A' })),
  ]);

  return {
    settlement: {
      messageId: hubIntent?.messageId ?? '',
      status: hubMessageStatus.status,
    },
    fill: {
      messageId: destinationIntents.find((d) => d && d.messageId)?.messageId ?? '',
      status: destinationMessageStatuses.find((d) => d.status !== 'N/A')?.status ?? 'N/A',
    },
    add: {
      messageId: originIntent?.messageId ?? '',
      status: originMessageStatus.status,
    },
  };
};

export const checkMessageStatus = async (shouldAlert = true) => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(checkMessageStatus.name);
  const uncompletedStatuses = [HyperlaneStatus.none, HyperlaneStatus.pending, HyperlaneStatus.relayable];
  let end = false;
  const limit = 100;
  let offset = 0;
  const messagesToAlert: string[] = [];
  while (!end) {
    const uncompletedMessages = await database.getMessagesByStatus(uncompletedStatuses, offset, limit);
    logger.debug('Getting hyperlane message status', requestContext, methodContext, {
      offset,
      limit,
      result: uncompletedMessages.length,
    });

    const statusRes = await Promise.all(
      uncompletedMessages.map(async (message) => {
        const messageStatus = await getMessageStatus(message.id);
        return messageStatus
          ? { id: message.id, status: messageStatus.status, timestamp: message.timestamp }
          : { id: message.id, status: HyperlaneStatus.none, timestamp: message.timestamp };
      }),
    );

    const curTimestamp = getNtpTimeSeconds();
    messagesToAlert.push(
      ...statusRes
        .filter(
          (it) =>
            it.status != HyperlaneStatus.delivered && curTimestamp > it.timestamp + config.thresholds.messageMaxDelay!,
        )
        .map((it) => it.id),
    );

    if (limit > uncompletedMessages.length) end = true;
    else offset += limit;
  }

  const report = {
    severity: Severity.Warning,
    type: 'HyperlaneMessagesProcessingDelayed',
    ids: messagesToAlert,
    reason: `Hyperlane messages processing exceeds threshold ${config.thresholds.messageMaxDelay!}s. \nMessages: ${messagesToAlert.join('\n\t')}`,
    timestamp: Date.now(),
    logger: logger,
    env: config.environment,
  };

  if (!messagesToAlert.length) {
    logger.info('All hyperlane messages are delivered', requestContext, methodContext);
    await resolveAlerts(report, logger, config, requestContext, true);
    return;
  }

  logger.warn('Hyperlane messages processing delayed', requestContext, methodContext, { messagesToAlert });

  if (!shouldAlert) return;

  await sendAlerts(report, logger, config, requestContext);
};
