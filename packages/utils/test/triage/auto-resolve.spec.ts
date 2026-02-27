import { expect, Severity } from '../../src';
import { shouldAutoResolve } from '../../src/triage/auto-resolve';
import { TEST_REPORT } from '../helpers/mock';

describe('triage:auto-resolve', () => {
  it('blocks critical alerts', () => {
    const decision = shouldAutoResolve(
      { ...TEST_REPORT, severity: Severity.Critical },
      {
        verdict: 'actionable',
        rca: 'x',
        confidence: 1,
        steps: [],
        autoResolveRecommendation: true,
        reasoning: 'x',
      },
      { mode: 'enabled' },
    );
    expect(decision.shouldAutoResolve).to.eq(false);
    expect(decision.reasonCode).to.eq('critical_alert');
  });

  it('allows whitelisted high-confidence recommendation', () => {
    const decision = shouldAutoResolve(
      { ...TEST_REPORT, type: 'BadRpcDetected', severity: Severity.Warning },
      {
        verdict: 'transient',
        rca: 'rpc recovered',
        confidence: 0.95,
        steps: ['verify'],
        autoResolveRecommendation: true,
        reasoning: 'healthy',
      },
      { mode: 'enabled', autoResolve: { allowedTypes: ['BadRpcDetected'], minConfidence: 0.9 } },
    );
    expect(decision.shouldAutoResolve).to.eq(true);
  });
});
