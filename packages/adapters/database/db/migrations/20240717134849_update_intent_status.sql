-- migrate:up

-- Step 1: Drop the existing enum type (you need to cascade to drop the columns using this type)
DROP MATERIALIZED VIEW IF EXISTS public.intents;
DROP INDEX IF EXISTS origin_intents_origin_status_idx;
DROP INDEX IF EXISTS destination_intents_destination_status_idx;
DROP INDEX IF EXISTS hub_intents_domain_status_queue_id_idx;
ALTER TABLE public.destination_intents DROP COLUMN status;
ALTER TABLE public.hub_intents DROP COLUMN status;
ALTER TABLE public.origin_intents DROP COLUMN status;

DROP TYPE public.intent_status CASCADE;

-- Step 2: Recreate the enum type with the new values
CREATE TYPE public.intent_status AS ENUM (
    'NONE',
    'ADDED',
    'DEPOSIT_PROCESSED',
    'FILLED',
    'ADDED_AND_FILLED',
    'INVOICED',
    'SETTLED',
    'SETTLED_AND_MANUALLY_EXECUTED',
    'UNSUPPORTED',
    'UNSUPPORTED_RETURNED',
    'DISPATCHED'
);

-- Step 3: Re-add the columns with the new enum type
ALTER TABLE public.destination_intents ADD COLUMN status public.intent_status DEFAULT 'NONE'::public.intent_status NOT NULL;
ALTER TABLE public.hub_intents ADD COLUMN status public.intent_status DEFAULT 'NONE'::public.intent_status NOT NULL;
ALTER TABLE public.origin_intents ADD COLUMN status public.intent_status DEFAULT 'NONE'::public.intent_status NOT NULL;

CREATE MATERIALIZED VIEW public.intents AS
 SELECT origin_intents.id,
    origin_intents.queue_idx AS origin_queue_idx,
    origin_intents.message_id AS origin_message_id,
    origin_intents.status AS origin_status,
    origin_intents.receiver AS origin_receiver,
    origin_intents.input_asset AS origin_input_asset,
    origin_intents.output_asset AS origin_output_asset,
    origin_intents.amount AS origin_amount,
    origin_intents.max_fee AS origin_max_fee,
    origin_intents.origin AS origin_origin,
    origin_intents.destination AS origin_destination,
    origin_intents.nonce AS origin_nonce,
    origin_intents.data AS origin_data,
    origin_intents.caller AS origin_caller,
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
    destination_intents.destination AS destination_destination,
    destination_intents.nonce AS destination_nonce,
    destination_intents.data AS destination_data,
    destination_intents.caller AS destination_caller,
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

CREATE INDEX origin_intents_origin_status_idx ON public.origin_intents USING btree (origin, status);
CREATE INDEX destination_intents_destination_status_idx ON public.destination_intents USING btree (destination, status);
CREATE INDEX hub_intents_domain_status_queue_id_idx ON public.hub_intents USING btree (domain, status, queue_id);

-- migrate:down
DROP MATERIALIZED VIEW IF EXISTS public.intents;
DROP INDEX IF EXISTS origin_intents_origin_status_idx;
DROP INDEX IF EXISTS destination_intents_destination_status_idx;
DROP INDEX IF EXISTS hub_intents_domain_status_queue_id_idx;
ALTER TABLE public.destination_intents DROP COLUMN status;
ALTER TABLE public.hub_intents DROP COLUMN status;
ALTER TABLE public.origin_intents DROP COLUMN status;

DROP TYPE public.intent_status CASCADE;

CREATE TYPE public.intent_status AS ENUM (
    'NONE',
    'ADDED',
    'DISPATCHED',
    'FILLED',
    'COMPLETED',
    'SETTLED',
    'SLOW_PATH_SETTLED',
    'UNSUPPORTED_RETURNED',
    'VERIFICATION_FAILED'
);

ALTER TABLE public.destination_intents ADD COLUMN status public.intent_status DEFAULT 'NONE'::public.intent_status NOT NULL;
ALTER TABLE public.hub_intents ADD COLUMN status public.intent_status DEFAULT 'NONE'::public.intent_status NOT NULL;
ALTER TABLE public.origin_intents ADD COLUMN status public.intent_status DEFAULT 'NONE'::public.intent_status NOT NULL;

CREATE MATERIALIZED VIEW public.intents AS
 SELECT origin_intents.id,
    origin_intents.queue_idx AS origin_queue_idx,
    origin_intents.message_id AS origin_message_id,
    origin_intents.status AS origin_status,
    origin_intents.receiver AS origin_receiver,
    origin_intents.input_asset AS origin_input_asset,
    origin_intents.output_asset AS origin_output_asset,
    origin_intents.amount AS origin_amount,
    origin_intents.max_fee AS origin_max_fee,
    origin_intents.origin AS origin_origin,
    origin_intents.destination AS origin_destination,
    origin_intents.nonce AS origin_nonce,
    origin_intents.data AS origin_data,
    origin_intents.caller AS origin_caller,
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
    destination_intents.destination AS destination_destination,
    destination_intents.nonce AS destination_nonce,
    destination_intents.data AS destination_data,
    destination_intents.caller AS destination_caller,
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

CREATE INDEX origin_intents_origin_status_idx ON public.origin_intents USING btree (origin, status);
CREATE INDEX destination_intents_destination_status_idx ON public.destination_intents USING btree (destination, status);
CREATE INDEX hub_intents_domain_status_queue_id_idx ON public.hub_intents USING btree (domain, status, queue_id);
