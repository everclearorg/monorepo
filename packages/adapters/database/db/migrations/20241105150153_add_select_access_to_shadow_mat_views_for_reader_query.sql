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
        EXECUTE format('GRANT SELECT ON public.%s TO reader', name);
        EXECUTE format('GRANT SELECT ON public.%s TO query', name);
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
        EXECUTE format('REVOKE SELECT ON public.%s FROM reader', name);
        EXECUTE format('REVOKE SELECT ON public.%s FROM query', name);
    END LOOP;
END $$;

