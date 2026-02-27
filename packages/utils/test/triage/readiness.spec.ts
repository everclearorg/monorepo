import { expect } from '../../src';
import { validateTriageReadiness } from '../../src/triage/readiness';

describe('triage:readiness', () => {
  it('passes when triage is disabled', () => {
    const result = validateTriageReadiness({ network: 'mainnet', triage: { mode: 'disabled' } });
    expect(result.ok).to.eq(true);
  });

  it('fails when provider keys are missing', () => {
    const result = validateTriageReadiness({ network: 'mainnet', triage: { mode: 'shadow' } });
    expect(result.ok).to.eq(false);
    expect(result.errors.length).to.be.greaterThan(0);
  });

  it('fails enabled mode without betteruptime credentials', () => {
    const result = validateTriageReadiness({
      network: 'mainnet',
      triage: {
        mode: 'enabled',
        providers: { openai: { apiKey: 'key' } },
      },
    });
    expect(result.ok).to.eq(false);
  });
});
