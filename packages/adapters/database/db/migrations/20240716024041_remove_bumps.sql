-- migrate:up
DROP TABLE IF EXISTS intent_bumps CASCADE;
DROP TYPE IF EXISTS bump_status;

-- migrate:down
CREATE TYPE public.bump_status AS ENUM (
    'NONE',
    'DISPATCHED',
    'PROCESSED'
);

CREATE TABLE public.intent_bumps (
    id character(66) NOT NULL,
    intent_id character(66) NOT NULL,
    amount character varying(255) NOT NULL,
    domain character varying(66) NOT NULL,
    status public.bump_status DEFAULT 'NONE'::public.bump_status NOT NULL,
    transaction_hash character(66) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL
);
