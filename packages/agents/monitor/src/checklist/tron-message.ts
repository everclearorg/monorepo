import { HyperlaneStatus, createLoggingContext, getNtpTimeSeconds } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { getMessageStatus } from '../helpers';
import { IntentMessageSummary, Severity } from '../types';
import { resolveAlerts, sendAlerts } from '../mockable';

/**
 * Tron-specific message status monitoring
 * Provides 1-1 parity with EVM message status checks but for Tron chains
 */

export const getTronIntentStatus = async (
  originDomain: string,
  destinationDomains: string[],
  intentId: string,
): Promise<IntentMessageSummary> => {
  const {
    config,
    adapters: { subgraph },
  } = getContext();

  // Filter destination domains to only include Tron chains
  const tronDestinationDomains = destinationDomains.filter(domain => 
    config.chains[domain]?.network === 'tvm'
  );

  // Retrieve intent records from subgraph for Tron destinations
  const [originIntent, hubIntent, ...destinationIntents] = await Promise.all([
    subgraph.getOriginIntentById(originDomain, intentId),
    subgraph.getHubIntentById(config.hub.domain, intentId),
    ...tronDestinationDomains.map((domain) => subgraph.getDestinationIntentById(domain, intentId)),
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

export const checkTronMessageStatus = async (shouldAlert = true) => {
  const {
    config,
    logger,
    adapters: { database },
  } = getContext();

  const { requestContext, methodContext } = createLoggingContext(checkTronMessageStatus.name);
  const uncompletedStatuses = [HyperlaneStatus.none, HyperlaneStatus.pending, HyperlaneStatus.relayable];
  
  // Filter for Tron chains only
  const tronDomains = Object.keys(config.chains).filter((domain) => config.chains[domain].network === 'tvm');
  
  let end = false;
  const limit = 100;
  let offset = 0;
  const messagesToAlert: string[] = [];
  
  while (!end) {
    // Get uncompleted messages specifically for Tron domains
    // Note: This assumes database has a method to filter by domains
    // If not available, we'll need to filter the results manually
    const uncompletedMessages = await database.getMessagesByStatus(uncompletedStatuses, offset, limit);
    // Filter for Tron domains after retrieval if needed
    const tronMessages = uncompletedMessages.filter(msg => tronDomains.includes(msg.domain?.toString()));
    logger.debug('Getting Tron hyperlane message status', requestContext, methodContext, {
      offset,
      limit,
      result: tronMessages.length,
      tronDomains,
    });

    const statusRes = await Promise.all(
      tronMessages.map(async (message) => {
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

    if (limit > tronMessages.length) end = true;
    else offset += limit;
  }

  const report = {
    severity: Severity.Warning,
    type: 'TronHyperlaneMessagesProcessingDelayed',
    ids: messagesToAlert,
    reason: `Tron Hyperlane messages processing exceeds threshold ${config.thresholds.messageMaxDelay!}s. \nMessages: ${messagesToAlert.join('\n\t')}`,
    timestamp: Date.now(),
    logger: logger,
    env: config.environment,
  };

  if (!messagesToAlert.length) {
    logger.info('All Tron hyperlane messages are delivered', requestContext, methodContext);
    await resolveAlerts(report, logger, config, requestContext, true);
    return;
  }

  logger.warn('Tron hyperlane messages processing delayed', requestContext, methodContext, { messagesToAlert });

  if (!shouldAlert) return;

  await sendAlerts(report, logger, config, requestContext);
};