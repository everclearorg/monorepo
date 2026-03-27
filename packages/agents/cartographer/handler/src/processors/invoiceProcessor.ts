import { HubIntent, TIntentStatus, LIGHTHOUSE_QUEUES } from '@chimera-monorepo/utils';
import { AppContext } from '@chimera-monorepo/cartographer-core';
import { parseHubInvoice, parseHubDeposit } from '../webhooks/parsers';
import { notifyLighthouse } from '../notify';

/**
 * Create a minimal HubIntent for status-only upserts.
 * The upsert only updates the `status` column; other fields are required by
 * the type but not written.
 */
function hubIntentStatusUpdate(id: string, domain: string, status: TIntentStatus): HubIntent {
  return { id, domain, status } as HubIntent;
}

export const processHubInvoice = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database },
    config,
  } = context;

  const invoice = parseHubInvoice(payload);
  if (!invoice.intentId) {
    logger.warn('Skipping hub invoice webhook: missing intent ID', undefined, undefined, { payload });
    return;
  }

  logger.debug('Processing hub invoice webhook', undefined, undefined, { intentId: invoice.intentId });

  await database.saveHubInvoices([invoice]);
  await database.saveHubIntents(
    [hubIntentStatusUpdate(invoice.intentId, config.hub.domain, TIntentStatus.Invoiced)],
    ['status'],
  );
  await notifyLighthouse(LIGHTHOUSE_QUEUES.INVOICE);
};

export const processHubDeposit = async (
  payload: Record<string, unknown>,
  context: AppContext,
  type: 'enqueued' | 'processed',
): Promise<void> => {
  const {
    logger,
    adapters: { database },
    config,
  } = context;

  const deposit = parseHubDeposit(payload, type);
  if (!deposit.intentId) {
    logger.warn('Skipping hub deposit webhook: missing intent ID', undefined, undefined, { payload, type });
    return;
  }

  logger.debug('Processing hub deposit webhook', undefined, undefined, { intentId: deposit.intentId, type });

  await database.saveHubDeposits([deposit]);

  const intentStatus = type === 'processed' ? TIntentStatus.DepositProcessed : TIntentStatus.Invoiced;
  await database.saveHubIntents(
    [hubIntentStatusUpdate(deposit.intentId, config.hub.domain, intentStatus)],
    ['status'],
  );
  await notifyLighthouse(LIGHTHOUSE_QUEUES.INVOICE);
};
