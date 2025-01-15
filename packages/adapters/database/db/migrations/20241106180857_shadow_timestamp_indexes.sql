-- migrate:up

DO $$
DECLARE
    name TEXT;
    names TEXT[] := ARRAY[
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
BEGIN
    FOREACH name IN ARRAY names LOOP
        EXECUTE format('CREATE INDEX %s_timestamp_idx ON public.%s(timestamp)', name, name);
    END LOOP;
END $$;

-- migrate:down

DO $$
DECLARE
    name TEXT;
    names TEXT[] := ARRAY[
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
BEGIN
    FOREACH name IN ARRAY names LOOP
        EXECUTE format('DROP INDEX %s_timestamp_idx', name);
    END LOOP;
END $$;

