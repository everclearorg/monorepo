-- migrate:up

CREATE TYPE queue_dispatch_relayer_type AS ENUM ('claim', 'gelato', 'everclear', 'mock');
CREATE TYPE queue_dispatch_status AS ENUM ('pending', 'failed', 'success', 'reverted', 'cancelled');

CREATE TABLE IF NOT EXISTS queue_dispatches (
  id serial PRIMARY KEY,
  domain varchar NOT NULL,
  queue_type varchar NOT NULL,
  queue_first bigint NOT NULL,
  queue_last bigint NOT NULL,
  task_id varchar,
  relayer_type queue_dispatch_relayer_type NOT NULL DEFAULT 'claim',
  status queue_dispatch_status NOT NULL DEFAULT 'pending',
  dispatched_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

-- Only one pending dispatch per queue slice at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_queue_dispatches_pending_unique
  ON queue_dispatches (domain, queue_type, queue_first, queue_last)
  WHERE status = 'pending';

-- For looking up dispatches by relayer task id
CREATE UNIQUE INDEX IF NOT EXISTS idx_queue_dispatches_task_id
  ON queue_dispatches (task_id)
  WHERE task_id IS NOT NULL;

-- For cleanup queries (pruneOldQueueDispatches filters by status + updated_at)
CREATE INDEX IF NOT EXISTS idx_queue_dispatches_status_updated
  ON queue_dispatches (status, updated_at);

-- migrate:down

DROP INDEX IF EXISTS idx_queue_dispatches_pending_unique;
DROP INDEX IF EXISTS idx_queue_dispatches_task_id;
DROP INDEX IF EXISTS idx_queue_dispatches_status_updated;
DROP TABLE IF EXISTS queue_dispatches;
DROP TYPE IF EXISTS queue_dispatch_status;
DROP TYPE IF EXISTS queue_dispatch_relayer_type;
