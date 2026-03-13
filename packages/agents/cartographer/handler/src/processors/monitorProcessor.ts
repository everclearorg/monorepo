import {
  getHyperlaneMsgDelivered,
  HyperlaneStatus,
  HubIntent,
  SOLANA_CHAINID,
  TIntentStatus,
  TMessageType,
  TSettlementMessageType,
  QueueType,
  Message,
  HubMessage,
} from '@chimera-monorepo/utils';
import { AppContext, CartographerConfig } from '@chimera-monorepo/cartographer-core';
import { notifyLighthouse } from '../notify';
import { LIGHTHOUSE_QUEUES } from '@chimera-monorepo/mqclient';
import {
  parseMessage,
  parseQueue,
  parseHubMeta,
  parseSpokeMeta,
  parseProtocolUpdateLog,
  parseHubTokenUpdateLog,
  parseHubAssetUpdateLog,
} from '../webhooks/parsers';

const getChainConfig = (domain: string, config: CartographerConfig) => {
  if (domain === config.hub.domain) return config.hub;
  return config.chains[domain];
};

const getMessageStatus = async (messageId: string, destinationDomain: string, context: AppContext) => {
  const {
    config,
    adapters: { chainreader },
  } = context;
  const chainConfig = getChainConfig(destinationDomain, config);
  if (!chainConfig) return HyperlaneStatus.pending;

  const gateway = chainConfig.deployments?.gateway;
  if (!gateway) return HyperlaneStatus.pending;

  try {
    const delivered = await getHyperlaneMsgDelivered(
      messageId,
      gateway,
      (params) => chainreader.readTx(params, 'latest'),
      +destinationDomain,
    );
    return delivered ? HyperlaneStatus.delivered : HyperlaneStatus.pending;
  } catch {
    return HyperlaneStatus.pending;
  }
};

export const processHubMessage = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;
  const msg = parseMessage(payload);
  logger.debug('Processing hub message webhook', undefined, undefined, { messageId: msg.id });

  // Query Hyperlane delivery status (skip for Solana destinations)
  const destDomain = msg.destinationDomain;
  const status =
    destDomain === SOLANA_CHAINID ? HyperlaneStatus.pending : await getMessageStatus(msg.id, destDomain, context);

  const message: HubMessage = {
    ...msg,
    status,
    settlementDomain: msg.settlementDomain,
    settlementType: msg.settlementType as TSettlementMessageType,
  };

  // Compute hub intent updates for settlement messages
  const hubIntentUpdates =
    msg.type === TMessageType.Settlement
      ? msg.intentIds.map((id: string) => ({
          id,
          messageId: msg.id,
          settlementDomain: msg.settlementDomain,
          status:
            msg.settlementType === TSettlementMessageType.Settled
              ? TIntentStatus.Dispatched
              : TIntentStatus.DispatchedUnsupported,
        }))
      : [];

  await database.saveMessages([message], [], [], hubIntentUpdates);

  // Notify lighthouse for settlement messages
  if (msg.type === TMessageType.Settlement) {
    if (destDomain === SOLANA_CHAINID) {
      await notifyLighthouse(LIGHTHOUSE_QUEUES.SOLANA);
    } else {
      await notifyLighthouse(LIGHTHOUSE_QUEUES.SETTLEMENT);
    }
  }
};

export const processSpokeMessage = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
    config,
  } = context;
  const msg = parseMessage(payload);
  logger.debug('Processing spoke message webhook', undefined, undefined, { messageId: msg.id });

  // All spoke messages go to the hub; use hub domain if no destination on the message
  const destDomain = msg.destinationDomain || config.hub.domain;
  const status = await getMessageStatus(msg.id, destDomain, context);

  const message: Message = {
    ...msg,
    status,
    destinationDomain: destDomain,
  };

  // Update intents with messageId and status
  const originIntentUpdates =
    msg.type === TMessageType.Intent
      ? msg.intentIds.map((id: string) => ({ id, messageId: msg.id, status: TIntentStatus.Dispatched }))
      : [];

  const destinationIntentUpdates =
    msg.type === TMessageType.Fill
      ? msg.intentIds.map((id: string) => ({ id, messageId: msg.id, status: TIntentStatus.Dispatched }))
      : [];

  await database.saveMessages([message], originIntentUpdates, destinationIntentUpdates, []);

  // Notify lighthouse for fill messages
  if (msg.type === TMessageType.Fill) {
    await notifyLighthouse(LIGHTHOUSE_QUEUES.FILL);
  }
};

export const processQueue = async (
  payload: Record<string, unknown>,
  context: AppContext,
  queueType: QueueType,
): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;
  const queue = parseQueue(payload, queueType);
  logger.debug('Processing queue webhook', undefined, undefined, { queueId: queue.id });

  await database.saveQueues([queue]);
};

export const processHubMeta = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;
  const meta = parseHubMeta(payload);
  logger.debug('Processing hub meta webhook', undefined, undefined, { domain: meta.domain });

  await database.saveHubMeta([meta]);
};

export const processSpokeMeta = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;
  const meta = parseSpokeMeta(payload);
  logger.debug('Processing spoke meta webhook', undefined, undefined, { domain: meta.domain });

  await database.saveSpokeMeta([meta]);
};

export const processSettlementEnqueued = async (
  payload: Record<string, unknown>,
  context: AppContext,
): Promise<void> => {
  const {
    logger,
    adapters: { database, subgraph },
    config,
  } = context;
  // Settlement enqueued events trigger intent status updates
  const intentId = payload.intent
    ? (payload.intent as string).startsWith('0x')
      ? (payload.intent as string)
      : '0x' + Buffer.from(payload.intent as string, 'base64').toString('hex')
    : undefined;

  if (intentId) {
    logger.debug('Processing settlement enqueued webhook', undefined, undefined, { intentId });

    // Try to get full hub intent from the subgraph
    const hubDomain = config.hub.domain;
    try {
      const fullIntent = await subgraph.getHubIntentById(hubDomain, intentId);
      if (fullIntent) {
        await database.saveHubIntents([{ ...fullIntent, status: TIntentStatus.Dispatched }], ['status']);
        return;
      }
    } catch {
      // Fall through to minimal update
    }

    await database.saveHubIntents(
      [{ id: intentId, domain: hubDomain, status: TIntentStatus.Dispatched } as HubIntent],
      ['status'],
    );
  }
};

export const processHubMetaUpdate = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;
  const log = parseProtocolUpdateLog(payload);
  logger.debug('Processing hub meta update webhook', undefined, undefined, { id: log.id });

  await database.saveProtocolUpdateLogs([log]);
};

export const processHubTokenUpdate = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;
  const log = parseHubTokenUpdateLog(payload);
  logger.debug('Processing hub token update webhook', undefined, undefined, { id: log.id });

  await database.saveHubTokenUpdateLogs([log]);
};

export const processHubAssetUpdate = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
  } = context;
  const log = parseHubAssetUpdateLog(payload);
  logger.debug('Processing hub asset update webhook', undefined, undefined, { id: log.id });

  await database.saveHubAssetUpdateLogs([log]);
};
