import { ajv } from '../../types/ajv';
import { redactSensitiveData } from '../redact';
import { TriageToolCall, TriageToolResult } from './types';
import { getToolDefinitionByName } from './registry';

export type TriageToolHandler = (args: Record<string, unknown>) => Promise<unknown>;
export type TriageToolHandlerMap = Record<string, TriageToolHandler>;

let toolHandlers: TriageToolHandlerMap = {};
const validatorCache = new Map<string, ReturnType<typeof ajv.compile>>();

export const setTriageToolHandlers = (handlers: TriageToolHandlerMap) => {
  toolHandlers = { ...handlers };
};

export const getTriageToolHandlers = (): TriageToolHandlerMap => ({ ...toolHandlers });

const sanitizeToolError = (error: unknown): string => {
  const text = error instanceof Error ? error.message : String(error);
  return String(redactSensitiveData(text));
};

const validateToolArgs = (call: TriageToolCall): string | undefined => {
  const definition = getToolDefinitionByName(call.name);
  if (!definition) {
    return undefined;
  }
  let validator = validatorCache.get(call.name);
  if (!validator) {
    validator = ajv.compile(definition.parameters);
    validatorCache.set(call.name, validator);
  }
  const valid = validator(call.args);
  if (valid) {
    return undefined;
  }
  return `Invalid tool args: ${ajv.errorsText(validator.errors)}`;
};

export const executeToolCall = async (call: TriageToolCall, perToolTimeoutMs: number): Promise<TriageToolResult> => {
  const handler = toolHandlers[call.name];
  if (!handler) {
    return {
      toolCallId: call.id,
      output: '',
      error: `Unknown tool: ${call.name}`,
    };
  }
  const validationError = validateToolArgs(call);
  if (validationError) {
    return {
      toolCallId: call.id,
      output: '',
      error: validationError,
    };
  }

  let timer: ReturnType<typeof setTimeout>;
  try {
    const timeoutPromise = new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(new Error('Tool timeout')), perToolTimeoutMs);
    });
    const output = await Promise.race([handler(call.args), timeoutPromise]);
    return {
      toolCallId: call.id,
      output: JSON.stringify(output),
    };
  } catch (error: unknown) {
    return {
      toolCallId: call.id,
      output: '',
      error: sanitizeToolError(error),
    };
  } finally {
    clearTimeout(timer!);
  }
};

export const executeToolCalls = async (calls: TriageToolCall[], perToolTimeoutMs: number): Promise<TriageToolResult[]> => {
  return Promise.all(calls.map((call) => executeToolCall(call, perToolTimeoutMs)));
};
