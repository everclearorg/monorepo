-- migrate:up
DROP MATERIALIZED VIEW IF EXISTS public.invoices_with_shadow_data;
DROP MATERIALIZED VIEW IF EXISTS public.intents_with_shadow_data;

DO $$
DECLARE
    shadow_table_name TEXT;
    table_name TEXT;
    table_names TEXT[] := ARRAY[
        'closedepochsprocessed',
        'depositenqueued',
        'depositprocessed',
        'finddepositdomain',
        'findinvoicedomain',
        'intentprocessed',
        'invoiceenqueued',
        'matchdeposit',
        'settledeposit',
        'settlementenqueued',
        'settlementqueueprocessed',
        'settlementsent'
    ];
    event_selector TEXT;
    event_selectors TEXT[][] := ARRAY[
        'fa915858',
        '2f2b1630',
        'ffe546d6',
        '2744076b',
        'e0b68ef7',
        'ad83ca5a',
        '81d2714b',
        '883a2568',
        '488e0804',
        '49194ff9',
        '17786ebb',
        'dac85f08'
    ];
    export_id TEXT;
    export_ids TEXT[] := ARRAY[
        'e367cbc6',
        '9d29eee8'
    ];
    index INT := 1;
BEGIN
    FOREACH table_name IN ARRAY table_names LOOP
        event_selector := event_selectors[index];
        FOREACH export_id IN ARRAY export_ids LOOP
            shadow_table_name := format('%s_%s_%s', table_name, event_selector, export_id);
            IF (public.table_exists(shadow_table_name, 'shadow')) THEN
                EXECUTE format('ALTER TABLE shadow.%s ADD COLUMN IF NOT EXISTS timestamp timestamp', shadow_table_name);
                EXECUTE format('ALTER TABLE shadow.%s ADD COLUMN IF NOT EXISTS latency interval', shadow_table_name);
                EXECUTE format('CREATE TRIGGER %s_set_timestamp_and_latency BEFORE INSERT ON shadow.%s FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency()',
                    table_name, shadow_table_name);
                PERFORM public.create_shadow_mat_view(shadow_table_name, table_name);
                EXECUTE format('CREATE INDEX %s_timestamp_idx ON public.%s(timestamp)', table_name, table_name);
                EXECUTE format('GRANT SELECT ON public.%s TO reader', table_name);
                EXECUTE format('GRANT SELECT ON public.%s TO query', table_name);
            END IF;
        END LOOP;
        index := index + 1;
    END LOOP;
END $$;

CREATE MATERIALIZED VIEW public.invoices_with_shadow_data AS
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
    hub_intents.settlement_epoch AS hub_settlement_epoch,
    COALESCE(findinvoicedomain.data__ticker_hash, matchdeposit.data__ticker_hash) AS ticker_hash,
    findinvoicedomain.data__amount_after_discount AS find_invoice_amount_after_discount,
    findinvoicedomain.data__amount_to_be_discoutned AS find_invoice_amount_to_be_discoutned,
    findinvoicedomain.data__current_epoch AS find_invoice_current_epoch,
    findinvoicedomain.data__discount_dbps AS find_invoice_discount_dbps,
    findinvoicedomain.data__entry_epoch AS find_invoice_entry_epoch,
    findinvoicedomain.data__invoice_amount AS find_invoice_invoice_amount,
    findinvoicedomain.data__invoice_owner AS find_invoice_invoice_owner,
    findinvoicedomain.data__rewards_for_depositors AS find_invoice_rewards_for_depositors,
    findinvoicedomain.data__domain AS find_invoice_current_domain,
    findinvoicedomain.data__selected_domain AS find_invoice_selected_domain,
    findinvoicedomain.data__liquidity AS find_invoice_liquidity,
    findinvoicedomain.data__selected_liquidity AS find_invoice_selected_liquidity,
    matchdeposit.data__deposit_intent_id AS match_deposit_intent_id,
    matchdeposit.data__deposit_purchase_power AS match_deposit_purchase_power,
    matchdeposit.data__deposit_rewards AS match_deposit_rewards,
    matchdeposit.data__discount_dbps AS match_deposit_discount_dbps,
    matchdeposit.data__domain AS match_deposit_domain,
    matchdeposit.data__invoice_amount AS match_deposit_invoice_amount,
    matchdeposit.data__invoice_owner AS match_deposit_invoice_owner,
    matchdeposit.data__match_count AS match_deposit_match_count,
    matchdeposit.data__remaining_amount AS match_deposit_remaining_amount,
    matchdeposit.data__selected_amount_after_discount AS match_deposit_selected_amount_after_discount,
    matchdeposit.data__selected_amount_to_be_discounted AS match_deposit_selected_amount_to_be_discounted,
    matchdeposit.data__selected_rewards_for_depositors AS match_deposit_selected_rewards_for_depositors
   FROM public.hub_invoices
    LEFT JOIN public.origin_intents ON origin_intents.id = hub_invoices.intent_id
    LEFT JOIN public.hub_intents ON origin_intents.id = hub_intents.id
    LEFT JOIN public.findinvoicedomain as findinvoicedomain ON origin_intents.id = findinvoicedomain.data__invoice_intent_id
    LEFT JOIN public.matchdeposit as matchdeposit ON origin_intents.id = matchdeposit.data__invoice_intent_id
  WITH NO DATA;

CREATE MATERIALIZED VIEW public.intents_with_shadow_data AS
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
    genStatus(origin_intents.status, hub_intents.status, settlement_intents.status, hasCallData(origin_intents.data)) AS status,
    hasCallData(origin_intents.data) AS has_calldata,
    hub_intents.auto_id AS hub_auto_id,
    finddepositdomain.data__amount AS find_deposit_amount,
    finddepositdomain.data__amount_and_rewards AS find_deposit_amount_and_rewards,
    finddepositdomain.data__destinations AS find_deposit_destinations,
    finddepositdomain.data__highest_liquidity_destination AS find_deposit_highest_liquidity_destination,
    finddepositdomain.data__liquidity_in_destinations AS find_deposit_liquidity_in_destinations,
    finddepositdomain.data__origin AS find_deposit_origin,
    finddepositdomain.data__selected_destination AS find_deposit_selected_destination,
    finddepositdomain.data__ticker_hash AS ticker_hash,
    finddepositdomain.data__is_deposit AS is_deposit,
    settledeposit.data__amount AS settle_deposit_amount,
    settledeposit.data__amount_after_fees AS settle_deposit_amount_after_fees,
    settledeposit.data__amount_and_rewards AS settle_deposit_amount_and_rewards,
    settledeposit.data__destinations AS settle_deposit_destinations,
    settledeposit.data__input_asset AS settle_deposit_input_asset,
    settledeposit.data__is_settlement AS settle_deposit_is_settlement,
    settledeposit.data__origin AS settle_deposit_origin,
    settledeposit.data__output_asset AS settle_deposit_output_asset,
    settledeposit.data__rewards AS settle_deposit_rewards,
    settledeposit.data__selected_destination AS settle_deposit_selected_destination
  FROM public.origin_intents
    LEFT JOIN public.destination_intents ON origin_intents.id = destination_intents.id
    LEFT JOIN public.settlement_intents ON origin_intents.id = settlement_intents.id
    LEFT JOIN public.hub_intents ON origin_intents.id = hub_intents.id
    LEFT JOIN public.finddepositdomain as finddepositdomain ON origin_intents.id = finddepositdomain.data__intent_id
    LEFT JOIN public.settledeposit as settledeposit ON origin_intents.id = settledeposit.data__intent_id
  WITH NO DATA;

REFRESH MATERIALIZED VIEW public.invoices_with_shadow_data;
REFRESH MATERIALIZED VIEW public.intents_with_shadow_data;
SELECT cron.schedule('* * * * *', $$REFRESH MATERIALIZED VIEW public.invoices_with_shadow_data;$$);
SELECT cron.schedule('* * * * *', $$REFRESH MATERIALIZED VIEW public.intents_with_shadow_data;$$);

GRANT SELECT ON public.invoices_with_shadow_data TO reader;
GRANT SELECT ON public.invoices_with_shadow_data TO query;
GRANT SELECT ON public.intents_with_shadow_data TO reader;
GRANT SELECT ON public.intents_with_shadow_data TO query;

-- migrate:down

SELECT cron.unschedule(jobid) FROM cron.job WHERE command = 'REFRESH MATERIALIZED VIEW public.invoices_with_shadow_data;';
SELECT cron.unschedule(jobid) FROM cron.job WHERE command = 'REFRESH MATERIALIZED VIEW public.intents_with_shadow_data;';
DROP MATERIALIZED VIEW IF EXISTS public.invoices_with_shadow_data;
DROP MATERIALIZED VIEW IF EXISTS public.intents_with_shadow_data;

DO $$
DECLARE
    table_name TEXT;
    table_names TEXT[] := ARRAY[
        'closedepochsprocessed',
        'depositenqueued',
        'depositprocessed',
        'finddepositdomain',
        'findinvoicedomain',
        'intentprocessed',
        'invoiceenqueued',
        'matchdeposit',
        'settledeposit',
        'settlementenqueued',
        'settlementqueueprocessed',
        'settlementsent'
    ];
BEGIN
    FOREACH table_name IN ARRAY table_names LOOP
        EXECUTE format('SELECT cron.unschedule(jobid) FROM cron.job WHERE command = ''REFRESH MATERIALIZED VIEW public.%s;''', table_name);
        EXECUTE format('DROP MATERIALIZED VIEW IF EXISTS public.%s', table_name);
    END LOOP;
END $$;

