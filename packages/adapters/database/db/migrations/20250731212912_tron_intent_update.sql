-- migrate:up

CREATE SCHEMA crypto;
CREATE EXTENSION pgcrypto WITH SCHEMA crypto;

CREATE OR REPLACE FUNCTION base58_encode(input_bytes BYTEA) RETURNS TEXT
    LANGUAGE plpgsql
    AS $$
DECLARE
    alphabet TEXT := '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    base INT := 58;
    digits INT[] := ARRAY[0];
    carry INT;
    i INT;
    j INT;
    digit INT;
    result TEXT := '';
BEGIN
    IF input_bytes IS NULL OR length(input_bytes) = 0 THEN
        RETURN '';
    END IF;

    FOR i IN 1..length(input_bytes) LOOP
        -- Shift all digits left by 8 bits
        FOR j IN 1..array_length(digits, 1) LOOP
            digits[j] := digits[j] << 8;
        END LOOP;

        -- Add current byte
        digits[1] := digits[1] + get_byte(input_bytes, i-1);

        -- Handle carries
        carry := 0;
        FOR j IN 1..array_length(digits, 1) LOOP
            digits[j] := digits[j] + carry;
            carry := digits[j] / base;
            digits[j] := digits[j] % base;
        END LOOP;

        -- Add new digits if carry remains
        WHILE carry > 0 LOOP
            digits := array_append(digits, carry % base);
            carry := carry / base;
        END LOOP;
    END LOOP;

    -- Add leading zeros for each leading zero byte
    FOR i IN 1..length(input_bytes) LOOP
        IF get_byte(input_bytes, i - 1) = 0 AND i < length(input_bytes) THEN
            digits := array_append(digits, 0);
        ELSE
            EXIT;
        END IF;
    END LOOP;

    -- Convert digits to base58 string
    FOR i IN REVERSE array_length(digits, 1)..1 LOOP
        result := result || substr(alphabet, digits[i] + 1, 1);
    END LOOP;

    RETURN result;
END;$$;

CREATE OR REPLACE FUNCTION get_tron_address(evm_address TEXT) RETURNS TEXT
    LANGUAGE plpgsql
    AS $$
DECLARE
    address_with_prefix TEXT;
    address_bytes BYTEA;
    hash0 BYTEA;
    hash1 BYTEA;
    checksum BYTEA;
    final_bytes BYTEA;
BEGIN
    -- Trim to 20-bytes hex string without '0x' prefix and add TRON address prefix
    address_with_prefix := '41' || lpad(regexp_replace(evm_address, '^0x?0*', ''), 40, '0');

    -- Convert to bytes
    address_bytes := decode(address_with_prefix, 'hex');

    -- Apply SHA256 twice for checksum
    hash0 := crypto.digest(address_bytes, 'sha256');
    hash1 := crypto.digest(hash0, 'sha256');

    -- Take first 4 bytes as checksum
    checksum := substring(hash1 FROM 1 FOR 4);

    -- Concatenate address bytes with checksum
    final_bytes := address_bytes || checksum;

    -- Encode to Base58
    RETURN base58_encode(final_bytes);
END$$;

CREATE TABLE tron.origin_intents
(
    id TEXT NOT NULL PRIMARY KEY,
    native_fee TEXT,
    token_fee TEXT,
    fee_adapter_initiator TEXT,
    order_id TEXT
);

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
    -- IntentWithFeesAdded event
    ELSIF NEW.topics LIKE '0x4cc03dfa265ccd4670a5059498b2551525947958b26b5e70f6a6dc62a950fd4e%' THEN
        res := add_new_tron_intent_with_fees(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron intent with fees, transaction %', NEW.transaction_hash;
        END IF;
    -- OrderCreated event
    ELSIF NEW.topics LIKE '0xc5929cfdbbc98a41855839bee1396d17ee4a149e40d5c324b6f4332655f5cffd%' THEN
        res := add_new_tron_order(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron order, transaction %', NEW.transaction_hash;
        END IF;
    END IF;

    RETURN NEW;
END;$$
LANGUAGE PLPGSQL
SECURITY DEFINER
SET search_path = tron, public;

CREATE OR REPLACE FUNCTION public.add_new_tron_origin_intent(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    origin_intent_id TEXT;
    queue_index NUMERIC;
    initiator TEXT;
    receiver TEXT;
    input_asset TEXT;
    output_asset TEXT;
    amount NUMERIC;
    max_fee INT;
    origin INT;
    nonce NUMERIC;
    ttl NUMERIC;
    timestamp NUMERIC;
    destination_count INT;
    destinations VARCHAR(66)[];
    data_length INT;
    data TEXT;
    pos INT := 3;
    i INT;
    queue_id TEXT = '728126428-0x494e54454e54';
    queue_rec RECORD;
    msg_id TEXT;
    msg_timestamp BIGINT;
    first_idx NUMERIC;
    last_idx NUMERIC;
    queue_size NUMERIC;
    fee_native TEXT;
    fee_token TEXT;
    origin_intent_initiator TEXT;
    origin_order_id TEXT;
BEGIN
    origin_intent_id := SUBSTRING(rec.topics, 68, 66);

    queue_index := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64 + 64;
    initiator := get_tron_address(SUBSTRING(rec.data, pos, 64));
    pos := pos + 64;
    receiver := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    input_asset := get_tron_address(SUBSTRING(rec.data, pos, 64));
    pos := pos + 64;
    output_asset := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    max_fee := to_int(SUBSTRING(rec.data, pos + 56, 8));
    pos := pos + 64;
    origin := to_int(SUBSTRING(rec.data, pos + 56, 8));
    pos := pos + 64;
    nonce := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    timestamp := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    ttl := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    amount := to_numeric(SUBSTRING(rec.data, pos + 32, 32));
    pos := pos + 64 + 64 + 64; -- Skip destination and data offsets
    destination_count := to_int(SUBSTRING(rec.data, pos + 56, 8));

    FOR i IN 0..(destination_count - 1) LOOP
        pos := pos + 64;
        destinations[i] := to_int(SUBSTRING(rec.data, pos + 56, 8));
    END LOOP;

    pos := pos + 64;
    data_length := to_int(SUBSTRING(rec.data, pos + 56, 8));

    pos := pos + 64;
    data := '0x' || SUBSTRING(rec.data, pos, data_length);

    SELECT native_fee, token_fee, fee_adapter_initiator, order_id
    INTO fee_native, fee_token, origin_intent_initiator, origin_order_id
    FROM tron.origin_intents
    WHERE id = origin_intent_id;

    INSERT INTO public.origin_intents(
        id,
        queue_idx,
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
        gas_limit,
        gas_price,
        status,
        initiator,
        ttl,
        destinations,
        native_fee,
        token_fee,
        fee_adapter_initiator,
        order_id
    )
    VALUES (
        origin_intent_id,
        queue_index,
        receiver,
        input_asset,
        output_asset,
        amount,
        max_fee,
        origin,
        nonce,
        data,
        SUBSTRING(rec.transaction_hash FROM 3),
        timestamp,
        rec.block_number,
        COALESCE(origin_intent_initiator, initiator),
        0,
        0,
        1,
        'ADDED',
        initiator,
        ttl,
        destinations,
        fee_native,
        fee_token,
        origin_intent_initiator,
        origin_order_id
    )
    ON CONFLICT (id)
    DO UPDATE SET
        queue_idx = EXCLUDED.queue_idx,
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
        gas_limit = EXCLUDED.gas_limit,
        gas_price = EXCLUDED.gas_price,
        status = EXCLUDED.status,
        initiator = EXCLUDED.initiator,
        ttl = EXCLUDED.ttl,
        destinations = EXCLUDED.destinations,
        native_fee = EXCLUDED.native_fee,
        token_fee = EXCLUDED.token_fee,
        fee_adapter_initiator = EXCLUDED.fee_adapter_initiator,
        order_id = EXCLUDED.order_id;

    SELECT message_id, message_timestamp INTO msg_id, msg_timestamp
    FROM tron.intent_queue
    WHERE queue_idx = queue_index;

    IF msg_id IS NOT NULL THEN
        UPDATE public.origin_intents
        SET message_id = msg_id,
            status = 'DISPATCHED'
        WHERE id = origin_intent_id;

        UPDATE public.messages
        SET intent_ids = array_append(intent_ids, origin_intent_id)
        WHERE id = msg_id
          AND NOT (origin_intent_id = ANY(intent_ids));
    END IF;

    SELECT * INTO queue_rec
    FROM public.queues
    WHERE id = queue_id;

    IF NOT FOUND THEN
        INSERT INTO public.queues(
            id,
            domain,
            size,
            first,
            last,
            type
        )
        VALUES (
            queue_id,
            '728126428',
            1,
            queue_index,
            queue_index,
            'INTENT'
        );
    ELSE
        IF msg_id IS NULL THEN
            first_idx := LEAST(queue_rec.first, queue_index);
            last_idx := GREATEST(queue_rec.last, queue_index);
            queue_size := 1 + last_idx - first_idx;

            UPDATE public.queues
            SET size = queue_size,
                first = first_idx,
                last = last_idx
            WHERE id = queue_id;
        ELSE
            first_idx := GREATEST(queue_rec.first, queue_index + 1);
            last_idx := GREATEST(queue_rec.last, queue_index);
            queue_size := 1 + last_idx - first_idx;

            UPDATE public.queues
            SET size = queue_size,
                first = first_idx,
                last = last_idx,
                last_processed = GREATEST(queue_rec.last_processed, msg_timestamp)
            WHERE id = queue_id;
        END IF;
    END IF;

    INSERT INTO tron.intent_queue(queue_idx, intent_id)
    VALUES (queue_index, origin_intent_id)
    ON CONFLICT (queue_idx)
    DO UPDATE SET intent_id = EXCLUDED.intent_id;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_destination_intent(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    destination_intent_id TEXT;
    solver TEXT;
    totalFeeDBPS NUMERIC;
    queue_index NUMERIC;
    initiator TEXT;
    receiver TEXT;
    input_asset TEXT;
    output_asset TEXT;
    amount NUMERIC;
    max_fee INT;
    origin INT;
    nonce NUMERIC;
    ttl NUMERIC;
    timestamp NUMERIC;
    destination_count INT;
    destinations VARCHAR(66)[];
    data_length INT;
    data TEXT;
    pos INT := 3;
    i INT;
    queue_id TEXT = '728126428-0x46494c4c';
    queue_rec RECORD;
    msg_id TEXT;
    first_idx NUMERIC;
    last_idx NUMERIC;
    queue_size NUMERIC;
    msg_timestamp BIGINT;
BEGIN
    destination_intent_id := SUBSTRING(rec.topics, 68, 66);
    solver := get_tron_address(SUBSTRING(rec.topics, 135, 66));

    totalFeeDBPS := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    queue_index := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64 + 64;
    initiator := get_tron_address(SUBSTRING(rec.data, pos, 64));
    pos := pos + 64;
    receiver := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    input_asset := get_tron_address(SUBSTRING(rec.data, pos, 64));
    pos := pos + 64;
    output_asset := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    max_fee := to_int(SUBSTRING(rec.data, pos + 56, 8));
    pos := pos + 64;
    origin := to_int(SUBSTRING(rec.data, pos + 56, 8));
    pos := pos + 64;
    nonce := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    timestamp := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    ttl := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    amount := to_numeric(SUBSTRING(rec.data, pos + 32, 32));
    pos := pos + 64 + 64 + 64; -- Skip destination and data offsets
    destination_count := to_int(SUBSTRING(rec.data, pos + 56, 8));

    FOR i IN 0..(destination_count - 1) LOOP
        pos := pos + 64;
        destinations[i] := to_int(SUBSTRING(rec.data, pos + 56, 8));
    END LOOP;

    pos := pos + 64;
    data_length := to_int(SUBSTRING(rec.data, pos + 56, 8));

    pos := pos + 64;
    data := '0x' || SUBSTRING(rec.data, pos, data_length);

    INSERT INTO public.destination_intents(
        id,
        queue_idx,
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
        max_fee,
        gas_limit,
        gas_price,
        status,
        destinations,
        ttl
    )
    VALUES (
        destination_intent_id,
        queue_index,
        initiator,
        receiver,
        solver,
        input_asset,
        output_asset,
        amount,
        totalFeeDBPS,
        origin,
        '728126428',
        nonce,
        data,
        SUBSTRING(rec.transaction_hash FROM 3),
        timestamp,
        rec.block_number,
        initiator,
        0,
        max_fee,
        0,
        1,
        'ADDED',
        destinations,
        ttl
    )
    ON CONFLICT (id)
    DO UPDATE SET
        queue_idx = EXCLUDED.queue_idx,
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
        max_fee = EXCLUDED.max_fee,
        gas_limit = EXCLUDED.gas_limit,
        gas_price = EXCLUDED.gas_price,
        status = EXCLUDED.status,
        destinations = EXCLUDED.destinations,
        ttl = EXCLUDED.ttl;

    SELECT message_id, message_timestamp INTO msg_id, msg_timestamp
    FROM tron.fill_queue
    WHERE queue_idx = queue_index;

    IF msg_id IS NOT NULL THEN
        UPDATE public.destination_intents
        SET message_id = msg_id,
            status = 'DISPATCHED'
        WHERE id = destination_intent_id;

        UPDATE public.messages
        SET intent_ids = array_append(intent_ids, destination_intent_id)
        WHERE id = msg_id
          AND NOT (destination_intent_id = ANY(intent_ids));
    END IF;

    SELECT * INTO queue_rec
    FROM public.queues
    WHERE id = queue_id;

    IF NOT FOUND THEN
        INSERT INTO public.queues(
            id,
            domain,
            size,
            first,
            last,
            type
        )
        VALUES (
            queue_id,
            '728126428',
            1,
            queue_index,
            queue_index,
            'FILL'
        );
    ELSE
        IF msg_id IS NULL THEN
            first_idx := LEAST(queue_rec.first, queue_index);
            last_idx := GREATEST(queue_rec.last, queue_index);
            queue_size := 1 + last_idx - first_idx;

            UPDATE public.queues
            SET size = queue_size,
                first = first_idx,
                last = last_idx
            WHERE id = queue_id;
        ELSE
            first_idx := GREATEST(queue_rec.first, queue_index + 1);
            last_idx := GREATEST(queue_rec.last, queue_index);
            queue_size := 1 + last_idx - first_idx;

            UPDATE public.queues
            SET size = queue_size,
                first = first_idx,
                last = last_idx,
                last_processed = GREATEST(queue_rec.last_processed, msg_timestamp)
            WHERE id = queue_id;
        END IF;
    END IF;

    INSERT INTO tron.fill_queue(queue_idx, intent_id)
    VALUES (queue_index, destination_intent_id)
    ON CONFLICT (queue_idx)
    DO UPDATE SET intent_id = EXCLUDED.intent_id;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_settlement(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    intent_id TEXT;
    recipient TEXT;
    asset TEXT;
    amount NUMERIC;
    pos INT := 3;
BEGIN
    intent_id := SUBSTRING(rec.topics, 68, 66);

    recipient := get_tron_address(SUBSTRING(rec.data, pos, 64));
    pos := pos + 64;
    asset := get_tron_address(SUBSTRING(rec.data, pos, 64));
    pos := pos + 64;
    amount := to_numeric(SUBSTRING(rec.data, pos + 32, 32));

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
        gas_limit,
        gas_price,
        status
    )
    VALUES (
        intent_id,
        amount,
        asset,
        recipient,
        '728126428',
        SUBSTRING(rec.transaction_hash FROM 3),
        rec.block_timestamp,
        rec.block_number,
        recipient,
        0,
        0,
        1,
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
        gas_limit = EXCLUDED.gas_limit,
        gas_price = EXCLUDED.gas_price,
        status = EXCLUDED.status;

    UPDATE public.origin_intents SET status = 'SETTLED' WHERE id = intent_id;
    UPDATE public.destination_intents SET status = 'SETTLED' WHERE id = intent_id;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_intent_message(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    msg_id TEXT;
    first_idx NUMERIC;
    last_idx NUMERIC;
    queue_size NUMERIC;
    quote NUMERIC;
    everclear_domain VARCHAR(66) = '25327';
    intent_ids VARCHAR(66)[] := ARRAY[]::VARCHAR(66)[];
    pos INT := 3;
    queue_id TEXT = '728126428-0x494e54454e54';
    queue_rec RECORD;
    origin_intent_id TEXT;
    i INT;
BEGIN
    msg_id := SUBSTRING(rec.topics, 68, 66);

    first_idx := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    last_idx := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    quote := to_numeric(SUBSTRING(rec.data, pos + 32, 32));

    FOR i IN first_idx..(last_idx - 1) LOOP
        SELECT intent_id INTO origin_intent_id
        FROM tron.intent_queue
        WHERE queue_idx = i;

        IF origin_intent_id IS NOT NULL THEN
            intent_ids := array_append(intent_ids, origin_intent_id);
        END IF;

        INSERT INTO tron.intent_queue as queue(queue_idx, message_id, message_timestamp)
        VALUES (i, msg_id, rec.block_timestamp)
        ON CONFLICT (queue_idx)
        DO UPDATE SET
            message_id = EXCLUDED.message_id,
            message_timestamp = EXCLUDED.message_timestamp;
    END LOOP;

    INSERT INTO public.messages(
        id,
        domain,
        type,
        quote,
        first,
        last,
        intent_ids,
        tx_origin,
        transaction_hash,
        "timestamp",
        block_number,
        tx_nonce,
        gas_price,
        gas_limit,
        message_status,
        origin_domain,
        destination_domain
    )
    VALUES (
        msg_id,
        '728126428',
        'INTENT',
        quote,
        first_idx,
        last_idx,
        intent_ids,
        '0x0000000000000000000000000000000000000000', -- Default tx_origin for gateway events
        SUBSTRING(rec.transaction_hash FROM 3),
        rec.block_timestamp,
        rec.block_number,
        0,
        1,
        0,
        'pending',
        '728126428',
        everclear_domain
    )
    ON CONFLICT (id)
    DO UPDATE SET
        domain = EXCLUDED.domain,
        type = EXCLUDED.type,
        quote = EXCLUDED.quote,
        first = EXCLUDED.first,
        last = EXCLUDED.last,
        intent_ids = EXCLUDED.intent_ids,
        tx_origin = EXCLUDED.tx_origin,
        transaction_hash = EXCLUDED.transaction_hash,
        "timestamp" = EXCLUDED."timestamp",
        block_number = EXCLUDED.block_number,
        tx_nonce = EXCLUDED.tx_nonce,
        gas_price = EXCLUDED.gas_price,
        gas_limit = EXCLUDED.gas_limit,
        message_status = EXCLUDED.message_status,
        origin_domain = EXCLUDED.origin_domain,
        destination_domain = EXCLUDED.destination_domain;

    UPDATE public.origin_intents SET message_id = msg_id, status = 'DISPATCHED' WHERE id = ANY(intent_ids);

    SELECT * INTO queue_rec
    FROM public.queues
    WHERE id = queue_id;

    IF FOUND THEN
        first_idx := GREATEST(queue_rec.first, last_idx);
        last_idx := GREATEST(queue_rec.last, last_idx - 1);
        queue_size := 1 + last_idx - first_idx;

        UPDATE public.queues
        SET size = queue_size,
            first = first_idx,
            last = last_idx,
            last_processed = GREATEST(queue_rec.last_processed, rec.block_timestamp)
        WHERE id = queue_id;
    END IF;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_fill_message(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    msg_id TEXT;
    first_idx NUMERIC;
    last_idx NUMERIC;
    queue_size NUMERIC;
    quote NUMERIC;
    everclear_domain VARCHAR(66) = '25327';
    intent_ids VARCHAR(66)[] := ARRAY[]::VARCHAR(66)[];
    pos INT := 3;
    queue_id TEXT = '728126428-0x46494c4c';
    queue_rec RECORD;
    fill_intent_id TEXT;
    i INT;
BEGIN
    msg_id := SUBSTRING(rec.topics, 68, 66);

    first_idx := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    last_idx := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    quote := to_numeric(SUBSTRING(rec.data, pos + 48, 16));

    FOR i IN first_idx..(last_idx - 1) LOOP
        SELECT intent_id INTO fill_intent_id
        FROM tron.fill_queue
        WHERE queue_idx = i;

        IF fill_intent_id IS NOT NULL THEN
            intent_ids := array_append(intent_ids, fill_intent_id);
        END IF;

        INSERT INTO tron.fill_queue(queue_idx, message_id, message_timestamp)
        VALUES (i, msg_id, rec.block_timestamp)
        ON CONFLICT (queue_idx)
        DO UPDATE SET
            message_id = EXCLUDED.message_id,
            message_timestamp = EXCLUDED.message_timestamp;
    END LOOP;

    INSERT INTO public.messages(
        id,
        domain,
        type,
        quote,
        first,
        last,
        intent_ids,
        tx_origin,
        transaction_hash,
        "timestamp",
        block_number,
        tx_nonce,
        gas_price,
        gas_limit,
        message_status,
        origin_domain,
        destination_domain
    )
    VALUES (
        msg_id,
        '728126428',
        'FILL',
        quote,
        first_idx,
        last_idx,
        intent_ids,
        '0x0000000000000000000000000000000000000000', -- Default tx_origin for gateway events
        SUBSTRING(rec.transaction_hash FROM 3),
        rec.block_timestamp,
        rec.block_number,
        0,
        1,
        0,
        'pending',
        '728126428',
        everclear_domain
    )
    ON CONFLICT (id)
    DO UPDATE SET
        domain = EXCLUDED.domain,
        type = EXCLUDED.type,
        quote = EXCLUDED.quote,
        first = EXCLUDED.first,
        last = EXCLUDED.last,
        intent_ids = EXCLUDED.intent_ids,
        tx_origin = EXCLUDED.tx_origin,
        transaction_hash = EXCLUDED.transaction_hash,
        "timestamp" = EXCLUDED."timestamp",
        block_number = EXCLUDED.block_number,
        tx_nonce = EXCLUDED.tx_nonce,
        gas_price = EXCLUDED.gas_price,
        gas_limit = EXCLUDED.gas_limit,
        message_status = EXCLUDED.message_status,
        origin_domain = EXCLUDED.origin_domain,
        destination_domain = EXCLUDED.destination_domain;

    UPDATE public.destination_intents SET message_id = msg_id, status = 'DISPATCHED' WHERE id = ANY(intent_ids);

    SELECT * INTO queue_rec
    FROM public.queues
    WHERE id = queue_id;

    IF FOUND THEN
        first_idx := GREATEST(queue_rec.first, last_idx);
        last_idx := GREATEST(queue_rec.last, last_idx - 1);
        queue_size := 1 + last_idx - first_idx;

        UPDATE public.queues
        SET size = queue_size,
            first = first_idx,
            last = last_idx,
            last_processed = GREATEST(queue_rec.last_processed, rec.block_timestamp)
        WHERE id = queue_id;
    END IF;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_intent_with_fees(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    intent_id TEXT;
    initiator TEXT;
    fee_token NUMERIC;
    fee_native NUMERIC;
    origin_intent RECORD;
    pos INT := 3;
BEGIN
    intent_id := SUBSTRING(rec.topics, 68, 66);
    initiator := get_tron_address(SUBSTRING(rec.topics, 135, 66));

    fee_token := to_numeric(SUBSTRING(rec.data, pos + 32, 32));
    pos := pos + 64;
    fee_native := to_numeric(SUBSTRING(rec.data, pos + 32, 32));

    SELECT * INTO origin_intent
    FROM public.origin_intents
    WHERE id = intent_id;

    IF FOUND THEN
        UPDATE public.origin_intents
        SET
            native_fee = fee_native,
            token_fee = fee_token,
            tx_origin = initiator,
            fee_adapter_initiator = initiator
        WHERE
            id = intent_id;
    ELSE
        INSERT INTO tron.origin_intents(
            id,
            native_fee,
            token_fee,
            fee_adapter_initiator
        )
        VALUES (
            intent_id,
            fee_native,
            fee_token,
            initiator
        )
        ON CONFLICT (id)
        DO UPDATE SET
            native_fee = EXCLUDED.native_fee,
            token_fee = EXCLUDED.token_fee,
            fee_adapter_initiator = EXCLUDED.fee_adapter_initiator;
    END IF;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_order(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    origin_order_id TEXT;
    intent_id TEXT;
    initiator TEXT;
    intent_count INT;
    origin_intent RECORD;
    pos INT := 195;
BEGIN
    origin_order_id := SUBSTRING(rec.topics, 68, 66);
    initiator := get_tron_address(SUBSTRING(rec.topics, 135, 66));

    intent_count := to_int(SUBSTRING(rec.data, pos + 56, 8));
    FOR i IN 1..intent_count LOOP
        pos := pos + 64;
        intent_id := '0x' || SUBSTRING(rec.data, pos, 64);

        SELECT * INTO origin_intent
        FROM public.origin_intents
        WHERE id = intent_id;

        IF FOUND THEN
            UPDATE public.origin_intents
            SET
                order_id = origin_order_id
            WHERE
                id = intent_id;
        ELSE
            INSERT INTO tron.origin_intents(
                id,
                order_id
            )
            VALUES (
                intent_id,
                origin_order_id
            );
        END IF;
    END LOOP;

    RETURN TRUE;
END;$$;

-- migrate:down

DROP EXTENSION pgcrypto;
DROP SCHEMA crypto;

DROP FUNCTION get_tron_address(evm_address TEXT);
DROP FUNCTION base58_encode(input_bytes BYTEA);

DROP TABLE tron.origin_intents;

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

DROP FUNCTION add_new_tron_intent_with_fees(rec record);
DROP FUNCTION add_new_tron_order(rec record);

CREATE OR REPLACE FUNCTION public.add_new_tron_origin_intent(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    origin_intent_id TEXT;
    queue_index NUMERIC;
    initiator TEXT;
    receiver TEXT;
    input_asset TEXT;
    output_asset TEXT;
    amount NUMERIC;
    max_fee INT;
    origin INT;
    nonce NUMERIC;
    ttl NUMERIC;
    timestamp NUMERIC;
    destination_count INT;
    destinations VARCHAR(66)[];
    data_length INT;
    data TEXT;
    pos INT := 3;
    i INT;
    queue_id TEXT = '728126428-0x494e54454e54';
    queue_rec RECORD;
    msg_id TEXT;
    msg_timestamp BIGINT;
    first_idx NUMERIC;
    last_idx NUMERIC;
    queue_size NUMERIC;
BEGIN
    origin_intent_id := SUBSTRING(rec.topics, 68, 66);

    queue_index := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64 + 64;
    initiator := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    receiver := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    input_asset := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    output_asset := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    max_fee := to_int(SUBSTRING(rec.data, pos + 56, 8));
    pos := pos + 64;
    origin := to_int(SUBSTRING(rec.data, pos + 56, 8));
    pos := pos + 64;
    nonce := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    timestamp := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    ttl := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    amount := to_numeric(SUBSTRING(rec.data, pos + 32, 32));
    pos := pos + 64 + 64 + 64; -- Skip destination and data offsets
    destination_count := to_int(SUBSTRING(rec.data, pos + 56, 8));

    FOR i IN 0..(destination_count - 1) LOOP
        pos := pos + 64;
        destinations[i] := to_int(SUBSTRING(rec.data, pos + 56, 8));
    END LOOP;

    pos := pos + 64;
    data_length := to_int(SUBSTRING(rec.data, pos + 56, 8));

    pos := pos + 64;
    data := '0x' || SUBSTRING(rec.data, pos, data_length);

    INSERT INTO public.origin_intents(
        id,
        queue_idx,
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
        gas_limit,
        gas_price,
        status,
        initiator,
        ttl,
        destinations
    )
    VALUES (
        origin_intent_id,
        queue_index,
        receiver,
        input_asset,
        output_asset,
        amount,
        max_fee,
        origin,
        nonce,
        data,
        rec.transaction_hash,
        timestamp,
        rec.block_number,
        initiator,
        0,
        0,
        1,
        'ADDED',
        initiator,
        ttl,
        destinations
    )
    ON CONFLICT (id)
    DO UPDATE SET
        queue_idx = EXCLUDED.queue_idx,
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
        gas_limit = EXCLUDED.gas_limit,
        gas_price = EXCLUDED.gas_price,
        status = EXCLUDED.status,
        initiator = EXCLUDED.initiator,
        ttl = EXCLUDED.ttl,
        destinations = EXCLUDED.destinations;

    SELECT message_id, message_timestamp INTO msg_id, msg_timestamp
    FROM tron.intent_queue
    WHERE queue_idx = queue_index;

    IF msg_id IS NOT NULL THEN
        UPDATE public.origin_intents
        SET message_id = msg_id,
            status = 'DISPATCHED'
        WHERE id = origin_intent_id;

        UPDATE public.messages
        SET intent_ids = array_append(intent_ids, origin_intent_id)
        WHERE id = msg_id
          AND NOT (origin_intent_id = ANY(intent_ids));
    END IF;

    SELECT * INTO queue_rec
    FROM public.queues
    WHERE id = queue_id;

    IF NOT FOUND THEN
        INSERT INTO public.queues(
            id,
            domain,
            size,
            first,
            last,
            type
        )
        VALUES (
            queue_id,
            '728126428',
            1,
            queue_index,
            queue_index,
            'INTENT'
        );
    ELSE
        IF msg_id IS NULL THEN
            first_idx := LEAST(queue_rec.first, queue_index);
            last_idx := GREATEST(queue_rec.last, queue_index);
            queue_size := 1 + last_idx - first_idx;

            UPDATE public.queues
            SET size = queue_size,
                first = first_idx,
                last = last_idx
            WHERE id = queue_id;
        ELSE
            first_idx := GREATEST(queue_rec.first, queue_index + 1);
            last_idx := GREATEST(queue_rec.last, queue_index);
            queue_size := 1 + last_idx - first_idx;

            UPDATE public.queues
            SET size = queue_size,
                first = first_idx,
                last = last_idx,
                last_processed = GREATEST(queue_rec.last_processed, msg_timestamp)
            WHERE id = queue_id;
        END IF;
    END IF;

    INSERT INTO tron.intent_queue(queue_idx, intent_id)
    VALUES (queue_index, origin_intent_id)
    ON CONFLICT (queue_idx)
    DO UPDATE SET intent_id = EXCLUDED.intent_id;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_destination_intent(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    destination_intent_id TEXT;
    solver TEXT;
    totalFeeDBPS NUMERIC;
    queue_index NUMERIC;
    initiator TEXT;
    receiver TEXT;
    input_asset TEXT;
    output_asset TEXT;
    amount NUMERIC;
    max_fee INT;
    origin INT;
    nonce NUMERIC;
    ttl NUMERIC;
    timestamp NUMERIC;
    destination_count INT;
    destinations VARCHAR(66)[];
    data_length INT;
    data TEXT;
    pos INT := 3;
    i INT;
    queue_id TEXT = '728126428-0x46494c4c';
    queue_rec RECORD;
    msg_id TEXT;
    first_idx NUMERIC;
    last_idx NUMERIC;
    queue_size NUMERIC;
    msg_timestamp BIGINT;
BEGIN
    destination_intent_id := SUBSTRING(rec.topics, 68, 66);
    solver := SUBSTRING(rec.topics, 135, 66);

    totalFeeDBPS := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    queue_index := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64 + 64;
    initiator := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    receiver := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    input_asset := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    output_asset := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    max_fee := to_int(SUBSTRING(rec.data, pos + 56, 8));
    pos := pos + 64;
    origin := to_int(SUBSTRING(rec.data, pos + 56, 8));
    pos := pos + 64;
    nonce := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    timestamp := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    ttl := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    amount := to_numeric(SUBSTRING(rec.data, pos + 32, 32));
    pos := pos + 64 + 64 + 64; -- Skip destination and data offsets
    destination_count := to_int(SUBSTRING(rec.data, pos + 56, 8));

    FOR i IN 0..(destination_count - 1) LOOP
        pos := pos + 64;
        destinations[i] := to_int(SUBSTRING(rec.data, pos + 56, 8));
    END LOOP;

    pos := pos + 64;
    data_length := to_int(SUBSTRING(rec.data, pos + 56, 8));

    pos := pos + 64;
    data := '0x' || SUBSTRING(rec.data, pos, data_length);

    INSERT INTO public.destination_intents(
        id,
        queue_idx,
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
        max_fee,
        gas_limit,
        gas_price,
        status,
        destinations,
        ttl
    )
    VALUES (
        destination_intent_id,
        queue_index,
        initiator,
        receiver,
        solver,
        input_asset,
        output_asset,
        amount,
        totalFeeDBPS,
        origin,
        '728126428',
        nonce,
        data,
        rec.transaction_hash,
        timestamp,
        rec.block_number,
        initiator,
        0,
        max_fee,
        0,
        1,
        'ADDED',
        destinations,
        ttl
    )
    ON CONFLICT (id)
    DO UPDATE SET
        queue_idx = EXCLUDED.queue_idx,
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
        max_fee = EXCLUDED.max_fee,
        gas_limit = EXCLUDED.gas_limit,
        gas_price = EXCLUDED.gas_price,
        status = EXCLUDED.status,
        destinations = EXCLUDED.destinations,
        ttl = EXCLUDED.ttl;

    SELECT message_id, message_timestamp INTO msg_id, msg_timestamp
    FROM tron.fill_queue
    WHERE queue_idx = queue_index;

    IF msg_id IS NOT NULL THEN
        UPDATE public.destination_intents
        SET message_id = msg_id,
            status = 'DISPATCHED'
        WHERE id = destination_intent_id;

        UPDATE public.messages
        SET intent_ids = array_append(intent_ids, destination_intent_id)
        WHERE id = msg_id
          AND NOT (destination_intent_id = ANY(intent_ids));
    END IF;

    SELECT * INTO queue_rec
    FROM public.queues
    WHERE id = queue_id;

    IF NOT FOUND THEN
        INSERT INTO public.queues(
            id,
            domain,
            size,
            first,
            last,
            type
        )
        VALUES (
            queue_id,
            '728126428',
            1,
            queue_index,
            queue_index,
            'FILL'
        );
    ELSE
        IF msg_id IS NULL THEN
            first_idx := LEAST(queue_rec.first, queue_index);
            last_idx := GREATEST(queue_rec.last, queue_index);
            queue_size := 1 + last_idx - first_idx;

            UPDATE public.queues
            SET size = queue_size,
                first = first_idx,
                last = last_idx
            WHERE id = queue_id;
        ELSE
            first_idx := GREATEST(queue_rec.first, queue_index + 1);
            last_idx := GREATEST(queue_rec.last, queue_index);
            queue_size := 1 + last_idx - first_idx;

            UPDATE public.queues
            SET size = queue_size,
                first = first_idx,
                last = last_idx,
                last_processed = GREATEST(queue_rec.last_processed, msg_timestamp)
            WHERE id = queue_id;
        END IF;
    END IF;

    INSERT INTO tron.fill_queue(queue_idx, intent_id)
    VALUES (queue_index, destination_intent_id)
    ON CONFLICT (queue_idx)
    DO UPDATE SET intent_id = EXCLUDED.intent_id;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_settlement(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    intent_id TEXT;
    recipient TEXT;
    asset TEXT;
    amount NUMERIC;
    pos INT := 3;
BEGIN
    intent_id := SUBSTRING(rec.topics, 68, 66);

    recipient := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    asset := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    amount := to_numeric(SUBSTRING(rec.data, pos + 32, 32));

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
        gas_limit,
        gas_price,
        status
    )
    VALUES (
        intent_id,
        amount,
        asset,
        recipient,
        '728126428',
        rec.transaction_hash,
        rec.block_timestamp,
        rec.block_number,
        recipient,
        0,
        0,
        1,
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
        gas_limit = EXCLUDED.gas_limit,
        gas_price = EXCLUDED.gas_price,
        status = EXCLUDED.status;

    UPDATE public.origin_intents SET status = 'SETTLED' WHERE id = intent_id;
    UPDATE public.destination_intents SET status = 'SETTLED' WHERE id = intent_id;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_intent_message(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    msg_id TEXT;
    first_idx NUMERIC;
    last_idx NUMERIC;
    queue_size NUMERIC;
    quote NUMERIC;
    everclear_domain VARCHAR(66) = '25327';
    intent_ids VARCHAR(66)[] := ARRAY[]::VARCHAR(66)[];
    pos INT := 3;
    queue_id TEXT = '728126428-0x494e54454e54';
    queue_rec RECORD;
    origin_intent_id TEXT;
    i INT;
BEGIN
    msg_id := SUBSTRING(rec.topics, 68, 66);

    first_idx := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    last_idx := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    quote := to_numeric(SUBSTRING(rec.data, pos + 32, 32));

    FOR i IN first_idx..(last_idx - 1) LOOP
        SELECT intent_id INTO origin_intent_id
        FROM tron.intent_queue
        WHERE queue_idx = i;

        IF origin_intent_id IS NOT NULL THEN
            intent_ids := array_append(intent_ids, origin_intent_id);
        END IF;

        INSERT INTO tron.intent_queue as queue(queue_idx, message_id, message_timestamp)
        VALUES (i, msg_id, rec.block_timestamp)
        ON CONFLICT (queue_idx)
        DO UPDATE SET
            message_id = EXCLUDED.message_id,
            message_timestamp = EXCLUDED.message_timestamp;
    END LOOP;

    INSERT INTO public.messages(
        id,
        domain,
        type,
        quote,
        first,
        last,
        intent_ids,
        tx_origin,
        transaction_hash,
        "timestamp",
        block_number,
        tx_nonce,
        gas_price,
        gas_limit,
        message_status,
        origin_domain,
        destination_domain
    )
    VALUES (
        msg_id,
        '728126428',
        'INTENT',
        quote,
        first_idx,
        last_idx,
        intent_ids,
        '0x0000000000000000000000000000000000000000', -- Default tx_origin for gateway events
        rec.transaction_hash,
        rec.block_timestamp,
        rec.block_number,
        0,
        1,
        0,
        'pending',
        '728126428',
        everclear_domain
    )
    ON CONFLICT (id)
    DO UPDATE SET
        domain = EXCLUDED.domain,
        type = EXCLUDED.type,
        quote = EXCLUDED.quote,
        first = EXCLUDED.first,
        last = EXCLUDED.last,
        intent_ids = EXCLUDED.intent_ids,
        tx_origin = EXCLUDED.tx_origin,
        transaction_hash = EXCLUDED.transaction_hash,
        "timestamp" = EXCLUDED."timestamp",
        block_number = EXCLUDED.block_number,
        tx_nonce = EXCLUDED.tx_nonce,
        gas_price = EXCLUDED.gas_price,
        gas_limit = EXCLUDED.gas_limit,
        message_status = EXCLUDED.message_status,
        origin_domain = EXCLUDED.origin_domain,
        destination_domain = EXCLUDED.destination_domain;

    UPDATE public.origin_intents SET message_id = msg_id, status = 'DISPATCHED' WHERE id = ANY(intent_ids);

    SELECT * INTO queue_rec
    FROM public.queues
    WHERE id = queue_id;

    IF FOUND THEN
        first_idx := GREATEST(queue_rec.first, last_idx);
        last_idx := GREATEST(queue_rec.last, last_idx - 1);
        queue_size := 1 + last_idx - first_idx;

        UPDATE public.queues
        SET size = queue_size,
            first = first_idx,
            last = last_idx,
            last_processed = GREATEST(queue_rec.last_processed, rec.block_timestamp)
        WHERE id = queue_id;
    END IF;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_fill_message(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    msg_id TEXT;
    first_idx NUMERIC;
    last_idx NUMERIC;
    queue_size NUMERIC;
    quote NUMERIC;
    everclear_domain VARCHAR(66) = '25327';
    intent_ids VARCHAR(66)[] := ARRAY[]::VARCHAR(66)[];
    pos INT := 3;
    queue_id TEXT = '728126428-0x46494c4c';
    queue_rec RECORD;
    fill_intent_id TEXT;
    i INT;
BEGIN
    msg_id := SUBSTRING(rec.topics, 68, 66);

    first_idx := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    last_idx := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64;
    quote := to_numeric(SUBSTRING(rec.data, pos + 48, 16));

    FOR i IN first_idx..(last_idx - 1) LOOP
        SELECT intent_id INTO fill_intent_id
        FROM tron.fill_queue
        WHERE queue_idx = i;

        IF fill_intent_id IS NOT NULL THEN
            intent_ids := array_append(intent_ids, fill_intent_id);
        END IF;

        INSERT INTO tron.fill_queue(queue_idx, message_id, message_timestamp)
        VALUES (i, msg_id, rec.block_timestamp)
        ON CONFLICT (queue_idx)
        DO UPDATE SET
            message_id = EXCLUDED.message_id,
            message_timestamp = EXCLUDED.message_timestamp;
    END LOOP;

    INSERT INTO public.messages(
        id,
        domain,
        type,
        quote,
        first,
        last,
        intent_ids,
        tx_origin,
        transaction_hash,
        "timestamp",
        block_number,
        tx_nonce,
        gas_price,
        gas_limit,
        message_status,
        origin_domain,
        destination_domain
    )
    VALUES (
        msg_id,
        '728126428',
        'FILL',
        quote,
        first_idx,
        last_idx,
        intent_ids,
        '0x0000000000000000000000000000000000000000', -- Default tx_origin for gateway events
        rec.transaction_hash,
        rec.block_timestamp,
        rec.block_number,
        0,
        1,
        0,
        'pending',
        '728126428',
        everclear_domain
    )
    ON CONFLICT (id)
    DO UPDATE SET
        domain = EXCLUDED.domain,
        type = EXCLUDED.type,
        quote = EXCLUDED.quote,
        first = EXCLUDED.first,
        last = EXCLUDED.last,
        intent_ids = EXCLUDED.intent_ids,
        tx_origin = EXCLUDED.tx_origin,
        transaction_hash = EXCLUDED.transaction_hash,
        "timestamp" = EXCLUDED."timestamp",
        block_number = EXCLUDED.block_number,
        tx_nonce = EXCLUDED.tx_nonce,
        gas_price = EXCLUDED.gas_price,
        gas_limit = EXCLUDED.gas_limit,
        message_status = EXCLUDED.message_status,
        origin_domain = EXCLUDED.origin_domain,
        destination_domain = EXCLUDED.destination_domain;

    UPDATE public.destination_intents SET message_id = msg_id, status = 'DISPATCHED' WHERE id = ANY(intent_ids);

    SELECT * INTO queue_rec
    FROM public.queues
    WHERE id = queue_id;

    IF FOUND THEN
        first_idx := GREATEST(queue_rec.first, last_idx);
        last_idx := GREATEST(queue_rec.last, last_idx - 1);
        queue_size := 1 + last_idx - first_idx;

        UPDATE public.queues
        SET size = queue_size,
            first = first_idx,
            last = last_idx,
            last_processed = GREATEST(queue_rec.last_processed, rec.block_timestamp)
        WHERE id = queue_id;
    END IF;

    RETURN TRUE;
END;$$;
