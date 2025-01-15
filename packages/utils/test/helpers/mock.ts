import { Logger, Severity, Report } from '../../src';

export const TEST_REPORT: Report = {
  severity: Severity.Informational,
  type: 'test',
  ids: ['test'],
  timestamp: Date.now(),
  reason: 'test',
  logger: new Logger({ name: 'mock', level: 'silent' }),
  env: 'staging',
};
