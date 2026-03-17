-- migrate:up

CREATE TABLE IF NOT EXISTS alert_triage_log (
  fingerprint character(64) PRIMARY KEY,
  report_type varchar(128) NOT NULL,
  severity varchar(16) NOT NULL,
  env varchar(64) NOT NULL,
  network varchar(32) NOT NULL,
  ids text[] NOT NULL DEFAULT '{}',
  reason text NOT NULL,
  triage_mode varchar(16) NOT NULL,
  triage_result jsonb,
  provider_used varchar(32),
  model_used varchar(64),
  triage_latency_ms integer,
  auto_resolve_attempted boolean NOT NULL DEFAULT false,
  auto_resolve_succeeded boolean NOT NULL DEFAULT false,
  auto_resolve_reason_code varchar(64),
  created_at timestamptz NOT NULL DEFAULT NOW(),
  expires_at timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_alert_triage_log_created_at ON alert_triage_log (created_at);
CREATE INDEX IF NOT EXISTS idx_alert_triage_log_type_env ON alert_triage_log (report_type, env);
CREATE INDEX IF NOT EXISTS idx_alert_triage_log_expires_at ON alert_triage_log (expires_at);

-- migrate:down

DROP INDEX IF EXISTS public.idx_alert_triage_log_created_at;
DROP INDEX IF EXISTS public.idx_alert_triage_log_type_env;
DROP INDEX IF EXISTS public.idx_alert_triage_log_expires_at;

DROP TABLE IF EXISTS alert_triage_log;
