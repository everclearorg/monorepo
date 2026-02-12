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
  'admintoken',
  'chatid',
  'bearertoken',
  'accesskey',
  'secretkey',
  'connectionstring',
]);

const URL_REGEX = /\b(https?:\/\/[^\s"'`]+|postgres(?:ql)?:\/\/[^\s"'`]+|mongodb:\/\/[^\s"'`]+|redis:\/\/[^\s"'`]+)\b/gi;
const BEARER_REGEX = /\bbearer\s+[a-z0-9._-]+\b/gi;
const ASSIGNMENT_SECRET_REGEX = /\b(api[_-]?key|token|secret|password|authorization|private[_-]?key)\b\s*[:=]\s*([^\s,;]+)/gi;
const OPENAI_KEY_REGEX = /\bsk-[A-Za-z0-9_-]{16,}\b/g;
const ANTHROPIC_KEY_REGEX = /\bsk-ant-[A-Za-z0-9_-]{16,}\b/g;
const HEX_PRIVATE_KEY_REGEX = /\b0x[a-fA-F0-9]{64}\b/g;

const normalizeKey = (key: string): string => key.toLowerCase().replace(/[^a-z0-9]/g, '');

const sanitizeUrl = (value: string): string => {
  try {
    const parsed = new URL(value);
    return `${parsed.protocol}//${parsed.hostname}{redacted}`;
  } catch {
    return '{redacted_url}';
  }
};

const redactString = (value: string): string => {
  let output = value;
  output = output.replace(URL_REGEX, (matched) => sanitizeUrl(matched));
  output = output.replace(BEARER_REGEX, 'Bearer {redacted}');
  output = output.replace(ASSIGNMENT_SECRET_REGEX, (_all, key) => `${key}={redacted}`);
  output = output.replace(OPENAI_KEY_REGEX, '{redacted_openai_key}');
  output = output.replace(ANTHROPIC_KEY_REGEX, '{redacted_anthropic_key}');
  output = output.replace(HEX_PRIVATE_KEY_REGEX, '{redacted_private_key}');
  return output;
};

export const redactSensitiveData = (input: unknown): unknown => {
  if (Array.isArray(input)) {
    return input.map((v) => redactSensitiveData(v));
  }
  if (typeof input === 'object' && input !== null) {
    const output: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(input)) {
      const normalizedKey = normalizeKey(key);
      if (REDACT_KEYS.has(normalizedKey)) {
        output[key] = '{redacted}';
        continue;
      }
      if (normalizedKey === 'providers' && Array.isArray(value)) {
        output[key] = value.map((provider) => (typeof provider === 'string' ? redactString(provider) : '{redacted}'));
        continue;
      }
      if (normalizedKey.endsWith('url') && typeof value === 'string') {
        output[key] = sanitizeUrl(value);
        continue;
      }
      output[key] = redactSensitiveData(value);
    }
    return output;
  }
  if (typeof input === 'string') {
    return redactString(input);
  }
  return input;
};
