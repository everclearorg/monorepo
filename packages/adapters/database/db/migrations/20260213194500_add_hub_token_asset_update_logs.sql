-- migrate:up

CREATE TABLE IF NOT EXISTS hub_token_update_logs (
  id character(120) PRIMARY KEY,
  domain varchar NOT NULL, -- hub domain (chain where update tx happened)
  ticker_hash character varying(66) NOT NULL,
  kind varchar NOT NULL,
  fee_recipients character varying[] NOT NULL DEFAULT '{}',
  fee_amounts character varying[] NOT NULL DEFAULT '{}',
  max_discount_bps bigint NOT NULL,
  discount_per_epoch bigint NOT NULL,
  prioritized_strategy character varying(255) NOT NULL,
  transaction_hash character(130) NOT NULL,
  timestamp bigint NOT NULL,
  block_number bigint NOT NULL,
  tx_origin character varying(66) NOT NULL,
  tx_nonce bigint NOT NULL
);

CREATE INDEX IF NOT EXISTS hub_token_update_logs_block_number_idx ON hub_token_update_logs (block_number);
CREATE INDEX IF NOT EXISTS hub_token_update_logs_timestamp_idx ON hub_token_update_logs ("timestamp");
CREATE INDEX IF NOT EXISTS hub_token_update_logs_ticker_hash_idx ON hub_token_update_logs (ticker_hash);

CREATE TABLE IF NOT EXISTS hub_asset_update_logs (
  id character(120) PRIMARY KEY,
  domain varchar NOT NULL, -- hub domain (chain where update tx happened)
  asset_id character varying(66) NOT NULL,
  token_id character varying(66), -- token entity id (ticker hash) when present
  ticker_hash character varying(66) NOT NULL,
  asset_domain character varying(66) NOT NULL, -- domain the asset config applies to
  kind varchar NOT NULL,
  asset_hash character varying(66) NOT NULL,
  adopted character varying(66) NOT NULL,
  approval boolean NOT NULL,
  strategy character varying(255) NOT NULL,
  transaction_hash character(130) NOT NULL,
  timestamp bigint NOT NULL,
  block_number bigint NOT NULL,
  tx_origin character varying(66) NOT NULL,
  tx_nonce bigint NOT NULL
);

CREATE INDEX IF NOT EXISTS hub_asset_update_logs_block_number_idx ON hub_asset_update_logs (block_number);
CREATE INDEX IF NOT EXISTS hub_asset_update_logs_timestamp_idx ON hub_asset_update_logs ("timestamp");
CREATE INDEX IF NOT EXISTS hub_asset_update_logs_ticker_hash_idx ON hub_asset_update_logs (ticker_hash);
CREATE INDEX IF NOT EXISTS hub_asset_update_logs_asset_domain_idx ON hub_asset_update_logs (asset_domain);
CREATE INDEX IF NOT EXISTS hub_asset_update_logs_asset_id_idx ON hub_asset_update_logs (asset_id);

GRANT SELECT ON public.hub_token_update_logs TO reader;
GRANT SELECT ON public.hub_token_update_logs TO query;

GRANT SELECT ON public.hub_asset_update_logs TO reader;
GRANT SELECT ON public.hub_asset_update_logs TO query;

-- migrate:down

REVOKE SELECT ON public.hub_token_update_logs FROM reader;
REVOKE SELECT ON public.hub_token_update_logs FROM query;

REVOKE SELECT ON public.hub_asset_update_logs FROM reader;
REVOKE SELECT ON public.hub_asset_update_logs FROM query;

DROP INDEX IF EXISTS public.hub_token_update_logs_block_number_idx;
DROP INDEX IF EXISTS public.hub_token_update_logs_timestamp_idx;
DROP INDEX IF EXISTS public.hub_token_update_logs_ticker_hash_idx;

DROP INDEX IF EXISTS public.hub_asset_update_logs_block_number_idx;
DROP INDEX IF EXISTS public.hub_asset_update_logs_timestamp_idx;
DROP INDEX IF EXISTS public.hub_asset_update_logs_ticker_hash_idx;
DROP INDEX IF EXISTS public.hub_asset_update_logs_asset_domain_idx;
DROP INDEX IF EXISTS public.hub_asset_update_logs_asset_id_idx;

DROP TABLE IF EXISTS hub_token_update_logs;
DROP TABLE IF EXISTS hub_asset_update_logs;

