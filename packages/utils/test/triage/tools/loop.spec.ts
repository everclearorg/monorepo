import { expect, Logger } from '../../../src';
import { triageWithTools } from '../../../src/triage/tools/loop';
import { TriageProvider } from '../../../src/triage/types';

const context = {
  report: {
    severity: 'warning',
    type: 'BadRpcDetected',
    ids: ['1111', 'https://rpc.test'],
    timestamp: Date.now(),
    reason: 'bad rpc',
    env: 'staging',
  },
  prompt: 'prompt',
  logger: new Logger({ name: 'test', level: 'error' }),
};

describe('triage:tools:loop', () => {
  it('uses provider tool loop and returns tool metadata', async () => {
    const provider: TriageProvider = {
      name: 'openai',
      analyze: async () => ({
        verdict: 'unknown',
        rca: 'fallback',
        confidence: 0,
        steps: [],
        autoResolveRecommendation: false,
        reasoning: 'fallback',
      }),
      analyzeWithTools: async (args) => {
        const results = await args.executeToolCalls([
          {
            id: 'call-1',
            name: 'check_rpc_health',
            args: { domain: '1111' },
          },
        ]);
        expect(results).to.have.length(1);
        return {
          verdict: 'transient',
          rca: 'resolved',
          confidence: 0.92,
          steps: ['observe'],
          autoResolveRecommendation: true,
          reasoning: 'tool confirmed recovery',
        };
      },
    };

    const output = await triageWithTools(
      provider,
      context,
      'gpt-4o-mini',
      500,
      [
        {
          name: 'check_rpc_health',
          description: 'check rpc',
          parameters: { type: 'object', properties: { domain: { type: 'string' } }, required: ['domain'] },
        },
      ],
      3,
      500,
    );

    expect(output.triageResult.verdict).to.eq('transient');
    expect(output.toolCallsMade).to.eq(1);
    expect(output.toolNamesUsed).to.deep.eq(['check_rpc_health']);
  });

  it('falls back to single-shot analyze when provider has no tool support', async () => {
    const provider: TriageProvider = {
      name: 'openai',
      analyze: async () => ({
        verdict: 'actionable',
        rca: 'single-shot',
        confidence: 0.5,
        steps: [],
        autoResolveRecommendation: false,
        reasoning: 'no tools',
      }),
    };

    const output = await triageWithTools(provider, context, 'gpt-4o-mini', 500, [], 3, 500);
    expect(output.triageResult.rca).to.eq('single-shot');
    expect(output.toolCallsMade).to.eq(0);
  });
});
