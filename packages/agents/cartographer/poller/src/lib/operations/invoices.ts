import {
  HubDeposit,
  HubInvoice,
  TIntentStatus,
  createLoggingContext,
  getMaxTxNonce,
  jsonifyError,
} from '@chimera-monorepo/utils';

import { getContext } from '../../shared';

export const updateHubInvoices = async () => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateHubInvoices.name);

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
  const enqueuedLatestNonce = await database.getCheckPoint('hub_invoice_' + config.hub.domain);
  const maxBlockNumber = latestBlockMap.get(config.hub.domain)!;
  logger.debug('Querying subgraph for hub invoices', requestContext, methodContext, {
    enqueuedLatestNonce,
    domain: config.hub.domain,
    latestBlock: maxBlockNumber,
  });

  // Get invoices from subgraph
  const [hubInvoices, hubIntents] = await subgraph.getHubInvoicesByNonce(
    config.hub.domain,
    enqueuedLatestNonce,
    maxBlockNumber,
  );
  logger.debug('Retrieved hub invoices', requestContext, methodContext, {
    hubInvoices: hubInvoices.map((i) => ({ id: i.id })),
    hubIntents: hubIntents.map((i) => ({ id: i.id, status: i.status })),
  });

  // Exit early if no new invoices are found
  if (hubInvoices.length === 0) {
    logger.info('No new hub invoices found', requestContext, methodContext);
    return;
  }

  // Deduplicate enqueued invoices
  const invoices = new Map<string, HubInvoice>();
  hubInvoices.forEach((invoice: HubInvoice) => {
    const existing = invoices.get(invoice.id)!;
    if (!existing || invoice.enqueuedTimestamp! > existing.enqueuedTimestamp!) {
      invoices.set(invoice.id, invoice);
    }
  });
  const deduplicatedInvoices = Array.from(invoices.values());

  // Save invoices to database
  await database.saveHubInvoices(deduplicatedInvoices);

  // Save intents status to database
  await database.saveHubIntents(hubIntents, ['status']);

  // Save latest checkpoint
  const latest = getMaxTxNonce(hubInvoices.map((i) => ({ txNonce: i.enqueuedTxNonce! })));
  await database.saveCheckPoint('hub_invoice_' + config.hub.domain, latest);
};

/**
 * @notice Updates processed and enqueued deposits from the hub subgraph.
 * @returns Promise<void>
 */
export const updateHubDeposits = async () => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = getContext();
  const { requestContext, methodContext } = createLoggingContext(updateHubDeposits.name);

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
  const [enqueuedLatestNonce, processedLatestNonce] = await Promise.all([
    database.getCheckPoint('hub_deposit_enqueued_' + config.hub.domain),
    database.getCheckPoint('hub_deposit_processed_' + config.hub.domain),
  ]);
  const maxBlockNumber = latestBlockMap.get(config.hub.domain)!;
  logger.debug('Querying subgraph for hub deposits', requestContext, methodContext, {
    processedLatestNonce,
    enqueuedLatestNonce,
    domain: config.hub.domain,
    latestBlock: maxBlockNumber,
  });

  // Get deposits from subgraph
  const [enqueuedDeposits, processedDeposits] = await Promise.all([
    subgraph.getDepositsEnqueuedByNonce(config.hub.domain, enqueuedLatestNonce, maxBlockNumber),
    subgraph.getDepositsProcessedByNonce(config.hub.domain, processedLatestNonce, maxBlockNumber),
  ]);
  logger.debug('Retrieved hub deposits', requestContext, methodContext, {
    enqueuedDeposits: enqueuedDeposits.map((i) => ({ id: i.id })),
    processedDeposits: processedDeposits.map((i) => ({ id: i.id })),
  });

  // Exit early if no new deposits are found
  if (enqueuedDeposits.length === 0 && processedDeposits.length === 0) {
    logger.info('No new hub deposits found', requestContext, methodContext);
    return;
  }

  // Only save latest entry (processed or enqueued) for each deposit
  const processed = new Map<string, HubDeposit & { status: TIntentStatus }>(processedDeposits.map((i) => [i.id, i]));
  enqueuedDeposits.forEach((deposit) => {
    const existing = processed.get(deposit.id)!;
    if (!existing || deposit.enqueuedTimestamp > existing.enqueuedTimestamp) {
      processed.set(deposit.id, deposit);
    }
  });
  const hubDeposits = Array.from(processed.values());

  // Save deposits to database
  await database.saveHubDeposits(hubDeposits);

  // Save intents status to database
  await database.saveHubIntents(
    hubDeposits.map((d) => ({ id: d.intentId, domain: config.hub.domain, status: d.status })),
    ['status'],
  );

  // Save latest checkpoint
  const latestEnqueued = getMaxTxNonce(enqueuedDeposits.map((i) => ({ txNonce: i.enqueuedTxNonce })));
  const latestProcessed = getMaxTxNonce(processedDeposits.map((i) => ({ txNonce: i.processedTxNonce ?? 0 })));
  await database.saveCheckPoint('hub_deposit_enqueued_' + config.hub.domain, latestEnqueued);
  await database.saveCheckPoint('hub_deposit_processed_' + config.hub.domain, latestProcessed);
};
