-- migrate:up

CREATE OR REPLACE FUNCTION public.parse_and_insert_delivered_cpi_event(hex_data TEXT, rec record) RETURNS BOOLEAN AS $$
DECLARE
    intent_id TEXT;
    recipient TEXT;
    asset TEXT;
    domain INT;
    pos INT := 33;
BEGIN
    domain := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
    pos := pos + 8;
    intent_id := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64 + 64; -- skip amount
    asset := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64;
    recipient := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64;

    INSERT INTO public.settlement_intents(
        id,
        amount,
        asset,
        recipient,
        domain,
        transaction_hash,
        "timestamp",
        block_number,
        tx_origin,
        tx_nonce,
        auto_id,
        gas_limit,
        gas_price,
        return_data,
        status
    )
    VALUES (
        intent_id,
        0,
        asset,
        recipient,
        domain,
        '',
        rec.block_timestamp,
        rec.block_slot,
        '',
        0,
        0,
        rec.tx_fee,
        1,
        '0x',
        'DELIVERED'
    )
    ON CONFLICT (id)
        DO UPDATE SET
            amount = EXCLUDED.amount,
            asset = EXCLUDED.asset,
            recipient = EXCLUDED.recipient,
            domain = EXCLUDED.domain,
            transaction_hash = EXCLUDED.transaction_hash,
            "timestamp" = EXCLUDED."timestamp",
            block_number = EXCLUDED.block_number,
            tx_origin = EXCLUDED.tx_origin,
            tx_nonce = EXCLUDED.tx_nonce,
            auto_id = EXCLUDED.auto_id,
            gas_limit = EXCLUDED.gas_limit,
            gas_price = EXCLUDED.gas_price,
            return_data = EXCLUDED.return_data,
            status = EXCLUDED.status;

    RETURN TRUE;
END;$$
    LANGUAGE PLPGSQL;

DROP TRIGGER process_cpi_events_trigger ON solana.solana_spoke_instructions;

DROP FUNCTION IF EXISTS public.process_cpi_events();
DROP FUNCTION IF EXISTS public.parse_and_insert_cpi_event(rec record);

CREATE OR REPLACE FUNCTION public.parse_and_insert_cpi_event(rec record) RETURNS BOOLEAN AS $$
DECLARE
    hex_data TEXT;
    expected_cpi_disc TEXT := 'e445a52e51cb9a1d';
    new_intent_disc TEXT := '1263e45a565b315d';
    settled_disc TEXT := '75cfc4aec5c80b43';
    delivered_disc TEXT := 'aadd51debc47162f';
    cpi_disc TEXT;
    ivent_disc TEXT;
    pos INT := 1;
BEGIN
    hex_data := to_hex(base58_decode(rec.data));

    cpi_disc := SUBSTRING(hex_data, pos, 16);
    pos := pos + 16;
    IF cpi_disc != expected_cpi_disc THEN
        RAISE WARNING 'invalid CPI discriminator %, expected %', cpi_disc, expected_cpi_disc;
        RETURN FALSE;
    END IF;

    ivent_disc := SUBSTRING(hex_data, pos, 16);
    pos := pos + 16;
    IF ivent_disc = new_intent_disc THEN
        RETURN parse_and_insert_new_intent_cpi_event(hex_data, rec);
    ELSIF ivent_disc = settled_disc THEN
        RETURN parse_and_insert_settled_cpi_event(hex_data, rec);
    ELSIF ivent_disc = delivered_disc THEN
        RETURN parse_and_insert_delivered_cpi_event(hex_data, rec);
    END IF;

    RETURN FALSE;
END;$$
    LANGUAGE PLPGSQL;

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

-- migrate:down

DROP TRIGGER process_cpi_events_trigger ON solana.solana_spoke_instructions;

DROP FUNCTION IF EXISTS public.process_cpi_events();
DROP FUNCTION IF EXISTS public.parse_and_insert_cpi_event(rec record);

CREATE OR REPLACE FUNCTION public.parse_and_insert_cpi_event(rec record) RETURNS BOOLEAN AS $$
DECLARE
    hex_data TEXT;
    expected_cpi_disc TEXT := 'e445a52e51cb9a1d';
    new_intent_disc TEXT := '1263e45a565b315d';
    settled_disc TEXT := '75cfc4aec5c80b43';
    cpi_disc TEXT;
    ivent_disc TEXT;
	pos INT := 1;
BEGIN
    hex_data := to_hex(base58_decode(rec.data));

	cpi_disc := SUBSTRING(hex_data, pos, 16);
	pos := pos + 16;
	IF cpi_disc != expected_cpi_disc THEN
		RAISE WARNING 'invalid CPI discriminator %, expected %', cpi_disc, expected_cpi_disc;
		RETURN FALSE;
	END IF;

	ivent_disc := SUBSTRING(hex_data, pos, 16);
	pos := pos + 16;
	IF ivent_disc = new_intent_disc THEN
		RETURN parse_and_insert_new_intent_cpi_event(hex_data, rec);
	ELSIF ivent_disc = settled_disc THEN
		RETURN parse_and_insert_settled_cpi_event(hex_data, rec);
	END IF;

    RETURN FALSE;
END;$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION public.process_cpi_events() RETURNS TRIGGER AS $$
DECLARE
	res BOOLEAN;
BEGIN
    IF NEW.accounts = '["HoUvmo3eC8gwMknYvyhto8S8iT8xZryUdErfXhawoHeG"]'
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

DROP FUNCTION IF EXISTS public.parse_and_insert_delivered_cpi_event(hex_data TEXT, rec record);


