import {
  HubDeposit,
  HubInvoice,
  TIntentStatus,
  createLoggingContext,
  jsonifyError,
} from '@chimera-monorepo/utils';
import { ReaderCheckpoints } from '@chimera-monorepo/adapters-subgraph';

import { AppContext } from '../context';
import { loadReaderCheckpoints, saveReaderCheckpoints } from './checkpoints';

export const updateHubInvoices = async (context: AppContext) => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = context;
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

  // Get per-reader checkpoints for the hub domain
  const readerTypes = subgraph.getReaderTypes();
  const checkpoints = await loadReaderCheckpoints(database, 'hub_invoice', config.hub.domain, readerTypes);
  const maxBlockNumber = latestBlockMap.get(config.hub.domain)!;
  logger.debug('Querying subgraph for hub invoices', requestContext, methodContext, {
    checkpoints,
    domain: config.hub.domain,
    latestBlock: maxBlockNumber,
  });

  // Get invoices from subgraph with per-reader checkpoints
  const [[hubInvoices, hubIntents], newCheckpoints] = await subgraph.getHubInvoicesByNonceWithCheckpoints(
    config.hub.domain,
    checkpoints,
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

  // Save per-reader checkpoints
  await saveReaderCheckpoints(database, 'hub_invoice', config.hub.domain, newCheckpoints);
};

/**
 * @notice Updates processed and enqueued deposits from the hub subgraph.
 * @returns Promise<void>
 */
export const updateHubDeposits = async (context: AppContext) => {
  const {
    adapters: { subgraph, database },
    config,
    logger,
  } = context;
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

  // Get per-reader checkpoints for the hub domain
  const readerTypes = subgraph.getReaderTypes();
  const [enqueuedCheckpoints, processedCheckpoints] = await Promise.all([
    loadReaderCheckpoints(database, 'hub_deposit_enqueued', config.hub.domain, readerTypes),
    loadReaderCheckpoints(database, 'hub_deposit_processed', config.hub.domain, readerTypes),
  ]);
  const maxBlockNumber = latestBlockMap.get(config.hub.domain)!;
  logger.debug('Querying subgraph for hub deposits', requestContext, methodContext, {
    enqueuedCheckpoints,
    processedCheckpoints,
    domain: config.hub.domain,
    latestBlock: maxBlockNumber,
  });

  // Get deposits from subgraph with per-reader checkpoints
  const [[enqueuedDeposits, enqueuedNewCps], [processedDeposits, processedNewCps]] = await Promise.all([
    subgraph.getDepositsEnqueuedByNonceWithCheckpoints(config.hub.domain, enqueuedCheckpoints, maxBlockNumber),
    subgraph.getDepositsProcessedByNonceWithCheckpoints(config.hub.domain, processedCheckpoints, maxBlockNumber),
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

  // Save per-reader checkpoints
  await Promise.all([
    saveReaderCheckpoints(database, 'hub_deposit_enqueued', config.hub.domain, enqueuedNewCps),
    saveReaderCheckpoints(database, 'hub_deposit_processed', config.hub.domain, processedNewCps),
  ]);
};
