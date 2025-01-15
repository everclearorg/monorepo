import {
  HyperlaneStatus,
  Message,
  TIntentStatus,
  TMessageType,
  TSettlementMessageType,
  createLoggingContext,
  getMaxEpoch,
  getMaxTxNonce,
} from '@chimera-monorepo/utils';

import { getContext } from '../../shared';
import { getHyperlaneMsgDelivered } from '../../mockable';
import { CartographerConfig } from '../../config';

const getChainConfig = (domain: string, config: CartographerConfig) => {
  if (domain == config.hub.domain) {
    return config.hub;
  }
  if (!config.chains[domain]) {
    throw new Error(`Chain (${domain}) not found in config. Included chains: ${Object.keys(config.chains).join(', ')}`);
  }
  return config.chains[domain];
};

const getMessageStatus = async (messageId: string, config: CartographerConfig, destinationDomain?: string) => {
  const chainConfig = getChainConfig(destinationDomain!, config);
  const gateway = chainConfig.deployments?.gateway;
  let status: HyperlaneStatus = HyperlaneStatus.pending;
  if (gateway) {
    const messageDelivered = await getHyperlaneMsgDelivered(messageId, chainConfig.providers, gateway);
    if (messageDelivered) {
      status = HyperlaneStatus.delivered;
    }
  }
  return status;
};

export const updateMessages = async () => {
  const {
    adapters: { subgraph, database },
    logger,
    config,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateMessages.name);

  const domains = Object.keys(config.chains).concat(config.hub.domain);
  for (const domain of domains) {
    // Retrieve the most recent timestamp
    const latestNonce = await database.getCheckPoint('message_' + domain);

    logger.debug('Retrieving messages', requestContext, methodContext, {
      domain,
      latestNonce,
    });

    let messages = [];
    if (domain === config.hub.domain) {
      messages = await subgraph.getHubMessages(domain, latestNonce);
      await Promise.all(
        messages.map(async (message) => {
          message.status = await getMessageStatus(message.id, config, message.destinationDomain);
        }),
      );

      const hubIntentUpdates = messages
        .filter((m) => m.type === TMessageType.Settlement)
        .flatMap((m) => {
          return m.intentIds.map((id) => ({
            id,
            messageId: m.id,
            settlementDomain: m.settlementDomain,
            status:
              m.settlementType === TSettlementMessageType.Settled
                ? TIntentStatus.Dispatched
                : TIntentStatus.DispatchedUnsupported,
          }));
        });
      await database.saveMessages(messages as Message[], [], [], hubIntentUpdates);
    } else {
      messages = await subgraph.getSpokeMessages(domain, latestNonce);
      await Promise.all(
        messages.map(async (message) => {
          // all spoke messages go to the hub, use this domain if no destination on message
          message.status = await getMessageStatus(message.id, config, message.destinationDomain ?? config.hub.domain);
        }),
      );

      // Update intents with messageId and status
      const originIntentUpdates = messages
        .filter((m) => m.type === TMessageType.Intent)
        .flatMap((m) => {
          return m.intentIds.map((id) => ({ id: id, messageId: m.id, status: TIntentStatus.Dispatched }));
        });
      const destinationIntentUpdates = messages
        .filter((m) => m.type === TMessageType.Fill)
        .flatMap((m) => {
          return m.intentIds.map((id) => ({ id: id, messageId: m.id, status: TIntentStatus.Dispatched }));
        });

      await database.saveMessages(
        messages.map((message) => ({ ...message, destinationDomain: config.hub.domain })),
        originIntentUpdates,
        destinationIntentUpdates,
        [],
      );
    }

    // If there are any new messages, update the checkpoint with the timestamp of the latest message
    if (messages.length > 0) {
      const maxNonce = getMaxTxNonce(messages);
      await database.saveCheckPoint('message_' + domain, maxNonce);
    }

    logger.debug('Saved messages', requestContext, methodContext, { messages });
  }
};

export const updateQueues = async () => {
  const {
    adapters: { subgraph, database },
    logger,
    config,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateQueues.name);

  const spokes = Object.keys(config.chains).filter((c) => c !== config.hub.domain);
  logger.debug('Method start', requestContext, methodContext, { spokes, hub: config.hub.domain });

  const settlementQueues = await subgraph.getSettlementQueues(config.hub.domain);
  logger.debug('Retrieved settlement queues', requestContext, methodContext, {
    settlementQueues: settlementQueues.length,
  });

  // Deposit queues are configured by `epoch-origin_domain-tickerhash`
  // There could be many more deposit queues than message queues, so these require a checkpoint
  const prevEpoch = await database.getCheckPoint('hub_queue_deposit');
  const depositQueues = await subgraph.getDepositQueues(config.hub.domain, prevEpoch);

  const spokeSubgraphReturn = await Promise.all(spokes.map((s) => subgraph.getSpokeQueues(s)));
  const spokeQueues = [...spokeSubgraphReturn.flat()];
  logger.debug('Retrieved spoke queues', requestContext, methodContext, {
    spokeQueues: spokeQueues.length,
  });
  const queues = [...settlementQueues, ...depositQueues, ...spokeQueues];
  await database.saveQueues(queues);

  logger.info('Saved queues', requestContext, methodContext, {
    queues: new Set(queues.map((q) => q.id)).size,
  });

  const latestEpoch = getMaxEpoch(depositQueues);
  await database.saveCheckPoint('hub_queue_deposit', latestEpoch);
  logger.debug('Saved checkpoint', requestContext, methodContext, { latestEpoch });

  logger.debug('Method complete', requestContext, methodContext, {
    queues: queues.map((q) => ({ id: q.id, domain: q.domain, size: q.size, lastProcessed: q.lastProcessed })),
  });
};

export const updateMessageStatus = async () => {
  const {
    adapters: { database },
    logger,
    config,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateMessageStatus.name);

  const uncompletedStatuses = [HyperlaneStatus.none, HyperlaneStatus.pending, HyperlaneStatus.relayable];
  let end = false;
  const limit = 100;
  let offset = 0;
  while (!end) {
    const uncompletedMessages = await database.getMessagesByStatus(uncompletedStatuses, offset, limit);
    logger.debug('Getting hyperlane message status', requestContext, methodContext, {
      offset,
      limit,
      result: uncompletedMessages.length,
    });

    const statusRes = await Promise.all(
      uncompletedMessages.map(async (message) => {
        const status = await getMessageStatus(message.id, config, message.destinationDomain);
        return { id: message.id, status };
      }),
    );

    await Promise.all(statusRes.map((res) => database.updateMessageStatus(res.id, res.status)));

    if (limit > uncompletedMessages.length) end = true;
    else offset += limit;
  }
};
