import { expect } from '../../src';
import { isProcessedFingerprint, tryReserveFingerprint, finalizeFingerprint } from '../../src/triage/dedup';

describe('triage:dedup', () => {
  it('marks and checks processed fingerprints', async () => {
    const fingerprint = `fp-${Date.now()}`;
    const before = await isProcessedFingerprint(fingerprint);
    expect(before).to.eq(false);

    const inserted = await tryReserveFingerprint({
      fingerprint,
      reportType: 'test',
      severity: 'warning',
      env: 'staging',
      network: 'mainnet',
      ids: ['1'],
      reason: 'test',
      triageMode: 'enabled',
      expiresAt: new Date(Date.now() + 60_000),
    });
    expect(inserted).to.eq(true);

    await finalizeFingerprint({
      fingerprint,
      reportType: 'test',
      severity: 'warning',
      env: 'staging',
      network: 'mainnet',
      ids: ['1'],
      reason: 'test',
      triageMode: 'enabled',
      expiresAt: new Date(Date.now() + 60_000),
    });

    const after = await isProcessedFingerprint(fingerprint);
    expect(after).to.eq(true);
  });
});
