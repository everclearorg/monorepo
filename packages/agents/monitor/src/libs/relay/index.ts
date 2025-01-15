import { RequestContext, MethodContext, domainToChainId, Message } from '@chimera-monorepo/utils';
import { getContext } from '../../context';
import { sendWithRelayerWithBackup } from '@chimera-monorepo/adapters-relayer';
import { getMessageStatus } from './../../helpers/hyperlane';
import { SelfRelayResponse } from '../../types';
import { jsonifyError } from '@chimera-monorepo/utils';

export const selfRelayHyperlaneMessages = async (
  messageIds: string[],
  requestContext: RequestContext,
  methodContext: MethodContext,
): Promise<SelfRelayResponse[]> => {
  // Get the config
  const {
    logger,
    config: { chains, hub },
    adapters: { database, chainreader, relayers },
  } = getContext();
  const results: SelfRelayResponse[] = [];

  if (relayers.length === 0) {
    logger.warn('No relayers configured, cannot self-relay hyperlane messages', requestContext, methodContext);
    return results;
  }

  // Retrieve the pending queues (i.e. those that have been sent via hyperlane, but
  // have not yet arrived on the clearing chain)

  // Get the spoke domains
  const domains = Object.keys(chains);
  const spokes = domains.filter((d) => d !== hub.domain);
  logger.info('Starting hyperlane self-process check.', requestContext, methodContext, {
    ids: messageIds,
    hub: hub.domain,
    spokes,
  });

  const messages: Message[] = [];
  if (messageIds.length === 0) {
    logger.debug('No message ids provided, fetching all hyperlane messages', requestContext, methodContext);
    // Get all intents with the status expected
    const [_intents, _fills] = await Promise.all([
      database.getOriginIntentsByStatus('DISPATCHED', spokes),
      database.getDestinationIntentsByStatus('DISPATCHED', spokes),
    ]);
    // Get unique hyperlane message ids
    const ids = [...new Set([..._intents, ..._fills].map((i) => i.id.toLowerCase()).filter((x) => !!x))] as string[];
    messages.concat(await database.getMessagesByIntentIds(ids));
  } else {
    // Get messages by the message id alone
    const stored = await database.getMessagesByIds(messageIds);
    messages.push(...stored);
  }

  if (messages.length === 0) {
    logger.info('No hyperlane messages to self process', requestContext, methodContext);
    return results;
  }
  // For each message, process if processable
  logger.debug('Attempting to self process hyperlane messages', requestContext, methodContext, {
    messageIds: messages.map((m) => m.id),
  });

  for (const { id: messageId } of messages) {
    const { status, relayTransaction } = await getMessageStatus(messageId, true);
    if (status !== 'relayable' || !messageId) {
      // Cant self-relay, continue
      continue;
    }
    logger.debug('Attempting to self process hyperlane message', requestContext, methodContext, {
      messageId,
    });
    // Process the message via relayers
    try {
      const { taskId, relayerType } = await sendWithRelayerWithBackup(
        domainToChainId(relayTransaction!.domain),
        relayTransaction!.domain.toString(),
        relayTransaction!.to,
        relayTransaction!.data,
        relayTransaction!.value,
        relayers,
        chainreader,
        logger,
        requestContext,
      );
      logger.info('Processed hyperlane message', requestContext, methodContext, {
        taskId,
        relayerType,
        messageId,
      });
      results.push({ messageId, taskId, relayerType, error: undefined } as unknown as SelfRelayResponse);
    } catch (err: unknown) {
      logger.error('Error processing hyperlane message', requestContext, methodContext, jsonifyError(err as Error));
      results.push({ messageId, error: err } as unknown as SelfRelayResponse);
    }
  }
  return results;
};
