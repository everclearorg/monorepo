import { expect } from '../../src';
import { redactSensitiveData } from '../../src/triage/redact';

describe('triage:redact', () => {
  it('redacts api and private keys', () => {
    const redacted = redactSensitiveData({
      apiKey: 'secret',
      privateKey: 'super-secret',
      nested: { authToken: 'token' },
    }) as Record<string, unknown>;

    expect(redacted.apiKey).to.eq('{redacted}');
    expect(redacted.privateKey).to.eq('{redacted}');
    expect((redacted.nested as Record<string, unknown>).authToken).to.eq('{redacted}');
  });

  it('redacts provider urls while keeping hostname', () => {
    const redacted = redactSensitiveData({
      providers: ['https://rpc.service.io/path?x=1'],
    }) as Record<string, unknown>;
    const providers = redacted.providers as string[];
    expect(providers[0]).to.include('rpc.service.io');
    expect(providers[0]).to.include('{redacted}');
  });
});
