-- migrate:up

DROP TABLE IF EXISTS tron.tron_gateway_raw_logs;

-- migrate:down

CREATE TABLE IF NOT EXISTS tron.tron_gateway_raw_logs
(
    id text NOT NULL,
    block_number bigint,
    block_hash text,
    transaction_hash text,
    transaction_index bigint,
    log_index bigint,
    address text,
    data text,
    topics text,
    block_timestamp bigint,
    CONSTRAINT tron_gateway_raw_logs_pkey PRIMARY KEY (id)
);