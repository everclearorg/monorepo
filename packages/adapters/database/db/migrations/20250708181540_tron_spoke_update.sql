-- migrate:up

DROP TRIGGER process_tron_gateway_events_trigger ON tron.tron_gateway_raw_logs;
DROP FUNCTION IF EXISTS public.process_tron_gateway_events();

CREATE OR REPLACE FUNCTION public.process_tron_spoke_events() RETURNS TRIGGER AS $$
DECLARE
    res BOOLEAN;
BEGIN
    -- IntentAdded event
    IF NEW.topics LIKE '0xefe68281645929e2db845c5b42e12f7c73485fb5f18737b7b29379da006fa5f7%' THEN
        res := add_new_tron_origin_intent(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron origin intent, transaction %', NEW.transaction_hash;
        END IF;
    -- IntentFilled event
    ELSIF NEW.topics LIKE '0x11cd513bfc9cb4365a2f38d87c35bea962f9cea1c1fe9c8a9a9488df7d507275%' THEN
        res := add_new_tron_destination_intent(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron destination intent, transaction %', NEW.transaction_hash;
        END IF;
    -- Settled event
    ELSIF NEW.topics LIKE '0x4190759d37d5cfe7a1a70e06ec7508a05d12fd9cb76f353da1c9e028e5a48dcf%' THEN
        res := add_new_tron_settlement(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron settlement, transaction %', NEW.transaction_hash;
        END IF;
    -- IntentQueueProcessed event
    ELSIF NEW.topics LIKE '0x43a52e9a77f317a192970b363b14ece56df243fe0dd94f459f63029d657efec3%' THEN
        res := add_new_tron_intent_message(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron intent message, transaction %', NEW.transaction_hash;
        END IF;
    -- FillQueueProcessed event
    ELSIF NEW.topics LIKE '0x5e3a5b80dcf8e0fb984fe128ed0db507a86cc0674c4f5980f83b129b2cfdc69e%' THEN
        res := add_new_tron_fill_message(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron fill message, transaction %', NEW.transaction_hash;
        END IF;
    END IF;

    RETURN NEW;
END;$$
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = tron, public;

CREATE OR REPLACE TRIGGER process_tron_spoke_events_trigger BEFORE INSERT OR UPDATE ON tron.tron_spoke_raw_logs
FOR EACH ROW EXECUTE FUNCTION public.process_tron_spoke_events();

-- migrate:down

CREATE OR REPLACE FUNCTION public.process_tron_spoke_events() RETURNS TRIGGER AS $$
DECLARE
    res BOOLEAN;
BEGIN
    -- IntentAdded event
    IF NEW.topics LIKE '0xefe68281645929e2db845c5b42e12f7c73485fb5f18737b7b29379da006fa5f7%' THEN
        res := add_new_tron_origin_intent(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron origin intent, transaction %', NEW.transaction_hash;
        END IF;
    -- IntentFilled event
    ELSIF NEW.topics LIKE '0x11cd513bfc9cb4365a2f38d87c35bea962f9cea1c1fe9c8a9a9488df7d507275%' THEN
        res := add_new_tron_destination_intent(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron destination intent, transaction %', NEW.transaction_hash;
        END IF;
    -- Settled event
    ELSIF NEW.topics LIKE '0x4190759d37d5cfe7a1a70e06ec7508a05d12fd9cb76f353da1c9e028e5a48dcf%' THEN
        res := add_new_tron_settlement(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron settlement, transaction %', NEW.transaction_hash;
        END IF;
    END IF;

    RETURN NEW;
END;$$
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = tron, public;

CREATE OR REPLACE TRIGGER process_tron_spoke_events_trigger BEFORE INSERT OR UPDATE ON tron.tron_spoke_raw_logs
FOR EACH ROW EXECUTE FUNCTION public.process_tron_spoke_events();

CREATE OR REPLACE FUNCTION public.process_tron_gateway_events() RETURNS TRIGGER AS $$
DECLARE
    res BOOLEAN;
BEGIN
    -- IntentQueueProcessed event
    IF NEW.topics LIKE '0x43a52e9a77f317a192970b363b14ece56df243fe0dd94f459f63029d657efec3%' THEN
        res := add_new_tron_intent_message(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron intent message, transaction %', NEW.transaction_hash;
        END IF;
    -- FillQueueProcessed event
    ELSIF NEW.topics LIKE '0x5e3a5b80dcf8e0fb984fe128ed0db507a86cc0674c4f5980f83b129b2cfdc69e%' THEN
        res := add_new_tron_fill_message(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron fill message, transaction %', NEW.transaction_hash;
        END IF;
    END IF;

    RETURN NEW;
END;$$
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = tron, public;

CREATE TRIGGER process_tron_gateway_events_trigger BEFORE INSERT OR UPDATE ON tron.tron_gateway_raw_logs
FOR EACH ROW EXECUTE FUNCTION public.process_tron_gateway_events();

