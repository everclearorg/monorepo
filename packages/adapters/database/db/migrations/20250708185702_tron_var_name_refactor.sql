-- migrate:up

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

    UPDATE public.destination_intents SET message_id = msg_id WHERE id = ANY(intent_ids);

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

    UPDATE public.origin_intents SET message_id = msg_id WHERE id = ANY(intent_ids);

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

-- migrate:down

