-- migrate:up

-- Create trigger for reward_claimed
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'reward_claimed_set_timestamp_and_latency'
  ) THEN
    CREATE TRIGGER reward_claimed_set_timestamp_and_latency
    BEFORE INSERT ON tokenomics.reward_claimed
    FOR EACH ROW
    EXECUTE FUNCTION tokenomics.set_timestamp_and_latency();
  END IF;
END;
$$;

-- Create index for reward_claimed
CREATE INDEX IF NOT EXISTS reward_claimed_timestamp_idx
  ON tokenomics.reward_claimed (insert_timestamp);


-- Create trigger for new_lock_position
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'new_lock_position_set_timestamp_and_latency'
  ) THEN
    CREATE TRIGGER new_lock_position_set_timestamp_and_latency
    BEFORE INSERT ON tokenomics.new_lock_position
    FOR EACH ROW
    EXECUTE FUNCTION tokenomics.set_timestamp_and_latency();
  END IF;
END;
$$;

-- Create index for new_lock_position
CREATE INDEX IF NOT EXISTS new_lock_position_timestamp_idx
  ON tokenomics.new_lock_position (insert_timestamp);

-- migrate:down

-- Drop triggers and indexes (for rollback)
DROP TRIGGER IF EXISTS reward_claimed_set_timestamp_and_latency ON tokenomics.reward_claimed;
DROP INDEX IF EXISTS reward_claimed_timestamp_idx;

DROP TRIGGER IF EXISTS new_lock_position_set_timestamp_and_latency ON tokenomics.new_lock_position;
DROP INDEX IF EXISTS new_lock_position_timestamp_idx;
