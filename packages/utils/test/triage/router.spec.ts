import { expect, Severity } from '../../src';
import { selectTriageRoute } from '../../src/triage/router';
import { TEST_REPORT } from '../helpers/mock';

describe('triage:router', () => {
  it('routes critical alerts to anthropic by default', () => {
    const route = selectTriageRoute({ ...TEST_REPORT, severity: Severity.Critical }, { mode: 'enabled' });
    expect(route.provider).to.eq('anthropic');
  });

  it('applies explicit overrides', () => {
    const route = selectTriageRoute(TEST_REPORT, {
      mode: 'enabled',
      routing: {
        default: { provider: 'anthropic', model: 'claude' },
        overrides: [{ match: { type: 'test' }, use: { provider: 'openai', model: 'gpt-4o-mini' } }],
      },
    });
    expect(route.provider).to.eq('openai');
    expect(route.model).to.eq('gpt-4o-mini');
  });
});
