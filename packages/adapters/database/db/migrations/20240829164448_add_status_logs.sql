-- migrate:up

DO $$
DECLARE
    table_name TEXT;
    intent_types TEXT[] := ARRAY['destination', 'hub', 'origin'];
BEGIN
    FOREACH table_name IN ARRAY intent_types
    LOOP
        -- Create status log table
        EXECUTE format('
            CREATE TABLE public.%I_intents_status_log (
                id SERIAL PRIMARY KEY,
                %I_intent_id CHARACTER(66) NOT NULL,
                new_status public.intent_status,
                changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            )', table_name, table_name);

        -- Grant permissions
        EXECUTE format('
            GRANT SELECT ON public.%I_intents_status_log TO reader', table_name);
        EXECUTE format('
            GRANT SELECT ON public.%I_intents_status_log TO query', table_name);

        -- Create trigger function
        EXECUTE format('
            CREATE OR REPLACE FUNCTION log_%I_intent_status_change()
            RETURNS TRIGGER AS $func$
            BEGIN
                IF OLD.status IS DISTINCT FROM NEW.status THEN
                    INSERT INTO public.%I_intents_status_log
                        (%I_intent_id, new_status, changed_at)
                    VALUES
                        (NEW.id, NEW.status, CURRENT_TIMESTAMP);
                END IF;
                RETURN NEW;
            END;
            $func$ LANGUAGE plpgsql', table_name, table_name, table_name);

        -- Create trigger
        EXECUTE format('
            CREATE TRIGGER %I_intent_status_change_trigger
            AFTER UPDATE OF status ON public.%I_intents
            FOR EACH ROW
            EXECUTE FUNCTION log_%I_intent_status_change()', table_name, table_name, table_name);
    END LOOP;
END $$;

-- Create queue_type log table
CREATE TABLE public.queues_type_log (
    id SERIAL PRIMARY KEY,
    queue_id CHARACTER(66) NOT NULL,
    new_type public.queue_type NOT NULL,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create trigger function for queue_type changes
CREATE OR REPLACE FUNCTION log_queue_type_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.type IS DISTINCT FROM NEW.type THEN
        INSERT INTO public.queues_type_log
            (queue_id, new_type, changed_at)
        VALUES
            (NEW.id, NEW.type, CURRENT_TIMESTAMP);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for queue_type changes
CREATE TRIGGER queue_type_change_trigger
AFTER UPDATE OF type ON public.queues
FOR EACH ROW
EXECUTE FUNCTION log_queue_type_change();

-- migrate:down
DO $$
DECLARE
    table_name TEXT;
    intent_types TEXT[] := ARRAY['destination', 'hub', 'origin'];
BEGIN
    FOREACH table_name IN ARRAY intent_types
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I_intent_status_change_trigger ON public.%I_intents', table_name, table_name);
        EXECUTE format('DROP FUNCTION IF EXISTS log_%I_intent_status_change()', table_name);
        EXECUTE format('DROP TABLE IF EXISTS public.%I_intents_status_log', table_name);
    END LOOP;

    DROP TRIGGER IF EXISTS queue_type_change_trigger ON public.queues;
    DROP FUNCTION IF EXISTS log_queue_type_change();
END $$;

DROP TABLE IF EXISTS public.queues_type_log;