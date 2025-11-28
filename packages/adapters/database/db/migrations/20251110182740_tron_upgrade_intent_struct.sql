-- migrate:up

CREATE OR REPLACE FUNCTION public.process_tron_spoke_events() RETURNS TRIGGER AS $$
DECLARE
    res BOOLEAN;
BEGIN
    -- IntentAdded event
    IF NEW.topics LIKE '0x80eb6c87e9da127233fe2ecab8adf29403109adc6bec90147df35eeee0745991%' THEN
        res := add_new_tron_origin_intent(NEW);
        IF res IS FALSE THEN
            RAISE WARNING 'Failed to parse and insert new tron origin intent, transaction %', NEW.transaction_hash;
        END IF;
    -- IntentFilled event
    ELSIF NEW.topics LIKE '0xe3bc4b05ac625e8c55084d86f8bb9a4c1ff02777dccc7ec0f3b3b7e7468cf383%' THEN
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
    tx_initiator TEXT;
    receiver TEXT;
    input_asset TEXT;
    output_asset TEXT;
    amount NUMERIC;
    amount_out_min NUMERIC;
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
    tx_initiator := get_tron_address(SUBSTRING(rec.data, pos, 64));
    pos := pos + 64;
    receiver := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    input_asset := get_tron_address(SUBSTRING(rec.data, pos, 64));
    pos := pos + 64;
    output_asset := '0x' || SUBSTRING(rec.data, pos, 64);
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
    pos := pos + 64;
    amount_out_min := to_numeric(SUBSTRING(rec.data, pos + 32, 32));
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
        order_id,
        amount_out_min
    )
    VALUES (
        origin_intent_id,
        queue_index,
        receiver,
        input_asset,
        output_asset,
        amount,
        '0',
        origin,
        nonce,
        data,
        SUBSTRING(rec.transaction_hash FROM 3),
        timestamp,
        rec.block_number,
        COALESCE(origin_intent_initiator, origin_order_initiator, tx_initiator),
        0,
        0,
        1,
        'ADDED',
        tx_initiator,
        ttl,
        destinations,
        fee_native,
        fee_token,
        origin_intent_initiator,
        origin_order_id,
        amount_out_min
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
        order_id = EXCLUDED.order_id,
        amount_out_min = EXCLUDED.amount_out_min;

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
    amount_out NUMERIC;
    queue_index NUMERIC;
    tx_initiator TEXT;
    receiver TEXT;
    input_asset TEXT;
    output_asset TEXT;
    amount NUMERIC;
    amount_out_min NUMERIC;
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

    amount_out := to_numeric(SUBSTRING(rec.data, pos + 32, 32));
    pos := pos + 64;
    queue_index := to_numeric(SUBSTRING(rec.data, pos + 48, 16));
    pos := pos + 64 + 64;
    tx_initiator := get_tron_address(SUBSTRING(rec.data, pos, 64));
    pos := pos + 64;
    receiver := '0x' || SUBSTRING(rec.data, pos, 64);
    pos := pos + 64;
    input_asset := get_tron_address(SUBSTRING(rec.data, pos, 64));
    pos := pos + 64;
    output_asset := '0x' || SUBSTRING(rec.data, pos, 64);
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
    pos := pos + 64;
    amount_out_min := to_numeric(SUBSTRING(rec.data, pos + 32, 32));
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
        ttl,
        amount_out,
        amount_out_min
    )
    VALUES (
        destination_intent_id,
        queue_index,
        tx_initiator,
        receiver,
        solver,
        input_asset,
        output_asset,
        amount,
        '0',
        origin,
        '728126428',
        nonce,
        data,
        SUBSTRING(rec.transaction_hash FROM 3),
        timestamp,
        rec.block_number,
        tx_initiator,
        0,
        '0',
        0,
        1,
        'ADDED',
        destinations,
        ttl,
        amount_out,
        amount_out_min
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
        ttl = EXCLUDED.ttl,
        amount_out = EXCLUDED.amount_out,
        amount_out_min = EXCLUDED.amount_out_min;

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
    tx_initiator TEXT;
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
    tx_initiator := get_tron_address(SUBSTRING(rec.data, pos, 64));
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
        COALESCE(origin_intent_initiator, origin_order_initiator, tx_initiator),
        0,
        0,
        1,
        'ADDED',
        tx_initiator,
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

-- Revert add_new_tron_destination_intent() to old structure (with _totalFeeDBPS and maxFee in Intent struct)
CREATE OR REPLACE FUNCTION public.add_new_tron_destination_intent(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    destination_intent_id TEXT;
    solver TEXT;
    totalFeeDBPS NUMERIC;
    queue_index NUMERIC;
    tx_initiator TEXT;
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
    tx_initiator := get_tron_address(SUBSTRING(rec.data, pos, 64));
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
        tx_initiator,
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
        tx_initiator,
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
