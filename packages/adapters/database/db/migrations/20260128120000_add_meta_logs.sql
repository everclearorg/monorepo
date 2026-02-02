-- migrate:up

CREATE TABLE IF NOT EXISTS protocol_update_logs (
  id character(120) PRIMARY KEY,
  domain varchar NOT NULL,
  event varchar NOT NULL,
  key varchar NOT NULL,
  updated text NOT NULL,
  chain_id character varying(66) NOT NULL,
  transaction_hash character(130) NOT NULL,
  timestamp bigint NOT NULL,
  block_number bigint NOT NULL,
  tx_origin character varying(66) NOT NULL,
  tx_nonce bigint NOT NULL
);

CREATE INDEX IF NOT EXISTS protocol_update_logs_block_number_idx ON protocol_update_logs (block_number);
CREATE INDEX IF NOT EXISTS protocol_update_logs_timestamp_idx ON protocol_update_logs ("timestamp");

-- migrate:down
DROP INDEX IF EXISTS public.protocol_update_logs_block_number_idx;
DROP INDEX IF EXISTS public.protocol_update_logs_timestamp_idx;


DROP TABLE IF EXISTS protocol_update_logs;
