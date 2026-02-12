const triageMetrics = {
  interceptedTotal: 0,
  triagedTotal: 0,
  dedupedTotal: 0,
  agentTimeoutTotal: 0,
  fallbackTotal: 0,
  autoResolveAttemptTotal: 0,
  autoResolveSuccessTotal: 0,
  toolCallsTotal: 0,
  toolRoundsTotal: 0,
  toolUsageByName: {} as Record<string, number>,
  triageLatencyMs: [] as number[],
};

export const recordTriageIntercepted = () => {
  triageMetrics.interceptedTotal += 1;
};

export const recordTriagePerformed = (latencyMs: number) => {
  triageMetrics.triagedTotal += 1;
  triageMetrics.triageLatencyMs.push(latencyMs);
};

export const recordTriageDeduped = () => {
  triageMetrics.dedupedTotal += 1;
};

export const recordTriageTimeout = () => {
  triageMetrics.agentTimeoutTotal += 1;
};

export const recordTriageFallback = () => {
  triageMetrics.fallbackTotal += 1;
};

export const recordAutoResolveAttempt = (succeeded: boolean) => {
  triageMetrics.autoResolveAttemptTotal += 1;
  if (succeeded) {
    triageMetrics.autoResolveSuccessTotal += 1;
  }
};

export const recordToolCallExecuted = (toolName: string) => {
  triageMetrics.toolCallsTotal += 1;
  triageMetrics.toolUsageByName[toolName] = (triageMetrics.toolUsageByName[toolName] ?? 0) + 1;
};

export const recordToolRoundsUsed = (rounds: number) => {
  triageMetrics.toolRoundsTotal += rounds;
};

export const getTriageMetricsSnapshot = () => ({
  ...triageMetrics,
  toolUsageByName: { ...triageMetrics.toolUsageByName },
  triageLatencyMs: [...triageMetrics.triageLatencyMs],
});
