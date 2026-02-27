import { Report, Severity } from '../helpers/config';
import { AutoResolvePolicyDecision, TriageConfig, TriageResult } from './types';

export const shouldAutoResolve = (
  report: Report,
  result: TriageResult,
  triageConfig?: TriageConfig,
): AutoResolvePolicyDecision => {
  if (!result.autoResolveRecommendation) {
    return { shouldAutoResolve: false, reasonCode: 'no_agent_recommendation' };
  }

  const minConfidence = triageConfig?.autoResolve?.minConfidence ?? 0.85;
  if (result.confidence < minConfidence) {
    return { shouldAutoResolve: false, reasonCode: 'low_confidence' };
  }

  const allowedTypes = triageConfig?.autoResolve?.allowedTypes ?? ['BadRpcDetected'];
  if (!allowedTypes.includes(report.type)) {
    // Non-allowlisted types at critical severity are also blocked here
    return { shouldAutoResolve: false, reasonCode: report.severity === Severity.Critical ? 'critical_alert' : 'type_not_allowed' };
  }

  // Allowlisted types with high confidence and agent recommendation can
  // auto-resolve even at critical severity (e.g. BadRpcDetected emitted
  // at critical due to sensor misconfiguration).
  return { shouldAutoResolve: true, reasonCode: 'policy_pass' };
};
