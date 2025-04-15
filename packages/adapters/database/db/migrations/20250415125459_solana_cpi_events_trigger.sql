-- migrate:up

DROP TRIGGER process_cpi_events_trigger ON solana.solana_spoke_instructions;
DROP FUNCTION IF EXISTS public.process_cpi_events();

CREATE OR REPLACE FUNCTION public.process_cpi_events() RETURNS TRIGGER AS $$
DECLARE
	res BOOLEAN;
BEGIN
    IF NEW.tx_status = 1 AND NEW.tx_err = 'null' THEN
        res := parse_and_insert_cpi_event(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert CPI event for transaction %', NEW.tx_signature;
        END IF;
    END IF;

    RETURN NEW;
END;$$
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = solana, public;

CREATE TRIGGER process_cpi_events_trigger BEFORE INSERT OR UPDATE ON solana.solana_spoke_instructions
FOR EACH ROW EXECUTE FUNCTION public.process_cpi_events();

-- migrate:down

DROP TRIGGER process_cpi_events_trigger ON solana.solana_spoke_instructions;
DROP FUNCTION IF EXISTS public.process_cpi_events();

CREATE OR REPLACE FUNCTION public.process_cpi_events() RETURNS TRIGGER AS $$
DECLARE
	res BOOLEAN;
BEGIN
    IF NEW.accounts = '["3RaCiTPYkAQPg61JVdfbxSp9V4tsw8ZuARtFMdQfNaMp"]'
           AND NEW.tx_status = 1 AND NEW.tx_err = 'null' THEN
        res := parse_and_insert_cpi_event(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert CPI event for transaction %', NEW.tx_signature;
        END IF;
    END IF;

    RETURN NEW;
END;$$
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = solana, public;

CREATE TRIGGER process_cpi_events_trigger BEFORE INSERT OR UPDATE ON solana.solana_spoke_instructions
FOR EACH ROW EXECUTE FUNCTION public.process_cpi_events();

