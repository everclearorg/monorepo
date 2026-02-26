import {
  alertViaBetterUptimeIfNeeded,
  createUniqueIds,
  resolveAlertViaBetterUptime,
  alertDiscord,
  alertTelegram,
} from '../alerts';
import { AlertConfig, Report } from './config';
import { Logger, RequestContext, createMethodContext } from '../logging';
import { triageInterceptor } from '../triage';
import { setAutoResolveOutcome } from '../triage/dedup';
import { recordAutoResolveSuccess } from '../triage/metrics';
import { redactSensitiveData } from '../triage/redact';
import { emitEvent, EventEmitterConfig } from './events';

// ---------------------------------------------------------------------------
// Pipeline mode: controls whether alerts are sent via legacy channels,
// the new event pipeline, or both.
//   - "legacy"      : existing Discord/Telegram/BetterUptime + triage (default)
//   - "dual"        : legacy channels AND event emission (migration phase)
//   - "events_only" : only emit MonitorEventV1 to everclear-agents
// ---------------------------------------------------------------------------
export type AlertPipelineMode = 'legacy' | 'dual' | 'events_only';

const getPipelineMode = (): AlertPipelineMode => {
  const raw = process.env.ALERT_PIPELINE_MODE ?? 'legacy';
  if (raw === 'dual' || raw === 'events_only') return raw;
  return 'legacy';
};

const getEmitterConfig = (config: AlertConfig): { emitterConfig: EventEmitterConfig | null; secretEmpty: boolean } => {
  const url =
    config.eventPipeline?.webhookUrl ??
    process.env.ALERT_EVENT_WEBHOOK_URL ??
    process.env.MONITOR_WEBHOOK_URL;
  const secret =
    config.eventPipeline?.webhookSecret ??
    process.env.ALERT_EVENT_WEBHOOK_SECRET ??
    process.env.MONITOR_WEBHOOK_SECRET ??
    '';
  if (!url) return { emitterConfig: null, secretEmpty: false };

  return {
    emitterConfig: {
      webhookUrl: url,
      webhookSecret: secret,
      environment:
        config.eventPipeline?.environment ??
        ((process.env.ALERT_EVENT_ENVIRONMENT ?? 'prod') as 'dev' | 'staging' | 'prod'),
      network: config.network,
      retries: config.eventPipeline?.retries ?? 3,
      retryBaseMs: config.eventPipeline?.retryBaseMs ?? 1000,
      timeoutMs: config.eventPipeline?.timeoutMs ?? 10_000,
    },
    secretEmpty: !secret,
  };
};

const preprocessReport = (report: Report, config: AlertConfig): Report => ({
  ...report,
  reason: `${report.reason}#${createUniqueIds(report.ids)}`,
  env: `${report.env} - ${config.network}`,
});

const toLogSafeReport = (report: Report) => {
  const redactedReason = String(redactSensitiveData(report.reason));
  return {
    type: report.type,
    severity: report.severity,
    env: report.env,
    ids: report.ids,
    timestamp: report.timestamp,
    reason: redactedReason.slice(0, 500),
  };
};

/**
 * Sends all alerts at once.
 *
 * Behaviour depends on ALERT_PIPELINE_MODE:
 *   - "legacy"      : triage + Discord/Telegram/BetterUptime (existing behaviour)
 *   - "dual"        : legacy channels AND emit MonitorEventV1 to everclear-agents
 *   - "events_only" : only emit MonitorEventV1 (no legacy channels, no triage)
 */
export async function sendAlerts(
  report: Report,
  logger: Logger,
  config: AlertConfig,
  requestContext: RequestContext,
): Promise<void> {
  const methodContext = createMethodContext(sendAlerts.name);
  const mode = getPipelineMode();
  const { emitterConfig, secretEmpty } = getEmitterConfig(config);

  if (secretEmpty && emitterConfig) {
    logger.warn('Event emitter webhook secret is empty — HMAC signatures will provide no authentication', requestContext, methodContext);
  }

  // --- Event emission (dual + events_only) ---
  if (mode !== 'legacy' && emitterConfig) {
    try {
      await emitEvent(report, emitterConfig, logger, requestContext);
    } catch (emitErr) {
      logger.error('Event emission failed; continuing with legacy path', requestContext, methodContext, {
        type: 'EventEmissionError',
        message: emitErr instanceof Error ? emitErr.message : String(emitErr),
        context: { mode },
        stack: emitErr instanceof Error ? emitErr.stack : undefined,
      });
    }
  }

  // --- If events_only, skip legacy entirely ---
  if (mode === 'events_only') {
    logger.info('Event emitted (events_only mode)', requestContext, methodContext, {
      report: toLogSafeReport(report),
      mode,
    });
    return;
  }

  // --- Legacy path (legacy + dual) ---
  const triageOutput = await triageInterceptor(report, config, requestContext);
  const alertReport = preprocessReport(triageOutput.report, config);
  const alertPromises = [];
  let autoResolvePromiseIndex: number | undefined = undefined;

  if (config.discord) {
    alertPromises.push(alertDiscord(alertReport, config.discord.url, requestContext));
  }
  if (config.telegram) {
    alertPromises.push(alertTelegram(alertReport, config.telegram, requestContext));
  }
  if (config.betterUptime) {
    if (triageOutput.shouldAutoResolve) {
      autoResolvePromiseIndex = alertPromises.length;
      alertPromises.push(resolveAlertViaBetterUptime(alertReport, config.betterUptime, requestContext, false));
    } else {
      alertPromises.push(alertViaBetterUptimeIfNeeded(alertReport, config.betterUptime, requestContext));
    }
  }

  const deliveryResults = await Promise.allSettled(alertPromises);
  if (triageOutput.shouldAutoResolve && triageOutput.fingerprint && autoResolvePromiseIndex !== undefined) {
    const autoResolveSettled = deliveryResults[autoResolvePromiseIndex];
    const succeeded = autoResolveSettled?.status === 'fulfilled';
    recordAutoResolveSuccess(succeeded);
    await setAutoResolveOutcome(
      triageOutput.fingerprint,
      succeeded,
      succeeded ? 'auto_resolve_dispatched' : 'auto_resolve_dispatch_failed',
    );
  }

  logger.info('Alerts sent', requestContext, methodContext, {
    report: toLogSafeReport(alertReport),
    mode,
    triage: {
      provider: triageOutput.providerUsed,
      model: triageOutput.modelUsed,
      autoResolve: triageOutput.shouldAutoResolve,
      reasonCode: triageOutput.autoResolveReasonCode,
      fingerprint: triageOutput.fingerprint,
      mode: triageOutput.mode,
    },
  });
}

/**
 * Resolves all alerts at once.
 */
export async function resolveAlerts(
  report: Report,
  logger: Logger,
  config: AlertConfig,
  requestContext: RequestContext,
  byName: boolean = false,
): Promise<void> {
  const methodContext = createMethodContext(resolveAlerts.name);
  const alertReport = preprocessReport(report, config);
  const resolvePromises = [];

  if (config.betterUptime) {
    resolvePromises.push(resolveAlertViaBetterUptime(alertReport, config.betterUptime, requestContext, byName));
  }

  await Promise.allSettled(resolvePromises);

  logger.info('Alerts resolved', requestContext, methodContext, {
    report: toLogSafeReport(alertReport),
  });
}
