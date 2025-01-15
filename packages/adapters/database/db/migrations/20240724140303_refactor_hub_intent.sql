-- migrate:up
DROP MATERIALIZED VIEW intents;

DROP INDEX IF EXISTS hub_intents_domain_status_queue_id_idx;

ALTER TABLE public.hub_intents DROP COLUMN queue_id;
ALTER TABLE public.hub_intents DROP COLUMN queue_node;

ALTER TABLE public.hub_intents ADD COLUMN queue_idx bigint;
ALTER TABLE public.hub_intents ADD COLUMN pending_rewards character varying(255) NOT NULL;

CREATE MATERIALIZED VIEW intents AS
 SELECT origin_intents.id,
    origin_intents.queue_idx AS origin_queue_idx,
    origin_intents.message_id AS origin_message_id,
    origin_intents.status AS origin_status,
    origin_intents.initiator AS origin_initiator,
    origin_intents.receiver AS origin_receiver,
    origin_intents.input_asset AS origin_input_asset,
    origin_intents.output_asset AS origin_output_asset,
    origin_intents.amount AS origin_amount,
    origin_intents.max_fee AS origin_max_fee,
    origin_intents.origin AS origin_origin,
    origin_intents.destinations AS origin_destinations,
    origin_intents.ttl AS origin_ttl,
    origin_intents.nonce AS origin_nonce,
    origin_intents.data AS origin_data,
    origin_intents.transaction_hash AS origin_transaction_hash,
    origin_intents."timestamp" AS origin_timestamp,
    origin_intents.block_number AS origin_block_number,
    origin_intents.gas_limit AS origin_gas_limit,
    origin_intents.gas_price AS origin_gas_price,
    origin_intents.tx_origin AS origin_tx_origin,
    origin_intents.tx_nonce AS origin_tx_nonce,
    origin_intents.auto_id AS origin_auto_id,
    destination_intents.queue_idx AS destination_queue_idx,
    destination_intents.message_id AS destination_message_id,
    destination_intents.status AS destination_status,
    destination_intents.initiator AS destination_initiator,
    destination_intents.receiver AS destination_receiver,
    destination_intents.solver AS destination_solver,
    destination_intents.input_asset AS destination_input_asset,
    destination_intents.output_asset AS destination_output_asset,
    destination_intents.amount AS destination_amount,
    destination_intents.fee AS destination_fee,
    destination_intents.origin AS destination_origin,
    destination_intents.destinations AS destination_destinations,
    destination_intents.ttl AS destination_ttl,
    destination_intents.filled_domain AS destination_filled,
    destination_intents.nonce AS destination_nonce,
    destination_intents.data AS destination_data,
    destination_intents.transaction_hash AS destination_transaction_hash,
    destination_intents."timestamp" AS destination_timestamp,
    destination_intents.block_number AS destination_block_number,
    destination_intents.gas_limit AS destination_gas_limit,
    destination_intents.gas_price AS destination_gas_price,
    destination_intents.tx_origin AS destination_tx_origin,
    destination_intents.tx_nonce AS destination_tx_nonce,
    destination_intents.auto_id AS destination_auto_id,
    hub_intents.domain AS hub_domain,
    hub_intents.queue_idx AS hub_queue_idx,
    hub_intents.message_id AS hub_message_id,
    hub_intents.status AS hub_status,
    hub_intents.settlement_domain AS hub_settlement_domain,
    hub_intents.pending_rewards AS hub_pending_rewards,
    hub_intents.added_tx_nonce AS hub_added_tx_nonce,
    hub_intents.added_timestamp AS hub_added_timestamp,
    hub_intents.filled_tx_nonce AS hub_filled_tx_nonce,
    hub_intents.filled_timestamp AS hub_filled_timestamp,
    hub_intents.enqueued_tx_nonce AS hub_enqueued_tx_nonce,
    hub_intents.enqueued_timestamp AS hub_enqueued_timestamp,
    hub_intents.auto_id AS hub_auto_id
   FROM ((public.origin_intents
     LEFT JOIN public.destination_intents ON ((origin_intents.id = destination_intents.id)))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
  WITH NO DATA;



-- migrate:down
DROP MATERIALIZED VIEW IF EXISTS public.intents;

ALTER TABLE public.hub_intents ADD COLUMN queue_id character(66);
ALTER TABLE public.hub_intents ADD COLUMN queue_node character(66);

ALTER TABLE public.hub_intents DROP COLUMN queue_idx;
ALTER TABLE public.hub_intents DROP COLUMN pending_rewards;

CREATE INDEX hub_intents_domain_status_queue_id_idx ON hub_intents (domain, status, queue_id);

CREATE MATERIALIZED VIEW intents AS
 SELECT origin_intents.id,
    origin_intents.queue_idx AS origin_queue_idx,
    origin_intents.message_id AS origin_message_id,
    origin_intents.status AS origin_status,
    origin_intents.initiator AS origin_initiator,
    origin_intents.receiver AS origin_receiver,
    origin_intents.input_asset AS origin_input_asset,
    origin_intents.output_asset AS origin_output_asset,
    origin_intents.amount AS origin_amount,
    origin_intents.max_fee AS origin_max_fee,
    origin_intents.origin AS origin_origin,
    origin_intents.destinations AS origin_destinations,
    origin_intents.ttl AS origin_ttl,
    origin_intents.nonce AS origin_nonce,
    origin_intents.data AS origin_data,
    origin_intents.transaction_hash AS origin_transaction_hash,
    origin_intents."timestamp" AS origin_timestamp,
    origin_intents.block_number AS origin_block_number,
    origin_intents.gas_limit AS origin_gas_limit,
    origin_intents.gas_price AS origin_gas_price,
    origin_intents.tx_origin AS origin_tx_origin,
    origin_intents.tx_nonce AS origin_tx_nonce,
    origin_intents.auto_id AS origin_auto_id,
    destination_intents.queue_idx AS destination_queue_idx,
    destination_intents.message_id AS destination_message_id,
    destination_intents.status AS destination_status,
    destination_intents.initiator AS destination_initiator,
    destination_intents.receiver AS destination_receiver,
    destination_intents.solver AS destination_solver,
    destination_intents.input_asset AS destination_input_asset,
    destination_intents.output_asset AS destination_output_asset,
    destination_intents.amount AS destination_amount,
    destination_intents.fee AS destination_fee,
    destination_intents.origin AS destination_origin,
    destination_intents.destinations AS destination_destinations,
    destination_intents.ttl AS destination_ttl,
    destination_intents.filled_domain AS destination_filled,
    destination_intents.nonce AS destination_nonce,
    destination_intents.data AS destination_data,
    destination_intents.transaction_hash AS destination_transaction_hash,
    destination_intents."timestamp" AS destination_timestamp,
    destination_intents.block_number AS destination_block_number,
    destination_intents.gas_limit AS destination_gas_limit,
    destination_intents.gas_price AS destination_gas_price,
    destination_intents.tx_origin AS destination_tx_origin,
    destination_intents.tx_nonce AS destination_tx_nonce,
    destination_intents.auto_id AS destination_auto_id,
    hub_intents.domain AS hub_domain,
    hub_intents.queue_id AS hub_queue_id,
    hub_intents.queue_node AS hub_queue_node,
    hub_intents.message_id AS hub_message_id,
    hub_intents.status AS hub_status,
    hub_intents.settlement_domain AS hub_settlement_domain,
    hub_intents.added_tx_nonce AS hub_added_tx_nonce,
    hub_intents.added_timestamp AS hub_added_timestamp,
    hub_intents.filled_tx_nonce AS hub_filled_tx_nonce,
    hub_intents.filled_timestamp AS hub_filled_timestamp,
    hub_intents.enqueued_tx_nonce AS hub_enqueued_tx_nonce,
    hub_intents.enqueued_timestamp AS hub_enqueued_timestamp,
    hub_intents.auto_id AS hub_auto_id
   FROM ((public.origin_intents
     LEFT JOIN public.destination_intents ON ((origin_intents.id = destination_intents.id)))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
  WITH NO DATA;

