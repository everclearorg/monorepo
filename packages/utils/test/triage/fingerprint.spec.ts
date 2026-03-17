import { expect } from '../../src';
import { computeFingerprint, normalizeReason, toTimeBucket } from '../../src/triage/fingerprint';
import { TEST_REPORT } from '../helpers/mock';

describe('triage:fingerprint', () => {
  it('normalizes dynamic reason segments', () => {
    const normalized = normalizeReason('Error at 2026-02-12T12:00:00Z for tx 0xabcdef123456 and value 42');
    expect(normalized).to.include('{timestamp}');
    expect(normalized).to.include('{hex}');
    expect(normalized).to.include('{num}');
  });

  it('computes deterministic fingerprint', () => {
    const first = computeFingerprint(TEST_REPORT, 'mainnet', 30);
    const second = computeFingerprint({ ...TEST_REPORT }, 'mainnet', 30);
    expect(first).to.eq(second);
    expect(first).to.have.length(64);
  });

  it('uses time buckets', () => {
    const a = toTimeBucket(60_000, 30);
    const b = toTimeBucket(61_000, 30);
    expect(a).to.eq(b);
  });
});
