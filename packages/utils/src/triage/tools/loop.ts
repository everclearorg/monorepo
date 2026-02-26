import { executeToolCalls } from './executor';
import { recordToolCallExecuted, recordToolRoundsUsed } from '../metrics';
import { TriageProvider } from '../types';
import { TriageContext, TriageResult } from '../types';
import { TriageToolDefinition } from './types';

export type TriageToolLoopOutput = {
  triageResult: TriageResult;
  toolCallsMade: number;
  toolNamesUsed: string[];
  roundsUsed: number;
};

export const triageWithTools = async (
  provider: TriageProvider,
  context: TriageContext,
  model: string,
  timeoutMs: number,
  tools: TriageToolDefinition[],
  maxRounds: number,
  perToolTimeoutMs: number,
): Promise<TriageToolLoopOutput> => {
  if (!provider.analyzeWithTools || tools.length === 0) {
    const triageResult = await provider.analyze(context, model, timeoutMs);
    return {
      triageResult,
      toolCallsMade: 0,
      toolNamesUsed: [],
      roundsUsed: 0,
    };
  }

  const toolNamesUsed = new Set<string>();
  let toolCallsMade = 0;
  let roundsUsed = 0;

  const triageResult = await provider.analyzeWithTools({
    context,
    model,
    timeoutMs,
    tools,
    maxRounds,
    executeToolCalls: async (calls) => {
      roundsUsed += 1;
      toolCallsMade += calls.length;
      for (const call of calls) {
        toolNamesUsed.add(call.name);
        recordToolCallExecuted(call.name);
      }
      return executeToolCalls(calls, perToolTimeoutMs);
    },
  });

  if (roundsUsed > 0) {
    recordToolRoundsUsed(roundsUsed);
  }

  return {
    triageResult,
    toolCallsMade,
    toolNamesUsed: [...toolNamesUsed],
    roundsUsed,
  };
};
