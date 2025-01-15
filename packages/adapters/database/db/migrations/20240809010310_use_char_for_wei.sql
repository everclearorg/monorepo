-- migrate:up

DROP MATERIALIZED VIEW IF EXISTS intents;
DROP MATERIALIZED VIEW IF EXISTS invoices;

ALTER TABLE hub_intents ALTER COLUMN settlement_amount TYPE character varying(66) USING settlement_amount::character varying(66);
ALTER TABLE hub_invoices ALTER COLUMN amount TYPE character varying(66) USING amount::character varying(66);

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
    settlement_intents.amount AS settlement_amount,
    settlement_intents.asset AS settlement_asset,
    settlement_intents.recipient AS settlement_recipient,
    settlement_intents.update_virtual_balances AS settlement_update_virtual_balances,
    settlement_intents.domain AS settlement_domain,
    settlement_intents.transaction_hash AS settlement_transaction_hash,
    settlement_intents."timestamp" AS settlement_timestamp,
    settlement_intents.block_number AS settlement_block_number,
    settlement_intents.gas_limit AS settlement_gas_limit,
    settlement_intents.gas_price AS settlement_gas_price,
    settlement_intents.tx_origin AS settlement_tx_origin,
    settlement_intents.tx_nonce AS settlement_tx_nonce,
    settlement_intents.auto_id AS settlement_auto_id,
    hub_intents.domain AS hub_domain,
    hub_intents.queue_idx AS hub_queue_idx,
    hub_intents.message_id AS hub_message_id,
    hub_intents.status AS hub_status,
    hub_intents.settlement_domain AS hub_settlement_domain,
    hub_intents.settlement_amount AS hub_settlement_amount,
    hub_intents.added_tx_nonce AS hub_added_tx_nonce,
    hub_intents.added_timestamp AS hub_added_timestamp,
    hub_intents.filled_tx_nonce AS hub_filled_tx_nonce,
    hub_intents.filled_timestamp AS hub_filled_timestamp,
    hub_intents.settlement_enqueued_tx_nonce AS hub_settlement_enqueued_tx_nonce,
    hub_intents.settlement_enqueued_block_number AS hub_settlement_enqueued_block_number,
    hub_intents.settlement_enqueued_timestamp AS hub_settlement_enqueued_timestamp,
    hub_intents.auto_id AS hub_auto_id
   FROM ((public.origin_intents
     LEFT JOIN public.destination_intents ON ((origin_intents.id = destination_intents.id)))
     LEFT JOIN public.settlement_intents ON ((origin_intents.id = settlement_intents.id))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
  WITH NO DATA;
  
CREATE MATERIALIZED VIEW public.invoices AS
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
    hub_invoices.id AS hub_invoice_id,
    hub_invoices.intent_id AS hub_invoice_intent_id,
    hub_invoices.amount AS hub_invoice_amount,
    hub_invoices.ticker_hash AS hub_invoice_ticker_hash,
    hub_invoices.owner AS hub_invoice_owner,
    hub_invoices.entry_epoch AS hub_invoice_entry_epoch,
    hub_invoices.enqueued_tx_nonce AS hub_invoice_enqueued_tx_nonce,
    hub_invoices.enqueued_timestamp AS hub_invoice_enqueued_timestamp,
    hub_invoices.auto_id AS hub_invoice_auto_id,
    hub_intents.status AS hub_status
   FROM ((public.origin_intents
     LEFT JOIN public.hub_invoices ON ((origin_intents.id = hub_invoices.intent_id)))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
  WITH NO DATA;

GRANT SELECT ON public.invoices TO reader;
GRANT SELECT ON public.intents TO reader;
GRANT SELECT ON public.invoices TO query;
GRANT SELECT ON public.intents TO query;

-- migrate:down

DROP MATERIALIZED VIEW IF EXISTS intents;
DROP MATERIALIZED VIEW IF EXISTS invoices;

ALTER TABLE hub_intents ALTER COLUMN settlement_amount TYPE bigint USING settlement_amount::bigint;
ALTER TABLE hub_invoices ALTER COLUMN amount TYPE bigint USING amount::bigint;

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
    settlement_intents.amount AS settlement_amount,
    settlement_intents.asset AS settlement_asset,
    settlement_intents.recipient AS settlement_recipient,
    settlement_intents.update_virtual_balances AS settlement_update_virtual_balances,
    settlement_intents.domain AS settlement_domain,
    settlement_intents.transaction_hash AS settlement_transaction_hash,
    settlement_intents."timestamp" AS settlement_timestamp,
    settlement_intents.block_number AS settlement_block_number,
    settlement_intents.gas_limit AS settlement_gas_limit,
    settlement_intents.gas_price AS settlement_gas_price,
    settlement_intents.tx_origin AS settlement_tx_origin,
    settlement_intents.tx_nonce AS settlement_tx_nonce,
    settlement_intents.auto_id AS settlement_auto_id,
    hub_intents.domain AS hub_domain,
    hub_intents.queue_idx AS hub_queue_idx,
    hub_intents.message_id AS hub_message_id,
    hub_intents.status AS hub_status,
    hub_intents.settlement_domain AS hub_settlement_domain,
    hub_intents.settlement_amount AS hub_settlement_amount,
    hub_intents.added_tx_nonce AS hub_added_tx_nonce,
    hub_intents.added_timestamp AS hub_added_timestamp,
    hub_intents.filled_tx_nonce AS hub_filled_tx_nonce,
    hub_intents.filled_timestamp AS hub_filled_timestamp,
    hub_intents.settlement_enqueued_tx_nonce AS hub_settlement_enqueued_tx_nonce,
    hub_intents.settlement_enqueued_block_number AS hub_settlement_enqueued_block_number,
    hub_intents.settlement_enqueued_timestamp AS hub_settlement_enqueued_timestamp,
    hub_intents.auto_id AS hub_auto_id
   FROM ((public.origin_intents
     LEFT JOIN public.destination_intents ON ((origin_intents.id = destination_intents.id)))
     LEFT JOIN public.settlement_intents ON ((origin_intents.id = settlement_intents.id))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
  WITH NO DATA;
  
CREATE MATERIALIZED VIEW public.invoices AS
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
    hub_invoices.id AS hub_invoice_id,
    hub_invoices.intent_id AS hub_invoice_intent_id,
    hub_invoices.amount AS hub_invoice_amount,
    hub_invoices.ticker_hash AS hub_invoice_ticker_hash,
    hub_invoices.owner AS hub_invoice_owner,
    hub_invoices.entry_epoch AS hub_invoice_entry_epoch,
    hub_invoices.enqueued_tx_nonce AS hub_invoice_enqueued_tx_nonce,
    hub_invoices.enqueued_timestamp AS hub_invoice_enqueued_timestamp,
    hub_invoices.auto_id AS hub_invoice_auto_id,
    hub_intents.status AS hub_status
   FROM ((public.origin_intents
     LEFT JOIN public.hub_invoices ON ((origin_intents.id = hub_invoices.intent_id)))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
  WITH NO DATA;

GRANT SELECT ON public.invoices TO reader;
GRANT SELECT ON public.intents TO reader;
GRANT SELECT ON public.invoices TO query;
GRANT SELECT ON public.intents TO query;