-- migrate:up

-- Create the new table in the public schema
CREATE TABLE public.merkle_trees (
    id SERIAL PRIMARY KEY,
    asset character varying(66) NOT NULL,
    root VARCHAR NOT NULL,
    epoch_end_timestamp TIMESTAMP NOT NULL,
    merkle_tree VARCHAR NOT NULL,
    proof VARCHAR NOT NULL,
    snapshot_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create an index on the id column
CREATE INDEX idx_merkle_trees_id ON public.merkle_trees (id);
-- Create an index on the root column
CREATE UNIQUE INDEX idx_merkle_trees_root ON public.merkle_trees (root);

-- Create an index on the asset column
CREATE INDEX idx_merkle_trees_asset ON public.merkle_trees (asset);


-- Create an index on the epoch_end_timestamp column
CREATE INDEX idx_merkle_trees_epoch_end_timestamp ON public.merkle_trees (epoch_end_timestamp);


CREATE TABLE public.rewards (
    id SERIAL PRIMARY KEY,
    account character varying(66) NOT NULL,
    asset character varying(66) NOT NULL,
    merkle_root VARCHAR NOT NULL,
    proof VARCHAR NOT NULL,
    stake_apy VARCHAR NOT NULL,
    stake_rewards VARCHAR NOT NULL,
    total_clear_staked VARCHAR NOT NULL,
    protocol_rewards VARCHAR NOT NULL DEFAULT '0',
    epoch_timestamp timestamp without time zone NOT NULL,
    proof_timestamp timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Create an index on the account column
CREATE INDEX idx_proofs_initiator ON public.rewards (account);

-- Create an index on the merkle_root column
CREATE INDEX idx_proofs_merkle_root ON public.rewards (merkle_root);

-- Create a unique index on the account, merkle_root, and proof columns
CREATE UNIQUE INDEX idx_proofs_initiator_merkle_root_proof ON public.rewards (account, merkle_root, proof);

CREATE TABLE public.epoch_results (
    id SERIAL PRIMARY KEY,
    account character varying(66) NOT NULL,
    domain VARCHAR NOT NULL,
    user_volume VARCHAR NOT NULL,
    total_volume VARCHAR NOT NULL,
    clear_emissions VARCHAR NOT NULL,
    epoch_timestamp timestamp without time zone NOT NULL,
    update_timestamp timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create an index on the account and domain columns
CREATE INDEX idx_epoch_results_account_domain ON public.epoch_results (account, domain);

-- Create an index on the epoch_timestamp column
CREATE INDEX idx_epoch_results_epoch_timestamp ON public.epoch_results (epoch_timestamp);

-- Create an index on the id column
CREATE INDEX idx_epoch_results_id ON public.epoch_results (id);


-- migrate:down

-- Drop the indexes
DROP INDEX IF EXISTS idx_proofs_initiator_merkle_root_proof;
DROP INDEX IF EXISTS idx_proofs_merkle_root;
DROP INDEX IF EXISTS idx_proofs_initiator;

-- Drop the rewards table
DROP TABLE IF EXISTS public.rewards;

-- Drop the indexes
DROP INDEX IF EXISTS idx_merkle_trees_epoch_end_timestamp;
DROP INDEX IF EXISTS idx_merkle_trees_asset;
DROP INDEX IF EXISTS idx_merkle_trees_root;
DROP INDEX IF EXISTS idx_merkle_trees_id;

-- Drop the merkle_trees table
DROP TABLE IF EXISTS public.merkle_trees;

-- Drop the indexes
DROP INDEX IF EXISTS idx_epoch_results_id;
DROP INDEX IF EXISTS idx_epoch_results_epoch_timestamp;
DROP INDEX IF EXISTS idx_epoch_results_account_domain;

-- Drop the epoch_results table
DROP TABLE IF EXISTS public.epoch_results;
