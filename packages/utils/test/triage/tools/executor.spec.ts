import { expect } from '../../../src';
import { executeToolCall, setTriageToolHandlers } from '../../../src/triage/tools/executor';

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
});
