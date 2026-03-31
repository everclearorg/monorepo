// eslint-disable-next-line @typescript-eslint/no-var-requires
const bs58 = require('bs58') as { decode: (input: string) => Uint8Array };
import { AppContext } from '@chimera-monorepo/cartographer-core';
import { LIGHTHOUSE_QUEUES, SOLANA_CHAINID } from '@chimera-monorepo/utils';
import { notifyLighthouse } from '../notify';

/** CPI discriminator that must match bytes 0–7 of the decoded instruction data. */
const CPI_DISCRIMINATOR = 'e445a52e51cb9a1d';

/** Map of event discriminator (hex) → lighthouse queue name. */
const EVENT_QUEUE_MAP: Record<string, string> = {
  '1263e45a565b315d': LIGHTHOUSE_QUEUES.INTENT, // IntentAdded
  '97e5c05b34bba821': LIGHTHOUSE_QUEUES.FILL, // IntentFilled
  '75cfc4aec5c80b43': LIGHTHOUSE_QUEUES.SOLANA, // Settled
  'aadd51debc47162f': LIGHTHOUSE_QUEUES.SOLANA, // Delivered
};

/**
 * Process a raw Solana instruction payload from the Goldsky webhook.
 *
 * Decodes the base58 `data` field, validates the CPI discriminator,
 * extracts the event discriminator, and notifies the appropriate
 * lighthouse queue.
 */
export async function processSolanaInstruction(payload: Record<string, unknown>, context: AppContext): Promise<void> {
  const { logger } = context;
  const data = payload.data as string | undefined;

  if (!data) {
    logger.debug('Solana instruction payload missing data field, skipping');
    return;
  }

  let bytes: Uint8Array;
  try {
    bytes = bs58.decode(data);
  } catch (err) {
    logger.warn('Failed to base58-decode Solana instruction data', undefined, undefined, {
      error: (err as Error).message,
    });
    return;
  }

  // Need at least 16 bytes: 8 CPI discriminator + 8 event discriminator
  if (bytes.length < 16) {
    logger.debug('Solana instruction data too short, skipping', undefined, undefined, {
      length: bytes.length,
    });
    return;
  }

  const cpiDisc = Buffer.from(bytes.slice(0, 8)).toString('hex');
  if (cpiDisc !== CPI_DISCRIMINATOR) {
    logger.debug('CPI discriminator mismatch, skipping', undefined, undefined, {
      expected: CPI_DISCRIMINATOR,
      actual: cpiDisc,
    });
    return;
  }

  const eventDisc = Buffer.from(bytes.slice(8, 16)).toString('hex');
  const queueName = EVENT_QUEUE_MAP[eventDisc];

  if (!queueName) {
    logger.debug('Unknown Solana event discriminator, skipping', undefined, undefined, {
      eventDisc,
    });
    return;
  }

  logger.info('Processing Solana instruction event', undefined, undefined, {
    eventDisc,
    queueName,
    domain: SOLANA_CHAINID,
  });

  await notifyLighthouse(queueName);
}
