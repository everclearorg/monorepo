import { delay } from '../../helpers/axios';
import { TriageToolCall, TriageToolResult } from './types';

export type TriageToolHandler = (args: Record<string, unknown>) => Promise<unknown>;
export type TriageToolHandlerMap = Record<string, TriageToolHandler>;

let toolHandlers: TriageToolHandlerMap = {};

export const setTriageToolHandlers = (handlers: TriageToolHandlerMap) => {
  toolHandlers = { ...handlers };
};

export const getTriageToolHandlers = (): TriageToolHandlerMap => ({ ...toolHandlers });

export const executeToolCall = async (call: TriageToolCall, perToolTimeoutMs: number): Promise<TriageToolResult> => {
  const handler = toolHandlers[call.name];
  if (!handler) {
    return {
      toolCallId: call.id,
      output: '',
      error: `Unknown tool: ${call.name}`,
    };
  }

  try {
    const output = await Promise.race([
      handler(call.args),
      (async () => {
        await delay(perToolTimeoutMs);
        throw new Error('Tool timeout');
      })(),
    ]);
    return {
      toolCallId: call.id,
      output: JSON.stringify(output),
    };
  } catch (error: unknown) {
    return {
      toolCallId: call.id,
      output: '',
      error: error instanceof Error ? error.message : String(error),
    };
  }
};

export const executeToolCalls = async (calls: TriageToolCall[], perToolTimeoutMs: number): Promise<TriageToolResult[]> => {
  return Promise.all(calls.map((call) => executeToolCall(call, perToolTimeoutMs)));
};
