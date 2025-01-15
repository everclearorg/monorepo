-- migrate:up

CREATE TYPE bump_status AS ENUM (
  'NONE',
  'DISPATCHED', -- created / sent to chain
  'PROCESSED' -- arrived on clearing chain
);

CREATE TABLE intent_bumps (
    id character(66) NOT NULL PRIMARY KEY,
    intent_id character(66) NOT NULL,
    amount character varying(255) NOT NULL,
    domain character varying(66) NOT NULL,

    status bump_status  DEFAULT 'NONE'::bump_status NOT NULL,

    transaction_hash character(66) NOT NULL,
    timestamp bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL
);


-- migrate:down

DROP TABLE intent_bumps;
DROP TYPE bump_status;