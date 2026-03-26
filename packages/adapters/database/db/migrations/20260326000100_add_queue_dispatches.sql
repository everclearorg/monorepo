-- migrate:up

CREATE TABLE IF NOT EXISTS queue_dispatches (
  domain varchar NOT NULL,
  queue_type varchar NOT NULL,
  queue_first bigint NOT NULL,
  queue_last bigint NOT NULL,
  task_id varchar NOT NULL,
  relayer_type varchar NOT NULL,
  status varchar NOT NULL DEFAULT 'pending',
  dispatched_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY (domain, queue_type, queue_first, queue_last)
);

-- Partial unique index: only one pending dispatch per queue slice
CREATE UNIQUE INDEX IF NOT EXISTS idx_queue_dispatches_dedup
  ON queue_dispatches (domain, queue_type, queue_first, queue_last)
  WHERE status = 'pending';

-- For cleanup and reconciliation queries
CREATE INDEX IF NOT EXISTS idx_queue_dispatches_status_dispatched
  ON queue_dispatches (status, dispatched_at);

-- migrate:down

DROP INDEX IF EXISTS idx_queue_dispatches_dedup;
DROP INDEX IF EXISTS idx_queue_dispatches_status_dispatched;
DROP TABLE IF EXISTS queue_dispatches;
