import { createHash } from 'crypto';
import { Report } from '../helpers/config';

const HEX_REGEX = /0x[a-fA-F0-9]{6,}/g;
const NUMBER_REGEX = /\b\d+\b/g;
const ISO_DATE_REGEX = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z/g;

export const normalizeReason = (reason: string | undefined | null): string => {
  return (reason ?? '')
    .replace(HEX_REGEX, '{hex}')
    .replace(ISO_DATE_REGEX, '{timestamp}')
    .replace(NUMBER_REGEX, '{num}')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
};

export const toTimeBucket = (timestamp: number, bucketSizeMinutes: number): number => {
  const bucketMs = Math.max(1, bucketSizeMinutes) * 60_000;
  return Math.floor(timestamp / bucketMs);
};

export const computeFingerprint = (
  report: Report,
  network: string,
  _bucketSizeMinutes: number,
): string => {
  const input = [
    report.env,
    network,
    report.type,
    report.severity,
    [...report.ids].sort().join(','),
    normalizeReason(report.reason),
  ].join('|');
  return createHash('sha256').update(input).digest('hex');
};
