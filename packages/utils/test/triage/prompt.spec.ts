import { expect } from '../../src';
import { parseTriageResult } from '../../src/triage/prompt';

describe('triage:prompt', () => {
  it('clamps confidence above 1', () => {
    const parsed = parseTriageResult(
      JSON.stringify({
        verdict: 'actionable',
        rca: 'x',
        confidence: 1.7,
        steps: [],
        autoResolveRecommendation: false,
        reasoning: 'x',
      }),
    );
    expect(parsed.confidence).to.eq(1);
  });

  it('clamps confidence below 0', () => {
    const parsed = parseTriageResult(
      JSON.stringify({
        verdict: 'duplicate',
        rca: 'x',
        confidence: -0.3,
        steps: [],
        autoResolveRecommendation: false,
        reasoning: 'x',
      }),
    );
    expect(parsed.confidence).to.eq(0);
  });
});
