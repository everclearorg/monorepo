import { createHmac, randomUUID } from 'crypto';
import { Report, Severity } from './config';
import { Logger, RequestContext, createMethodContext } from '../logging';
import { axiosPost } from './axios';

// ---------------------------------------------------------------------------
// MonitorEvent v1 — mirrors everclear-agents/src/alert-pipeline/types.ts
// ---------------------------------------------------------------------------

export type MonitorEventV1 = {
  version: '1.0';
  eventId: string;
  fingerprintHint?: string;
  source: 'monorepo-monitor' | 'everclear-indexer';
  type: string;
  severity: 'info' | 'warning' | 'critical';
  detectedAt: string;
  environment: 'dev' | 'staging' | 'prod';
  context: Record<string, unknown>;
  rawData?: unknown;
  routingHints?: {
    category?: string;
    chainIds?: number[];
    service?: string;
  };
};

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

export type EventEmitterConfig = {
  webhookUrl: string;
  webhookSecret: string;
  environment: 'dev' | 'staging' | 'prod';
  network: string;
  retries: number;
  retryBaseMs: number;
  timeoutMs: number;
};

const DEFAULT_CONFIG: Partial<EventEmitterConfig> = {
  retries: 3,
  retryBaseMs: 1000,
  timeoutMs: 10_000,
};

// ---------------------------------------------------------------------------
// Dead-letter queue (in-memory, bounded)
// ---------------------------------------------------------------------------

const MAX_DLQ_SIZE = 500;
const dlq: MonitorEventV1[] = [];

export function getDlqSize(): number {
  return dlq.length;
}

// ---------------------------------------------------------------------------
// Convert a Report into a MonitorEventV1
// ---------------------------------------------------------------------------

function reportToEvent(
  report: Report,
  config: EventEmitterConfig,
): MonitorEventV1 {
  const severityMap: Record<string, 'info' | 'warning' | 'critical'> = {
    [Severity.Informational]: 'info',
    [Severity.Warning]: 'warning',
    [Severity.Critical]: 'critical',
  };

  return {
    version: '1.0',
    eventId: randomUUID(),
    source: 'monorepo-monitor',
    type: report.type,
    severity: severityMap[report.severity] ?? 'warning',
    detectedAt: new Date(report.timestamp).toISOString(),
    environment: config.environment,
    context: {
      ids: report.ids,
      reason: report.reason,
      env: report.env,
      network: config.network,
    },
  };
}

// ---------------------------------------------------------------------------
// Sign and send
// ---------------------------------------------------------------------------

function signPayload(
  body: string,
  secret: string,
): { signature: string; timestamp: string; nonce: string } {
  const timestamp = String(Date.now());
  const nonce = randomUUID();
  const signature = createHmac('sha256', secret)
    .update(`${timestamp}.${nonce}.${body}`)
    .digest('hex');
  return { signature, timestamp, nonce };
}

async function sendWithRetry(
  event: MonitorEventV1,
  config: EventEmitterConfig,
): Promise<boolean> {
  const body = JSON.stringify(event);

  for (let attempt = 0; attempt <= config.retries; attempt++) {
    try {
      const { signature, timestamp, nonce } = signPayload(body, config.webhookSecret);
      const response = await axiosPost(
        config.webhookUrl,
        event,
        {
          timeout: config.timeoutMs,
          headers: {
            'Content-Type': 'application/json',
            'X-Signature': signature,
            'X-Timestamp': timestamp,
            'X-Nonce': nonce,
          },
          validateStatus: () => true,
        },
        1,
      );

      if (response.status >= 200 && response.status < 300) {
        return true;
      }

      // 4xx errors are not retryable (bad payload, auth failure)
      if (response.status >= 400 && response.status < 500) {
        return false;
      }
    } catch {
      // Network error or timeout — retry
    }

    if (attempt < config.retries) {
      const delay = config.retryBaseMs * Math.pow(2, attempt);
      await new Promise((r) => setTimeout(r, delay));
    }
  }

  return false;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Emit a Report as a MonitorEventV1 to the everclear-agents ingestion endpoint.
 * On failure after retries, the event is added to an in-memory dead-letter queue.
 */
export async function emitEvent(
  report: Report,
  emitterConfig: EventEmitterConfig,
  logger: Logger,
  requestContext: RequestContext,
): Promise<void> {
  const methodContext = createMethodContext('emitEvent');
  const resolvedConfig = { ...DEFAULT_CONFIG, ...emitterConfig } as EventEmitterConfig;
  const event = reportToEvent(report, resolvedConfig);

  const delivered = await sendWithRetry(event, resolvedConfig);

  if (!delivered) {
    if (dlq.length < MAX_DLQ_SIZE) {
      dlq.push(event);
    } else {
      logger.error('DLQ full — event dropped permanently', requestContext, methodContext, {
        eventId: event.eventId,
        type: event.type,
        dlqSize: dlq.length,
        maxDlqSize: MAX_DLQ_SIZE,
      });
    }
    logger.warn('Event delivery failed, added to DLQ', requestContext, methodContext, {
      eventId: event.eventId,
      type: event.type,
      dlqSize: dlq.length,
    });
  } else {
    logger.info('Event emitted', requestContext, methodContext, {
      eventId: event.eventId,
      type: event.type,
    });
  }
}

/**
 * Attempt to flush the dead-letter queue.
 */
export async function flushDlq(
  emitterConfig: EventEmitterConfig,
  logger: Logger,
  requestContext: RequestContext,
): Promise<number> {
  const methodContext = createMethodContext('flushDlq');
  let flushed = 0;
  const resolvedConfig = { ...DEFAULT_CONFIG, ...emitterConfig } as EventEmitterConfig;

  const remaining: MonitorEventV1[] = [];
  while (dlq.length > 0) {
    const event = dlq.shift()!;
    const delivered = await sendWithRetry(event, resolvedConfig);
    if (delivered) {
      flushed++;
    } else {
      remaining.push(event);
    }
  }
  dlq.push(...remaining);

  if (flushed > 0) {
    logger.info('DLQ flushed', requestContext, methodContext, {
      flushed,
      remaining: dlq.length,
    });
  }

  return flushed;
}
