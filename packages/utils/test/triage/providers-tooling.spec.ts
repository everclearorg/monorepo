import { createStubInstance, restore, stub } from 'sinon';
import { expect, Logger } from '../../src';
import { OpenAITriageProvider } from '../../src/triage/providers/openai';
import { AnthropicTriageProvider } from '../../src/triage/providers/anthropic';

describe('triage:providers:tooling', () => {
  afterEach(() => {
    restore();
  });

  it('openai synthesizes final answer from accumulated tool history at max rounds', async () => {
    const provider = new OpenAITriageProvider({ apiKey: 'test' });
    const createStub = stub((provider as any).client.chat.completions, 'create');
    createStub.onFirstCall().resolves({
      choices: [
        {
          finish_reason: 'tool_calls',
          message: {
            content: null,
            tool_calls: [
              {
                id: 'tc1',
                type: 'function',
                function: { name: 'check_rpc_health', arguments: JSON.stringify({ domain: '1111' }) },
              },
            ],
          },
        },
      ],
    } as any);
    createStub.onSecondCall().resolves({
      choices: [
        {
          finish_reason: 'stop',
          message: {
            content: JSON.stringify({
              verdict: 'transient',
              rca: 'rpc recovered',
              confidence: 0.93,
              steps: ['observe'],
              autoResolveRecommendation: true,
              reasoning: 'verified via tools',
            }),
          },
        },
      ],
    } as any);

    const result = await provider.analyzeWithTools!({
      context: {
        report: {
          severity: 'warning',
          type: 'BadRpcDetected',
          ids: ['1111'],
          timestamp: Date.now(),
          reason: 'rpc issue',
          env: 'staging',
        },
        prompt: 'test',
        logger: createStubInstance(Logger),
      },
      model: 'gpt-4o-mini',
      timeoutMs: 1000,
      tools: [
        {
          name: 'check_rpc_health',
          description: 'check rpc',
          parameters: {
            type: 'object',
            properties: { domain: { type: 'string' } },
            required: ['domain'],
            additionalProperties: false,
          },
        },
      ],
      maxRounds: 1,
      executeToolCalls: async () => [{ toolCallId: 'tc1', output: JSON.stringify({ healthy: true }) }],
    });

    expect(createStub.callCount).to.eq(2);
    expect(result.verdict).to.eq('transient');
    expect(result.autoResolveRecommendation).to.eq(true);
  });

  it('anthropic synthesizes final answer from accumulated tool history at max rounds', async () => {
    const provider = new AnthropicTriageProvider({ apiKey: 'test' });
    const createStub = stub((provider as any).client.messages, 'create');
    createStub.onFirstCall().resolves({
      content: [
        {
          type: 'tool_use',
          id: 'tu1',
          name: 'check_rpc_health',
          input: { domain: '1111' },
        },
      ],
    } as any);
    createStub.onSecondCall().resolves({
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            verdict: 'transient',
            rca: 'rpc recovered',
            confidence: 0.95,
            steps: ['observe'],
            autoResolveRecommendation: true,
            reasoning: 'verified via tools',
          }),
        },
      ],
    } as any);

    const result = await provider.analyzeWithTools!({
      context: {
        report: {
          severity: 'warning',
          type: 'BadRpcDetected',
          ids: ['1111'],
          timestamp: Date.now(),
          reason: 'rpc issue',
          env: 'staging',
        },
        prompt: 'test',
        logger: createStubInstance(Logger),
      },
      model: 'claude-sonnet-4-20250514',
      timeoutMs: 1000,
      tools: [
        {
          name: 'check_rpc_health',
          description: 'check rpc',
          parameters: {
            type: 'object',
            properties: { domain: { type: 'string' } },
            required: ['domain'],
            additionalProperties: false,
          },
        },
      ],
      maxRounds: 1,
      executeToolCalls: async () => [{ toolCallId: 'tu1', output: JSON.stringify({ healthy: true }) }],
    });

    expect(createStub.callCount).to.eq(2);
    expect(result.verdict).to.eq('transient');
    expect(result.autoResolveRecommendation).to.eq(true);
  });
});
