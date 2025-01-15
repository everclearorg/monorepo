-- migrate:up

DO $$
DECLARE
    table_name TEXT;
    table_names TEXT[] := ARRAY[ 'lock_position', 'user' ];
BEGIN
    FOREACH table_name IN ARRAY table_names LOOP
        IF (public.table_exists(table_name, 'tokenomics')) THEN
            EXECUTE format('DROP TRIGGER IF EXISTS %s_set_timestamp_and_latency ON tokenomics.%s', table_name, table_name);
            EXECUTE format('DROP INDEX IF EXISTS %s_timestamp_idx', table_name);
            EXECUTE format('ALTER TABLE tokenomics.%s DROP COLUMN IF EXISTS insert_timestamp', table_name);
            EXECUTE format('ALTER TABLE tokenomics.%s DROP COLUMN IF EXISTS latency', table_name);
        END IF;
    END LOOP;
END $$;

-- migrate:down

