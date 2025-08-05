-- migrate:up

ALTER TABLE tron.intent_queue ALTER COLUMN intent_id DROP NOT NULL;
ALTER TABLE tron.intent_queue ADD COLUMN message_id text;
ALTER TABLE tron.intent_queue ADD COLUMN message_timestamp bigint;
ALTER TABLE tron.fill_queue ALTER COLUMN intent_id DROP NOT NULL;
ALTER TABLE tron.fill_queue ADD COLUMN message_id text;
ALTER TABLE tron.fill_queue ADD COLUMN message_timestamp bigint;

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

-- migrate:down

ALTER TABLE tron.intent_queue DROP COLUMN message_timestamp;
ALTER TABLE tron.intent_queue DROP COLUMN message_id;
ALTER TABLE tron.intent_queue ALTER COLUMN intent_id SET NOT NULL;
ALTER TABLE tron.fill_queue DROP COLUMN message_timestamp;
ALTER TABLE tron.fill_queue DROP COLUMN message_id;
ALTER TABLE tron.fill_queue ALTER COLUMN intent_id SET NOT NULL;

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
        UPDATE public.queues
        SET size = queue_rec.size + 1,
            last = queue_index
        WHERE id = queue_id;
    END IF;

    INSERT INTO tron.intent_queue(queue_idx, intent_id)
    VALUES (queue_index, origin_intent_id)
    ON CONFLICT (queue_idx)
    DO UPDATE SET intent_id = EXCLUDED.intent_id;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_intent_message(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    msg_id TEXT;
    first_idx NUMERIC;
    last_idx NUMERIC;
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

    FOR i IN first_idx..last_idx LOOP
        SELECT intent_id INTO origin_intent_id
        FROM tron.intent_queue
        WHERE queue_idx = i;

        IF FOUND THEN
            intent_ids := array_append(intent_ids, origin_intent_id);
        END IF;
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
        UPDATE public.queues
        SET size = queue_rec.size - (last_idx - first_idx),
            first = last_idx,
            last_processed = rec.block_timestamp
        WHERE id = queue_id;
    END IF;

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
        UPDATE public.queues
        SET size = queue_rec.size + 1,
            last = queue_index
        WHERE id = queue_id;
    END IF;

    INSERT INTO tron.fill_queue(queue_idx, intent_id)
    VALUES (queue_index, destination_intent_id)
    ON CONFLICT (queue_idx)
    DO UPDATE SET intent_id = EXCLUDED.intent_id;

    RETURN TRUE;
END;$$;

CREATE OR REPLACE FUNCTION public.add_new_tron_fill_message(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    msg_id TEXT;
    first_idx NUMERIC;
    last_idx NUMERIC;
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

    FOR i IN first_idx..last_idx LOOP
        SELECT intent_id INTO fill_intent_id
        FROM tron.fill_queue
        WHERE queue_idx = i;

        IF FOUND THEN
            intent_ids := array_append(intent_ids, fill_intent_id);
        END IF;
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
        UPDATE public.queues
        SET size = queue_rec.size - (last_idx - first_idx),
            first = last_idx,
            last_processed = rec.block_timestamp
        WHERE id = queue_id;
    END IF;

    RETURN TRUE;
END;$$;

