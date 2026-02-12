import { createStubInstance, restore, stub } from 'sinon';
import { expect, Logger, createRequestContext } from '../../src';
import { triageInterceptor } from '../../src/triage/interceptor';
import * as ProviderModule from '../../src/triage/providers';
import * as HistoryModule from '../../src/triage/history';
import { setTriagePersistenceStore } from '../../src/triage/dedup';
import { TEST_REPORT } from '../helpers/mock';

describe('triage:interceptor', () => {
  const config = {
    network: 'mainnet',
    betterUptime: {
      apiKey: 'test-api-key',
      requesterEmail: 'test@example.com',
    },
    triage: {
      mode: 'enabled' as const,
      timeoutMs: 2000,
      lookbackHours: 6,
      retentionHours: 1,
      timeBucketMinutes: 30,
      providers: {
        openai: {
          apiKey: 'test-api-key',
          model: 'gpt-4o-mini',
        },
      },
    },
  };

  beforeEach(() => {
    const seen = new Set<string>();
    setTriagePersistenceStore({
      hasProcessed: async (fp: string) => seen.has(fp),
      tryReserve: async (record) => {
        if (seen.has(record.fingerprint)) return false;
        seen.add(record.fingerprint);
        return true;
      },
      finalize: async () => undefined,
      pruneExpired: async () => 0,
    });
  });

  afterEach(() => {
    restore();
  });

  it('returns original report when mode is disabled', async () => {
    const output = await triageInterceptor(
      { ...TEST_REPORT, logger: createStubInstance(Logger) },
      { ...config, triage: { ...config.triage, mode: 'disabled' } },
      createRequestContext('test'),
    );
    expect(output.report.reason).to.eq(TEST_REPORT.reason);
    expect(output.shouldAutoResolve).to.eq(false);
  });

  it('enriches alert report on successful triage', async () => {
    stub(HistoryModule, 'fetchRecentIncidents').resolves([]);
    stub(HistoryModule, 'clusterIncidents').returns([]);
    stub(ProviderModule, 'createTriageProviders').returns({
      openai: {
        name: 'openai',
        analyze: async () => ({
          verdict: 'actionable',
          rca: 'test',
          confidence: 0.9,
          steps: ['step'],
          autoResolveRecommendation: false,
          reasoning: 'x',
        }),
      },
    });
    const output = await triageInterceptor(
      { ...TEST_REPORT, logger: createStubInstance(Logger) },
      config,
      createRequestContext('test'),
    );
    expect(output.report.reason).to.include('Agent Analysis');
  });

  it('keeps original reason in dry-run mode', async () => {
    stub(HistoryModule, 'fetchRecentIncidents').resolves([]);
    stub(HistoryModule, 'clusterIncidents').returns([]);
    stub(ProviderModule, 'createTriageProviders').returns({
      openai: {
        name: 'openai',
        analyze: async () => ({
          verdict: 'actionable',
          rca: 'test',
          confidence: 0.9,
          steps: ['step'],
          autoResolveRecommendation: false,
          reasoning: 'x',
        }),
      },
    });
    const output = await triageInterceptor(
      { ...TEST_REPORT, logger: createStubInstance(Logger) },
      { ...config, triage: { ...config.triage, mode: 'dry-run' } },
      createRequestContext('test'),
    );
    expect(output.report.reason).to.eq(TEST_REPORT.reason);
  });

  it('bypasses triage when readiness check fails', async () => {
    const output = await triageInterceptor(
      { ...TEST_REPORT, logger: createStubInstance(Logger) },
      { network: 'mainnet', triage: { mode: 'enabled' } },
      createRequestContext('test'),
    );
    expect(output.report.reason).to.eq(TEST_REPORT.reason);
    expect(output.shouldAutoResolve).to.eq(false);
  });

  it('falls back to secondary provider when primary fails', async () => {
    stub(HistoryModule, 'fetchRecentIncidents').resolves([]);
    stub(HistoryModule, 'clusterIncidents').returns([]);
    stub(ProviderModule, 'createTriageProviders').returns({
      openai: {
        name: 'openai',
        analyze: async () => {
          throw new Error('provider unavailable');
        },
      },
      anthropic: {
        name: 'anthropic',
        analyze: async () => ({
          verdict: 'actionable',
          rca: 'fallback path',
          confidence: 0.91,
          steps: ['step'],
          autoResolveRecommendation: false,
          reasoning: 'fallback succeeded',
        }),
      },
    });
    const output = await triageInterceptor(
      { ...TEST_REPORT, logger: createStubInstance(Logger) },
      {
        ...config,
        triage: {
          ...config.triage,
          providers: {
            ...config.triage.providers,
            anthropic: { apiKey: 'x', model: 'claude-sonnet-4-20250514' },
          },
        },
      },
      createRequestContext('test'),
    );
    expect(output.providerUsed).to.eq('anthropic');
    expect(output.modelUsed).to.eq('claude-sonnet-4-20250514');
    expect(output.report.reason).to.include('Agent Analysis');
  });

  it('falls back to original alert when provider times out', async () => {
    stub(HistoryModule, 'fetchRecentIncidents').resolves([]);
    stub(HistoryModule, 'clusterIncidents').returns([]);
    stub(ProviderModule, 'createTriageProviders').returns({
      openai: {
        name: 'openai',
        analyze: async () => {
          throw new Error('request timeout');
        },
      },
    });
    const output = await triageInterceptor(
      { ...TEST_REPORT, logger: createStubInstance(Logger) },
      config,
      createRequestContext('test'),
    );
    expect(output.report.reason).to.eq(TEST_REPORT.reason);
    expect(output.shouldAutoResolve).to.eq(false);
  });
});
