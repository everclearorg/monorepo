import { BetterUptimeConfig, Report } from '../helpers/config';
import { axiosGet } from '../helpers/axios';

export type IncidentSummary = {
  id: string;
  name: string;
  status: string;
  startedAt: string;
  metadata: Record<string, unknown>;
};

export type IncidentCluster = {
  key: string;
  count: number;
  incidentIds: string[];
  startedAtMin: string;
  startedAtMax: string;
  sampleNames: string[];
};

const INCIDENTS_URL = 'https://uptime.betterstack.com/api/v3/incidents';

type BetterUptimeListResponse = {
  data: Array<{
    id: string;
    attributes: {
      name: string;
      status: string;
      started_at: string;
      metadata?: Record<string, unknown>;
    };
  }>;
  pagination?: {
    next?: string | null;
  };
};

const getMetadataValue = (metadata: Record<string, unknown>, key: string): string => {
  const raw = metadata[key];
  if (Array.isArray(raw)) {
    const first = raw[0];
    if (typeof first === 'string') {
      return first;
    }
    if (first && typeof first === 'object' && 'value' in (first as Record<string, unknown>)) {
      return String((first as Record<string, unknown>).value ?? 'unknown');
    }
  }
  if (raw && typeof raw === 'object' && 'value' in (raw as Record<string, unknown>)) {
    return String((raw as Record<string, unknown>).value ?? 'unknown');
  }
  return raw == null ? 'unknown' : String(raw);
};

export const fetchRecentIncidents = async (
  _report: Report,
  betterUptime: BetterUptimeConfig | undefined,
  lookbackHours: number,
): Promise<IncidentSummary[]> => {
  if (!betterUptime?.apiKey) {
    return [];
  }
  const cutoff = Date.now() - lookbackHours * 60 * 60 * 1000;
  const incidents: IncidentSummary[] = [];
  let page = 1;
  while (page <= 10) {
    const url = `${INCIDENTS_URL}?resolved=false&per_page=50&page=${page}`;
    const response = await axiosGet<BetterUptimeListResponse>(url, {
      headers: { Authorization: `Bearer ${betterUptime.apiKey}` },
    });
    const payload = response.data;
    if (!payload?.data?.length) {
      break;
    }

    for (const incident of payload.data) {
      const startedAtMs = Date.parse(incident.attributes.started_at);
      if (!Number.isFinite(startedAtMs) || startedAtMs < cutoff) {
        continue;
      }
      incidents.push({
        id: incident.id,
        name: incident.attributes.name,
        status: incident.attributes.status,
        startedAt: incident.attributes.started_at,
        metadata: incident.attributes.metadata ?? {},
      });
    }

    const oldest = payload.data[payload.data.length - 1];
    if (Date.parse(oldest.attributes.started_at) < cutoff) {
      break;
    }
    if (!payload.pagination?.next) {
      break;
    }
    page += 1;
  }
  return incidents;
};

export const clusterIncidents = (incidents: IncidentSummary[]): IncidentCluster[] => {
  const grouped = new Map<string, IncidentSummary[]>();
  for (const incident of incidents) {
    const metadata = incident.metadata as Record<string, unknown>;
    const env = getMetadataValue(metadata, 'everclear_env');
    const reportType = getMetadataValue(metadata, 'report_type');
    const severity = getMetadataValue(metadata, 'severity_level');
    const key = `${incident.name}|${env}|${reportType}|${severity}`;
    const existing = grouped.get(key) ?? [];
    existing.push(incident);
    grouped.set(key, existing);
  }

  return [...grouped.entries()].map(([key, values]) => {
    const sorted = [...values].sort((a, b) => Date.parse(a.startedAt) - Date.parse(b.startedAt));
    return {
      key,
      count: values.length,
      incidentIds: values.map((i) => i.id),
      startedAtMin: sorted[0].startedAt,
      startedAtMax: sorted[sorted.length - 1].startedAt,
      sampleNames: [...new Set(values.map((i) => i.name))].slice(0, 3),
    };
  });
};
