-- migrate:up

ALTER TABLE alert_triage_log
  ADD COLUMN IF NOT EXISTS tool_calls_made integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tool_names_used text[] NOT NULL DEFAULT '{}';

-- migrate:down

ALTER TABLE alert_triage_log
  DROP COLUMN IF EXISTS tool_calls_made,
  DROP COLUMN IF EXISTS tool_names_used;
