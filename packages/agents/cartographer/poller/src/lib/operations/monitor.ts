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
  SpokeMeta,
  jsonifyError,
  EverclearError,
  isPolymerRoute,
} from '@chimera-monorepo/utils';

import { getContext } from '../../shared';
import { getHyperlaneMsgDelivered, getPolymerMsgDelivered } from '../../mockable';
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

const getMessageStatus = async (
  messageId: string,
  config: CartographerConfig,
  originDomain?: string,
  destinationDomain?: string,
) => {
  const {
    adapters: { chainreader },
    logger,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(getMessageStatus.name);

  // For Polymer-routed messages, query the Polymer relayer API instead of on-chain mailbox
  if (originDomain && destinationDomain && isPolymerRoute(originDomain, destinationDomain)) {
    try {
      return await getPolymerMsgDelivered(messageId);
    } catch (err) {
      logger.error(
        'Failed to get Polymer message status',
        requestContext,
        methodContext,
        jsonifyError(err as EverclearError),
        {
          messageId,
          originDomain,
          destinationDomain,
        },
      );
    }
    return HyperlaneStatus.pending;
  }

  const chainConfig = getChainConfig(destinationDomain!, config);
  const gateway = chainConfig.deployments?.gateway;
  let status: HyperlaneStatus = HyperlaneStatus.pending;
  if (gateway) {
    try {
      const messageDelivered = await getHyperlaneMsgDelivered(
        messageId,
        gateway,
        (params) => chainreader.readTx(params, 'latest'),
        +destinationDomain!,
      );
      if (messageDelivered) {
        status = HyperlaneStatus.delivered;
      }
    } catch (err) {
      logger.error('Failed to get message status', requestContext, methodContext, jsonifyError(err as EverclearError), {
        messageId,
        destinationDomain,
      });
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
          // Skip contract read for hub → Solana
          // Set message status 'pending', LH will update it to 'delivered' when the intent is settled
          if (message.destinationDomain === SOLANA_CHAINID) {
            message.status = HyperlaneStatus.pending;
            return;
          }
          message.status = await getMessageStatus(message.id, config, domain, message.destinationDomain);
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
          message.status = await getMessageStatus(message.id, config, domain, message.destinationDomain ?? config.hub.domain);
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
    // 1) Meta update logs (hub + spoke)
    const metaCheckpointKey = isHub ? 'hub_meta_log_block' : `spoke_meta_log_block_${domain}`;
    const metaLastBlock = await database.getCheckPoint(metaCheckpointKey);
    const metaUpdates = isHub
      ? await subgraph.getHubMetaUpdates(domain, metaLastBlock)
      : await subgraph.getSpokeMetaUpdates(domain, metaLastBlock);

    if (metaUpdates.length > 0) {
      const latestBlock = Math.max(metaLastBlock, getMaxBlockNumber(metaUpdates));
      await database.saveProtocolUpdateLogs(metaUpdates);
      await database.saveCheckPoint(metaCheckpointKey, latestBlock);
      logger.debug('Saved meta update logs', requestContext, methodContext, {
        domain,
        count: metaUpdates.length,
        latestBlock,
      });
    } else {
      logger.debug('No meta updates found', requestContext, methodContext, {
        domain,
        checkpoint: metaLastBlock,
      });
    }

    // 2) Hub token/asset update logs (hub only)
    if (isHub) {
      const tokenCheckpointKey = 'hub_token_log_block';
      const tokenLastBlock = await database.getCheckPoint(tokenCheckpointKey);
      const tokenUpdates = await subgraph.getHubTokenUpdates(domain, tokenLastBlock);
      if (tokenUpdates.length > 0) {
        const latestBlock = Math.max(tokenLastBlock, getMaxBlockNumber(tokenUpdates));
        await database.saveHubTokenUpdateLogs(tokenUpdates);
        await database.saveCheckPoint(tokenCheckpointKey, latestBlock);
        logger.debug('Saved hub token update logs', requestContext, methodContext, {
          domain,
          count: tokenUpdates.length,
          latestBlock,
        });
      } else {
        logger.debug('No hub token updates found', requestContext, methodContext, {
          domain,
          checkpoint: tokenLastBlock,
        });
      }

      const assetCheckpointKey = 'hub_asset_log_block';
      const assetLastBlock = await database.getCheckPoint(assetCheckpointKey);
      const assetUpdates = await subgraph.getHubAssetUpdates(domain, assetLastBlock);
      if (assetUpdates.length > 0) {
        const latestBlock = Math.max(assetLastBlock, getMaxBlockNumber(assetUpdates));
        await database.saveHubAssetUpdateLogs(assetUpdates);
        await database.saveCheckPoint(assetCheckpointKey, latestBlock);
        logger.debug('Saved hub asset update logs', requestContext, methodContext, {
          domain,
          count: assetUpdates.length,
          latestBlock,
        });
      } else {
        logger.debug('No hub asset updates found', requestContext, methodContext, {
          domain,
          checkpoint: assetLastBlock,
        });
      }
    }
  }
};

export const updateHubSpokeMeta = async () => {
  const {
    adapters: { subgraph, database },
    logger,
    config,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateHubSpokeMeta.name);

  const spokeDomains = getSubgraphSupportedDomains(config);
  const hubDomain = config.hub.domain;

  const hubMeta = await subgraph.getHubMeta(hubDomain);
  if (hubMeta) {
    await database.saveHubMeta([hubMeta]);
    logger.debug('Saved hub meta', requestContext, methodContext, { domain: hubDomain });
  } else {
    logger.debug('No hub meta found', requestContext, methodContext, { domain: hubDomain });
  }

  const spokeMetas: (SpokeMeta | undefined)[] = await Promise.all(
    spokeDomains.map(async (domain) => subgraph.getSpokeMeta(domain)),
  );
  const validSpokeMetas = spokeMetas.filter((meta): meta is SpokeMeta => Boolean(meta));

  if (validSpokeMetas.length > 0) {
    await database.saveSpokeMeta(validSpokeMetas);
    logger.debug('Saved spoke meta', requestContext, methodContext, { count: validSpokeMetas.length });
  } else {
    logger.debug('No spoke meta found', requestContext, methodContext, { count: 0 });
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
        const status = await getMessageStatus(message.id, config, message.originDomain, message.destinationDomain);
        return { id: message.id, status };
      }),
    );

    await Promise.all(statusRes.map((res) => database.updateMessageStatus(res.id, res.status)));

    if (limit > uncompletedMessages.length) end = true;
    else offset += limit;
  }
};
