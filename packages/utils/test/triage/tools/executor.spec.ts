import { expect } from '../../../src';
import { executeToolCall, executeToolCalls, setTriageToolHandlers } from '../../../src/triage/tools/executor';

describe('triage:tools:executor', () => {
  beforeEach(() => {
    setTriageToolHandlers({});
  });

  it('executes a configured tool handler', async () => {
    setTriageToolHandlers({
      test_tool: async (args) => ({ ok: true, echo: args.value }),
    });

    const result = await executeToolCall(
      {
        id: 'call-1',
        name: 'test_tool',
        args: { value: 'hello' },
      },
      100,
    );

    expect(result.error).to.be.undefined;
    expect(JSON.parse(result.output)).to.deep.eq({ ok: true, echo: 'hello' });
  });

  it('returns unknown tool error when handler is missing', async () => {
    const result = await executeToolCall(
      {
        id: 'call-2',
        name: 'missing_tool',
        args: {},
      },
      100,
    );
    expect(result.error).to.include('Unknown tool');
  });

  it('returns timeout error when handler exceeds timeout', async () => {
    setTriageToolHandlers({
      slow_tool: async () => {
        await new Promise((resolve) => setTimeout(resolve, 25));
        return { ok: true };
      },
    });

    const result = await executeToolCall(
      {
        id: 'call-3',
        name: 'slow_tool',
        args: {},
      },
      5,
    );

    expect(result.error).to.eq('Tool timeout');
  });

  it('rejects invalid args against registered schema', async () => {
    let invoked = false;
    setTriageToolHandlers({
      check_rpc_health: async () => {
        invoked = true;
        return { healthy: true };
      },
    });
    const result = await executeToolCall(
      {
        id: 'call-4',
        name: 'check_rpc_health',
        args: {},
      },
      100,
    );
    expect(invoked).to.eq(false);
    expect(result.error).to.include('Invalid tool args');
  });

  it('handles mixed batch outcomes for executeToolCalls', async () => {
    setTriageToolHandlers({
      check_rpc_health: async () => ({ healthy: true }),
      get_current_epoch: async () => {
        throw new Error('secret=abc123');
      },
    });
    const results = await executeToolCalls(
      [
        { id: 'call-5', name: 'check_rpc_health', args: { domain: '1111' } },
        { id: 'call-6', name: 'get_current_epoch', args: {} },
      ],
      100,
    );
    expect(results).to.have.length(2);
    expect(JSON.parse(results[0].output)).to.deep.eq({ healthy: true });
    expect(results[1].error).to.include('{redacted}');
  });
});
