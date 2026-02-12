import { AlertConfig } from '../helpers/config';
import { TriageConfig } from './types';

export type ReadinessResult = {
  ok: boolean;
  errors: string[];
  warnings: string[];
};

const hasProviderConfig = (triage?: TriageConfig): boolean => {
  return Boolean(triage?.providers?.anthropic?.apiKey || triage?.providers?.openai?.apiKey);
};

export const validateTriageReadiness = (config: AlertConfig): ReadinessResult => {
  const triage = config.triage;
  const mode = triage?.mode ?? 'disabled';
  const errors: string[] = [];
  const warnings: string[] = [];

  if (mode === 'disabled') {
    return { ok: true, errors, warnings };
  }

  if (!hasProviderConfig(triage)) {
    errors.push('No triage provider API key configured.');
  }

  if (mode === 'enabled') {
    if (!config.betterUptime?.apiKey || !config.betterUptime?.requesterEmail) {
      errors.push('Enabled mode requires BetterUptime credentials.');
    }
    if ((triage?.autoResolve?.allowedTypes?.length ?? 0) === 0) {
      warnings.push('Enabled mode has no allowed auto-resolve alert types configured.');
    }
  }

  const timeoutMs = triage?.timeoutMs ?? 15000;
  if (timeoutMs < 1000 || timeoutMs > 30000) {
    warnings.push('triage.timeoutMs should typically be within 1000-30000ms.');
  }

  return { ok: errors.length === 0, errors, warnings };
};
