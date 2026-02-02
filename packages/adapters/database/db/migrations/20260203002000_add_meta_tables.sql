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

CREATE TABLE IF NOT EXISTS hub_meta (
  id character(120) PRIMARY KEY,
  domain varchar NOT NULL,
  paused boolean,
  owner character varying(66),
  proposed_owner character varying(66),
  proposed_ownership_timestamp bigint,
  gateway character varying(66),
  watchtower character varying(66),
  manager character varying(66),
  settler character varying(66),
  min_solver_supported_domains bigint,
  expiry_time_buffer bigint,
  discount_per_epoch bigint,
  epoch_length bigint,
  mailbox character varying(66),
  security_module character varying(66),
  acceptance_delay bigint,
  supported_domains jsonb,
  chain_gateways jsonb
);

CREATE TABLE IF NOT EXISTS spoke_meta (
  id character(120) PRIMARY KEY,
  domain varchar NOT NULL,
  paused boolean,
  gateway character varying(66),
  lighthouse character varying(66),
  message_receiver character varying(66),
  watchtower character varying(66),
  message_gas_limit bigint,
  fee_adapter character varying(66),
  fee_adapter_recipient character varying(66),
  fill_signer character varying(66),
  fee_signer character varying(66),
  mailbox character varying(66),
  security_module character varying(66),
  module_for_strategies jsonb
);

CREATE INDEX IF NOT EXISTS hub_meta_domain_idx ON hub_meta (domain);
CREATE INDEX IF NOT EXISTS spoke_meta_domain_idx ON spoke_meta (domain);

-- migrate:down

DROP INDEX IF EXISTS public.protocol_update_logs_block_number_idx;
DROP INDEX IF EXISTS public.protocol_update_logs_timestamp_idx;
DROP INDEX IF EXISTS public.hub_meta_domain_idx;
DROP INDEX IF EXISTS public.spoke_meta_domain_idx;

DROP TABLE IF EXISTS protocol_update_logs;
DROP TABLE IF EXISTS hub_meta;
DROP TABLE IF EXISTS spoke_meta;
