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

  it('redacts underscore and camelCase secret keys', () => {
    const redacted = redactSensitiveData({
      api_key: 'a',
      adminToken: 'b',
      bearer_token: 'c',
      nested_config: {
        private_key: 'd',
      },
    }) as Record<string, unknown>;

    expect(redacted.api_key).to.eq('{redacted}');
    expect(redacted.adminToken).to.eq('{redacted}');
    expect(redacted.bearer_token).to.eq('{redacted}');
    expect((redacted.nested_config as Record<string, unknown>).private_key).to.eq('{redacted}');
  });

  it('redacts sensitive tokens inside free-form strings', () => {
    const redacted = redactSensitiveData({
      reason: 'Bearer abcdef123456 sk-test1234567890 api_key=xyz 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    }) as Record<string, unknown>;
    const reason = String(redacted.reason);
    expect(reason).to.not.include('abcdef123456');
    expect(reason).to.not.include('sk-test1234567890');
    expect(reason).to.not.include('xyz');
    expect(reason).to.not.include('0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
  });
});
