-- migrate:up

-- Partial index for updateMessageStatuses: only covers non-delivered rows so
-- the bulk UPDATE can skip a sequential scan of the entire messages table.
-- Rows transition to 'delivered' and drop out of the index automatically.
CREATE INDEX IF NOT EXISTS messages_status_type_partial_idx
  ON messages (message_status, type)
  WHERE message_status != 'delivered';

-- migrate:down

DROP INDEX IF EXISTS messages_status_type_partial_idx;
