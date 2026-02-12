import { Report, Severity } from '../helpers/config';
import { AutoResolvePolicyDecision, TriageConfig, TriageResult } from './types';

export const shouldAutoResolve = (
  report: Report,
  result: TriageResult,
  triageConfig?: TriageConfig,
): AutoResolvePolicyDecision => {
  if (report.severity === Severity.Critical) {
    return { shouldAutoResolve: false, reasonCode: 'critical_alert' };
  }
  if (!result.autoResolveRecommendation) {
    return { shouldAutoResolve: false, reasonCode: 'no_agent_recommendation' };
  }

  const minConfidence = triageConfig?.autoResolve?.minConfidence ?? 0.85;
  if (result.confidence < minConfidence) {
    return { shouldAutoResolve: false, reasonCode: 'low_confidence' };
  }

  const allowedTypes = triageConfig?.autoResolve?.allowedTypes ?? ['BadRpcDetected'];
  if (!allowedTypes.includes(report.type)) {
    return { shouldAutoResolve: false, reasonCode: 'type_not_allowed' };
  }

  return { shouldAutoResolve: true, reasonCode: 'policy_pass' };
};
