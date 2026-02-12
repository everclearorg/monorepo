import { AlertConfig, Report } from '../helpers/config';
import { MethodContext, RequestContext, createMethodContext } from '../logging';
import { shouldAutoResolve } from './auto-resolve';
import { finalizeFingerprint, pruneExpiredFingerprints, tryReserveFingerprint } from './dedup';
import { computeFingerprint } from './fingerprint';
import { clusterIncidents, fetchRecentIncidents } from './history';
import {
  recordAutoResolveAttempt,
  recordTriageDeduped,
  recordTriageFallback,
  recordTriageIntercepted,
  recordTriagePerformed,
  recordTriageTimeout,
} from './metrics';
import { buildTriagePrompt } from './prompt';
import { createTriageProviders } from './providers';
import { redactSensitiveData } from './redact';
import { validateTriageReadiness } from './readiness';
import { selectTriageRoute } from './router';
import { DEFAULT_TRIAGE_CONFIG, TriageResult } from './types';

type InterceptorOutput = {
  report: Report;
  triageResult?: TriageResult;
  shouldAutoResolve: boolean;
  autoResolveReasonCode?: string;
  providerUsed?: string;
  modelUsed?: string;
  fingerprint?: string;
  mode?: string;
};

type ProviderName = 'anthropic' | 'openai';

const appendAgentAnalysis = (report: Report, result: TriageResult): Report => {
  const analysis = [
    '',
    'Agent Analysis:',
    `- Verdict: ${result.verdict}`,
    `- Confidence: ${result.confidence.toFixed(2)}`,
    `- RCA: ${result.rca}`,
    `- Steps: ${result.steps.join(' | ') || 'none'}`,
    `- Recommended Auto Resolve: ${result.autoResolveRecommendation ? 'yes' : 'no'}`,
    `- Reasoning: ${result.reasoning}`,
  ].join('\n');
  return {
    ...report,
    reason: `${report.reason}\n${analysis}`,
  };
};

const hasAcknowledgedIncident = (report: Report, incidents: Awaited<ReturnType<typeof fetchRecentIncidents>>): boolean => {
  return incidents.some((incident) => incident.status === 'Acknowledged' && incident.name.includes(report.type));
};

const safeMarkProcessed = async (
  report: Report,
  requestContext: RequestContext,
  methodContext: MethodContext | undefined,
  record: Parameters<typeof finalizeFingerprint>[0],
) => {
  try {
    await finalizeFingerprint(record);
  } catch (error: unknown) {
    report.logger.warn('Failed to persist triage fingerprint, continuing', requestContext, methodContext, {
      error: error instanceof Error ? error.message : String(error),
      fingerprint: record.fingerprint,
    });
  }
};

const modelForProvider = (provider: ProviderName, config: AlertConfig['triage'], defaultModel: string): string => {
  if (provider === 'anthropic') {
    return config?.providers?.anthropic?.model ?? 'claude-sonnet-4-20250514';
  }
  return config?.providers?.openai?.model ?? defaultModel;
};

export const triageInterceptor = async (
  report: Report,
  config: AlertConfig,
  requestContext: RequestContext,
): Promise<InterceptorOutput> => {
  const methodContext = createMethodContext(triageInterceptor.name);
  const triageConfig = {
    ...DEFAULT_TRIAGE_CONFIG,
    ...(config.triage ?? {}),
  };

  if (triageConfig.mode === 'disabled') {
    return { report, shouldAutoResolve: false, mode: triageConfig.mode };
  }

  const readiness = validateTriageReadiness(config);
  if (!readiness.ok) {
    report.logger.warn('Triage readiness check failed; bypassing triage', requestContext, methodContext, {
      errors: readiness.errors,
      warnings: readiness.warnings,
      mode: triageConfig.mode,
    });
    recordTriageFallback();
    return { report, shouldAutoResolve: false, mode: triageConfig.mode };
  }
  if (readiness.warnings.length > 0) {
    report.logger.warn('Triage readiness warnings detected', requestContext, methodContext, {
      warnings: readiness.warnings,
      mode: triageConfig.mode,
    });
  }

  recordTriageIntercepted();
  try {
    await pruneExpiredFingerprints();
  } catch (error: unknown) {
    report.logger.warn('Failed to prune triage fingerprints, continuing', requestContext, methodContext, {
      error: error instanceof Error ? error.message : String(error),
    });
  }

  const fingerprint = computeFingerprint(report, config.network, triageConfig.timeBucketMinutes);
  const baseRecord = {
    fingerprint,
    reportType: report.type,
    severity: String(report.severity),
    env: report.env,
    network: config.network,
    ids: report.ids,
    reason: report.reason,
    triageMode: triageConfig.mode,
    expiresAt: new Date(Date.now() + triageConfig.retentionHours * 60 * 60 * 1000),
  } as const;
  try {
    if (!(await tryReserveFingerprint(baseRecord))) {
      report.logger.info('Skipping triage for already processed fingerprint', requestContext, methodContext, {
        fingerprint,
        type: report.type,
      });
      recordTriageDeduped();
      return { report, shouldAutoResolve: false, fingerprint, mode: triageConfig.mode };
    }
  } catch (error: unknown) {
    report.logger.warn('Failed to check fingerprint dedup state, continuing', requestContext, methodContext, {
      error: error instanceof Error ? error.message : String(error),
      fingerprint,
    });
  }

  const providers = createTriageProviders(config.triage);
  const route = selectTriageRoute(report, config.triage);
  const primaryProvider = providers[route.provider];
  const secondaryProviderName = (route.provider === 'openai' ? 'anthropic' : 'openai') as ProviderName;
  const secondaryProvider = providers[secondaryProviderName];

  if (!primaryProvider && !secondaryProvider) {
    recordTriageFallback();
    await safeMarkProcessed(report, requestContext, methodContext, baseRecord);
    return { report, shouldAutoResolve: false, fingerprint, mode: triageConfig.mode };
  }

  try {
    const history = await fetchRecentIncidents(report, config.betterUptime, triageConfig.lookbackHours);
    const clustered = clusterIncidents(history);
    const prompt = buildTriagePrompt(report, redactSensitiveData(config), clustered);
    const start = Date.now();
    const triageContext = {
      report,
      prompt,
      logger: report.logger,
    };
    let providerUsed = route.provider as ProviderName;
    let modelUsed = route.model;
    let triageResult: TriageResult;
    try {
      if (!primaryProvider) {
        throw new Error(`Primary provider unavailable: ${route.provider}`);
      }
      triageResult = await primaryProvider.analyze(triageContext, route.model, triageConfig.timeoutMs);
    } catch (primaryError: unknown) {
      if (!secondaryProvider) {
        throw primaryError;
      }
      providerUsed = secondaryProviderName;
      modelUsed = modelForProvider(secondaryProviderName, config.triage, route.model);
      report.logger.warn('Primary triage provider failed, retrying with fallback provider', requestContext, methodContext, {
        primaryProvider: route.provider,
        fallbackProvider: secondaryProviderName,
        primaryError: primaryError instanceof Error ? primaryError.message : String(primaryError),
      });
      triageResult = await secondaryProvider.analyze(triageContext, modelUsed, triageConfig.timeoutMs);
    }
    const latencyMs = Date.now() - start;
    recordTriagePerformed(latencyMs);

    const policy = shouldAutoResolve(report, triageResult, config.triage);
    if (policy.shouldAutoResolve && hasAcknowledgedIncident(report, history)) {
      policy.shouldAutoResolve = false;
      policy.reasonCode = 'human_acknowledged_incident';
    }
    if (policy.shouldAutoResolve) {
      recordAutoResolveAttempt(true);
    }

    await safeMarkProcessed(report, requestContext, methodContext, {
      ...baseRecord,
      triageResult,
      providerUsed,
      modelUsed,
      triageLatencyMs: latencyMs,
      autoResolveAttempted: policy.shouldAutoResolve,
      autoResolveSucceeded: false,
      autoResolveReasonCode: policy.reasonCode,
      expiresAt: new Date(Date.now() + triageConfig.retentionHours * 60 * 60 * 1000),
    });

    const enrichedReport = triageConfig.mode === 'dry-run' ? report : appendAgentAnalysis(report, triageResult);
    return {
      report: enrichedReport,
      triageResult,
      shouldAutoResolve: triageConfig.mode === 'enabled' && policy.shouldAutoResolve,
      autoResolveReasonCode: policy.reasonCode,
      providerUsed,
      modelUsed,
      fingerprint,
      mode: triageConfig.mode,
    };
  } catch (error: unknown) {
    const isTimeout = error instanceof Error && error.message.toLowerCase().includes('timeout');
    if (isTimeout) {
      recordTriageTimeout();
    }
    recordTriageFallback();
    report.logger.warn('Triage interceptor failed, falling back to original alert', requestContext, methodContext, {
      type: report.type,
      reason: report.reason,
      error: error instanceof Error ? error.message : String(error),
    });
    await safeMarkProcessed(report, requestContext, methodContext, baseRecord);
    return { report, shouldAutoResolve: false, fingerprint, mode: triageConfig.mode };
  }
};
