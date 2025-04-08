-- migrate:up
CREATE TABLE IF NOT EXISTS tokenomics.bridge_in_error (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    timestamp numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.bridge_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    old_bridge bytea NOT NULL,
    new_bridge bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.bridged_in (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    src_chain_id numeric NOT NULL,
    sender bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.bridged_lock (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    chain_id numeric NOT NULL,
    sender bytea NOT NULL,
    amount numeric NOT NULL,
    expiry numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.bridged_lock_error (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    receiver bytea NOT NULL,
    amount numeric NOT NULL,
    expiry numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.bridged_out (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    dst_chain_id numeric NOT NULL,
    bridge_user bytea NOT NULL,
    token_receiver bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.chain_gateway_added (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    chain_id numeric NOT NULL,
    gateway bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.chain_gateway_removed (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    chain_id numeric NOT NULL,
    gateway bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.early_exit (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    "user" bytea NOT NULL,
    amount_unlocked numeric NOT NULL,
    amount_received numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.eip712_domain_changed (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.epoch_rewards_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    epoch numeric[] NOT NULL,
    rewards numeric[] NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.eth_withdrawn (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    sender bytea NOT NULL,
    amount numeric NOT NULL,
    withdraw_id numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.fee_info (
    vid bigint NOT NULL,
    block_range text NOT NULL,
    id bytea NOT NULL,
    domain numeric NOT NULL,
    fee numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.gateway_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    old_gateway bytea NOT NULL,
    new_gateway bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.hub_gauge_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    hub_gauge bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.lock_position (
    vid bigint NOT NULL,
    block_range text NOT NULL,
    id bytea NOT NULL,
    owner bytea NOT NULL,
    delegate bytea NOT NULL,
    amount numeric NOT NULL,
    expiry numeric NOT NULL,
    vb_balance numeric NOT NULL,
    bias numeric NOT NULL,
    slope numeric NOT NULL,
    timestamp numeric NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS tokenomics.mailbox_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    old_mailbox bytea NOT NULL,
    new_mailbox bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.message_gas_limit_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    domain numeric[] NOT NULL,
    old_gas_limit numeric[] NOT NULL,
    new_gas_limit numeric[] NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.mint_message_sent (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    sender bytea NOT NULL,
    amount numeric NOT NULL,
    domain numeric NOT NULL,
    message_id bytea NOT NULL,
    fee_spent numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.new_lock_position (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    caller bytea NOT NULL,
    "user" bytea NOT NULL,
    new_total_amount_locked numeric NOT NULL,
    expiry numeric NOT NULL,
    new_vb_balance numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.ownership_transferred (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    previous_owner bytea NOT NULL,
    new_owner bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.process_error (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    nonce numeric NOT NULL,
    error_id integer NOT NULL,
    sender bytea NOT NULL,
    amount numeric NOT NULL,
    additional_data numeric NOT NULL,
    active boolean NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.retry_bridge_out (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    domain numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.retry_lock (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    receiver bytea NOT NULL,
    amount numeric NOT NULL,
    expiry numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.retry_message (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    domain numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.retry_mint (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    chain_id numeric NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.retry_transfer (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    chain_id numeric NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.return_fee_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    domain numeric[] NOT NULL,
    old_fee numeric[] NOT NULL,
    new_fee numeric[] NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.reward_claimed (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    token bytea NOT NULL,
    account bytea NOT NULL,
    amount numeric NOT NULL,
    update_count numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.reward_metadata_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    token bytea NOT NULL,
    merkle_root bytea NOT NULL,
    proof bytea NOT NULL,
    update_count numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.rewards_claimed (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    recipient bytea NOT NULL,
    epoch numeric NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.security_module_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    old_security_module bytea NOT NULL,
    new_security_module bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics."user" (
    vid bigint NOT NULL,
    block_range text NOT NULL,
    id bytea NOT NULL,
    claimed numeric NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS tokenomics.vote_cast (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    owner bytea NOT NULL,
    domain numeric NOT NULL,
    votes numeric NOT NULL,
    epoch numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.vote_delegated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    "user" bytea NOT NULL,
    delegate bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.withdraw (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

CREATE TABLE IF NOT EXISTS tokenomics.withdraw_eth (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    receiver bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text PRIMARY KEY,
    insert_timestamp timestamp without time zone,
    latency interval
);

-- migrate:down
DROP TABLE IF EXISTS tokenomics.bridge_in_error;
DROP TABLE IF EXISTS tokenomics.bridge_updated;
DROP TABLE IF EXISTS tokenomics.bridged_in;
DROP TABLE IF EXISTS tokenomics.bridged_lock;
DROP TABLE IF EXISTS tokenomics.bridged_lock_error;
DROP TABLE IF EXISTS tokenomics.bridged_out;
DROP TABLE IF EXISTS tokenomics.chain_gateway_added;
DROP TABLE IF EXISTS tokenomics.chain_gateway_removed;
DROP TABLE IF EXISTS tokenomics.early_exit;
DROP TABLE IF EXISTS tokenomics.eip712_domain_changed;
DROP TABLE IF EXISTS tokenomics.epoch_rewards_updated;
DROP TABLE IF EXISTS tokenomics.eth_withdrawn;
DROP TABLE IF EXISTS tokenomics.fee_info;
DROP TABLE IF EXISTS tokenomics.gateway_updated;
DROP TABLE IF EXISTS tokenomics.hub_gauge_updated;
DROP TABLE IF EXISTS tokenomics.lock_position;
DROP TABLE IF EXISTS tokenomics.mailbox_updated;
DROP TABLE IF EXISTS tokenomics.message_gas_limit_updated;
DROP TABLE IF EXISTS tokenomics.mint_message_sent;
DROP TABLE IF EXISTS tokenomics.new_lock_position;
DROP TABLE IF EXISTS tokenomics.ownership_transferred;
DROP TABLE IF EXISTS tokenomics.process_error;
DROP TABLE IF EXISTS tokenomics.retry_bridge_out;
DROP TABLE IF EXISTS tokenomics.retry_lock;
DROP TABLE IF EXISTS tokenomics.retry_message;
DROP TABLE IF EXISTS tokenomics.retry_mint;
DROP TABLE IF EXISTS tokenomics.retry_transfer;
DROP TABLE IF EXISTS tokenomics.return_fee_updated;
DROP TABLE IF EXISTS tokenomics.reward_claimed;
DROP TABLE IF EXISTS tokenomics.reward_metadata_updated;
DROP TABLE IF EXISTS tokenomics.rewards_claimed;
DROP TABLE IF EXISTS tokenomics.security_module_updated;
DROP TABLE IF EXISTS tokenomics."user";
DROP TABLE IF EXISTS tokenomics.vote_cast;
DROP TABLE IF EXISTS tokenomics.vote_delegated;
DROP TABLE IF EXISTS tokenomics.withdraw;
DROP TABLE IF EXISTS tokenomics.withdraw_eth;

