import { createLoggingContext, jsonifyError } from '@chimera-monorepo/utils';
import { SubgraphQueryMetaParams } from '@chimera-monorepo/adapters-subgraph';

import { AppContext } from '../context';
import { DEFAULT_SAFE_CONFIRMATIONS } from '../config';
import { getSubgraphSupportedDomains } from './helper';
import { computeIsSwap } from '../lib/intentHelpers';
import { loadReaderCheckpoints, saveReaderCheckpoints } from './checkpoints';

export const updateOriginIntents = async (context: AppContext) => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = context;
  const { requestContext, methodContext } = createLoggingContext(updateOriginIntents.name);
  const domains = getSubgraphSupportedDomains(config);
  const readerTypes = subgraph.getReaderTypes();

  logger.debug('Method start', requestContext, methodContext, { domains, chains: Object.keys(config.chains) });

  // Build per-reader query params: each reader gets its own checkpoint per domain
  const queryParamsPerReader = new Map<string, Map<string, SubgraphQueryMetaParams>>();
  const latestBlockNumbers: Map<string, number> = await subgraph.getLatestBlockNumber(domains);
  for (const rt of readerTypes) {
    queryParamsPerReader.set(rt, new Map());
  }

  await Promise.all(
    domains.map(async (domain) => {
      const latestBlockNumber = latestBlockNumbers.get(domain);
      if (!latestBlockNumber) {
        logger.error('Error getting the latestBlockNumber for domain.', requestContext, methodContext, undefined, {
          domain,
          latestBlockNumber,
          latestBlockNumbers,
        });
        return;
      }

      const safeConfirmations = config.chains[domain].confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;
      const maxBlock = latestBlockNumber - safeConfirmations;
      const checkpoints = await loadReaderCheckpoints(database, 'origin_intent', domain, readerTypes);

      for (const rt of readerTypes) {
        queryParamsPerReader.get(rt)!.set(domain, {
          maxBlockNumber: maxBlock,
          latestNonce: checkpoints[rt] ?? 0,
          orderDirection: 'asc',
        });
      }
    }),
  );

  if (queryParamsPerReader.values().next().value?.size === 0) {
    logger.debug('No domains to update', requestContext, methodContext, { domains });
    return;
  }

  // Get origin intents for all domains with per-reader checkpoints
  const [intents, domainCheckpoints] = await subgraph.getOriginIntentsByNonceWithCheckpoints(queryParamsPerReader);
  logger.info('Retrieved origin intents', requestContext, methodContext, { intents: intents.length });

  // Compute is_swap for each intent by comparing ticker hashes
  const intentsWithSwapFlag = intents.map((intent) => {
    const { requestContext: _requestContext, methodContext: _methodContext } = createLoggingContext(
      updateOriginIntents.name,
    );
    logger.debug('Retrieved origin intent', _requestContext, _methodContext, { intent });

    const isSwap = computeIsSwap(intent, config, logger);

    return {
      ...intent,
      isSwap,
    };
  });

  await database.saveOriginIntents(intentsWithSwapFlag);

  // Save per-reader checkpoints for each domain
  for (const [domain, readerCps] of domainCheckpoints.entries()) {
    await saveReaderCheckpoints(database, 'origin_intent', domain, readerCps);
  }
  // Log the successful update
  logger.debug('Updated OriginIntents in database', requestContext, methodContext, { intents });
};

export const updateDestinationIntents = async (context: AppContext) => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = context;
  const { requestContext, methodContext } = createLoggingContext(updateDestinationIntents.name);

  const domains = getSubgraphSupportedDomains(config);
  const readerTypes = subgraph.getReaderTypes();

  const queryParamsPerReader = new Map<string, Map<string, SubgraphQueryMetaParams>>();
  const latestBlockNumbers: Map<string, number> = await subgraph.getLatestBlockNumber(domains);
  for (const rt of readerTypes) {
    queryParamsPerReader.set(rt, new Map());
  }

  await Promise.all(
    domains.map(async (domain) => {
      const latestBlockNumber = latestBlockNumbers.get(domain);
      if (!latestBlockNumber) {
        logger.error('Error getting the latestBlockNumber for domain.', requestContext, methodContext, undefined, {
          domain,
          latestBlockNumber,
          latestBlockNumbers,
        });
        return;
      }

      const safeConfirmations = config.chains[domain].confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;
      const maxBlock = latestBlockNumber - safeConfirmations;
      const checkpoints = await loadReaderCheckpoints(database, 'destination_intent', domain, readerTypes);

      for (const rt of readerTypes) {
        queryParamsPerReader.get(rt)!.set(domain, {
          maxBlockNumber: maxBlock,
          latestNonce: checkpoints[rt] ?? 0,
          orderDirection: 'asc',
        });
      }
    }),
  );

  if (queryParamsPerReader.values().next().value?.size === 0) {
    return;
  }

  // Get destination intents with per-reader checkpoints
  const [intents, domainCheckpoints] = await subgraph.getDestinationIntentsByNonceWithCheckpoints(queryParamsPerReader);
  intents.forEach((intent) => {
    const { requestContext: _requestContext, methodContext: _methodContext } = createLoggingContext(
      updateDestinationIntents.name,
    );
    logger.debug('Retrieved destination intent', _requestContext, _methodContext, { intent });
  });

  await database.saveDestinationIntents(intents);

  // Save per-reader checkpoints for each domain
  for (const [domain, readerCps] of domainCheckpoints.entries()) {
    await saveReaderCheckpoints(database, 'destination_intent', domain, readerCps);
  }
  // Log the successful update
  logger.debug('Updated DestinationIntents in database', requestContext, methodContext, { intents });
};

export const updateHubIntents = async (context: AppContext) => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = context;
  const { requestContext, methodContext } = createLoggingContext(updateHubIntents.name);
  const readerTypes = subgraph.getReaderTypes();

  logger.debug('Method start', requestContext, methodContext, { hubDomain: config.hub.domain });
  const latestBlockMap = await subgraph.getLatestBlockNumber([config.hub.domain]);
  if (!latestBlockMap.has(config.hub.domain)) {
    logger.error(
      'Error getting the latestBlockNumber for hub domain.',
      requestContext,
      methodContext,
      jsonifyError(new Error(`Returned mapping missing domain key: ${config.hub.domain}`)),
      {
        hubDomain: config.hub.domain,
        latestBlockMap: Object.fromEntries(latestBlockMap.entries()),
      },
    );
    return;
  }

  // Get per-reader checkpoints for the hub domain
  const [addedCheckpoints, filledCheckpoints, enqueuedCheckpoints] = await Promise.all([
    loadReaderCheckpoints(database, 'hub_intent_added', config.hub.domain, readerTypes),
    loadReaderCheckpoints(database, 'hub_intent_filled', config.hub.domain, readerTypes),
    loadReaderCheckpoints(database, 'hub_intent_enqueued', config.hub.domain, readerTypes),
  ]);
  const safeConfirmations = config.hub.confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;
  const maxBlockNumber = latestBlockMap.get(config.hub.domain)! - safeConfirmations;
  logger.debug('Querying subgraph for hub intents', requestContext, methodContext, {
    addedCheckpoints,
    filledCheckpoints,
    enqueuedCheckpoints,
    domain: config.hub.domain,
    latestBlock: maxBlockNumber,
  });

  // Get intents from subgraph with per-reader checkpoints
  // NOTE: enqueued intents will also include the slow path intents
  const [[addedIntents, filledIntents, enqueuedIntents], addedNewCps, filledNewCps, enqueuedNewCps] =
    await subgraph.getHubIntentsByNonceWithCheckpoints(
      config.hub.domain,
      addedCheckpoints,
      filledCheckpoints,
      enqueuedCheckpoints,
      maxBlockNumber,
    );
  logger.debug('Retrieved hub intents', requestContext, methodContext, {
    addedIntents: addedIntents.map((i) => ({ id: i.id, status: i.status })),
    filledIntents: filledIntents.map((i) => ({ id: i.id, status: i.status })),
    enqueuedIntents: enqueuedIntents.map((i) => ({ id: i.id, status: i.status })),
  });

  // Exit early if no new intents are found
  if (addedIntents.length === 0 && filledIntents.length === 0 && enqueuedIntents.length === 0) {
    logger.debug('No new intents found', requestContext, methodContext);
    return;
  }

  // Save intents to the database
  await database.saveHubIntents(addedIntents, ['added_timestamp', 'added_tx_nonce', 'status']);
  await database.saveHubIntents(filledIntents, ['filled_timestamp', 'filled_tx_nonce', 'status']);
  await database.saveHubIntents(enqueuedIntents, [
    'settlement_enqueued_timestamp',
    'settlement_enqueued_tx_nonce',
    'settlement_enqueued_block_number',
    'settlement_domain',
    'settlement_amount',
    'settlement_epoch',
    'status',
    'queue_idx',
  ]);

  // Save per-reader checkpoints
  await Promise.all([
    saveReaderCheckpoints(database, 'hub_intent_added', config.hub.domain, addedNewCps),
    saveReaderCheckpoints(database, 'hub_intent_filled', config.hub.domain, filledNewCps),
    saveReaderCheckpoints(database, 'hub_intent_enqueued', config.hub.domain, enqueuedNewCps),
  ]);
};

export const updateSettlementIntents = async (context: AppContext) => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = context;
  const { requestContext, methodContext } = createLoggingContext(updateSettlementIntents.name);
  const domains = getSubgraphSupportedDomains(config);
  const readerTypes = subgraph.getReaderTypes();

  logger.debug('Method start', requestContext, methodContext, { domains, chains: Object.keys(config.chains) });

  const queryParamsPerReader = new Map<string, Map<string, SubgraphQueryMetaParams>>();
  const latestBlockNumbers: Map<string, number> = await subgraph.getLatestBlockNumber(domains);
  for (const rt of readerTypes) {
    queryParamsPerReader.set(rt, new Map());
  }

  await Promise.all(
    domains.map(async (domain) => {
      const latestBlockNumber = latestBlockNumbers.get(domain);
      if (!latestBlockNumber) {
        logger.error('Error getting the latestBlockNumber for domain.', requestContext, methodContext, undefined, {
          domain,
          latestBlockNumber,
          latestBlockNumbers,
        });
        return;
      }

      const safeConfirmations = config.chains[domain].confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;
      const maxBlock = latestBlockNumber - safeConfirmations;
      const checkpoints = await loadReaderCheckpoints(database, 'settlement_intent', domain, readerTypes);

      for (const rt of readerTypes) {
        queryParamsPerReader.get(rt)!.set(domain, {
          maxBlockNumber: maxBlock,
          latestNonce: checkpoints[rt] ?? 0,
          orderDirection: 'asc',
        });
      }
    }),
  );

  if (queryParamsPerReader.values().next().value?.size === 0) {
    logger.debug('No domains to update', requestContext, methodContext, { domains });
    return;
  }

  // Get settlement intents with per-reader checkpoints
  const [intents, domainCheckpoints] =
    await subgraph.getSettlementIntentsByNonceWithCheckpoints(queryParamsPerReader);
  logger.info('Retrieved settlement intents', requestContext, methodContext, { intents: intents.length });
  intents.forEach((intent) => {
    const { requestContext: _requestContext, methodContext: _methodContext } = createLoggingContext(
      updateSettlementIntents.name,
    );
    logger.debug('Retrieved settlement intent', _requestContext, _methodContext, { intent });
  });

  await database.saveSettlementIntents(intents);

  // Save per-reader checkpoints for each domain
  for (const [domain, readerCps] of domainCheckpoints.entries()) {
    await saveReaderCheckpoints(database, 'settlement_intent', domain, readerCps);
  }
  // Log the successful update
  logger.debug('Updated SettlementIntents in database', requestContext, methodContext, { intents });
};

export const updateOrders = async (context: AppContext) => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = context;
  const { requestContext, methodContext } = createLoggingContext(updateOrders.name);
  const domains = getSubgraphSupportedDomains(config);
  const readerTypes = subgraph.getReaderTypes();

  logger.debug('Method start', requestContext, methodContext, { domains, chains: Object.keys(config.chains) });

  const queryParamsPerReader = new Map<string, Map<string, SubgraphQueryMetaParams>>();
  const latestBlockNumbers: Map<string, number> = await subgraph.getLatestBlockNumber(domains);
  for (const rt of readerTypes) {
    queryParamsPerReader.set(rt, new Map());
  }

  await Promise.all(
    domains.map(async (domain) => {
      const latestBlockNumber = latestBlockNumbers.get(domain);
      if (!latestBlockNumber) {
        logger.error('Error getting the latestBlockNumber for domain.', requestContext, methodContext, undefined, {
          domain,
          latestBlockNumber,
          latestBlockNumbers,
        });
        return;
      }

      const safeConfirmations = config.chains[domain].confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;
      const maxBlock = latestBlockNumber - safeConfirmations;
      const checkpoints = await loadReaderCheckpoints(database, 'order', domain, readerTypes);

      for (const rt of readerTypes) {
        queryParamsPerReader.get(rt)!.set(domain, {
          maxBlockNumber: maxBlock,
          latestNonce: checkpoints[rt] ?? 0,
          orderDirection: 'asc',
        });
      }
    }),
  );

  if (queryParamsPerReader.values().next().value?.size === 0) {
    logger.debug('No domains to update', requestContext, methodContext, { domains });
    return;
  }

  // Get orders with per-reader checkpoints
  const [orders, domainCheckpoints] = await subgraph.getOrdersByNonceWithCheckpoints(queryParamsPerReader);
  logger.info('Retrieved orders', requestContext, methodContext, { domains, orders: orders.length });
  orders.forEach((order) => {
    const { requestContext: _requestContext, methodContext: _methodContext } = createLoggingContext(updateOrders.name);
    logger.debug('Retrieved order', _requestContext, _methodContext, { order });
  });

  await database.saveOrders(orders);

  // Save per-reader checkpoints for each domain
  for (const [domain, readerCps] of domainCheckpoints.entries()) {
    await saveReaderCheckpoints(database, 'order', domain, readerCps);
  }
  // Log the successful update
  logger.debug('Updated Orders in database', requestContext, methodContext, { orders });
};
