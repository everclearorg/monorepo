const REDACT_KEYS = new Set([
  'apikey',
  'privatekey',
  'authtoken',
  'requesteremail',
  'databaseurl',
  'token',
  'secret',
  'password',
  'authorization',
  'url',
]);

const redactString = (value: string): string => {
  if (/^(https?:\/\/|postgres:\/\/|postgresql:\/\/|mongodb:\/\/|redis:\/\/)/.test(value)) {
    try {
      const parsed = new URL(value);
      return `${parsed.protocol}//${parsed.hostname}{redacted}`;
    } catch {
      return '{redacted_url}';
    }
  }
  if (value.length > 8) {
    return `{redacted:${value.slice(0, 2)}...${value.slice(-2)}}`;
  }
  return '{redacted}';
};

export const redactSensitiveData = (input: unknown): unknown => {
  if (Array.isArray(input)) {
    return input.map((v) => redactSensitiveData(v));
  }
  if (typeof input === 'object' && input !== null) {
    const output: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(input)) {
      if (REDACT_KEYS.has(key.toLowerCase())) {
        output[key] = '{redacted}';
        continue;
      }
      if (key.toLowerCase() === 'providers' && Array.isArray(value)) {
        output[key] = value.map((provider) => (typeof provider === 'string' ? redactString(provider) : '{redacted}'));
        continue;
      }
      output[key] = redactSensitiveData(value);
    }
    return output;
  }
  if (typeof input === 'string' && /https?:\/\//.test(input)) {
    return redactString(input);
  }
  return input;
};
