import { expect } from '../../src';
import { CircuitBreaker, withRetry } from '../../src/triage/providers/base';

describe('triage:providers:base', () => {
  it('opens after threshold failures in window', () => {
    const breaker = new CircuitBreaker(2, 1000);
    breaker.recordFailure(100);
    expect(breaker.canExecute(200)).to.eq(true);
    breaker.recordFailure(300);
    expect(breaker.canExecute(301)).to.eq(false);
  });

  it('recovers after failure window elapses', () => {
    const breaker = new CircuitBreaker(2, 1000);
    breaker.recordFailure(100);
    breaker.recordFailure(300);
    expect(breaker.canExecute(350)).to.eq(false);
    expect(breaker.canExecute(1401)).to.eq(true);
  });

  it('retries transient failures then succeeds', async () => {
    let attempts = 0;
    const result = await withRetry(async () => {
      attempts += 1;
      if (attempts < 2) {
        throw new Error('transient');
      }
      return 'ok';
    }, 2, 1);
    expect(result).to.eq('ok');
    expect(attempts).to.eq(2);
  });
});
