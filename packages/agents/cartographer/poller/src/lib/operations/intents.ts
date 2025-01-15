import { createLoggingContext, getMaxTxNonce, jsonifyError } from '@chimera-monorepo/utils';
import { SubgraphQueryMetaParams } from '@chimera-monorepo/adapters-subgraph';

import { getContext } from '../../shared';
import { DEFAULT_SAFE_CONFIRMATIONS } from '.';

export const updateOriginIntents = async () => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateOriginIntents.name);
  const domains = Object.keys(config.chains).filter((domain) => domain !== config.hub.domain);

  logger.debug('Method start', requestContext, methodContext, { domains, chains: Object.keys(config.chains) });

  const queryMetaParams: Map<string, SubgraphQueryMetaParams> = new Map();
  const latestBlockNumbers: Map<string, number> = await subgraph.getLatestBlockNumber(domains);
  await Promise.all(
    domains.map(async (domain) => {
      let latestBlockNumber: number | undefined = undefined;
      if (latestBlockNumbers.has(domain)) {
        latestBlockNumber = latestBlockNumbers.get(domain)!;
      }

      if (!latestBlockNumber) {
        logger.error('Error getting the latestBlockNumber for domain.', requestContext, methodContext, undefined, {
          domain,
          latestBlockNumber,
          latestBlockNumbers,
        });
        return;
      }

      // Retrieve the most recent origin intent nonce we've saved for this domain.
      const safeConfirmations = config.chains[domain].confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;
      const latestNonce = await database.getCheckPoint('origin_intent_' + domain);
      queryMetaParams.set(domain, {
        maxBlockNumber: latestBlockNumber - safeConfirmations,
        latestNonce: latestNonce,
        orderDirection: 'asc',
      });
    }),
  );

  if (queryMetaParams.size === 0) {
    logger.debug('No domains to update', requestContext, methodContext, { domains });
    return;
  }

  // Get origin intents for all domains in the mapping.
  const intents = await subgraph.getOriginIntentsByNonce(queryMetaParams);
  logger.info('Retrieved origin intents', requestContext, methodContext, { intents: intents.length });
  intents.forEach((intent) => {
    const { requestContext: _requestContext, methodContext: _methodContext } = createLoggingContext(
      updateOriginIntents.name,
    );
    logger.debug('Retrieved origin intent', _requestContext, _methodContext, { intent });
  });
  const checkpoints = domains
    .map((domain) => {
      const domainIntents = intents.filter((intent) => intent.origin === domain);
      const max = getMaxTxNonce(domainIntents);
      const latest = queryMetaParams.get(domain)?.latestNonce ?? 0;
      if (domainIntents.length > 0 && max > latest) {
        return { domain, checkpoint: max };
      }
      return undefined;
    })
    .filter((x) => !!x) as { domain: string; checkpoint: number }[];

  await database.saveOriginIntents(intents);
  for (const checkpoint of checkpoints) {
    await database.saveCheckPoint('origin_intent_' + checkpoint.domain, checkpoint.checkpoint);
  }
  // Log the successful update
  logger.debug('Updated OriginIntents in database', requestContext, methodContext, { intents });
};

export const updateDestinationIntents = async () => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateDestinationIntents.name);

  const domains = Object.keys(config.chains).filter((domain) => domain !== config.hub.domain);

  const queryMetaParams: Map<string, SubgraphQueryMetaParams> = new Map();
  const latestBlockNumbers: Map<string, number> = await subgraph.getLatestBlockNumber(domains);
  await Promise.all(
    domains.map(async (domain) => {
      let latestBlockNumber: number | undefined = undefined;
      if (latestBlockNumbers.has(domain)) {
        latestBlockNumber = latestBlockNumbers.get(domain)!;
      }

      if (!latestBlockNumber) {
        logger.error('Error getting the latestBlockNumber for domain.', requestContext, methodContext, undefined, {
          domain,
          latestBlockNumber,
          latestBlockNumbers,
        });
        return;
      }

      // Retrieve the most recent destination intent nonce we've saved for this domain.
      const latestNonce = await database.getCheckPoint('destination_intent_' + domain);
      const safeConfirmations = config.chains[domain].confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;
      queryMetaParams.set(domain, {
        maxBlockNumber: latestBlockNumber - safeConfirmations,
        latestNonce: latestNonce,
        orderDirection: 'asc',
      });
    }),
  );

  if (queryMetaParams.size > 0) {
    // Get destination intents for all domains in the mapping.
    const intents = await subgraph.getDestinationIntentsByNonce(queryMetaParams);
    intents.forEach((intent) => {
      const { requestContext: _requestContext, methodContext: _methodContext } = createLoggingContext(
        updateDestinationIntents.name,
      );
      logger.debug('Retrieved destination intent', _requestContext, _methodContext, { intent });
    });
    const checkpoints = domains
      .map((domain) => {
        const domainIntents = intents.filter((intent) => intent.destination === domain);
        const max = getMaxTxNonce(domainIntents);
        const latest = queryMetaParams.get(domain)?.latestNonce ?? 0;
        if (domainIntents.length > 0 && max > latest) {
          return { domain, checkpoint: max };
        }
        return undefined;
      })
      .filter((x) => !!x) as { domain: string; checkpoint: number }[];

    await database.saveDestinationIntents(intents);
    for (const checkpoint of checkpoints) {
      await database.saveCheckPoint('destination_intent_' + checkpoint.domain, checkpoint.checkpoint);
    }
    // Log the successful update
    logger.debug('Updated DestinationIntents in database', requestContext, methodContext, { intents });
  }
};

export const updateHubIntents = async () => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateHubIntents.name);

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

  // Get the latest checkpoint for the hub domain
  const addedLatestNonce = await database.getCheckPoint('hub_intent_added_' + config.hub.domain);
  const filledLatestNonce = await database.getCheckPoint('hub_intent_filled_' + config.hub.domain);
  const enqueuedLatestNonce = await database.getCheckPoint('hub_intent_enqueued_' + config.hub.domain);
  const safeConfirmations = config.hub.confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;
  const maxBlockNumber = latestBlockMap.get(config.hub.domain)! - safeConfirmations;
  logger.debug('Querying subgraph for hub intents', requestContext, methodContext, {
    addedLatestNonce,
    filledLatestNonce,
    enqueuedLatestNonce,
    domain: config.hub.domain,
    latestBlock: maxBlockNumber,
  });

  // Get intents from subgraph
  // NOTE: enqueued intents will also include the slow path intents
  const [addedIntents, filledIntents, enqueuedIntents] = await subgraph.getHubIntentsByNonce(
    config.hub.domain,
    addedLatestNonce,
    filledLatestNonce,
    enqueuedLatestNonce,
    maxBlockNumber,
  );
  logger.debug('Retrieved hub intents', requestContext, methodContext, {
    addedIntents: addedIntents.map((i) => ({ id: i.id, status: i.status })),
    filledIntents: filledIntents.map((i) => ({ id: i.id, status: i.status })),
    enqueuedIntents: enqueuedIntents.map((i) => ({ id: i.id, status: i.status })),
  });

  // Exit early if no new intents are found
  if (addedIntents.length === 0 && filledIntents.length === 0 && enqueuedIntents.length === 0) {
    // Save latest checkpoint
    logger.debug('No new intents found', requestContext, methodContext);
    return;
  }

  // Save intents to database
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

  // Save checkpoints
  if (addedIntents.length !== 0) {
    // Save latest checkpoint
    const latest = getMaxTxNonce(addedIntents.map((i) => ({ txNonce: i.addedTxNonce! })));
    await database.saveCheckPoint('hub_intent_added_' + config.hub.domain, latest);
  }
  if (filledIntents.length !== 0) {
    // Save latest checkpoint
    const latest = getMaxTxNonce(filledIntents.map((i) => ({ txNonce: i.filledTxNonce! })));
    await database.saveCheckPoint('hub_intent_filled_' + config.hub.domain, latest);
  }
  if (enqueuedIntents.length !== 0) {
    // Save latest checkpoint
    const latest = getMaxTxNonce(enqueuedIntents.map((i) => ({ txNonce: i.settlementEnqueuedTxNonce! })));
    await database.saveCheckPoint('hub_intent_enqueued_' + config.hub.domain, latest);
  }
};

export const updateSettlementIntents = async () => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateSettlementIntents.name);
  const domains = Object.keys(config.chains).filter((domain) => domain !== config.hub.domain);

  logger.debug('Method start', requestContext, methodContext, { domains, chains: Object.keys(config.chains) });

  const queryMetaParams: Map<string, SubgraphQueryMetaParams> = new Map();
  const latestBlockNumbers: Map<string, number> = await subgraph.getLatestBlockNumber(domains);
  await Promise.all(
    domains.map(async (domain) => {
      let latestBlockNumber: number | undefined = undefined;
      if (latestBlockNumbers.has(domain)) {
        latestBlockNumber = latestBlockNumbers.get(domain)!;
      }

      if (!latestBlockNumber) {
        logger.error('Error getting the latestBlockNumber for domain.', requestContext, methodContext, undefined, {
          domain,
          latestBlockNumber,
          latestBlockNumbers,
        });
        return;
      }

      // Retrieve the most recent settlement intent nonce we've saved for this domain.
      const latestNonce = await database.getCheckPoint('settlement_intent_' + domain);
      const safeConfirmations = config.chains[domain].confirmations ?? DEFAULT_SAFE_CONFIRMATIONS;
      queryMetaParams.set(domain, {
        maxBlockNumber: latestBlockNumber - safeConfirmations,
        latestNonce: latestNonce,
        orderDirection: 'asc',
      });
    }),
  );

  if (queryMetaParams.size === 0) {
    logger.debug('No domains to update', requestContext, methodContext, { domains });
    return;
  }

  // Get settlement intents for all domains in the mapping.
  const intents = await subgraph.getSettlementIntentsByNonce(queryMetaParams);
  logger.info('Retrieved settlement intents', requestContext, methodContext, { intents: intents.length });
  intents.forEach((intent) => {
    const { requestContext: _requestContext, methodContext: _methodContext } = createLoggingContext(
      updateSettlementIntents.name,
    );
    logger.debug('Retrieved setttlement intent', _requestContext, _methodContext, { intent });
  });
  const checkpoints = domains
    .map((domain) => {
      const domainIntents = intents.filter((intent) => intent.domain === domain);
      const max = getMaxTxNonce(domainIntents);
      const latest = queryMetaParams.get(domain)?.latestNonce ?? 0;
      if (domainIntents.length > 0 && max > latest) {
        return { domain, checkpoint: max };
      }
      return undefined;
    })
    .filter((x) => !!x) as { domain: string; checkpoint: number }[];

  await database.saveSettlementIntents(intents);
  for (const checkpoint of checkpoints) {
    await database.saveCheckPoint('settlement_intent_' + checkpoint.domain, checkpoint.checkpoint);
  }
  // Log the successful update
  logger.debug('Updated SettlementIntents in database', requestContext, methodContext, { intents });
};
