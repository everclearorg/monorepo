import { TriageContext, TriageResult } from '../types';

export type JsonSchemaObject = Record<string, unknown>;

export type TriageToolDefinition = {
  name: string;
  description: string;
  parameters: JsonSchemaObject;
};

export type TriageToolCall = {
  id: string;
  name: string;
  args: Record<string, unknown>;
};

export type TriageToolResult = {
  toolCallId: string;
  output: string;
  error?: string;
};

export type ProviderTurnResult =
  | { kind: 'final'; text: string }
  | { kind: 'tool_calls'; calls: TriageToolCall[]; assistantPayload: unknown };

export type TriageToolExecutor = (calls: TriageToolCall[]) => Promise<TriageToolResult[]>;

export type AnalyzeWithToolsArgs = {
  context: TriageContext;
  model: string;
  timeoutMs: number;
  tools: TriageToolDefinition[];
  maxRounds: number;
  executeToolCalls: TriageToolExecutor;
};

export type AnalyzeWithToolsFn = (args: AnalyzeWithToolsArgs) => Promise<TriageResult>;
