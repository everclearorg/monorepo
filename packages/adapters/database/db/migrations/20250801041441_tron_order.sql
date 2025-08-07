-- migrate:up

ALTER TABLE tron.origin_intents ADD COLUMN order_initiator text;

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
                order_id = origin_order_id,
                tx_origin = initiator
            WHERE
                id = intent_id;
        ELSE
            INSERT INTO tron.origin_intents(
                id,
                order_id,
                order_initiator
            )
            VALUES (
                intent_id,
                origin_order_id,
                initiator
            );
        END IF;
    END LOOP;

    RETURN TRUE;
END;$$;

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
    origin_order_initiator TEXT;
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

    SELECT native_fee, token_fee, fee_adapter_initiator, order_id, order_initiator
    INTO fee_native, fee_token, origin_intent_initiator, origin_order_id, origin_order_initiator
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
        COALESCE(origin_intent_initiator, origin_order_initiator, initiator),
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

-- migrate:down

ALTER TABLE tron.origin_intents DROP COLUMN order_initiator;

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

