import { Report, Severity } from '../helpers/config';
import { TriageConfig, TriageRoute } from './types';

const defaultRoute = (): TriageRoute => ({
  provider: 'openai',
  model: 'gpt-4o-mini',
});

export const getBlastRadius = (report: Report): number => {
  return new Set(report.ids).size;
};

export const selectTriageRoute = (report: Report, config?: TriageConfig): TriageRoute => {
  const blastRadius = getBlastRadius(report);
  const overrides = config?.routing?.overrides ?? [];
  for (const rule of overrides) {
    const severityMatch = !rule.match.severity || rule.match.severity === report.severity;
    const typeMatch = !rule.match.type || rule.match.type === report.type;
    const radiusMatch = !rule.match.minBlastRadius || blastRadius >= rule.match.minBlastRadius;
    if (severityMatch && typeMatch && radiusMatch) {
      return rule.use;
    }
  }

  if (config?.routing?.default) {
    return config.routing.default;
  }

  if (report.severity === Severity.Critical) {
    return { provider: 'anthropic', model: config?.providers?.anthropic?.model ?? 'claude-sonnet-4-20250514' };
  }
  if (report.severity === Severity.Warning && blastRadius >= 3) {
    return { provider: 'anthropic', model: config?.providers?.anthropic?.model ?? 'claude-sonnet-4-20250514' };
  }
  return defaultRoute();
};
