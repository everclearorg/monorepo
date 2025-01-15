-- migrate:up
DROP INDEX IF EXISTS public.hub_invoices_domain_status_queue_id_idx;
DROP MATERIALIZED VIEW IF EXISTS public.invoices;

ALTER TABLE ONLY public.hub_invoices DROP CONSTRAINT IF EXISTS hub_invoices_pkey;

ALTER TABLE public.hub_invoices ALTER COLUMN id TYPE character varying(255);

ALTER TABLE public.hub_invoices ADD PRIMARY KEY (id);

CREATE INDEX hub_invoices_domain_status_queue_id_idx ON public.hub_invoices USING btree (owner, id);

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
        hub_invoices.auto_id AS hub_invoice_auto_id
    FROM public.origin_intents 
        LEFT JOIN public.hub_invoices ON ((origin_intents.id = hub_invoices.intent_id))
    WITH NO DATA;
-- migrate:down
DROP INDEX IF EXISTS public.hub_invoices_domain_status_queue_id_idx;
DROP MATERIALIZED VIEW IF EXISTS public.invoices;

ALTER TABLE ONLY public.hub_invoices DROP CONSTRAINT IF EXISTS hub_invoices_pkey;

ALTER TABLE public.hub_invoices ALTER COLUMN id TYPE character(66);

ALTER TABLE public.hub_invoices ADD PRIMARY KEY (id);

CREATE INDEX hub_invoices_domain_status_queue_id_idx ON public.hub_invoices USING btree (owner, id);

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
        hub_invoices.auto_id AS hub_invoice_auto_id
    FROM public.origin_intents 
        LEFT JOIN public.hub_invoices ON ((origin_intents.id = hub_invoices.intent_id))
    WITH NO DATA;

