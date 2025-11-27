-- migrate:up

CREATE OR REPLACE FUNCTION public.parse_and_insert_cpi_event(rec record) RETURNS BOOLEAN AS $$
DECLARE
    hex_data TEXT;
    expected_cpi_disc TEXT := 'e445a52e51cb9a1d';
    new_intent_disc TEXT := '1263e45a565b315d';
    settled_disc TEXT := '75cfc4aec5c80b43';
    delivered_disc TEXT := 'aadd51debc47162f';
    intent_filled_disc TEXT := '97e5c05b34bba821';
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
    ELSIF ivent_disc = intent_filled_disc THEN
        RETURN parse_and_insert_intent_filled_cpi_event(hex_data, rec);
    END IF;

    RETURN FALSE;
END;$$
    LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION public.parse_and_insert_intent_filled_cpi_event(hex_data TEXT, rec record) RETURNS BOOLEAN AS $$
DECLARE
    intent_id TEXT;
    message_id TEXT;
    solver TEXT;
    receiver TEXT;
    amount_out NUMERIC;
    initiator TEXT;
    input_asset TEXT;
    output_asset TEXT;
    origin_domain INT;
    nonce NUMERIC;
    timestamp NUMERIC;
    ttl NUMERIC;
    amount NUMERIC;
    amount_out_min NUMERIC;
    destination_count INT;
    destinations VARCHAR(66)[];
    data_length INT;
    data TEXT;
    pos INT := 33;
    i INT;
BEGIN
    -- Parse IntentFilledEvent fields
    intent_id := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64;
    message_id := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64;
    solver := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64;
    receiver := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64;
    amount_out := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
    pos := pos + 16;
    
    -- Parse EVMIntent struct fields
    initiator := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64;
    -- Skip intent.receiver (we already have the receiver from IntentFilledEvent)
    pos := pos + 64;
    input_asset := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64;
    output_asset := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64;
    origin_domain := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
    pos := pos + 8;
    nonce := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
    pos := pos + 16;
    timestamp := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
    pos := pos + 16;
    ttl := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
    pos := pos + 16;
    amount := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 32)));
    pos := pos + 32;
    amount_out_min := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 32)));
    pos := pos + 32;
    destination_count := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
    pos := pos + 8;

    FOR i IN 0..(destination_count - 1) LOOP
		destinations[i] := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
        pos := pos + 8;
    END LOOP;

    data_length := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
    pos := pos + 8;
    data := '0x' || SUBSTRING(hex_data, pos, data_length);

    INSERT INTO public.destination_intents(
        id,
        queue_idx,
        message_id,
        initiator,
        receiver,
        solver,
        input_asset,
        output_asset,
        amount,
        fee,
        origin,
        filled_domain,
        nonce,
        data,
        transaction_hash,
        "timestamp",
        block_number,
        tx_origin,
        tx_nonce,
        gas_limit,
        gas_price,
        status,
        destinations,
        ttl,
        amount_out_min,
        amount_out
    )
    VALUES (
        intent_id,
        0,
        message_id,
        initiator,
        receiver,
        solver,
        input_asset,
        output_asset,
        amount,
        '0',
        origin_domain,
        '1399811149',
        nonce,
        data,
        rec.tx_signature,
        rec.block_timestamp,
        rec.block_slot,
        solver,
        0,
        rec.tx_fee,
        1,
        'FILLED',
        destinations,
        ttl,
        amount_out_min,
        amount_out
    )
    ON CONFLICT (id)
    DO UPDATE SET
        message_id = EXCLUDED.message_id,
        initiator = EXCLUDED.initiator,
        receiver = EXCLUDED.receiver,
        solver = EXCLUDED.solver,
        input_asset = EXCLUDED.input_asset,
        output_asset = EXCLUDED.output_asset,
        amount = EXCLUDED.amount,
        fee = EXCLUDED.fee,
        origin = EXCLUDED.origin,
        filled_domain = EXCLUDED.filled_domain,
        nonce = EXCLUDED.nonce,
        data = EXCLUDED.data,
        transaction_hash = EXCLUDED.transaction_hash,
        "timestamp" = EXCLUDED."timestamp",
        block_number = EXCLUDED.block_number,
        tx_origin = EXCLUDED.tx_origin,
        tx_nonce = EXCLUDED.tx_nonce,
        gas_limit = EXCLUDED.gas_limit,
        gas_price = EXCLUDED.gas_price,
        status = EXCLUDED.status,
        destinations = EXCLUDED.destinations,
        ttl = EXCLUDED.ttl,
        amount_out_min = EXCLUDED.amount_out_min,
        amount_out = EXCLUDED.amount_out;

    RETURN TRUE;
END;$$
    LANGUAGE PLPGSQL;

-- migrate:down

DROP FUNCTION IF EXISTS public.parse_and_insert_intent_filled_cpi_event(hex_data TEXT, rec record);

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
