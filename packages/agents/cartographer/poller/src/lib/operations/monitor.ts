import {
  HyperlaneStatus,
  Message,
  TIntentStatus,
  TMessageType,
  TSettlementMessageType,
  createLoggingContext,
  getMaxBlockNumber,
  getMaxTxNonce,
  SOLANA_CHAINID,
} from '@chimera-monorepo/utils';

import { getContext } from '../../shared';
import { getHyperlaneMsgDelivered } from '../../mockable';
import { getSubgraphSupportedDomains } from './helper';
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

  const evmDomains = Object.keys(config.chains)
    .filter((d) => config.chains[d].network === 'evm')
    .concat(config.hub.domain);
  for (const domain of evmDomains) {
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

  const evmDomains = Object.keys(config.chains).filter(
    (c) => c !== config.hub.domain && config.chains[c].network === 'evm',
  );
  logger.debug('Method start', requestContext, methodContext, { spokes: evmDomains, hub: config.hub.domain });

  const settlementQueues = await subgraph.getSettlementQueues(config.hub.domain);
  logger.debug('Retrieved settlement queues', requestContext, methodContext, {
    settlementQueues: settlementQueues.length,
  });

  // Deposit queues are configured by `epoch-origin_domain-tickerhash`
  // There could be many more deposit queues than message queues, so these require a checkpoint
  const prevBlock = await database.getCheckPoint('hub_queue_deposit');
  const depositQueues = await subgraph.getDepositQueues(config.hub.domain, prevBlock);
  logger.debug('Retrieved deposit queues', requestContext, methodContext, {
    depositQueues,
  });

  const spokeSubgraphReturn = await Promise.all(evmDomains.map((s) => subgraph.getSpokeQueues(s)));
  const spokeQueues = [...spokeSubgraphReturn.flat()];
  logger.debug('Retrieved spoke queues', requestContext, methodContext, {
    spokeQueues: spokeQueues.length,
  });
  const queues = [...settlementQueues, ...depositQueues, ...spokeQueues];
  await database.saveQueues(queues);

  logger.info('Saved queues', requestContext, methodContext, {
    queues: new Set(queues.map((q) => q.id)).size,
  });

  const latestBlock = getMaxBlockNumber(depositQueues);
  await database.saveCheckPoint('hub_queue_deposit', latestBlock);
  logger.debug('Saved checkpoint', requestContext, methodContext, { latestBlock });

  logger.debug('Method complete', requestContext, methodContext, {
    queues: queues.map((q) => ({ id: q.id, domain: q.domain, size: q.size, lastProcessed: q.lastProcessed })),
  });
};

export const updateProtocolUpdateLogs = async () => {
  const {
    adapters: { subgraph, database },
    logger,
    config,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateProtocolUpdateLogs.name);

  const spokeDomains = getSubgraphSupportedDomains(config);
  const domains = [...spokeDomains, config.hub.domain];
  for (const domain of domains) {
    const isHub = domain === config.hub.domain;
    const checkpointKey = isHub ? 'hub_meta_log_block' : `spoke_meta_log_block_${domain}`;
    const lastBlock = await database.getCheckPoint(checkpointKey);
    const updates = isHub
      ? await subgraph.getHubMetaUpdates(domain, lastBlock)
      : await subgraph.getSpokeMetaUpdates(domain, lastBlock);

    if (updates.length === 0) {
      logger.debug('No meta updates found', requestContext, methodContext, {
        domain,
        checkpoint: lastBlock,
      });
      continue;
    }

    const latestBlock = Math.max(lastBlock, getMaxBlockNumber(updates));
    await database.saveProtocolUpdateLogs(updates);

    await database.saveCheckPoint(checkpointKey, latestBlock);
    logger.debug('Saved protocol update logs', requestContext, methodContext, {
      domain,
      count: updates.length,
      latestBlock,
    });
  }
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

    // Skip messages going to solana, they will be updated by lighthouse
    const messagesToProcess = uncompletedMessages.filter((message) => message.destinationDomain !== SOLANA_CHAINID);

    const statusRes = await Promise.all(
      messagesToProcess.map(async (message) => {
        const status = await getMessageStatus(message.id, config, message.destinationDomain);
        return { id: message.id, status };
      }),
    );

    await Promise.all(statusRes.map((res) => database.updateMessageStatus(res.id, res.status)));

    if (limit > uncompletedMessages.length) end = true;
    else offset += limit;
  }
};
