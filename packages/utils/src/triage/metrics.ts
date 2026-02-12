const triageMetrics = {
  interceptedTotal: 0,
  triagedTotal: 0,
  dedupedTotal: 0,
  agentTimeoutTotal: 0,
  fallbackTotal: 0,
  autoResolveAttemptTotal: 0,
  autoResolveSuccessTotal: 0,
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

export const getTriageMetricsSnapshot = () => ({
  ...triageMetrics,
  triageLatencyMs: [...triageMetrics.triageLatencyMs],
});
