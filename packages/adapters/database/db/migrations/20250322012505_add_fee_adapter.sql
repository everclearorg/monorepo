-- migrate:up

-- Create orders table first
CREATE TABLE orders (
    id character varying(66) PRIMARY KEY,
    auto_id SERIAL NOT NULL,
    token_fee character varying(255),
    native_fee character varying(255),
    intent_ids character varying(66)[] NOT NULL
);

-- Create index on auto_id for efficient ordering
CREATE INDEX orders_auto_id_idx ON orders(auto_id);

-- Grant permissions on orders table
GRANT SELECT ON orders TO reader;
GRANT SELECT ON orders TO query;

-- Now add fee columns and order_id to origin_intents table
ALTER TABLE origin_intents
ADD COLUMN native_fee character varying(255),
ADD COLUMN token_fee character varying(255),
ADD COLUMN fee_adapter_initiator character varying(66),
ADD COLUMN order_id character varying(66) REFERENCES orders(id);

-- Create index on order_id for efficient lookups
CREATE INDEX origin_intents_order_id_idx ON origin_intents(order_id);

-- Drop the existing materialized view and its dependencies
DROP MATERIALIZED VIEW IF EXISTS public.daily_metrics_by_chains_tokens;
DROP MATERIALIZED VIEW IF EXISTS public.daily_metrics_by_date;
DROP MATERIALIZED VIEW IF EXISTS public.invoices;
DROP MATERIALIZED VIEW IF EXISTS public.intents;

-- Recreate the materialized view with the new fee columns
CREATE MATERIALIZED VIEW public.intents AS
  SELECT 
    origin_intents.id,
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
    origin_intents.native_fee AS origin_native_fee,
    origin_intents.token_fee AS origin_token_fee,
    origin_intents.fee_adapter_initiator AS origin_fee_adapter_initiator,
    origin_intents.order_id AS origin_order_id,
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
    settlement_intents.domain AS settlement_domain,
    settlement_intents.status AS settlement_status,
    COALESCE(destination_intents.return_data, settlement_intents.return_data) AS destination_return_data,
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
    hub_intents.settlement_epoch AS hub_settlement_epoch,
    hub_intents.update_virtual_balance AS hub_update_virtual_balance,
    genStatus(origin_intents.status, hub_intents.status, settlement_intents.status, hasCallData(origin_intents.data)) AS status,
    hasCallData(origin_intents.data) AS has_calldata,
    hub_intents.auto_id AS hub_auto_id
  FROM public.origin_intents
  LEFT JOIN public.destination_intents ON origin_intents.id = destination_intents.id
  LEFT JOIN public.settlement_intents ON origin_intents.id = settlement_intents.id
  LEFT JOIN public.hub_intents ON origin_intents.id = hub_intents.id
  WITH NO DATA;

-- Recreate invoices
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
    hub_intents.status AS hub_status,
    hub_intents.settlement_epoch AS hub_settlement_epoch
   FROM ((public.hub_invoices
     LEFT JOIN public.origin_intents ON ((origin_intents.id = hub_invoices.intent_id)))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
  WITH NO DATA;

-- Recreate daily metrics by chain
CREATE MATERIALIZED VIEW public.daily_metrics_by_chains_tokens AS
 WITH metadata AS (
         SELECT asset_data.symbol,
            asset_data.decimals AS "decimal",
            asset_data.domainid AS domain_id,
            lower(asset_data.address) AS address,
            lower(concat('0x', lpad(SUBSTRING(asset_data.address FROM 3), 64, '0'::text))) AS adopted_address
           FROM ( VALUES ('Wrapped Ether'::text,'WETH'::text,18,1,'0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'::text), ('Wrapped Ether'::text,'WETH'::text,18,10,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,56,'0x2170Ed0880ac9A755fd29B2688956BD959F933F8'::text), ('Wrapped Ether'::text,'WETH'::text,18,8453,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,42161,'0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'::text), ('USD Coin'::text,'USDC'::text,6,1,'0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'::text), ('USD Coin'::text,'USDC'::text,6,10,'0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85'::text), ('USD Coin'::text,'USDC'::text,18,56,'0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'::text), ('USD Coin'::text,'USDC'::text,6,8453,'0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'::text), ('USD Coin'::text,'USDC'::text,6,42161,'0xaf88d065e77c8cC2239327C5EDb3A432268e5831'::text), ('Tether USD'::text,'USDT'::text,6,1,'0xdAC17F958D2ee523a2206206994597C13D831ec7'::text), ('Tether USD'::text,'USDT'::text,6,10,'0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'::text), ('Tether USD'::text,'USDT'::text,18,56,'0x55d398326f99059fF775485246999027B3197955'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'::text)) asset_data(assetname, symbol, decimals, domainid, address)
        ), netted_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision)) AS day,
            (i.origin_origin)::integer AS from_chain_id,
            i.origin_input_asset AS from_asset_address,
            fm.symbol AS from_asset_symbol,
            (i.settlement_domain)::integer AS to_chain_id,
            i.settlement_asset AS to_asset_address,
            tm.symbol AS to_asset_symbol,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_volume,
            avg((((i.settlement_timestamp)::double precision - (i.origin_timestamp)::double precision) / (3600)::double precision)) AS netting_avg_time_in_hrs,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS netting_protocol_revenue,
            count(i.id) AS netting_total_intents,
            avg(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_avg_intent_size
           FROM (((public.intents i
             LEFT JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((inv.id IS NULL) AND (i.status = ANY (ARRAY['SETTLED_AND_COMPLETED'::public.intent_status, 'SETTLED_AND_MANUALLY_EXECUTED'::public.intent_status])) AND (i.hub_status <> 'DISPATCHED_UNSUPPORTED'::public.intent_status))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision))), (i.origin_origin)::integer, i.origin_input_asset, fm.symbol, (i.settlement_domain)::integer, i.settlement_asset, tm.symbol
        ), netted_final AS (
         SELECT netted_raw.day,
            netted_raw.from_chain_id,
            netted_raw.from_asset_address,
            netted_raw.from_asset_symbol,
            netted_raw.to_chain_id,
            netted_raw.to_asset_address,
            netted_raw.to_asset_symbol,
            netted_raw.netting_volume,
            netted_raw.netting_avg_intent_size,
            netted_raw.netting_protocol_revenue,
            netted_raw.netting_total_intents,
            netted_raw.netting_avg_time_in_hrs
           FROM netted_raw
        ), settled_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision)) AS day,
            (i.origin_origin)::integer AS from_chain_id,
            i.origin_input_asset AS from_asset_address,
            fm.symbol AS from_asset_symbol,
            (i.settlement_domain)::integer AS to_chain_id,
            i.settlement_asset AS to_asset_address,
            tm.symbol AS to_asset_symbol,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS avg_discounts_by_mm,
            sum((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS discounts_by_mm,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision)))) AS avg_rewards_by_invoice,
            sum(((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) - (((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision)))) AS rewards_for_invoices,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS volume_settled_by_mm,
            count(i.id) AS total_intents_by_mm,
            avg((((i.hub_settlement_enqueued_timestamp)::double precision - (i.hub_added_timestamp)::double precision) / (3600)::double precision)) AS avg_time_in_hrs,
            round(avg((inv.hub_settlement_epoch - inv.hub_invoice_entry_epoch)), 0) AS avg_discount_epoch,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS protocol_revenue_mm
           FROM (((public.intents i
             JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((i.status = ANY (ARRAY['SETTLED_AND_COMPLETED'::public.intent_status, 'SETTLED_AND_MANUALLY_EXECUTED'::public.intent_status])) AND (i.hub_status = ANY (ARRAY['DISPATCHED'::public.intent_status, 'SETTLED'::public.intent_status])))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision))), (i.origin_origin)::integer, i.origin_input_asset, fm.symbol, (i.settlement_domain)::integer, i.settlement_asset, tm.symbol
        ), settled_final AS (
         SELECT settled_raw.day,
            settled_raw.from_chain_id,
            settled_raw.from_asset_address,
            settled_raw.from_asset_symbol,
            settled_raw.to_chain_id,
            settled_raw.to_asset_address,
            settled_raw.to_asset_symbol,
            settled_raw.volume_settled_by_mm,
            settled_raw.protocol_revenue_mm,
            settled_raw.total_intents_by_mm,
            settled_raw.discounts_by_mm,
            settled_raw.avg_discounts_by_mm,
            settled_raw.rewards_for_invoices,
            settled_raw.avg_rewards_by_invoice,
            settled_raw.avg_time_in_hrs AS avg_settlement_time_in_hrs_by_mm,
            (((settled_raw.discounts_by_mm / settled_raw.volume_settled_by_mm) * (365)::double precision) * (100)::double precision) AS apy,
            settled_raw.avg_discount_epoch AS avg_discount_epoch_by_mm
           FROM settled_raw
        ), combined AS (
         SELECT COALESCE(n.day, s.day) AS day,
            COALESCE(n.from_chain_id, s.from_chain_id) AS from_chain_id,
            COALESCE(n.from_asset_address, s.from_asset_address) AS from_asset_address,
            COALESCE(n.from_asset_symbol, s.from_asset_symbol) AS from_asset_symbol,
            COALESCE(n.to_chain_id, s.to_chain_id) AS to_chain_id,
            COALESCE(n.to_asset_address, s.to_asset_address) AS to_asset_address,
            COALESCE(n.to_asset_symbol, s.to_asset_symbol) AS to_asset_symbol,
            n.netting_volume,
            n.netting_avg_intent_size,
            n.netting_protocol_revenue,
            n.netting_total_intents,
            n.netting_avg_time_in_hrs,
            s.volume_settled_by_mm,
            s.total_intents_by_mm,
            s.discounts_by_mm,
            s.avg_discounts_by_mm,
            s.rewards_for_invoices,
            s.avg_rewards_by_invoice,
            s.avg_settlement_time_in_hrs_by_mm,
            s.apy,
            s.avg_discount_epoch_by_mm,
            (COALESCE(n.netting_volume, (0)::double precision) + COALESCE(s.volume_settled_by_mm, (0)::double precision)) AS total_volume,
            (COALESCE(n.netting_total_intents, (0)::bigint) + COALESCE(s.total_intents_by_mm, (0)::bigint)) AS total_intents,
            (COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) AS total_protocol_revenue,
            ((COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) + COALESCE(s.discounts_by_mm, (0)::double precision)) AS total_rebalancing_fee
           FROM (netted_final n
             FULL JOIN settled_final s ON (((n.day = s.day) AND (n.from_chain_id = s.from_chain_id) AND (n.to_chain_id = s.to_chain_id) AND ((n.from_asset_address)::text = (s.from_asset_address)::text) AND ((n.to_asset_address)::text = (s.to_asset_address)::text))))
        )
 SELECT day,
    from_chain_id,
    from_asset_address,
    from_asset_symbol,
    to_chain_id,
    to_asset_address,
    to_asset_symbol,
    netting_volume,
    netting_avg_intent_size,
    netting_protocol_revenue,
    netting_total_intents,
    netting_avg_time_in_hrs,
    volume_settled_by_mm,
    total_intents_by_mm,
    discounts_by_mm,
    avg_discounts_by_mm,
    rewards_for_invoices,
    avg_rewards_by_invoice,
    avg_settlement_time_in_hrs_by_mm,
    apy,
    avg_discount_epoch_by_mm,
    total_volume,
    total_intents,
    total_protocol_revenue,
    total_rebalancing_fee
   FROM combined
  WITH NO DATA;

-- Recreate daily metrics by date
CREATE MATERIALIZED VIEW public.daily_metrics_by_date AS
 WITH metadata AS (
         SELECT asset_data.symbol,
            asset_data.decimals AS "decimal",
            asset_data.domainid AS domain_id,
            lower(asset_data.address) AS address,
            lower(concat('0x', lpad(SUBSTRING(asset_data.address FROM 3), 64, '0'::text))) AS adopted_address
           FROM ( VALUES ('Wrapped Ether'::text,'WETH'::text,18,1,'0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'::text), ('Wrapped Ether'::text,'WETH'::text,18,10,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,56,'0x2170Ed0880ac9A755fd29B2688956BD959F933F8'::text), ('Wrapped Ether'::text,'WETH'::text,18,8453,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,42161,'0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'::text), ('USD Coin'::text,'USDC'::text,6,1,'0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'::text), ('USD Coin'::text,'USDC'::text,6,10,'0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85'::text), ('USD Coin'::text,'USDC'::text,18,56,'0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'::text), ('USD Coin'::text,'USDC'::text,6,8453,'0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'::text), ('USD Coin'::text,'USDC'::text,6,42161,'0xaf88d065e77c8cC2239327C5EDb3A432268e5831'::text), ('Tether USD'::text,'USDT'::text,6,1,'0xdAC17F958D2ee523a2206206994597C13D831ec7'::text), ('Tether USD'::text,'USDT'::text,6,10,'0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'::text), ('Tether USD'::text,'USDT'::text,18,56,'0x55d398326f99059fF775485246999027B3197955'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'::text)) asset_data(assetname, symbol, decimals, domainid, address)
        ), netted_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)) AS day,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_volume,
            avg((((i.settlement_timestamp)::double precision - (i.origin_timestamp)::double precision) / (3600)::double precision)) AS netting_avg_time_in_hrs,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS netting_protocol_revenue,
            count(i.id) AS netting_total_intents,
            avg(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_avg_intent_size
           FROM (((public.intents i
             LEFT JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((inv.id IS NULL) AND (i.status = 'SETTLED_AND_COMPLETED'::public.intent_status) AND (i.hub_status <> 'DISPATCHED_UNSUPPORTED'::public.intent_status))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)))
        ), netted_final AS (
         SELECT netted_raw.day,
            netted_raw.netting_volume,
            netted_raw.netting_avg_intent_size,
            netted_raw.netting_protocol_revenue,
            netted_raw.netting_total_intents,
            netted_raw.netting_avg_time_in_hrs
           FROM netted_raw
        ), settled_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)) AS day,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS avg_discounts_by_mm,
            sum((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS discounts_by_mm,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision)))) AS avg_rewards_by_invoice,
            sum(((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) - (((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision)))) AS rewards_for_invoices,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS volume_settled_by_mm,
            count(i.id) AS total_intents_by_mm,
            avg((((i.hub_settlement_enqueued_timestamp)::double precision - (i.hub_added_timestamp)::double precision) / (3600)::double precision)) AS avg_time_in_hrs,
            round(avg((inv.hub_settlement_epoch - inv.hub_invoice_entry_epoch)), 0) AS avg_discount_epoch,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS protocol_revenue_mm
           FROM (((public.intents i
             JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((i.status = 'SETTLED_AND_COMPLETED'::public.intent_status) AND (i.hub_status = ANY (ARRAY['DISPATCHED'::public.intent_status, 'SETTLED'::public.intent_status])))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)))
        ), settled_final AS (
         SELECT settled_raw.day,
            settled_raw.volume_settled_by_mm,
            settled_raw.protocol_revenue_mm,
            settled_raw.total_intents_by_mm,
            settled_raw.discounts_by_mm,
            settled_raw.avg_discounts_by_mm,
            settled_raw.rewards_for_invoices,
            settled_raw.avg_rewards_by_invoice,
            settled_raw.avg_time_in_hrs AS avg_settlement_time_in_hrs_by_mm,
            (((settled_raw.discounts_by_mm / settled_raw.volume_settled_by_mm) * (365)::double precision) * (100)::double precision) AS apy,
            settled_raw.avg_discount_epoch AS avg_discount_epoch_by_mm
           FROM settled_raw
        )
 SELECT COALESCE(n.day, s.day) AS day,
    n.netting_volume,
    n.netting_avg_intent_size,
    n.netting_protocol_revenue,
    n.netting_total_intents,
    n.netting_avg_time_in_hrs,
    s.volume_settled_by_mm,
    s.total_intents_by_mm,
    s.discounts_by_mm,
    s.avg_discounts_by_mm,
    s.rewards_for_invoices,
    s.avg_rewards_by_invoice,
    s.avg_settlement_time_in_hrs_by_mm,
    s.apy,
    s.avg_discount_epoch_by_mm,
    (COALESCE(n.netting_volume, (0)::double precision) + COALESCE(s.volume_settled_by_mm, (0)::double precision)) AS total_volume,
    (COALESCE(n.netting_total_intents, (0)::bigint) + COALESCE(s.total_intents_by_mm, (0)::bigint)) AS total_intents,
    (COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) AS total_protocol_revenue,
    ((COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) + COALESCE(s.discounts_by_mm, (0)::double precision)) AS total_rebalancing_fee
   FROM (netted_final n
     FULL JOIN settled_final s ON ((n.day = s.day)))
  WITH NO DATA;

-- migrate:down

-- Revoke permissions on orders table before dropping
REVOKE SELECT ON orders FROM reader;
REVOKE SELECT ON orders FROM query;

-- Drop the existing materialized view and its dependencies
DROP MATERIALIZED VIEW IF EXISTS public.daily_metrics_by_chains_tokens;
DROP MATERIALIZED VIEW IF EXISTS public.daily_metrics_by_date;
DROP MATERIALIZED VIEW IF EXISTS public.invoices;
DROP MATERIALIZED VIEW IF EXISTS public.intents;

-- Drop the orders table
DROP TABLE IF EXISTS orders;

-- Remove the fee columns and order_id from origin_intents
ALTER TABLE origin_intents
DROP COLUMN IF EXISTS native_fee,
DROP COLUMN IF EXISTS token_fee,
DROP COLUMN IF EXISTS fee_adapter_initiator,
DROP COLUMN IF EXISTS order_id;

-- Recreate the original materialized view without the fee columns
CREATE MATERIALIZED VIEW public.intents AS
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
    settlement_intents.domain AS settlement_domain,
    settlement_intents.status AS settlement_status,
    COALESCE(destination_intents.return_data, settlement_intents.return_data) AS destination_return_data,
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
    hub_intents.settlement_epoch AS hub_settlement_epoch,
    hub_intents.update_virtual_balance AS hub_update_virtual_balance,
    public.genstatus(origin_intents.status, hub_intents.status, settlement_intents.status, public.hascalldata(origin_intents.data)) AS status,
    public.hascalldata(origin_intents.data) AS has_calldata,
    hub_intents.auto_id AS hub_auto_id
   FROM (((public.origin_intents
     LEFT JOIN public.destination_intents ON ((origin_intents.id = destination_intents.id)))
     LEFT JOIN public.settlement_intents ON ((origin_intents.id = settlement_intents.id)))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
  WITH NO DATA;

-- Recreate invoices
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
    hub_intents.status AS hub_status,
    hub_intents.settlement_epoch AS hub_settlement_epoch
   FROM ((public.hub_invoices
     LEFT JOIN public.origin_intents ON ((origin_intents.id = hub_invoices.intent_id)))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
  WITH NO DATA;

-- Recreate daily metrics by chains

CREATE MATERIALIZED VIEW public.daily_metrics_by_chains_tokens AS
 WITH metadata AS (
         SELECT asset_data.symbol,
            asset_data.decimals AS "decimal",
            asset_data.domainid AS domain_id,
            lower(asset_data.address) AS address,
            lower(concat('0x', lpad(SUBSTRING(asset_data.address FROM 3), 64, '0'::text))) AS adopted_address
           FROM ( VALUES ('Wrapped Ether'::text,'WETH'::text,18,1,'0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'::text), ('Wrapped Ether'::text,'WETH'::text,18,10,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,56,'0x2170Ed0880ac9A755fd29B2688956BD959F933F8'::text), ('Wrapped Ether'::text,'WETH'::text,18,8453,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,42161,'0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'::text), ('USD Coin'::text,'USDC'::text,6,1,'0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'::text), ('USD Coin'::text,'USDC'::text,6,10,'0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85'::text), ('USD Coin'::text,'USDC'::text,18,56,'0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'::text), ('USD Coin'::text,'USDC'::text,6,8453,'0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'::text), ('USD Coin'::text,'USDC'::text,6,42161,'0xaf88d065e77c8cC2239327C5EDb3A432268e5831'::text), ('Tether USD'::text,'USDT'::text,6,1,'0xdAC17F958D2ee523a2206206994597C13D831ec7'::text), ('Tether USD'::text,'USDT'::text,6,10,'0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'::text), ('Tether USD'::text,'USDT'::text,18,56,'0x55d398326f99059fF775485246999027B3197955'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'::text)) asset_data(assetname, symbol, decimals, domainid, address)
        ), netted_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision)) AS day,
            (i.origin_origin)::integer AS from_chain_id,
            i.origin_input_asset AS from_asset_address,
            fm.symbol AS from_asset_symbol,
            (i.settlement_domain)::integer AS to_chain_id,
            i.settlement_asset AS to_asset_address,
            tm.symbol AS to_asset_symbol,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_volume,
            avg((((i.settlement_timestamp)::double precision - (i.origin_timestamp)::double precision) / (3600)::double precision)) AS netting_avg_time_in_hrs,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS netting_protocol_revenue,
            count(i.id) AS netting_total_intents,
            avg(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_avg_intent_size
           FROM (((public.intents i
             LEFT JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((inv.id IS NULL) AND (i.status = ANY (ARRAY['SETTLED_AND_COMPLETED'::public.intent_status, 'SETTLED_AND_MANUALLY_EXECUTED'::public.intent_status])) AND (i.hub_status <> 'DISPATCHED_UNSUPPORTED'::public.intent_status))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision))), (i.origin_origin)::integer, i.origin_input_asset, fm.symbol, (i.settlement_domain)::integer, i.settlement_asset, tm.symbol
        ), netted_final AS (
         SELECT netted_raw.day,
            netted_raw.from_chain_id,
            netted_raw.from_asset_address,
            netted_raw.from_asset_symbol,
            netted_raw.to_chain_id,
            netted_raw.to_asset_address,
            netted_raw.to_asset_symbol,
            netted_raw.netting_volume,
            netted_raw.netting_avg_intent_size,
            netted_raw.netting_protocol_revenue,
            netted_raw.netting_total_intents,
            netted_raw.netting_avg_time_in_hrs
           FROM netted_raw
        ), settled_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision)) AS day,
            (i.origin_origin)::integer AS from_chain_id,
            i.origin_input_asset AS from_asset_address,
            fm.symbol AS from_asset_symbol,
            (i.settlement_domain)::integer AS to_chain_id,
            i.settlement_asset AS to_asset_address,
            tm.symbol AS to_asset_symbol,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS avg_discounts_by_mm,
            sum((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS discounts_by_mm,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision)))) AS avg_rewards_by_invoice,
            sum(((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) - (((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision)))) AS rewards_for_invoices,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS volume_settled_by_mm,
            count(i.id) AS total_intents_by_mm,
            avg((((i.hub_settlement_enqueued_timestamp)::double precision - (i.hub_added_timestamp)::double precision) / (3600)::double precision)) AS avg_time_in_hrs,
            round(avg((inv.hub_settlement_epoch - inv.hub_invoice_entry_epoch)), 0) AS avg_discount_epoch,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS protocol_revenue_mm
           FROM (((public.intents i
             JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((i.status = ANY (ARRAY['SETTLED_AND_COMPLETED'::public.intent_status, 'SETTLED_AND_MANUALLY_EXECUTED'::public.intent_status])) AND (i.hub_status = ANY (ARRAY['DISPATCHED'::public.intent_status, 'SETTLED'::public.intent_status])))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision))), (i.origin_origin)::integer, i.origin_input_asset, fm.symbol, (i.settlement_domain)::integer, i.settlement_asset, tm.symbol
        ), settled_final AS (
         SELECT settled_raw.day,
            settled_raw.from_chain_id,
            settled_raw.from_asset_address,
            settled_raw.from_asset_symbol,
            settled_raw.to_chain_id,
            settled_raw.to_asset_address,
            settled_raw.to_asset_symbol,
            settled_raw.volume_settled_by_mm,
            settled_raw.protocol_revenue_mm,
            settled_raw.total_intents_by_mm,
            settled_raw.discounts_by_mm,
            settled_raw.avg_discounts_by_mm,
            settled_raw.rewards_for_invoices,
            settled_raw.avg_rewards_by_invoice,
            settled_raw.avg_time_in_hrs AS avg_settlement_time_in_hrs_by_mm,
            (((settled_raw.discounts_by_mm / settled_raw.volume_settled_by_mm) * (365)::double precision) * (100)::double precision) AS apy,
            settled_raw.avg_discount_epoch AS avg_discount_epoch_by_mm
           FROM settled_raw
        ), combined AS (
         SELECT COALESCE(n.day, s.day) AS day,
            COALESCE(n.from_chain_id, s.from_chain_id) AS from_chain_id,
            COALESCE(n.from_asset_address, s.from_asset_address) AS from_asset_address,
            COALESCE(n.from_asset_symbol, s.from_asset_symbol) AS from_asset_symbol,
            COALESCE(n.to_chain_id, s.to_chain_id) AS to_chain_id,
            COALESCE(n.to_asset_address, s.to_asset_address) AS to_asset_address,
            COALESCE(n.to_asset_symbol, s.to_asset_symbol) AS to_asset_symbol,
            n.netting_volume,
            n.netting_avg_intent_size,
            n.netting_protocol_revenue,
            n.netting_total_intents,
            n.netting_avg_time_in_hrs,
            s.volume_settled_by_mm,
            s.total_intents_by_mm,
            s.discounts_by_mm,
            s.avg_discounts_by_mm,
            s.rewards_for_invoices,
            s.avg_rewards_by_invoice,
            s.avg_settlement_time_in_hrs_by_mm,
            s.apy,
            s.avg_discount_epoch_by_mm,
            (COALESCE(n.netting_volume, (0)::double precision) + COALESCE(s.volume_settled_by_mm, (0)::double precision)) AS total_volume,
            (COALESCE(n.netting_total_intents, (0)::bigint) + COALESCE(s.total_intents_by_mm, (0)::bigint)) AS total_intents,
            (COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) AS total_protocol_revenue,
            ((COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) + COALESCE(s.discounts_by_mm, (0)::double precision)) AS total_rebalancing_fee
           FROM (netted_final n
             FULL JOIN settled_final s ON (((n.day = s.day) AND (n.from_chain_id = s.from_chain_id) AND (n.to_chain_id = s.to_chain_id) AND ((n.from_asset_address)::text = (s.from_asset_address)::text) AND ((n.to_asset_address)::text = (s.to_asset_address)::text))))
        )
 SELECT day,
    from_chain_id,
    from_asset_address,
    from_asset_symbol,
    to_chain_id,
    to_asset_address,
    to_asset_symbol,
    netting_volume,
    netting_avg_intent_size,
    netting_protocol_revenue,
    netting_total_intents,
    netting_avg_time_in_hrs,
    volume_settled_by_mm,
    total_intents_by_mm,
    discounts_by_mm,
    avg_discounts_by_mm,
    rewards_for_invoices,
    avg_rewards_by_invoice,
    avg_settlement_time_in_hrs_by_mm,
    apy,
    avg_discount_epoch_by_mm,
    total_volume,
    total_intents,
    total_protocol_revenue,
    total_rebalancing_fee
   FROM combined
  WITH NO DATA;


-- Recreate daily metrics by date
CREATE MATERIALIZED VIEW public.daily_metrics_by_date AS
 WITH metadata AS (
         SELECT asset_data.symbol,
            asset_data.decimals AS "decimal",
            asset_data.domainid AS domain_id,
            lower(asset_data.address) AS address,
            lower(concat('0x', lpad(SUBSTRING(asset_data.address FROM 3), 64, '0'::text))) AS adopted_address
           FROM ( VALUES ('Wrapped Ether'::text,'WETH'::text,18,1,'0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'::text), ('Wrapped Ether'::text,'WETH'::text,18,10,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,56,'0x2170Ed0880ac9A755fd29B2688956BD959F933F8'::text), ('Wrapped Ether'::text,'WETH'::text,18,8453,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,42161,'0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'::text), ('USD Coin'::text,'USDC'::text,6,1,'0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'::text), ('USD Coin'::text,'USDC'::text,6,10,'0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85'::text), ('USD Coin'::text,'USDC'::text,18,56,'0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'::text), ('USD Coin'::text,'USDC'::text,6,8453,'0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'::text), ('USD Coin'::text,'USDC'::text,6,42161,'0xaf88d065e77c8cC2239327C5EDb3A432268e5831'::text), ('Tether USD'::text,'USDT'::text,6,1,'0xdAC17F958D2ee523a2206206994597C13D831ec7'::text), ('Tether USD'::text,'USDT'::text,6,10,'0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'::text), ('Tether USD'::text,'USDT'::text,18,56,'0x55d398326f99059fF775485246999027B3197955'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'::text)) asset_data(assetname, symbol, decimals, domainid, address)
        ), netted_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)) AS day,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_volume,
            avg((((i.settlement_timestamp)::double precision - (i.origin_timestamp)::double precision) / (3600)::double precision)) AS netting_avg_time_in_hrs,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS netting_protocol_revenue,
            count(i.id) AS netting_total_intents,
            avg(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_avg_intent_size
           FROM (((public.intents i
             LEFT JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((inv.id IS NULL) AND (i.status = 'SETTLED_AND_COMPLETED'::public.intent_status) AND (i.hub_status <> 'DISPATCHED_UNSUPPORTED'::public.intent_status))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)))
        ), netted_final AS (
         SELECT netted_raw.day,
            netted_raw.netting_volume,
            netted_raw.netting_avg_intent_size,
            netted_raw.netting_protocol_revenue,
            netted_raw.netting_total_intents,
            netted_raw.netting_avg_time_in_hrs
           FROM netted_raw
        ), settled_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)) AS day,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS avg_discounts_by_mm,
            sum((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS discounts_by_mm,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision)))) AS avg_rewards_by_invoice,
            sum(((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) - (((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision)))) AS rewards_for_invoices,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS volume_settled_by_mm,
            count(i.id) AS total_intents_by_mm,
            avg((((i.hub_settlement_enqueued_timestamp)::double precision - (i.hub_added_timestamp)::double precision) / (3600)::double precision)) AS avg_time_in_hrs,
            round(avg((inv.hub_settlement_epoch - inv.hub_invoice_entry_epoch)), 0) AS avg_discount_epoch,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS protocol_revenue_mm
           FROM (((public.intents i
             JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((i.status = 'SETTLED_AND_COMPLETED'::public.intent_status) AND (i.hub_status = ANY (ARRAY['DISPATCHED'::public.intent_status, 'SETTLED'::public.intent_status])))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)))
        ), settled_final AS (
         SELECT settled_raw.day,
            settled_raw.volume_settled_by_mm,
            settled_raw.protocol_revenue_mm,
            settled_raw.total_intents_by_mm,
            settled_raw.discounts_by_mm,
            settled_raw.avg_discounts_by_mm,
            settled_raw.rewards_for_invoices,
            settled_raw.avg_rewards_by_invoice,
            settled_raw.avg_time_in_hrs AS avg_settlement_time_in_hrs_by_mm,
            (((settled_raw.discounts_by_mm / settled_raw.volume_settled_by_mm) * (365)::double precision) * (100)::double precision) AS apy,
            settled_raw.avg_discount_epoch AS avg_discount_epoch_by_mm
           FROM settled_raw
        )
 SELECT COALESCE(n.day, s.day) AS day,
    n.netting_volume,
    n.netting_avg_intent_size,
    n.netting_protocol_revenue,
    n.netting_total_intents,
    n.netting_avg_time_in_hrs,
    s.volume_settled_by_mm,
    s.total_intents_by_mm,
    s.discounts_by_mm,
    s.avg_discounts_by_mm,
    s.rewards_for_invoices,
    s.avg_rewards_by_invoice,
    s.avg_settlement_time_in_hrs_by_mm,
    s.apy,
    s.avg_discount_epoch_by_mm,
    (COALESCE(n.netting_volume, (0)::double precision) + COALESCE(s.volume_settled_by_mm, (0)::double precision)) AS total_volume,
    (COALESCE(n.netting_total_intents, (0)::bigint) + COALESCE(s.total_intents_by_mm, (0)::bigint)) AS total_intents,
    (COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) AS total_protocol_revenue,
    ((COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) + COALESCE(s.discounts_by_mm, (0)::double precision)) AS total_rebalancing_fee
   FROM (netted_final n
     FULL JOIN settled_final s ON ((n.day = s.day)))
  WITH NO DATA;


-- Grant permissions back
GRANT SELECT ON public.intents TO reader;
GRANT SELECT ON public.intents TO query;

