-- migrate:up

DO $$
BEGIN
    IF NOT EXISTS (SELECT * FROM pg_roles WHERE rolname = 'sol-ingestor') THEN
        CREATE ROLE "sol-ingestor" WITH
            LOGIN
            NOSUPERUSER
            NOINHERIT
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            NOBYPASSRLS;
        ALTER ROLE "sol-ingestor" SET search_path TO solana;
    END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS solana;
GRANT ALL ON SCHEMA solana TO "sol-ingestor";

CREATE TABLE IF NOT EXISTS solana.solana_spoke_instructions
(
    id text NOT NULL,
    block_slot bigint,
    block_hash text,
    block_timestamp bigint,
    tx_signature text,
    tx_status bigint,
    tx_index bigint,
    tx_fee bigint,
    tx_err text,
    index bigint,
    parent_index bigint,
    accounts text,
    data text,
    program text,
    program_id text,
    instruction_type text,
    params text,
    parsed text,
    CONSTRAINT solana_spoke_instructions_pkey PRIMARY KEY (id)
);

ALTER TABLE solana.solana_spoke_instructions OWNER to "sol-ingestor";

CREATE OR REPLACE FUNCTION public.base58_decode(base58_str TEXT) RETURNS numeric AS $$
DECLARE
	alphabet TEXT := '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
	c CHAR(1);
	p INT;
	res numeric;
BEGIN
	res := 0;
	FOR i IN 1..char_length(base58_str) LOOP
		c := substring(base58_str FROM i FOR 1);
		p := position(c IN alphabet);
		IF p = 0 THEN
			RAISE 'Illegal base58 character ''%''', c;
		END IF;
		res := (res * 58) + (p - 1);
	END LOOP;
	
	RETURN res;
END;$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION public.to_hex(n NUMERIC) RETURNS TEXT AS $$
DECLARE
    b INT;
    res TEXT := '';
BEGIN
    WHILE n > 0 LOOP
        b := n % 256;
        res := lpad(to_hex(b), 2, '0') || res;
        n := (n - b) / 256;
    END LOOP;
    RETURN res;
END;$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION public.reverse_bytes(hex_str TEXT) RETURNS TEXT AS $$
DECLARE
    reversed TEXT := '';
BEGIN
    FOR i IN 0..(length(hex_str) / 2 - 1) LOOP
        reversed := substr(hex_str, i * 2 + 1, 2) || reversed;
    END LOOP;
    RETURN reversed;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.to_int(hex_str TEXT) RETURNS INT AS $$
BEGIN
    RETURN CAST(CAST(('x' || hex_str) AS bit(32)) AS INT);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.to_bigint(hex_str TEXT) RETURNS BIGINT AS $$
BEGIN
    RETURN CAST(CAST(('x' || hex_str) AS bit(64)) AS BIGINT);
END;
$$ LANGUAGE plpgsql;

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

CREATE OR REPLACE FUNCTION public.parse_and_insert_new_intent_cpi_event(hex_data TEXT, rec record) RETURNS BOOLEAN AS $$
DECLARE
    intent_id TEXT;
    message_id TEXT;
    initiator TEXT;
    receiver TEXT;
    input_asset TEXT;
    output_asset TEXT;
    normalized_amount BIGINT;
    max_fee INT;
    origin_domain INT;
    nonce BIGINT;
    ttl BIGINT;
    timestamp BIGINT;
    destination_count INT;
    destinations VARCHAR(66)[];
    data_length INT;
    data TEXT;
	pos INT := 33;
	i INT;
BEGIN
	intent_id := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	message_id := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	initiator := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	receiver := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	input_asset := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	output_asset := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	normalized_amount := to_bigint(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
	pos := pos + 16;
	max_fee := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
	pos := pos + 8;
	origin_domain := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
	pos := pos + 8;
	nonce := to_bigint(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
	pos := pos + 16;
	ttl := to_bigint(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
	pos := pos + 16;
	timestamp := to_bigint(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
	pos := pos + 16;
	destination_count := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
	pos := pos + 8;


	FOR i IN 0..(destination_count - 1) LOOP
		destinations[i] := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
		pos := pos + 8;
	END LOOP;

	data_length := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
	pos := pos + 8;

	data := '0x' || SUBSTRING(hex_data, pos, data_length);

	INSERT INTO public.origin_intents(
		id,
		queue_idx,
		message_id,
		receiver,
		input_asset,
		output_asset,
		amount,
		max_fee,
		origin,
		nonce,
		data,
		transaction_hash,
		"timestamp",
		block_number,
		tx_origin,
		tx_nonce,
		auto_id,
		gas_limit,
		gas_price,
		status,
		initiator,
		ttl,
		destinations
	)
	VALUES (
		intent_id,
		0,
		message_id,
		receiver,
		input_asset,
		output_asset,
		normalized_amount,
		max_fee,
		origin_domain,
		nonce,
		data,
		'',
		timestamp,
		rec.block_slot,
		'',
		0,
		0,
		rec.tx_fee,
		1,
		'DISPATCHED',
		initiator,
		ttl,
		destinations
	)
	ON CONFLICT (id)
	DO UPDATE SET
		queue_idx = EXCLUDED.queue_idx,
		message_id = EXCLUDED.message_id,
		receiver = EXCLUDED.receiver,
		input_asset = EXCLUDED.input_asset,
		output_asset = EXCLUDED.output_asset,
		amount = EXCLUDED.amount,
		max_fee = EXCLUDED.max_fee,
		origin = EXCLUDED.origin,
		nonce = EXCLUDED.nonce,
		data = EXCLUDED.data,
		transaction_hash = EXCLUDED.transaction_hash,
		"timestamp" = EXCLUDED."timestamp",
		block_number = EXCLUDED.block_number,
		tx_origin = EXCLUDED.tx_origin,
		tx_nonce = EXCLUDED.tx_nonce,
		auto_id = EXCLUDED.auto_id,
		gas_limit = EXCLUDED.gas_limit,
		gas_price = EXCLUDED.gas_price,
		status = EXCLUDED.status,
		initiator = EXCLUDED.initiator,
		ttl = EXCLUDED.ttl,
		destinations = EXCLUDED.destinations;

    RETURN TRUE;
END;$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION public.parse_and_insert_settled_cpi_event(hex_data TEXT, rec record) RETURNS BOOLEAN AS $$
DECLARE
    intent_id TEXT;
    recipient TEXT;
    asset TEXT;
    amount BIGINT;
    domain INT;
	pos INT := 33;
BEGIN
	intent_id := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	recipient := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	asset := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	amount := to_bigint(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
	pos := pos + 16;
	domain := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
	pos := pos + 8;

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
		amount,
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
		'SETTLED'
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

-- migrate:down

DROP TRIGGER process_cpi_events_trigger ON solana.solana_spoke_instructions;

DROP FUNCTION IF EXISTS public.parse_and_insert_settled_cpi_event(hex_data TEXT, rec record);
DROP FUNCTION IF EXISTS public.parse_and_insert_new_intent_cpi_event(hex_data TEXT, rec record);
DROP FUNCTION IF EXISTS public.parse_and_insert_cpi_event(rec record);
DROP FUNCTION IF EXISTS public.process_cpi_events();
DROP FUNCTION IF EXISTS public.to_bigint(hex_str TEXT);
DROP FUNCTION IF EXISTS public.to_int(hex_str TEXT);
DROP FUNCTION IF EXISTS public.reverse_bytes(hex_str TEXT);
DROP FUNCTION IF EXISTS public.to_hex(n NUMERIC);
DROP FUNCTION IF EXISTS public.base58_decode(base58_str TEXT);

