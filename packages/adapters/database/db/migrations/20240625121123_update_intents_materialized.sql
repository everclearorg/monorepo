
-- migrate:up

DROP MATERIALIZED VIEW IF EXISTS intents;

CREATE MATERIALIZED VIEW intents AS
SELECT 
    origin_intents.id as id, 
    origin_intents.queue_idx as origin_queue_idx, 
    origin_intents.message_id as origin_message_id, 
    origin_intents.status as origin_status, 
    origin_intents.receiver as origin_receiver, 
    origin_intents.input_asset as origin_input_asset, 
    origin_intents.output_asset as origin_output_asset, 
    origin_intents.amount as origin_amount, 
    origin_intents.max_routers_fee as origin_max_routers_fee, 
    origin_intents.origin as origin_origin, 
    origin_intents.destination as origin_destination, 
    origin_intents.nonce as origin_nonce, 
    origin_intents.data as origin_data, 
    origin_intents.caller as origin_caller, 
    origin_intents.transaction_hash as origin_transaction_hash, 
    origin_intents."timestamp" as origin_timestamp, 
    origin_intents.block_number as origin_block_number, 
    origin_intents.gas_limit as origin_gas_limit, 
    origin_intents.gas_price as origin_gas_price, 
    origin_intents.tx_origin as origin_tx_origin, 
    origin_intents.tx_nonce as origin_tx_nonce, 
    origin_intents.auto_id as origin_auto_id, 
    destination_intents.queue_idx as destination_queue_idx, 
    destination_intents.message_id as destination_message_id, 
    destination_intents.status as destination_status, 
    destination_intents.initiator as destination_initiator, 
    destination_intents.receiver as destination_receiver, 
    destination_intents.filler as destination_filler, 
    destination_intents.input_asset as destination_input_asset, 
    destination_intents.output_asset as destination_output_asset, 
    destination_intents.amount as destination_amount, 
    destination_intents.fee as destination_fee, 
    destination_intents.origin as destination_origin, 
    destination_intents.destination as destination_destination, 
    destination_intents.nonce as destination_nonce, 
    destination_intents.data as destination_data, 
    destination_intents.caller as destination_caller, 
    destination_intents.transaction_hash as destination_transaction_hash, 
    destination_intents."timestamp" as destination_timestamp, 
    destination_intents.block_number as destination_block_number, 
    destination_intents.gas_limit as destination_gas_limit, 
    destination_intents.gas_price as destination_gas_price, 
    destination_intents.tx_origin as destination_tx_origin, 
    destination_intents.tx_nonce as destination_tx_nonce, 
    destination_intents.auto_id as destination_auto_id,
    hub_intents.domain as hub_domain,
    hub_intents.queue_id as hub_queue_id,
    hub_intents.queue_node as hub_queue_node,
    hub_intents.message_id as hub_message_id,
    hub_intents.status as hub_status,
    hub_intents.settlement_domain as hub_settlement_domain,
    hub_intents.added_tx_nonce as hub_added_tx_nonce,
    hub_intents.added_timestamp as hub_added_timestamp,
    hub_intents.filled_tx_nonce as hub_filled_tx_nonce,
    hub_intents.filled_timestamp as hub_filled_timestamp,
    hub_intents.enqueued_tx_nonce as hub_enqueued_tx_nonce,
    hub_intents.enqueued_timestamp as hub_enqueued_timestamp,
    hub_intents.auto_id as hub_auto_id
FROM origin_intents
LEFT JOIN destination_intents
ON origin_intents.id = destination_intents.id
LEFT JOIN hub_intents
ON origin_intents.id = hub_intents.id;

-- migrate:down
DROP MATERIALIZED VIEW IF EXISTS intents;