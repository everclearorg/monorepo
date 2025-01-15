-- migrate:up

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE FUNCTION public.table_exists(table_name TEXT, schema_name TEXT) RETURNS BOOLEAN
    LANGUAGE plpgsql
AS $$
DECLARE
    table_count INT;
BEGIN
    EXECUTE format('SELECT COUNT(table_name) FROM information_schema.tables
        WHERE table_schema = ''%s'' AND table_name LIKE ''%s''', schema_name, table_name) INTO table_count;

    return table_count > 0;
END;
$$;

CREATE FUNCTION shadow.set_timestamp_and_latency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
            NEW.timestamp := CURRENT_TIMESTAMP;
            NEW.latency := NEW.timestamp - NEW.block_timestamp;
            RETURN NEW;
        END;
    $$;

CREATE FUNCTION public.create_shadow_mat_view(shadow_table_name TEXT, view_name TEXT) RETURNS VOID
    LANGUAGE plpgsql
AS $$
DECLARE
    rec record;
    view_columns TEXT := '';
    add_comma BOOLEAN := FALSE;
BEGIN
    FOR rec IN (SELECT * FROM information_schema.columns WHERE table_schema = 'shadow' AND table_name = shadow_table_name) LOOP
        IF (add_comma) THEN
            view_columns := view_columns || ', ';
        END IF;
        view_columns := view_columns || 'shadow_table.' || rec.column_name;
        add_comma := TRUE;
    END LOOP;

    EXECUTE format('DROP MATERIALIZED VIEW IF EXISTS public.%s', view_name);
    EXECUTE format('CREATE MATERIALIZED VIEW public.%s AS SELECT %s FROM shadow.%s as shadow_table WITH NO DATA', view_name, view_columns, shadow_table_name);
    EXECUTE format('REFRESH MATERIALIZED VIEW public.%s', view_name);
    EXECUTE format('SELECT cron.schedule(''* * * * *'', ''REFRESH MATERIALIZED VIEW public.%s;'')', view_name);
END;
$$;

DO $$
BEGIN
    IF (NOT public.table_exists('closedepochsprocessed%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.closedepochsprocessed_fa915858_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data___last_closed_epoch_processed bigint,
            data___ticker_hash character varying(66),
            CONSTRAINT closedepochsprocessed_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;

    IF (NOT public.table_exists('depositenqueued%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.depositenqueued_2f2b1630_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data___amount numeric(78,0),
            data___domain integer,
            data___epoch bigint,
            data___intent_id character varying(66),
            data___ticker_hash character varying(66),
            CONSTRAINT depositenqueued_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;

    IF (NOT public.table_exists('depositprocessed%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.depositprocessed_ffe546d6_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data___amount_and_rewards numeric(78,0),
            data___domain bigint,
            data___epoch bigint,
            data___intent_id character varying(66),
            data___ticker_hash character varying(66),
            CONSTRAINT depositprocessed_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;

    IF (NOT public.table_exists('finddepositdomain%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.finddepositdomain_2744076b_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data__amount numeric(78,0),
            data__amount_and_rewards numeric(78,0),
            data__destinations jsonb,
            data__highest_liquidity_destination numeric(78,0),
            data__intent_id character varying(66),
            data__is_deposit boolean,
            data__liquidity_in_destinations jsonb,
            data__origin bigint,
            data__selected_destination bigint,
            data__ticker_hash character varying(66),
            CONSTRAINT finddepositdomain_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;

    IF (NOT public.table_exists('findinvoicedomain%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.findinvoicedomain_e0b68ef7_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data__amount_after_discount numeric(78,0),
            data__amount_to_be_discoutned numeric(78,0),
            data__current_epoch bigint,
            data__discount_dbps integer,
            data__domain bigint,
            data__entry_epoch bigint,
            data__invoice_amount numeric(78,0),
            data__invoice_intent_id character varying(66),
            data__invoice_owner character varying(66),
            data__liquidity numeric(78,0),
            data__rewards_for_depositors numeric(78,0),
            data__selected_domain bigint,
            data__selected_liquidity numeric(78,0),
            data__ticker_hash character varying(66),
            CONSTRAINT findinvoicedomain_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;

    IF (NOT public.table_exists('invoiceenqueued%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.invoiceenqueued_81d2714b_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data___amount numeric(78,0),
            data___entry_epoch bigint,
            data___intent_id character varying(66),
            data___owner character varying(66),
            data___ticker_hash character varying(66),
            CONSTRAINT invoiceenqueued_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;

    IF (NOT public.table_exists('matchdeposit%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.matchdeposit_883a2568_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data__deposit_intent_id character varying(66),
            data__deposit_purchase_power numeric(78,0),
            data__deposit_rewards numeric(78,0),
            data__discount_dbps integer,
            data__domain bigint,
            data__invoice_amount numeric(78,0),
            data__invoice_intent_id character varying(66),
            data__invoice_owner character varying(66),
            data__match_count numeric(78,0),
            data__remaining_amount numeric(78,0),
            data__selected_amount_after_discount numeric(78,0),
            data__selected_amount_to_be_discounted numeric(78,0),
            data__selected_rewards_for_depositors numeric(78,0),
            data__ticker_hash character varying(66),
            CONSTRAINT matchdeposit_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;

    IF (NOT public.table_exists('settledeposit%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.settledeposit_488e0804_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data__amount numeric(78,0),
            data__amount_after_fees numeric(78,0),
            data__amount_and_rewards numeric(78,0),
            data__destinations jsonb,
            data__input_asset character varying(66),
            data__intent_id character varying(66),
            data__is_deposit boolean,
            data__is_settlement boolean,
            data__origin bigint,
            data__output_asset character varying(66),
            data__rewards numeric(78,0),
            data__selected_destination bigint,
            CONSTRAINT settledeposit_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;

    IF (NOT public.table_exists('settlementenqueued%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.settlementenqueued_49194ff9_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data___amount numeric(78,0),
            data___asset character varying(66),
            data___domain bigint,
            data___entry_epoch bigint,
            data___intent_id character varying(66),
            data___owner character varying(66),
            data___update_virtual_balance boolean,
            CONSTRAINT settlementenqueued_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;

    IF (NOT public.table_exists('settlementqueueprocessed%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.settlementqueueprocessed_17786ebb_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data___amount bigint,
            data___domain bigint,
            data___message_id character varying(66),
            data___quote numeric(78,0),
            CONSTRAINT settlementqueueprocessed_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;

    IF (NOT public.table_exists('settlementsent%', 'shadow')) THEN
        CREATE TABLE IF NOT EXISTS shadow.settlementsent_dac85f08_73f6f386
        (
            address character varying(66) NOT NULL,
            block_hash character varying(66) NOT NULL,
            block_number bigint NOT NULL,
            block_timestamp timestamp NOT NULL,
            chain character varying(20) NOT NULL,
            block_log_index bigint,
            name character varying(66),
            network character varying(20) NOT NULL,
            topic_0 character varying(66) NOT NULL,
            topic_1 character varying(66),
            topic_2 character varying(66),
            topic_3 character varying(66),
            transaction_hash character varying(66) NOT NULL,
            transaction_index bigint NOT NULL,
            transaction_log_index bigint NOT NULL,
            data__current_epoch bigint,
            data__intent_ids jsonb,
            CONSTRAINT settlementsent_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index)
        );
    END IF;
END $$;

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
        'invoiceenqueued',
        'matchdeposit',
        'settledeposit',
        'settlementenqueued',
        'settlementqueueprocessed',
        'settlementsent'
    ];
    event_selectors TEXT[][] := ARRAY[
        'fa915858',
        '2f2b1630',
        'ffe546d6',
        '2744076b',
        'e0b68ef7',
        '81d2714b',
        '883a2568',
        '488e0804',
        '49194ff9',
        '17786ebb',
        'dac85f08'
    ];
    event_selector TEXT;
    export_id TEXT;
    export_ids TEXT[] := ARRAY[
        '1e576179',
        'e6c5ebc0',
        '73f6f386'
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
            END IF;
        END LOOP;
        index := index + 1;
    END LOOP;
END $$;

-- migrate:down

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
        'invoiceenqueued',
        'matchdeposit',
        'settledeposit',
        'settlementenqueued',
        'settlementqueueprocessed',
        'settlementsent'
    ];
    event_selectors TEXT[][] := ARRAY[
        [ 'fa915858', '' ],
        [ '2f2b1630', '' ],
        [ 'ffe546d6', '' ],
        [ '57b7ed66', '2744076b' ],
        [ 'e0b68ef7', '' ],
        [ '81d2714b', '' ],
        [ '883a2568', '' ],
        [ 'f8268691', '488e0804' ],
        [ '49194ff9', '' ],
        [ '17786ebb', '' ],
        [ 'dac85f08', '' ]
    ];
    export_id TEXT;
    export_ids TEXT[] := ARRAY[
        '1c70dbeb',
        'e6c5ebc0',
        '1e576179',
        '73f6f386'
    ];
    index INT := 1;
    sub_index INT;
BEGIN
    FOREACH table_name IN ARRAY table_names LOOP
        EXECUTE format('SELECT cron.unschedule(jobid) FROM cron.job WHERE command = ''REFRESH MATERIALIZED VIEW public.%s;''', table_name);
        IF (public.table_exists(table_name, 'public')) THEN
            EXECUTE format('DROP TABLE IF EXISTS public.%s', table_name);
        ELSE
            EXECUTE format('DROP MATERIALIZED VIEW IF EXISTS public.%s', table_name);
        END IF;

        FOR sub_index IN 1..ARRAY_LENGTH(event_selectors, 2) LOOP
            FOREACH export_id IN ARRAY export_ids LOOP
                shadow_table_name := format('%s_%s_%s', table_name, event_selectors[index][sub_index], export_id);
                IF (public.table_exists(shadow_table_name, 'shadow')) THEN
                    EXECUTE format('DROP TRIGGER IF EXISTS %s_copy_data_trigger ON shadow.%s', table_name, shadow_table_name);
                    EXECUTE format('DROP TRIGGER IF EXISTS %s_set_timestamp_and_latency ON shadow.%s', table_name, shadow_table_name);
                END IF;
            END LOOP;
        END LOOP;
        index := index + 1;
    END LOOP;
END $$;

DO $$
DECLARE
    table_name TEXT;
    table_names TEXT[] := ARRAY[
        'closedepochsprocessed',
        'depositenqueued',
        'depositprocessed',
        'finddepositdomain',
        'findinvoicedomain',
        'invoiceenqueued',
        'matchdeposit',
        'settledeposit',
        'settlementenqueued',
        'settlementqueueprocessed',
        'settlementsent'
    ];
    event_selectors TEXT[][] := ARRAY[
        'fa915858',
        '2f2b1630',
        'ffe546d6',
        '2744076b',
        'e0b68ef7',
        '81d2714b',
        '883a2568',
        '488e0804',
        '49194ff9',
        '17786ebb',
        'dac85f08'
    ];
    export_id TEXT;
    export_ids TEXT[] := ARRAY[
        '73f6f386'
    ];
    index INT := 1;
BEGIN
    FOREACH table_name IN ARRAY table_names LOOP
        FOREACH export_id IN ARRAY export_ids LOOP
            EXECUTE format('DROP TABLE IF EXISTS shadow.%s_%s_%s', table_name, event_selectors[index], export_id);
        END LOOP;
        index := index + 1;
    END LOOP;
END $$;

DROP FUNCTION IF EXISTS public.table_exists(table_name TEXT, schema_name TEXT);
DROP FUNCTION IF EXISTS public.create_shadow_mat_view(shadow_table_name TEXT, view_name TEXT);
DROP FUNCTION IF EXISTS shadow.set_timestamp_and_latency();
DROP FUNCTION IF EXISTS shadow.copy_shadow_data();

