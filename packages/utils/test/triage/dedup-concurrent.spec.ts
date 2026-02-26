import { expect } from '../../src';
import { tryReserveFingerprint } from '../../src/triage/dedup';

describe('triage:dedup-concurrent', () => {
  it('allows only one writer for same fingerprint', async () => {
    const fingerprint = `fp-concurrent-${Date.now()}`;
    const attempts = await Promise.all(
      new Array(10).fill(0).map(() =>
        tryReserveFingerprint({
          fingerprint,
          reportType: 'test',
          severity: 'warning',
          env: 'staging',
          network: 'mainnet',
          ids: ['1'],
          reason: 'test',
          triageMode: 'enabled',
          expiresAt: new Date(Date.now() + 60_000),
        }),
      ),
    );
    const successful = attempts.filter(Boolean);
    expect(successful.length).to.eq(1);
  });
});
