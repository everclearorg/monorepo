import { timingSafeEqual } from 'crypto';
import { AppContext } from '@chimera-monorepo/cartographer-core';
import { jsonifyError, QueueType } from '@chimera-monorepo/utils';

import { processHubInvoice, processHubDeposit } from '../processors/invoiceProcessor';
import {
  processOriginIntent,
  processDestinationIntent,
  processHubIntent,
  processSettlementIntent,
  processOrder,
} from '../processors/intentProcessor';
import {
  processHubMessage,
  processSpokeMessage,
  processQueue,
  processHubMeta,
  processSpokeMeta,
  processSettlementEnqueued,
  processHubMetaUpdate,
  processHubTokenUpdate,
  processHubAssetUpdate,
} from '../processors/monitorProcessor';
import { processDepositorEvent, processToken } from '../processors/depositorProcessor';

export interface WebhookResponse {
  message: string;
  processed: boolean;
  webhookId: string;
}

/**
 * Convert base64-encoded bytes to 0x-prefixed hex string.
 * Goldsky Mirror pipeline payloads encode byte fields in base64.
 */
export function base64ToHex(b64: string): string {
  return '0x' + Buffer.from(b64, 'base64').toString('hex');
}

/**
 * Verify a secret using timing-safe comparison.
 */
export function verifySecret(webhookSecretHeader: string | undefined, expectedSecret: string): boolean {
  if (!webhookSecretHeader) return false;

  try {
    const providedSecret = Buffer.from(webhookSecretHeader);
    const expected = Buffer.from(expectedSecret);

    if (providedSecret.length !== expected.length) return false;

    return timingSafeEqual(providedSecret, expected);
  } catch {
    return false;
  }
}

/**
 * Route webhook payload to the appropriate processor based on webhookName.
 *
 * @param payload - Raw webhook payload from Goldsky Mirror.
 * @param webhookName - Identifies the entity type (e.g. 'origin-intent', 'hub-message').
 * @param context - Application context with adapters, config, and logger.
 * @param domain - Optional domain from URL query param (for spoke webhooks).
 *   Spoke Goldsky pipelines include `?domain=XXXX` in the webhook URL so the
 *   handler knows which spoke chain the entity belongs to.
 */
export async function routeWebhook(
  payload: Record<string, unknown>,
  webhookName: string,
  context: AppContext,
  domain?: string,
): Promise<WebhookResponse> {
  const webhookId = (payload._gs_gid as string) || `mirror-${Date.now()}`;
  const {
    logger,
    adapters: { database },
  } = context;

  logger.debug('Routing webhook', undefined, undefined, { webhookName, webhookId, domain, payload });

  try {
    switch (webhookName) {
      // Hub invoice/deposit webhooks
      case 'hub-invoice':
        await processHubInvoice(payload, context);
        await database.refreshInvoicesView();
        break;
      case 'hub-deposit-enqueued':
        await processHubDeposit(payload, context, 'enqueued');
        await database.refreshInvoicesView();
        break;
      case 'hub-deposit-processed':
        await processHubDeposit(payload, context, 'processed');
        await database.refreshInvoicesView();
        break;

      // Intent webhooks
      case 'origin-intent':
        await processOriginIntent(payload, context, domain);
        await database.refreshIntentsView();
        break;
      case 'destination-intent':
        await processDestinationIntent(payload, context, domain);
        await database.refreshIntentsView();
        break;
      case 'hub-intent':
        await processHubIntent(payload, context);
        await database.refreshIntentsView();
        break;
      case 'settlement-intent':
        await processSettlementIntent(payload, context, domain);
        await database.refreshIntentsView();
        break;
      case 'order':
        await processOrder(payload, context);
        break;

      // Monitor webhooks
      case 'hub-message':
        await processHubMessage(payload, context);
        break;
      case 'spoke-message':
        await processSpokeMessage(payload, context);
        break;
      case 'settlement-queue':
        await processQueue(payload, context, QueueType.Settlement);
        break;
      case 'deposit-queue':
        await processQueue(payload, context, QueueType.Deposit);
        break;
      case 'spoke-queue':
        await processQueue(payload, context, (payload.type as QueueType) || QueueType.Intent);
        break;
      case 'hub-meta':
        await processHubMeta(payload, context);
        break;
      case 'spoke-meta':
        await processSpokeMeta(payload, context);
        break;
      case 'settlement-enqueued':
        await processSettlementEnqueued(payload, context);
        break;
      case 'hub-meta-update':
        await processHubMetaUpdate(payload, context);
        break;
      case 'hub-token-update':
        await processHubTokenUpdate(payload, context);
        break;
      case 'hub-asset-update':
        await processHubAssetUpdate(payload, context);
        break;

      // Depositor webhooks
      case 'depositor-event':
        await processDepositorEvent(payload, context);
        break;
      case 'hub-token':
        await processToken(payload, context);
        break;

      default:
        return { message: `Unknown webhook type: ${webhookName}`, processed: false, webhookId };
    }

    return { message: 'Webhook processed', processed: true, webhookId };
  } catch (error) {
    logger.error('Error processing webhook', undefined, undefined, jsonifyError(error as Error), {
      webhookName,
      webhookId,
    });
    throw error;
  }
}
