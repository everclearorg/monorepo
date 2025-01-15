-- migrate:up

-- Add queue type to deposit
ALTER TYPE queue_type ADD VALUE 'DEPOSIT';

-- Add deposit queue fields
ALTER TABLE queues ADD COLUMN IF NOT EXISTS ticker_hash VARCHAR(255); -- only populated on deposit queues
ALTER TABLE queues ADD COLUMN IF NOT EXISTS epoch BIGINT; -- only populated on deposit queues

-- Add deposit entities
CREATE TABLE public.hub_deposits (
    id character(66) NOT NULL,
    intent_id character(66) NOT NULL,
    epoch bigint NOT NULL,
    ticker_hash character(66) NOT NULL,
    domain character(66) NOT NULL,
    amount character varying(255) NOT NULL,
    enqueued_tx_nonce bigint NOT NULL,
    enqueued_timestamp bigint NOT NULL,
    processed_tx_nonce bigint,
    processed_timestamp bigint,
    auto_id bigserial NOT NULL
);
CREATE INDEX hub_deposits_auto_id_index ON hub_deposits(auto_id);

-- migrate:down
ALTER TABLE IF EXISTS queues DROP COLUMN IF EXISTS ticker_hash;
ALTER TABLE IF EXISTS queues DROP COLUMN IF EXISTS epoch;

ALTER TYPE IF EXISTS queue_type DROP VALUE 'DEPOSIT';

DROP TABLE IF EXISTS public.hub_deposits;
DROP INDEX IF EXISTS hub_deposits_auto_id_index;
