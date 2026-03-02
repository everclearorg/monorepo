import { delay } from '../../helpers/axios';

export class CircuitBreaker {
  private failures: number[] = [];

  constructor(
    private readonly failureThreshold: number,
    private readonly windowMs: number,
  ) {}

  public canExecute(now: number = Date.now()): boolean {
    this.prune(now);
    return this.failures.length < this.failureThreshold;
  }

  public recordFailure(now: number = Date.now()): void {
    this.failures.push(now);
    this.prune(now);
  }

  public recordSuccess(): void {
    this.failures = [];
  }

  private prune(now: number): void {
    const cutoff = now - this.windowMs;
    this.failures = this.failures.filter((ts) => ts >= cutoff);
  }
}

export const withRetry = async <T>(operation: () => Promise<T>, attempts = 2, retryDelayMs = 500): Promise<T> => {
  let latestError: unknown;
  for (let i = 0; i < attempts; i++) {
    try {
      return await operation();
    } catch (e) {
      latestError = e;
      if (i < attempts - 1) {
        await delay(retryDelayMs);
      }
    }
  }
  throw latestError;
};
