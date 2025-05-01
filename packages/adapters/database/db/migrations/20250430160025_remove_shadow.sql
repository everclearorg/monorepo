-- migrate:up

DO $$
DECLARE
    table_name TEXT;
    table_names TEXT[] := ARRAY[
        'invoices_with_shadow_data',
        'intents_with_shadow_data',
        'invoice_enqueued_not_settled',
        'deposit_enqueued_not_processed',
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
    END LOOP;
END $$;

DROP SCHEMA IF EXISTS shadow CASCADE;
DROP FUNCTION IF EXISTS public.create_shadow_mat_view(shadow_table_name TEXT, view_name TEXT);

-- migrate:down

-- not restoring shadow stuff
-- can be restored later if needed with forward migration though no shadow service continuation is expected
