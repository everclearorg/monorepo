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
  PRIMARY KEY (task_id)
);

-- Only one pending dispatch per queue slice at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_queue_dispatches_pending_unique
  ON queue_dispatches (domain, queue_type, queue_first, queue_last)
  WHERE status = 'pending';

-- For cleanup queries (pruneOldQueueDispatches filters by status + updated_at)
CREATE INDEX IF NOT EXISTS idx_queue_dispatches_status_updated
  ON queue_dispatches (status, updated_at);

-- migrate:down

DROP INDEX IF EXISTS idx_queue_dispatches_pending_unique;
DROP INDEX IF EXISTS idx_queue_dispatches_status_updated;
DROP TABLE IF EXISTS queue_dispatches;
