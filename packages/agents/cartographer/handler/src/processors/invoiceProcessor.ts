import { HubIntent, TIntentStatus } from '@chimera-monorepo/utils';
import { AppContext } from '@chimera-monorepo/cartographer-core';
import { parseHubInvoice, parseHubDeposit } from '../webhooks/parsers';
import { base64ToHex } from '../webhooks/webhookHandler';

/**
 * Create a minimal HubIntent for status-only upserts.
 * The upsert only updates the `status` column; other fields are required by
 * the type but not written.
 */
function hubIntentStatusUpdate(id: string, domain: string, status: TIntentStatus): HubIntent {
  return { id, domain, status } as HubIntent;
}

/**
 * Safely extract an intent ID from the webhook payload.
 */
function extractIntentId(payload: Record<string, unknown>): string {
  const raw = (payload.intent || payload.intent_id || payload.id) as string | undefined;
  if (!raw) return '';
  if (raw.startsWith('0x')) return raw;
  try {
    return base64ToHex(raw);
  } catch {
    return raw;
  }
}

export const processHubInvoice = async (payload: Record<string, unknown>, context: AppContext): Promise<void> => {
  const {
    logger,
    adapters: { database, subgraph },
    config,
  } = context;
  const intentId = extractIntentId(payload);
  if (!intentId) {
    logger.warn('Skipping hub invoice webhook: missing intent ID', undefined, undefined, { payload });
    return;
  }
  const hubDomain = config.hub.domain;

  logger.debug('Processing hub invoice webhook', undefined, undefined, { intentId });

  // Query subgraph for complete invoice data
  try {
    const fullInvoice = await subgraph.getHubInvoiceById(hubDomain, intentId);
    if (fullInvoice) {
      await database.saveHubInvoices([fullInvoice]);

      // Update hub intent status with full data from the subgraph
      const fullIntent = await subgraph.getHubIntentById(hubDomain, intentId).catch(() => undefined);
      if (fullIntent) {
        await database.saveHubIntents([{ ...fullIntent, status: TIntentStatus.Invoiced }], ['status']);
      } else {
        await database.saveHubIntents([hubIntentStatusUpdate(intentId, hubDomain, TIntentStatus.Invoiced)], ['status']);
      }
      return;
    }
    logger.warn('Invoice not found in subgraph, falling back to webhook data', undefined, undefined, { intentId });
  } catch (error) {
    logger.warn('Failed to query subgraph for invoice, falling back to webhook data', undefined, undefined, {
      intentId,
      error: (error as Error).message,
    });
  }

  // Fallback: parse webhook payload
  const invoice = parseHubInvoice(payload);
  await database.saveHubInvoices([invoice]);
  await database.saveHubIntents([hubIntentStatusUpdate(invoice.id, hubDomain, TIntentStatus.Invoiced)], ['status']);
};

export const processHubDeposit = async (
  payload: Record<string, unknown>,
  context: AppContext,
  type: 'enqueued' | 'processed',
): Promise<void> => {
  const {
    logger,
    adapters: { database, subgraph },
    config,
  } = context;
  const intentId = extractIntentId(payload);
  if (!intentId) {
    logger.warn('Skipping hub deposit webhook: missing intent ID', undefined, undefined, { payload, type });
    return;
  }
  const hubDomain = config.hub.domain;

  logger.debug('Processing hub deposit webhook', undefined, undefined, { intentId, type });

  // Query subgraph for complete deposit data
  try {
    const fullDeposit =
      type === 'enqueued'
        ? await subgraph.getHubDepositEnqueuedById(hubDomain, intentId)
        : await subgraph.getHubDepositProcessedById(hubDomain, intentId);

    if (fullDeposit) {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { status, ...deposit } = fullDeposit;
      await database.saveHubDeposits([deposit]);

      // Update hub intent status
      if (deposit.intentId) {
        const fullIntent = await subgraph.getHubIntentById(hubDomain, deposit.intentId).catch(() => undefined);
        if (fullIntent) {
          const intentStatus = type === 'processed' ? TIntentStatus.DepositProcessed : TIntentStatus.Invoiced;
          await database.saveHubIntents([{ ...fullIntent, status: intentStatus }], ['status']);
        } else {
          const intentStatus = type === 'processed' ? TIntentStatus.DepositProcessed : TIntentStatus.Invoiced;
          await database.saveHubIntents([hubIntentStatusUpdate(deposit.intentId, hubDomain, intentStatus)], ['status']);
        }
      }
      return;
    }
    logger.warn('Deposit not found in subgraph, falling back to webhook data', undefined, undefined, {
      intentId,
      type,
    });
  } catch (error) {
    logger.warn('Failed to query subgraph for deposit, falling back to webhook data', undefined, undefined, {
      intentId,
      error: (error as Error).message,
    });
  }

  // Fallback: parse webhook payload
  const deposit = parseHubDeposit(payload, type);
  await database.saveHubDeposits([deposit]);

  if (deposit.intentId) {
    const intentStatus = type === 'processed' ? TIntentStatus.DepositProcessed : TIntentStatus.Invoiced;
    await database.saveHubIntents([hubIntentStatusUpdate(deposit.intentId, hubDomain, intentStatus)], ['status']);
  }
};
