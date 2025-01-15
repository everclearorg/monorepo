-- migrate:up

CREATE TYPE intent_status AS ENUM (
  'NONE',
  'ADDED',
  'DISPATCHED',
  'FILLED',
  'COMPLETED',
  'SETTLED',
  'SLOW_PATH_SETTLED',
  'RETURN_UNSUPPORTED'
);

CREATE TYPE message_type AS ENUM (
  'INTENT',
  'FILL',
  'SETTLEMENT',
  'MAILBOX_UPDATE',
  'SECURITY_MODULE_UPDATE',
  'GATEWAY_UPDATE',
  'LIGHTHOUSE_UPDATE'
);

CREATE TYPE queue_type AS ENUM (
  'INTENT',
  'FILL',
  'SETTLEMENT',
  'BUMP'
);

CREATE TABLE origin_intents (
    id character(66) NOT NULL PRIMARY KEY,
    queue_idx bigint NOT NULL,
    message_id character(66),
    status intent_status  DEFAULT 'NONE'::intent_status NOT NULL,
    receiver character varying(66) NOT NULL,
    input_asset character varying(66) NOT NULL,
    output_asset character varying(66) NOT NULL,
    amount character varying(255) NOT NULL,
    max_routers_fee character varying(255) NOT NULL,
    origin character varying(66) NOT NULL,
    destination character varying(66) NOT NULL,
    nonce bigint NOT NULL,
    data bytea,

    caller character varying(66) NOT NULL,
    transaction_hash character(66) NOT NULL,
    timestamp bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL
);

CREATE TABLE destination_intents (
    id character(66) NOT NULL PRIMARY KEY,
    queue_idx bigint NOT NULL,
    message_id character(66),
    status intent_status  DEFAULT 'NONE'::intent_status NOT NULL,
    initiator character varying(66) NOT NULL,
    receiver character varying(66) NOT NULL,
    filler character varying(66) NOT NULL,
    input_asset character varying(66) NOT NULL,
    output_asset character varying(66) NOT NULL,
    amount character varying(255) NOT NULL,
    fee character varying(255) NOT NULL,
    origin character varying(66) NOT NULL,
    destination character varying(66) NOT NULL,
    nonce bigint NOT NULL,
    data bytea,

    caller character varying(66) NOT NULL,
    transaction_hash character(66) NOT NULL,
    timestamp bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL
);

CREATE TABLE hub_intents (
    id character(66) NOT NULL PRIMARY KEY,
    domain character varying(66) NOT NULL,  --hub chain domain
    queue_id character(66),
    queue_node character(66),
    message_id character(66),
    status intent_status  DEFAULT 'NONE'::intent_status NOT NULL,
    settlement_domain character varying(66),

    added_tx_nonce bigint,
    added_timestamp bigint,
    filled_tx_nonce bigint,
    filled_timestamp bigint,
    enqueued_tx_nonce bigint,
    enqueued_timestamp bigint
);

CREATE TABLE messages (
    id character varying(255) NOT NULL PRIMARY KEY,
    domain character varying(66) NOT NULL,
    type message_type NOT NULL,
    quote character varying(255),
    first bigint NOT NULL,
    last bigint NOT NULL,
    intent_ids character varying(66)[] NOT NULL,
    
    caller character varying(66) NOT NULL,
    transaction_hash character(66) NOT NULL,
    timestamp bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_nonce bigint NOT NULL
);

CREATE TABLE queues (
    id character varying(255) NOT NULL PRIMARY KEY,
    domain character varying(66) NOT NULL,
    last_processed bigint,
    size bigint NOT NULL,
    first bigint NOT NULL,
    last bigint NOT NULL,
    type queue_type NOT NULL
);

CREATE TABLE bids (
    id character varying(255) NOT NULL PRIMARY KEY,
    origin character varying(66) NOT NULL,
    auction character varying NOT NULL,
    router character(66) NOT NULL,
    fee character varying(255) NOT NULL,
    index bigint NOT NULL,
    
    transaction_hash character(66) NOT NULL,
    timestamp bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL
);

CREATE TABLE auctions (
    id character varying(255) NOT NULL PRIMARY KEY,
    origin character varying(66) NOT NULL,
    winner character varying(66),
    lowest_fee character varying(255),
    end_time bigint NOT NULL,
    bid_count bigint NOT NULL,
    
    transaction_hash character(66) NOT NULL,
    timestamp bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL
);

CREATE TABLE routers (
    address character varying(66) NOT NULL PRIMARY KEY,
    owner character varying(66) NOT NULL,
    supported_domains character varying(66)[] NOT NULL
);

CREATE TABLE assets (
    id character varying(255) NOT NULL PRIMARY KEY, -- `domain-token_id`
    token_id character varying,
    domain character varying(66),
    adopted character varying(66) NOT NULL,
    decimals numeric NOT NULL,
    approval boolean NOT NULL
);

CREATE TABLE tokens (
    id character(66) NOT NULL PRIMARY KEY,
    fee_recipients character varying[],
    fee_amounts character varying[]
);

CREATE TABLE depositors (
    id character varying(66) NOT NULL PRIMARY KEY
);

CREATE TABLE balances (
    id character varying(66) NOT NULL PRIMARY KEY,
    account character varying(66) NOT NULL REFERENCES depositors(id),
    asset character varying(66) NOT NULL,
    amount character varying NOT NULL
);


CREATE TABLE checkpoints (
    check_name character varying(255) NOT NULL PRIMARY KEY,
    check_point numeric DEFAULT 0 NOT NULL
);


-- migrate:down

DROP TABLE origin_intents;
DROP TABLE destination_intents;
DROP TABLE messages;
DROP TABLE queues;
DROP TABLE bids;
DROP TABLE auctions;
DROP TABLE routers;
DROP TABLE assets;
DROP TABLE tokens;
DROP TABLE balances;
DROP TABLE depositors;
DROP TABLE checkpoints;
DROP TYPE intent_status;
DROP TYPE message_type;
DROP TYPE queue_type;

