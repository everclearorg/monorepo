import { createHmac, randomUUID } from 'crypto';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import { dirname } from 'path';
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
// Dead-letter queue (persisted to disk, bounded)
// ---------------------------------------------------------------------------

const MAX_DLQ_SIZE = 500;
const DLQ_ALERT_THRESHOLD = 50;
const DLQ_FILE = process.env.DLQ_FILE_PATH ?? '/tmp/everclear-monitor-dlq.json';
const dlq: MonitorEventV1[] = [];
let dlqLoaded = false;

function ensureDlqLoaded(): void {
  if (dlqLoaded) return;
  dlqLoaded = true;
  try {
    if (existsSync(DLQ_FILE)) {
      const raw = readFileSync(DLQ_FILE, 'utf-8');
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        dlq.push(...parsed.slice(0, MAX_DLQ_SIZE));
      }
    }
  } catch {
    // corrupted file — start fresh
  }
}

function persistDlq(): void {
  try {
    const dir = dirname(DLQ_FILE);
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    writeFileSync(DLQ_FILE, JSON.stringify(dlq), 'utf-8');
  } catch {
    // non-fatal: persistence is best-effort
  }
}

export function getDlqSize(): number {
  ensureDlqLoaded();
  return dlq.length;
}

// ---------------------------------------------------------------------------
// Convert a Report into a MonitorEventV1
// ---------------------------------------------------------------------------

const TYPE_CATEGORY_MAP: Record<string, string> = {
  BadRpcDetected: 'chain-infra',
  ChainDelayed: 'chain-infra',
  LowGasRelayer: 'gas',
  LowGasGateway: 'gas',
  LowGasTokenomicsGateway: 'gas',
  MissingSpokeBalance: 'spoke-balance',
  ExecutionQueueCountExceeded: 'queue',
  ExecutionQueueLatencyExceeded: 'queue',
  IntentQueueCountExceeded: 'queue',
  IntentQueueLatencyExceeded: 'queue',
  SettlementQueueCountExceeded: 'queue',
  SettlementQueueAmountExceeded: 'queue',
  SettlementQueueLatencyExceeded: 'queue',
  DepositQueueCountExceeded: 'queue',
  DepositQueueLatencyExceeded: 'queue',
  InvoiceNotProcessedYet: 'invoice',
  InvoiceDiscountedMoreThan5Times: 'invoice',
  InvoiceAmountLessThanCustodiedAmount: 'invoice',
  TokenomicsDataExportDelayed: 'tokenomics',
  TokenomicsDataExportHighLatency: 'tokenomics',
  HyperlaneMessagesProcessingDelayed: 'messaging',
};

function reportToEvent(
  report: Report,
  config: EventEmitterConfig,
): MonitorEventV1 {
  const severityMap: Record<string, 'info' | 'warning' | 'critical'> = {
    [Severity.Informational]: 'info',
    [Severity.Warning]: 'warning',
    [Severity.Critical]: 'critical',
  };

  const chainIds = report.ids
    .map((id) => parseInt(id, 10))
    .filter((n) => !isNaN(n) && n > 0);

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
    routingHints: {
      category: TYPE_CATEGORY_MAP[report.type],
      chainIds: chainIds.length > 0 ? chainIds : undefined,
      service: 'monitor',
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

  ensureDlqLoaded();
  const delivered = await sendWithRetry(event, resolvedConfig);

  if (!delivered) {
    if (dlq.length < MAX_DLQ_SIZE) {
      dlq.push(event);
      persistDlq();

      logger.warn('Event delivery failed, added to DLQ', requestContext, methodContext, {
        eventId: event.eventId,
        type: event.type,
        dlqSize: dlq.length,
      });

      if (dlq.length >= DLQ_ALERT_THRESHOLD && dlq.length % DLQ_ALERT_THRESHOLD === 0) {
        logger.error('DLQ size exceeds alert threshold', requestContext, methodContext, {
          type: 'DLQThresholdExceeded',
          message: `DLQ has ${dlq.length} undelivered events (threshold: ${DLQ_ALERT_THRESHOLD})`,
          context: { dlqSize: dlq.length, threshold: DLQ_ALERT_THRESHOLD, maxDlqSize: MAX_DLQ_SIZE },
        });
      }
    } else {
      logger.error('DLQ full — event dropped permanently', requestContext, methodContext, {
        type: 'DLQFullError',
        message: 'DLQ full — event dropped permanently',
        context: { eventId: event.eventId, type: event.type, dlqSize: dlq.length, maxDlqSize: MAX_DLQ_SIZE },
      });
    }
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
/**
 * Check the health of the everclear-agents pipeline via heartbeat endpoint.
 * Returns null on success, or an error message on failure.
 */
export async function checkPipelineHeartbeat(
  webhookUrl: string,
  logger: Logger,
  requestContext: RequestContext,
  timeoutMs = 5_000,
): Promise<{ ok: boolean; details?: Record<string, unknown>; error?: string }> {
  const methodContext = createMethodContext('checkPipelineHeartbeat');
  const heartbeatUrl = webhookUrl.replace(/\/events\/?$/, '/heartbeat');

  try {
    const response = await axiosPost(
      heartbeatUrl,
      {},
      { timeout: timeoutMs, validateStatus: () => true },
      1,
    );

    if (response.status >= 200 && response.status < 300) {
      logger.info('Pipeline heartbeat OK', requestContext, methodContext, {
        response: response.data,
      });
      return { ok: true, details: response.data as Record<string, unknown> };
    }

    const msg = `Heartbeat returned HTTP ${response.status}`;
    logger.warn(msg, requestContext, methodContext);
    return { ok: false, error: msg };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    logger.warn('Pipeline heartbeat failed', requestContext, methodContext, {
      error: msg,
    });
    return { ok: false, error: msg };
  }
}

export async function flushDlq(
  emitterConfig: EventEmitterConfig,
  logger: Logger,
  requestContext: RequestContext,
): Promise<number> {
  const methodContext = createMethodContext('flushDlq');
  let flushed = 0;
  const resolvedConfig = { ...DEFAULT_CONFIG, ...emitterConfig } as EventEmitterConfig;

  ensureDlqLoaded();
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
  persistDlq();

  if (flushed > 0) {
    logger.info('DLQ flushed', requestContext, methodContext, {
      flushed,
      remaining: dlq.length,
    });
  }

  return flushed;
}
