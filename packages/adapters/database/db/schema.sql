\restrict 91qdweOh5mTVodfEIBpHZn4WexPfX4kRQzL8QqOotlUeBanVg9jWPDyNGmedwe3

-- Dumped from database version 14.12 (Debian 14.12-1.pgdg120+1)
-- Dumped by pg_dump version 16.11 (Ubuntu 16.11-1.pgdg22.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_cron; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION pg_cron; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_cron IS 'Job scheduler for PostgreSQL';


--
-- Name: crypto; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA crypto;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: solana; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA solana;


--
-- Name: tokenomics; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA tokenomics;


--
-- Name: tron; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA tron;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA crypto;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: intent_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.intent_status AS ENUM (
    'NONE',
    'ADDED',
    'DEPOSIT_PROCESSED',
    'FILLED',
    'ADDED_AND_FILLED',
    'INVOICED',
    'SETTLED',
    'SETTLED_AND_MANUALLY_EXECUTED',
    'UNSUPPORTED',
    'UNSUPPORTED_RETURNED',
    'DISPATCHED',
    'DISPATCHED_UNSUPPORTED',
    'DISPATCHED_SPOKE',
    'DISPATCHED_HUB',
    'SETTLED_AND_COMPLETED',
    'ADDED_SPOKE',
    'ADDED_HUB',
    'DELIVERED'
);


--
-- Name: message_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.message_status AS ENUM (
    'none',
    'pending',
    'delivered',
    'relayable'
);


--
-- Name: message_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.message_type AS ENUM (
    'INTENT',
    'FILL',
    'SETTLEMENT',
    'MAILBOX_UPDATE',
    'SECURITY_MODULE_UPDATE',
    'GATEWAY_UPDATE',
    'LIGHTHOUSE_UPDATE'
);


--
-- Name: queue_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.queue_type AS ENUM (
    'INTENT',
    'FILL',
    'SETTLEMENT',
    'DEPOSIT'
);


--
-- Name: add_new_tron_destination_intent(record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_new_tron_destination_intent(rec record) RETURNS boolean
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


--
-- Name: add_new_tron_fill_message(record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_new_tron_fill_message(rec record) RETURNS boolean
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


--
-- Name: add_new_tron_intent_message(record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_new_tron_intent_message(rec record) RETURNS boolean
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


--
-- Name: add_new_tron_intent_with_fees(record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_new_tron_intent_with_fees(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    intent_id TEXT;
    tx_initiator TEXT;
    fee_token NUMERIC;
    fee_native NUMERIC;
    origin_intent RECORD;
    pos INT := 3;
BEGIN
    intent_id := SUBSTRING(rec.topics, 68, 66);
    tx_initiator := get_tron_address(SUBSTRING(rec.topics, 135, 66));

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
            tx_origin = tx_initiator,
            fee_adapter_initiator = tx_initiator
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
            tx_initiator
        )
        ON CONFLICT (id)
        DO UPDATE SET
            native_fee = EXCLUDED.native_fee,
            token_fee = EXCLUDED.token_fee,
            fee_adapter_initiator = EXCLUDED.fee_adapter_initiator;
    END IF;

    RETURN TRUE;
END;$$;


--
-- Name: add_new_tron_order(record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_new_tron_order(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    origin_order_id TEXT;
    intent_id TEXT;
    tx_initiator TEXT;
    intent_count INT;
    origin_intent RECORD;
    pos INT := 195;
BEGIN
    origin_order_id := SUBSTRING(rec.topics, 68, 66);
    tx_initiator := get_tron_address(SUBSTRING(rec.topics, 135, 66));

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
                tx_origin = tx_initiator
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
                tx_initiator
            );
        END IF;
    END LOOP;

    RETURN TRUE;
END;$$;


--
-- Name: add_new_tron_origin_intent(record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_new_tron_origin_intent(rec record) RETURNS boolean
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


--
-- Name: add_new_tron_settlement(record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_new_tron_settlement(rec record) RETURNS boolean
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


--
-- Name: base58_decode(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.base58_decode(base58_str text) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
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
END;$$;


--
-- Name: base58_encode(bytea); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.base58_encode(input_bytes bytea) RETURNS text
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


--
-- Name: genstatus(public.intent_status, public.intent_status, public.intent_status, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.genstatus(origin_status public.intent_status, hub_status public.intent_status, settlement_status public.intent_status, has_calldata boolean) RETURNS public.intent_status
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    IF settlement_status = 'SETTLED' THEN
        IF has_calldata THEN
            RETURN 'SETTLED';
        ELSE
            RETURN 'SETTLED_AND_COMPLETED';
        END IF;
    ELSIF origin_status = 'DISPATCHED' THEN
        IF hub_status IS NULL OR hub_status = 'NONE' THEN
            RETURN 'DISPATCHED_SPOKE';
        ELSIF hub_status = 'ADDED' THEN
            RETURN 'ADDED_HUB';
        ELSIF hub_status = 'DISPATCHED' THEN
            RETURN 'DISPATCHED_HUB';
        ELSE
            RETURN hub_status;
        END IF;
    ELSIF origin_status = 'ADDED' AND (hub_status IS NULL OR hub_status = 'NONE') THEN
        RETURN 'ADDED_SPOKE';
    ELSIF hub_status = 'ADDED' THEN
        RETURN 'ADDED_HUB';
    ELSE
        RETURN COALESCE(
            CASE WHEN hub_status IS NOT NULL AND hub_status != 'NONE' THEN hub_status END,
            origin_status
        );
    END IF;
END;
$$;


--
-- Name: get_intent_status_order(public.intent_status); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_intent_status_order(status public.intent_status) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    RETURN CASE status
        WHEN 'NONE' THEN 0
        WHEN 'ADDED' THEN 10
        WHEN 'ADDED_SPOKE' THEN 11
        WHEN 'ADDED_HUB' THEN 12
        WHEN 'DEPOSIT_PROCESSED' THEN 20
        WHEN 'FILLED' THEN 30
        WHEN 'ADDED_AND_FILLED' THEN 31
        WHEN 'INVOICED' THEN 40
        WHEN 'DISPATCHED' THEN 50
        WHEN 'DISPATCHED_HUB' THEN 51
        WHEN 'DISPATCHED_SPOKE' THEN 52
        WHEN 'DISPATCHED_UNSUPPORTED' THEN 53
        WHEN 'DELIVERED' THEN 60
        WHEN 'SETTLED' THEN 70
        WHEN 'SETTLED_AND_COMPLETED' THEN 71
        WHEN 'SETTLED_AND_MANUALLY_EXECUTED' THEN 72
        WHEN 'UNSUPPORTED' THEN 80
        WHEN 'UNSUPPORTED_RETURNED' THEN 81
        ELSE 0
    END;
END;
$$;


--
-- Name: get_tron_address(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_tron_address(evm_address text) RETURNS text
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


--
-- Name: hascalldata(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hascalldata(data text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    hex_part TEXT;
BEGIN
    IF data IS NOT NULL AND data LIKE '0x%' THEN
        -- Remove leading "0x"
        hex_part := SUBSTRING(data FROM 3);
        -- Remove leading zeros after "0x"
        hex_part := REGEXP_REPLACE(hex_part, '^0+', '');
        -- Return FALSE if nothing is left, otherwise return TRUE
        RETURN NULLIF(hex_part, '') IS NOT NULL;
    END IF;
    -- If the input doesn't start with "0x", default to FALSE
    RETURN FALSE;
END;
$$;


--
-- Name: log_destination_intent_status_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_destination_intent_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                IF OLD.status IS DISTINCT FROM NEW.status THEN
                    INSERT INTO public.destination_intents_status_log
                        (destination_intent_id, new_status, changed_at)
                    VALUES
                        (NEW.id, NEW.status, CURRENT_TIMESTAMP);
                END IF;
                RETURN NEW;
            END;
            $$;


--
-- Name: log_hub_intent_status_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_hub_intent_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                IF OLD.status IS DISTINCT FROM NEW.status THEN
                    INSERT INTO public.hub_intents_status_log
                        (hub_intent_id, new_status, changed_at)
                    VALUES
                        (NEW.id, NEW.status, CURRENT_TIMESTAMP);
                END IF;
                RETURN NEW;
            END;
            $$;


--
-- Name: log_origin_intent_status_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_origin_intent_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                IF OLD.status IS DISTINCT FROM NEW.status THEN
                    INSERT INTO public.origin_intents_status_log
                        (origin_intent_id, new_status, changed_at)
                    VALUES
                        (NEW.id, NEW.status, CURRENT_TIMESTAMP);
                END IF;
                RETURN NEW;
            END;
            $$;


--
-- Name: log_queue_type_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_queue_type_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.type IS DISTINCT FROM NEW.type THEN
        INSERT INTO public.queues_type_log
            (queue_id, new_type, changed_at)
        VALUES
            (NEW.id, NEW.type, CURRENT_TIMESTAMP);
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: parse_and_insert_cpi_event(record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.parse_and_insert_cpi_event(rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
END;$$;


--
-- Name: parse_and_insert_delivered_cpi_event(text, record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.parse_and_insert_delivered_cpi_event(hex_data text, rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
        rec.tx_signature,
        rec.block_timestamp,
        rec.block_slot,
        recipient,
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
            gas_limit = EXCLUDED.gas_limit,
            gas_price = EXCLUDED.gas_price,
            return_data = EXCLUDED.return_data,
            status = EXCLUDED.status;

    RETURN TRUE;
END;$$;


--
-- Name: parse_and_insert_intent_filled_cpi_event(text, record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.parse_and_insert_intent_filled_cpi_event(hex_data text, rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
    -- Get receiver from the EVMIntent struct
    pos := pos + 64;
    amount_out := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
    pos := pos + 16;

    -- Parse EVMIntent struct fields
    initiator := '0x' || SUBSTRING(hex_data, pos, 64);
    pos := pos + 64;
	receiver := '0x' || SUBSTRING(hex_data, pos, 64);
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
    amount := to_numeric(SUBSTRING(hex_data, pos + 32, 32));
    pos := pos + 64;
    amount_out_min := to_numeric(SUBSTRING(hex_data, pos + 32, 32));
    pos := pos + 64;
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
        max_fee,
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
        '0',
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
        max_fee = EXCLUDED.max_fee,
        gas_limit = EXCLUDED.gas_limit,
        gas_price = EXCLUDED.gas_price,
        status = EXCLUDED.status,
        destinations = EXCLUDED.destinations,
        ttl = EXCLUDED.ttl,
        amount_out_min = EXCLUDED.amount_out_min,
        amount_out = EXCLUDED.amount_out;

    RETURN TRUE;
END;$$;


--
-- Name: parse_and_insert_new_intent_cpi_event(text, record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.parse_and_insert_new_intent_cpi_event(hex_data text, rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    intent_id TEXT;
    message_id TEXT;
    initiator TEXT;
    receiver TEXT;
    input_asset TEXT;
    output_asset TEXT;
    normalized_amount NUMERIC;
    amount_out_min NUMERIC;
    origin_domain INT;
    nonce NUMERIC;
    ttl NUMERIC;
    timestamp NUMERIC;
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
	normalized_amount := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 32)));
	pos := pos + 32;
	amount_out_min := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 32)));
	pos := pos + 32;
	origin_domain := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
	pos := pos + 8;
	nonce := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
	pos := pos + 16;
	ttl := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
	pos := pos + 16;
	timestamp := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
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
		amount_out_min,
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
		intent_id,
		0,
		message_id,
		receiver,
		input_asset,
		output_asset,
		normalized_amount,
		amount_out_min,
		0,
		origin_domain,
		nonce,
		data,
		rec.tx_signature,
		timestamp,
		rec.block_slot,
		initiator,
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
		amount_out_min = EXCLUDED.amount_out_min,
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
		message_id,
		origin_domain,
		'INTENT',
		'0',
		0,
		0,
		ARRAY[intent_id],
		initiator,
		rec.tx_signature,
		timestamp,
		rec.block_slot,
		0,
		1,
		rec.tx_fee,
		'delivered',
		origin_domain,
		'25327'
	)
	ON CONFLICT (id)
	DO UPDATE SET
		id = EXCLUDED.id,
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

    RETURN TRUE;
END;$$;


--
-- Name: parse_and_insert_settled_cpi_event(text, record); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.parse_and_insert_settled_cpi_event(hex_data text, rec record) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    intent_id TEXT;
    recipient TEXT;
    asset TEXT;
    amount NUMERIC;
    domain INT;
	pos INT := 33;
BEGIN
	intent_id := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	recipient := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	asset := '0x' || SUBSTRING(hex_data, pos, 64);
	pos := pos + 64;
	amount := to_numeric(reverse_bytes(SUBSTRING(hex_data, pos, 16)));
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
        rec.tx_signature,
		rec.block_timestamp,
		rec.block_slot,
		recipient,
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
		gas_limit = EXCLUDED.gas_limit,
		gas_price = EXCLUDED.gas_price,
		return_data = EXCLUDED.return_data,
		status = EXCLUDED.status;

    RETURN TRUE;
END;$$;


--
-- Name: process_cpi_events(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_cpi_events() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'solana', 'public'
    AS $$
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
END;$$;


--
-- Name: process_tron_spoke_events(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_tron_spoke_events() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'tron', 'public'
    AS $$
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
END;$$;


--
-- Name: reverse_bytes(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reverse_bytes(hex_str text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    reversed TEXT := '';
BEGIN
    FOR i IN 0..(length(hex_str) / 2 - 1) LOOP
        reversed := substr(hex_str, i * 2 + 1, 2) || reversed;
    END LOOP;
    RETURN reversed;
END;
$$;


--
-- Name: table_exists(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.table_exists(table_name text, schema_name text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    table_count INT;
BEGIN
    EXECUTE format('SELECT COUNT(table_name) FROM information_schema.tables
        WHERE table_schema = ''%s'' AND table_name LIKE ''%s''', schema_name, table_name) INTO table_count;

    return table_count > 0;
END;
$$;


--
-- Name: to_bigint(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_bigint(hex_str text) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN CAST(CAST(('x' || hex_str) AS bit(64)) AS BIGINT);
END;
$$;


--
-- Name: to_hex(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_hex(n numeric) RETURNS text
    LANGUAGE plpgsql
    AS $$
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
END;$$;


--
-- Name: to_int(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_int(hex_str text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN CAST(CAST(('x' || hex_str) AS bit(32)) AS INT);
END;
$$;


--
-- Name: to_numeric(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_numeric(hex_str text) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN ('0x' || hex_str)::numeric;
END;
$$;


--
-- Name: validate_ascending_status_transition(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_ascending_status_transition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    old_order INTEGER;
    new_order INTEGER;
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        old_order := get_intent_status_order(OLD.status);
        new_order := get_intent_status_order(NEW.status);
        IF new_order < old_order THEN
            NEW.status := OLD.status;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: set_timestamp_and_latency(); Type: FUNCTION; Schema: tokenomics; Owner: -
--

CREATE FUNCTION tokenomics.set_timestamp_and_latency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
            NEW.insert_timestamp := CURRENT_TIMESTAMP;
            NEW.latency := NEW.insert_timestamp - TO_TIMESTAMP(NEW.block_timestamp);
            RETURN NEW;
        END;
    $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alert_triage_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alert_triage_log (
    fingerprint character(64) NOT NULL,
    report_type character varying(128) NOT NULL,
    severity character varying(16) NOT NULL,
    env character varying(64) NOT NULL,
    network character varying(32) NOT NULL,
    ids text[] DEFAULT '{}'::text[] NOT NULL,
    reason text NOT NULL,
    triage_mode character varying(16) NOT NULL,
    triage_result jsonb,
    provider_used character varying(32),
    model_used character varying(64),
    triage_latency_ms integer,
    auto_resolve_attempted boolean DEFAULT false NOT NULL,
    auto_resolve_succeeded boolean DEFAULT false NOT NULL,
    auto_resolve_reason_code character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    tool_calls_made integer DEFAULT 0 NOT NULL,
    tool_names_used text[] DEFAULT '{}'::text[] NOT NULL
);


--
-- Name: assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assets (
    id character varying(255) NOT NULL,
    token_id character varying,
    domain character varying(66),
    adopted character varying(66) NOT NULL,
    approval boolean NOT NULL,
    strategy character varying(255) NOT NULL
);


--
-- Name: balances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.balances (
    id character varying(66) NOT NULL,
    account character varying(66) NOT NULL,
    asset character varying(66) NOT NULL,
    amount character varying NOT NULL
);


--
-- Name: checkpoints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checkpoints (
    check_name character varying(255) NOT NULL,
    check_point numeric DEFAULT 0 NOT NULL
);


--
-- Name: destination_intents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.destination_intents (
    id character(66) NOT NULL,
    queue_idx bigint NOT NULL,
    message_id character(66),
    initiator character varying(66) NOT NULL,
    receiver character varying(66) NOT NULL,
    solver character varying(66) NOT NULL,
    input_asset character varying(66) NOT NULL,
    output_asset character varying(66) NOT NULL,
    amount character varying(255) NOT NULL,
    fee character varying(255) NOT NULL,
    origin character varying(66) NOT NULL,
    filled_domain character varying(66) NOT NULL,
    nonce bigint NOT NULL,
    data text,
    transaction_hash character(130) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL,
    auto_id bigint NOT NULL,
    max_fee character varying(255) NOT NULL,
    gas_limit bigint NOT NULL,
    gas_price bigint NOT NULL,
    status public.intent_status DEFAULT 'NONE'::public.intent_status NOT NULL,
    destinations character varying(66)[] NOT NULL,
    ttl bigint NOT NULL,
    return_data character varying,
    amount_out_min character varying(255),
    amount_out character varying(255)
);


--
-- Name: hub_intents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hub_intents (
    id character(66) NOT NULL,
    domain character varying(66) NOT NULL,
    message_id character(66),
    settlement_domain character varying(66),
    added_tx_nonce bigint,
    added_timestamp bigint,
    filled_tx_nonce bigint,
    filled_timestamp bigint,
    settlement_enqueued_tx_nonce bigint,
    settlement_enqueued_timestamp bigint,
    auto_id bigint NOT NULL,
    status public.intent_status DEFAULT 'NONE'::public.intent_status NOT NULL,
    queue_idx bigint,
    settlement_enqueued_block_number bigint,
    settlement_amount character varying(66),
    settlement_epoch bigint,
    update_virtual_balance boolean
);


--
-- Name: hub_invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hub_invoices (
    id character varying(255) NOT NULL,
    intent_id character(66) NOT NULL,
    amount character varying(66) NOT NULL,
    ticker_hash character(66) NOT NULL,
    owner character(66) NOT NULL,
    entry_epoch bigint NOT NULL,
    enqueued_tx_nonce bigint,
    enqueued_timestamp bigint,
    auto_id bigint NOT NULL,
    enqueued_transaction_hash character varying(66) NOT NULL,
    enqueued_block_number bigint NOT NULL
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id character varying(255) NOT NULL,
    domain character varying(66) NOT NULL,
    type public.message_type NOT NULL,
    quote character varying(255),
    first bigint NOT NULL,
    last bigint NOT NULL,
    intent_ids character varying(66)[] NOT NULL,
    tx_origin character varying(66) NOT NULL,
    transaction_hash character(130) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_nonce bigint NOT NULL,
    auto_id bigint NOT NULL,
    gas_price bigint NOT NULL,
    gas_limit bigint NOT NULL,
    message_status public.message_status DEFAULT 'none'::public.message_status NOT NULL,
    origin_domain character varying(66),
    destination_domain character varying(66)
);


--
-- Name: origin_intents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.origin_intents (
    id character(66) NOT NULL,
    queue_idx bigint NOT NULL,
    message_id character(66),
    receiver character varying(66) NOT NULL,
    input_asset character varying(66) NOT NULL,
    output_asset character varying(66) NOT NULL,
    amount character varying(255) NOT NULL,
    max_fee character varying(255) NOT NULL,
    origin character varying(66) NOT NULL,
    nonce bigint NOT NULL,
    data text,
    transaction_hash character(130) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL,
    auto_id bigint NOT NULL,
    gas_limit bigint NOT NULL,
    gas_price bigint NOT NULL,
    status public.intent_status DEFAULT 'NONE'::public.intent_status NOT NULL,
    initiator character varying(66) NOT NULL,
    ttl bigint NOT NULL,
    destinations character varying(66)[] NOT NULL,
    native_fee character varying(255),
    token_fee character varying(255),
    fee_adapter_initiator character varying(66),
    order_id character varying(66),
    amount_out_min character varying(255),
    is_swap boolean DEFAULT false NOT NULL
);


--
-- Name: settlement_intents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settlement_intents (
    id character(66) NOT NULL,
    amount character varying(255) NOT NULL,
    asset character varying(66) NOT NULL,
    recipient character varying(66) NOT NULL,
    domain character varying(66) NOT NULL,
    transaction_hash character(130) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL,
    auto_id bigint NOT NULL,
    gas_limit bigint NOT NULL,
    gas_price bigint NOT NULL,
    return_data character varying,
    status public.intent_status DEFAULT 'SETTLED'::public.intent_status NOT NULL
);


--
-- Name: intents; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.intents AS
 SELECT t.id,
    t.origin_queue_idx,
    t.origin_message_id,
    t.origin_status,
    t.origin_initiator,
    t.origin_receiver,
    t.origin_input_asset,
    t.origin_output_asset,
    t.origin_amount,
    t.origin_max_fee,
    t.origin_origin,
    t.origin_destinations,
    t.origin_ttl,
    t.origin_nonce,
    t.origin_data,
    t.origin_transaction_hash,
    t.origin_timestamp,
    t.origin_block_number,
    t.origin_gas_limit,
    t.origin_gas_price,
    t.origin_tx_origin,
    t.origin_tx_nonce,
    t.origin_auto_id,
    t.origin_native_fee,
    t.origin_token_fee,
    t.origin_fee_adapter_initiator,
    t.origin_order_id,
    t.origin_amount_out_min,
    t.origin_is_swap,
    t.destination_queue_idx,
    t.destination_message_id,
    t.destination_status,
    t.destination_initiator,
    t.destination_receiver,
    t.destination_solver,
    t.destination_input_asset,
    t.destination_output_asset,
    t.destination_amount,
    t.destination_fee,
    t.destination_origin,
    t.destination_destinations,
    t.destination_ttl,
    t.destination_filled,
    t.destination_nonce,
    t.destination_data,
    t.destination_transaction_hash,
    t.destination_timestamp,
    t.destination_block_number,
    t.destination_gas_limit,
    t.destination_gas_price,
    t.destination_tx_origin,
    t.destination_tx_nonce,
    t.destination_auto_id,
    t.settlement_amount_out_min,
    t.destination_amount_out,
    t.settlement_amount,
    t.settlement_asset,
    t.settlement_recipient,
    t.settlement_domain,
    t.settlement_status,
    t.destination_return_data,
    t.settlement_transaction_hash,
    t.settlement_timestamp,
    t.settlement_block_number,
    t.settlement_gas_limit,
    t.settlement_gas_price,
    t.settlement_tx_origin,
    t.settlement_tx_nonce,
    t.settlement_auto_id,
    t.hub_domain,
    t.hub_queue_idx,
    t.hub_message_id,
    t.hub_status,
    t.hub_settlement_domain,
    t.hub_settlement_amount,
    t.hub_added_tx_nonce,
    t.hub_added_timestamp,
    t.hub_filled_tx_nonce,
    t.hub_filled_timestamp,
    t.hub_settlement_enqueued_tx_nonce,
    t.hub_settlement_enqueued_block_number,
    t.hub_settlement_enqueued_timestamp,
    t.hub_settlement_epoch,
    t.hub_update_virtual_balance,
    t.intent_queue_processed_tx_hash,
    t.intent_queue_processed_timestamp,
    t.fill_queue_processed_tx_hash,
    t.fill_queue_processed_timestamp,
    t.settlement_queue_processed_tx_hash,
    t.settlement_queue_processed_timestamp,
    t.status,
    t.has_calldata,
    t.hub_auto_id
   FROM ( SELECT origin_intents.id,
            origin_intents.queue_idx AS origin_queue_idx,
            origin_intents.message_id AS origin_message_id,
            origin_intents.status AS origin_status,
            origin_intents.initiator AS origin_initiator,
            origin_intents.receiver AS origin_receiver,
            origin_intents.input_asset AS origin_input_asset,
            origin_intents.output_asset AS origin_output_asset,
            origin_intents.amount AS origin_amount,
            origin_intents.max_fee AS origin_max_fee,
            origin_intents.origin AS origin_origin,
            origin_intents.destinations AS origin_destinations,
            origin_intents.ttl AS origin_ttl,
            origin_intents.nonce AS origin_nonce,
            origin_intents.data AS origin_data,
            origin_intents.transaction_hash AS origin_transaction_hash,
            origin_intents."timestamp" AS origin_timestamp,
            origin_intents.block_number AS origin_block_number,
            origin_intents.gas_limit AS origin_gas_limit,
            origin_intents.gas_price AS origin_gas_price,
            origin_intents.tx_origin AS origin_tx_origin,
            origin_intents.tx_nonce AS origin_tx_nonce,
            origin_intents.auto_id AS origin_auto_id,
            origin_intents.native_fee AS origin_native_fee,
            origin_intents.token_fee AS origin_token_fee,
            origin_intents.fee_adapter_initiator AS origin_fee_adapter_initiator,
            origin_intents.order_id AS origin_order_id,
            origin_intents.amount_out_min AS origin_amount_out_min,
            origin_intents.is_swap AS origin_is_swap,
            destination_intents.queue_idx AS destination_queue_idx,
            destination_intents.message_id AS destination_message_id,
            destination_intents.status AS destination_status,
            destination_intents.initiator AS destination_initiator,
            destination_intents.receiver AS destination_receiver,
            destination_intents.solver AS destination_solver,
            destination_intents.input_asset AS destination_input_asset,
            destination_intents.output_asset AS destination_output_asset,
            destination_intents.amount AS destination_amount,
            destination_intents.fee AS destination_fee,
            destination_intents.origin AS destination_origin,
            destination_intents.destinations AS destination_destinations,
            destination_intents.ttl AS destination_ttl,
            destination_intents.filled_domain AS destination_filled,
            destination_intents.nonce AS destination_nonce,
            destination_intents.data AS destination_data,
            destination_intents.transaction_hash AS destination_transaction_hash,
            destination_intents."timestamp" AS destination_timestamp,
            destination_intents.block_number AS destination_block_number,
            destination_intents.gas_limit AS destination_gas_limit,
            destination_intents.gas_price AS destination_gas_price,
            destination_intents.tx_origin AS destination_tx_origin,
            destination_intents.tx_nonce AS destination_tx_nonce,
            destination_intents.auto_id AS destination_auto_id,
            destination_intents.amount_out_min AS settlement_amount_out_min,
            destination_intents.amount_out AS destination_amount_out,
            settlement_intents.amount AS settlement_amount,
            settlement_intents.asset AS settlement_asset,
            settlement_intents.recipient AS settlement_recipient,
            settlement_intents.domain AS settlement_domain,
            settlement_intents.status AS settlement_status,
            COALESCE(destination_intents.return_data, settlement_intents.return_data) AS destination_return_data,
            settlement_intents.transaction_hash AS settlement_transaction_hash,
            settlement_intents."timestamp" AS settlement_timestamp,
            settlement_intents.block_number AS settlement_block_number,
            settlement_intents.gas_limit AS settlement_gas_limit,
            settlement_intents.gas_price AS settlement_gas_price,
            settlement_intents.tx_origin AS settlement_tx_origin,
            settlement_intents.tx_nonce AS settlement_tx_nonce,
            settlement_intents.auto_id AS settlement_auto_id,
            hub_intents.domain AS hub_domain,
            hub_intents.queue_idx AS hub_queue_idx,
            hub_intents.message_id AS hub_message_id,
            hub_intents.status AS hub_status,
            hub_intents.settlement_domain AS hub_settlement_domain,
            hub_intents.settlement_amount AS hub_settlement_amount,
            hub_intents.added_tx_nonce AS hub_added_tx_nonce,
            hub_intents.added_timestamp AS hub_added_timestamp,
            hub_intents.filled_tx_nonce AS hub_filled_tx_nonce,
            hub_intents.filled_timestamp AS hub_filled_timestamp,
            hub_intents.settlement_enqueued_tx_nonce AS hub_settlement_enqueued_tx_nonce,
            hub_intents.settlement_enqueued_block_number AS hub_settlement_enqueued_block_number,
            hub_intents.settlement_enqueued_timestamp AS hub_settlement_enqueued_timestamp,
            hub_intents.settlement_epoch AS hub_settlement_epoch,
            hub_intents.update_virtual_balance AS hub_update_virtual_balance,
            intent_msg.transaction_hash AS intent_queue_processed_tx_hash,
            intent_msg."timestamp" AS intent_queue_processed_timestamp,
            fill_msg.transaction_hash AS fill_queue_processed_tx_hash,
            fill_msg."timestamp" AS fill_queue_processed_timestamp,
            settlement_msg.transaction_hash AS settlement_queue_processed_tx_hash,
            settlement_msg."timestamp" AS settlement_queue_processed_timestamp,
            public.genstatus(origin_intents.status, hub_intents.status, settlement_intents.status, public.hascalldata(origin_intents.data)) AS status,
            public.hascalldata(origin_intents.data) AS has_calldata,
            hub_intents.auto_id AS hub_auto_id
           FROM ((((((public.origin_intents
             LEFT JOIN public.destination_intents ON ((origin_intents.id = destination_intents.id)))
             LEFT JOIN public.settlement_intents ON ((origin_intents.id = settlement_intents.id)))
             LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
             LEFT JOIN public.messages intent_msg ON (((origin_intents.message_id = (intent_msg.id)::bpchar) AND (intent_msg.type = 'INTENT'::public.message_type))))
             LEFT JOIN public.messages fill_msg ON (((destination_intents.message_id = (fill_msg.id)::bpchar) AND (fill_msg.type = 'FILL'::public.message_type))))
             LEFT JOIN public.messages settlement_msg ON (((hub_intents.message_id = (settlement_msg.id)::bpchar) AND (settlement_msg.type = 'SETTLEMENT'::public.message_type))))) t
  WITH NO DATA;


--
-- Name: invoices; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.invoices AS
 SELECT t.id,
    t.origin_queue_idx,
    t.origin_message_id,
    t.origin_status,
    t.origin_initiator,
    t.origin_receiver,
    t.origin_input_asset,
    t.origin_output_asset,
    t.origin_amount,
    t.origin_max_fee,
    t.origin_origin,
    t.origin_destinations,
    t.origin_ttl,
    t.origin_nonce,
    t.origin_data,
    t.origin_transaction_hash,
    t.origin_timestamp,
    t.origin_block_number,
    t.origin_gas_limit,
    t.origin_gas_price,
    t.origin_tx_origin,
    t.origin_tx_nonce,
    t.origin_auto_id,
    t.origin_native_fee,
    t.origin_token_fee,
    t.origin_fee_adapter_initiator,
    t.origin_order_id,
    t.origin_amount_out_min,
    t.origin_is_swap,
    t.hub_invoice_id,
    t.hub_invoice_intent_id,
    t.hub_invoice_amount,
    t.hub_invoice_ticker_hash,
    t.hub_invoice_owner,
    t.hub_invoice_entry_epoch,
    t.hub_invoice_enqueued_tx_nonce,
    t.hub_invoice_enqueued_timestamp,
    t.hub_invoice_auto_id,
    t.hub_status,
    t.hub_settlement_epoch
   FROM ( SELECT origin_intents.id,
            origin_intents.queue_idx AS origin_queue_idx,
            origin_intents.message_id AS origin_message_id,
            origin_intents.status AS origin_status,
            origin_intents.initiator AS origin_initiator,
            origin_intents.receiver AS origin_receiver,
            origin_intents.input_asset AS origin_input_asset,
            origin_intents.output_asset AS origin_output_asset,
            origin_intents.amount AS origin_amount,
            origin_intents.max_fee AS origin_max_fee,
            origin_intents.origin AS origin_origin,
            origin_intents.destinations AS origin_destinations,
            origin_intents.ttl AS origin_ttl,
            origin_intents.nonce AS origin_nonce,
            origin_intents.data AS origin_data,
            origin_intents.transaction_hash AS origin_transaction_hash,
            origin_intents."timestamp" AS origin_timestamp,
            origin_intents.block_number AS origin_block_number,
            origin_intents.gas_limit AS origin_gas_limit,
            origin_intents.gas_price AS origin_gas_price,
            origin_intents.tx_origin AS origin_tx_origin,
            origin_intents.tx_nonce AS origin_tx_nonce,
            origin_intents.auto_id AS origin_auto_id,
            origin_intents.native_fee AS origin_native_fee,
            origin_intents.token_fee AS origin_token_fee,
            origin_intents.fee_adapter_initiator AS origin_fee_adapter_initiator,
            origin_intents.order_id AS origin_order_id,
            origin_intents.amount_out_min AS origin_amount_out_min,
            origin_intents.is_swap AS origin_is_swap,
            hub_invoices.id AS hub_invoice_id,
            hub_invoices.intent_id AS hub_invoice_intent_id,
            hub_invoices.amount AS hub_invoice_amount,
            hub_invoices.ticker_hash AS hub_invoice_ticker_hash,
            hub_invoices.owner AS hub_invoice_owner,
            hub_invoices.entry_epoch AS hub_invoice_entry_epoch,
            hub_invoices.enqueued_tx_nonce AS hub_invoice_enqueued_tx_nonce,
            hub_invoices.enqueued_timestamp AS hub_invoice_enqueued_timestamp,
            hub_invoices.auto_id AS hub_invoice_auto_id,
            hub_intents.status AS hub_status,
            hub_intents.settlement_epoch AS hub_settlement_epoch
           FROM ((public.hub_invoices
             LEFT JOIN public.origin_intents ON ((origin_intents.id = hub_invoices.intent_id)))
             LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))) t
  WITH NO DATA;


--
-- Name: daily_metrics_by_chains_tokens; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.daily_metrics_by_chains_tokens AS
 WITH metadata AS (
         SELECT asset_data.symbol,
            asset_data.decimals AS "decimal",
            asset_data.domainid AS domain_id,
            lower(asset_data.address) AS address,
            lower(concat('0x', lpad(SUBSTRING(asset_data.address FROM 3), 64, '0'::text))) AS adopted_address
           FROM ( VALUES ('Wrapped Ether'::text,'WETH'::text,18,1,'0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'::text), ('Wrapped Ether'::text,'WETH'::text,18,10,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,56,'0x2170Ed0880ac9A755fd29B2688956BD959F933F8'::text), ('Wrapped Ether'::text,'WETH'::text,18,8453,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,42161,'0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'::text), ('USD Coin'::text,'USDC'::text,6,1,'0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'::text), ('USD Coin'::text,'USDC'::text,6,10,'0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85'::text), ('USD Coin'::text,'USDC'::text,18,56,'0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'::text), ('USD Coin'::text,'USDC'::text,6,8453,'0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'::text), ('USD Coin'::text,'USDC'::text,6,42161,'0xaf88d065e77c8cC2239327C5EDb3A432268e5831'::text), ('Tether USD'::text,'USDT'::text,6,1,'0xdAC17F958D2ee523a2206206994597C13D831ec7'::text), ('Tether USD'::text,'USDT'::text,6,10,'0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'::text), ('Tether USD'::text,'USDT'::text,18,56,'0x55d398326f99059fF775485246999027B3197955'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'::text)) asset_data(assetname, symbol, decimals, domainid, address)
        ), netted_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision)) AS day,
            (i.origin_origin)::integer AS from_chain_id,
            i.origin_input_asset AS from_asset_address,
            fm.symbol AS from_asset_symbol,
            (i.settlement_domain)::integer AS to_chain_id,
            i.settlement_asset AS to_asset_address,
            tm.symbol AS to_asset_symbol,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_volume,
            avg((((i.settlement_timestamp)::double precision - (i.origin_timestamp)::double precision) / (3600)::double precision)) AS netting_avg_time_in_hrs,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS netting_protocol_revenue,
            count(i.id) AS netting_total_intents,
            avg(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_avg_intent_size
           FROM (((public.intents i
             LEFT JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((inv.id IS NULL) AND (i.status = ANY (ARRAY['SETTLED_AND_COMPLETED'::public.intent_status, 'SETTLED_AND_MANUALLY_EXECUTED'::public.intent_status])) AND (i.hub_status <> 'DISPATCHED_UNSUPPORTED'::public.intent_status))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision))), (i.origin_origin)::integer, i.origin_input_asset, fm.symbol, (i.settlement_domain)::integer, i.settlement_asset, tm.symbol
        ), netted_final AS (
         SELECT netted_raw.day,
            netted_raw.from_chain_id,
            netted_raw.from_asset_address,
            netted_raw.from_asset_symbol,
            netted_raw.to_chain_id,
            netted_raw.to_asset_address,
            netted_raw.to_asset_symbol,
            netted_raw.netting_volume,
            netted_raw.netting_avg_intent_size,
            netted_raw.netting_protocol_revenue,
            netted_raw.netting_total_intents,
            netted_raw.netting_avg_time_in_hrs
           FROM netted_raw
        ), settled_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision)) AS day,
            (i.origin_origin)::integer AS from_chain_id,
            i.origin_input_asset AS from_asset_address,
            fm.symbol AS from_asset_symbol,
            (i.settlement_domain)::integer AS to_chain_id,
            i.settlement_asset AS to_asset_address,
            tm.symbol AS to_asset_symbol,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS avg_discounts_by_mm,
            sum((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS discounts_by_mm,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision)))) AS avg_rewards_by_invoice,
            sum(((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) - (((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision)))) AS rewards_for_invoices,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS volume_settled_by_mm,
            count(i.id) AS total_intents_by_mm,
            avg((((i.hub_settlement_enqueued_timestamp)::double precision - (i.hub_added_timestamp)::double precision) / (3600)::double precision)) AS avg_time_in_hrs,
            round(avg((inv.hub_settlement_epoch - inv.hub_invoice_entry_epoch)), 0) AS avg_discount_epoch,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS protocol_revenue_mm
           FROM (((public.intents i
             JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((i.status = ANY (ARRAY['SETTLED_AND_COMPLETED'::public.intent_status, 'SETTLED_AND_MANUALLY_EXECUTED'::public.intent_status])) AND (i.hub_status = ANY (ARRAY['DISPATCHED'::public.intent_status, 'SETTLED'::public.intent_status])))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.settlement_timestamp)::double precision))), (i.origin_origin)::integer, i.origin_input_asset, fm.symbol, (i.settlement_domain)::integer, i.settlement_asset, tm.symbol
        ), settled_final AS (
         SELECT settled_raw.day,
            settled_raw.from_chain_id,
            settled_raw.from_asset_address,
            settled_raw.from_asset_symbol,
            settled_raw.to_chain_id,
            settled_raw.to_asset_address,
            settled_raw.to_asset_symbol,
            settled_raw.volume_settled_by_mm,
            settled_raw.protocol_revenue_mm,
            settled_raw.total_intents_by_mm,
            settled_raw.discounts_by_mm,
            settled_raw.avg_discounts_by_mm,
            settled_raw.rewards_for_invoices,
            settled_raw.avg_rewards_by_invoice,
            settled_raw.avg_time_in_hrs AS avg_settlement_time_in_hrs_by_mm,
            (((settled_raw.discounts_by_mm / settled_raw.volume_settled_by_mm) * (365)::double precision) * (100)::double precision) AS apy,
            settled_raw.avg_discount_epoch AS avg_discount_epoch_by_mm
           FROM settled_raw
        ), combined AS (
         SELECT COALESCE(n.day, s.day) AS day,
            COALESCE(n.from_chain_id, s.from_chain_id) AS from_chain_id,
            COALESCE(n.from_asset_address, s.from_asset_address) AS from_asset_address,
            COALESCE(n.from_asset_symbol, s.from_asset_symbol) AS from_asset_symbol,
            COALESCE(n.to_chain_id, s.to_chain_id) AS to_chain_id,
            COALESCE(n.to_asset_address, s.to_asset_address) AS to_asset_address,
            COALESCE(n.to_asset_symbol, s.to_asset_symbol) AS to_asset_symbol,
            n.netting_volume,
            n.netting_avg_intent_size,
            n.netting_protocol_revenue,
            n.netting_total_intents,
            n.netting_avg_time_in_hrs,
            s.volume_settled_by_mm,
            s.total_intents_by_mm,
            s.discounts_by_mm,
            s.avg_discounts_by_mm,
            s.rewards_for_invoices,
            s.avg_rewards_by_invoice,
            s.avg_settlement_time_in_hrs_by_mm,
            s.apy,
            s.avg_discount_epoch_by_mm,
            (COALESCE(n.netting_volume, (0)::double precision) + COALESCE(s.volume_settled_by_mm, (0)::double precision)) AS total_volume,
            (COALESCE(n.netting_total_intents, (0)::bigint) + COALESCE(s.total_intents_by_mm, (0)::bigint)) AS total_intents,
            (COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) AS total_protocol_revenue,
            ((COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) + COALESCE(s.discounts_by_mm, (0)::double precision)) AS total_rebalancing_fee
           FROM (netted_final n
             FULL JOIN settled_final s ON (((n.day = s.day) AND (n.from_chain_id = s.from_chain_id) AND (n.to_chain_id = s.to_chain_id) AND ((n.from_asset_address)::text = (s.from_asset_address)::text) AND ((n.to_asset_address)::text = (s.to_asset_address)::text))))
        )
 SELECT combined.day,
    combined.from_chain_id,
    combined.from_asset_address,
    combined.from_asset_symbol,
    combined.to_chain_id,
    combined.to_asset_address,
    combined.to_asset_symbol,
    combined.netting_volume,
    combined.netting_avg_intent_size,
    combined.netting_protocol_revenue,
    combined.netting_total_intents,
    combined.netting_avg_time_in_hrs,
    combined.volume_settled_by_mm,
    combined.total_intents_by_mm,
    combined.discounts_by_mm,
    combined.avg_discounts_by_mm,
    combined.rewards_for_invoices,
    combined.avg_rewards_by_invoice,
    combined.avg_settlement_time_in_hrs_by_mm,
    combined.apy,
    combined.avg_discount_epoch_by_mm,
    combined.total_volume,
    combined.total_intents,
    combined.total_protocol_revenue,
    combined.total_rebalancing_fee
   FROM combined
  WITH NO DATA;


--
-- Name: daily_metrics_by_date; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.daily_metrics_by_date AS
 WITH metadata AS (
         SELECT asset_data.symbol,
            asset_data.decimals AS "decimal",
            asset_data.domainid AS domain_id,
            lower(asset_data.address) AS address,
            lower(concat('0x', lpad(SUBSTRING(asset_data.address FROM 3), 64, '0'::text))) AS adopted_address
           FROM ( VALUES ('Wrapped Ether'::text,'WETH'::text,18,1,'0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'::text), ('Wrapped Ether'::text,'WETH'::text,18,10,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,56,'0x2170Ed0880ac9A755fd29B2688956BD959F933F8'::text), ('Wrapped Ether'::text,'WETH'::text,18,8453,'0x4200000000000000000000000000000000000006'::text), ('Wrapped Ether'::text,'WETH'::text,18,42161,'0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'::text), ('USD Coin'::text,'USDC'::text,6,1,'0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'::text), ('USD Coin'::text,'USDC'::text,6,10,'0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85'::text), ('USD Coin'::text,'USDC'::text,18,56,'0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'::text), ('USD Coin'::text,'USDC'::text,6,8453,'0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'::text), ('USD Coin'::text,'USDC'::text,6,42161,'0xaf88d065e77c8cC2239327C5EDb3A432268e5831'::text), ('Tether USD'::text,'USDT'::text,6,1,'0xdAC17F958D2ee523a2206206994597C13D831ec7'::text), ('Tether USD'::text,'USDT'::text,6,10,'0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'::text), ('Tether USD'::text,'USDT'::text,18,56,'0x55d398326f99059fF775485246999027B3197955'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'::text), ('Tether USD'::text,'USDT'::text,6,42161,'0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'::text)) asset_data(assetname, symbol, decimals, domainid, address)
        ), netted_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)) AS day,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_volume,
            avg((((i.settlement_timestamp)::double precision - (i.origin_timestamp)::double precision) / (3600)::double precision)) AS netting_avg_time_in_hrs,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS netting_protocol_revenue,
            count(i.id) AS netting_total_intents,
            avg(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS netting_avg_intent_size
           FROM (((public.intents i
             LEFT JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((inv.id IS NULL) AND (i.status = 'SETTLED_AND_COMPLETED'::public.intent_status) AND (i.hub_status <> 'DISPATCHED_UNSUPPORTED'::public.intent_status))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)))
        ), netted_final AS (
         SELECT netted_raw.day,
            netted_raw.netting_volume,
            netted_raw.netting_avg_intent_size,
            netted_raw.netting_protocol_revenue,
            netted_raw.netting_total_intents,
            netted_raw.netting_avg_time_in_hrs
           FROM netted_raw
        ), settled_raw AS (
         SELECT date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)) AS day,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS avg_discounts_by_mm,
            sum((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.settlement_amount)::double precision / ((10)::double precision ^ (tm."decimal")::double precision)))) AS discounts_by_mm,
            avg((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision)))) AS avg_rewards_by_invoice,
            sum(((((inv.hub_invoice_amount)::double precision / ((10)::double precision ^ (18)::double precision)) - ((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) - (((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision)))) AS rewards_for_invoices,
            sum(((i.origin_amount)::double precision / ((10)::double precision ^ (18)::double precision))) AS volume_settled_by_mm,
            count(i.id) AS total_intents_by_mm,
            avg((((i.hub_settlement_enqueued_timestamp)::double precision - (i.hub_added_timestamp)::double precision) / (3600)::double precision)) AS avg_time_in_hrs,
            round(avg((inv.hub_settlement_epoch - inv.hub_invoice_entry_epoch)), 0) AS avg_discount_epoch,
            sum((((0.0001)::double precision * (i.origin_amount)::double precision) / ((10)::double precision ^ (18)::double precision))) AS protocol_revenue_mm
           FROM (((public.intents i
             JOIN public.invoices inv ON ((i.id = inv.id)))
             LEFT JOIN metadata fm ON ((((i.origin_input_asset)::text = fm.adopted_address) AND ((i.origin_origin)::integer = fm.domain_id))))
             LEFT JOIN metadata tm ON (((lower((i.settlement_asset)::text) = tm.address) AND ((i.settlement_domain)::integer = tm.domain_id))))
          WHERE ((i.status = 'SETTLED_AND_COMPLETED'::public.intent_status) AND (i.hub_status = ANY (ARRAY['DISPATCHED'::public.intent_status, 'SETTLED'::public.intent_status])))
          GROUP BY (date_trunc('day'::text, to_timestamp((i.origin_timestamp)::double precision)))
        ), settled_final AS (
         SELECT settled_raw.day,
            settled_raw.volume_settled_by_mm,
            settled_raw.protocol_revenue_mm,
            settled_raw.total_intents_by_mm,
            settled_raw.discounts_by_mm,
            settled_raw.avg_discounts_by_mm,
            settled_raw.rewards_for_invoices,
            settled_raw.avg_rewards_by_invoice,
            settled_raw.avg_time_in_hrs AS avg_settlement_time_in_hrs_by_mm,
            (((settled_raw.discounts_by_mm / settled_raw.volume_settled_by_mm) * (365)::double precision) * (100)::double precision) AS apy,
            settled_raw.avg_discount_epoch AS avg_discount_epoch_by_mm
           FROM settled_raw
        )
 SELECT COALESCE(n.day, s.day) AS day,
    n.netting_volume,
    n.netting_avg_intent_size,
    n.netting_protocol_revenue,
    n.netting_total_intents,
    n.netting_avg_time_in_hrs,
    s.volume_settled_by_mm,
    s.total_intents_by_mm,
    s.discounts_by_mm,
    s.avg_discounts_by_mm,
    s.rewards_for_invoices,
    s.avg_rewards_by_invoice,
    s.avg_settlement_time_in_hrs_by_mm,
    s.apy,
    s.avg_discount_epoch_by_mm,
    (COALESCE(n.netting_volume, (0)::double precision) + COALESCE(s.volume_settled_by_mm, (0)::double precision)) AS total_volume,
    (COALESCE(n.netting_total_intents, (0)::bigint) + COALESCE(s.total_intents_by_mm, (0)::bigint)) AS total_intents,
    (COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) AS total_protocol_revenue,
    ((COALESCE(n.netting_protocol_revenue, (0)::double precision) + COALESCE(s.protocol_revenue_mm, (0)::double precision)) + COALESCE(s.discounts_by_mm, (0)::double precision)) AS total_rebalancing_fee
   FROM (netted_final n
     FULL JOIN settled_final s ON ((n.day = s.day)))
  WITH NO DATA;


--
-- Name: depositors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.depositors (
    id character varying(66) NOT NULL
);


--
-- Name: destination_intents_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.destination_intents_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: destination_intents_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.destination_intents_auto_id_seq OWNED BY public.destination_intents.auto_id;


--
-- Name: destination_intents_status_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.destination_intents_status_log (
    id integer NOT NULL,
    destination_intent_id character(66) NOT NULL,
    new_status public.intent_status,
    changed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: destination_intents_status_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.destination_intents_status_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: destination_intents_status_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.destination_intents_status_log_id_seq OWNED BY public.destination_intents_status_log.id;


--
-- Name: epoch_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.epoch_results (
    id integer NOT NULL,
    account character varying(66) NOT NULL,
    domain character varying NOT NULL,
    user_volume character varying NOT NULL,
    total_volume character varying NOT NULL,
    clear_emissions character varying NOT NULL,
    epoch_timestamp timestamp without time zone NOT NULL,
    update_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cumulative_rewards character varying DEFAULT '0'::character varying NOT NULL
);


--
-- Name: epoch_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.epoch_results_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: epoch_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.epoch_results_id_seq OWNED BY public.epoch_results.id;


--
-- Name: hub_asset_update_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hub_asset_update_logs (
    id character(120) NOT NULL,
    domain character varying NOT NULL,
    asset_id character varying(66) NOT NULL,
    token_id character varying(66),
    ticker_hash character varying(66) NOT NULL,
    asset_domain character varying(66) NOT NULL,
    kind character varying NOT NULL,
    asset_hash character varying(66) NOT NULL,
    adopted character varying(66) NOT NULL,
    approval boolean NOT NULL,
    strategy character varying(255) NOT NULL,
    transaction_hash character(130) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL
);


--
-- Name: hub_deposits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hub_deposits (
    id character(66) NOT NULL,
    intent_id character(66) NOT NULL,
    epoch bigint NOT NULL,
    ticker_hash character(66) NOT NULL,
    domain character varying(66) NOT NULL,
    amount character varying(255) NOT NULL,
    enqueued_tx_nonce bigint NOT NULL,
    enqueued_timestamp bigint NOT NULL,
    processed_tx_nonce bigint,
    processed_timestamp bigint,
    auto_id bigint NOT NULL
);


--
-- Name: hub_deposits_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hub_deposits_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hub_deposits_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hub_deposits_auto_id_seq OWNED BY public.hub_deposits.auto_id;


--
-- Name: hub_intents_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hub_intents_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hub_intents_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hub_intents_auto_id_seq OWNED BY public.hub_intents.auto_id;


--
-- Name: hub_intents_status_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hub_intents_status_log (
    id integer NOT NULL,
    hub_intent_id character(66) NOT NULL,
    new_status public.intent_status,
    changed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: hub_intents_status_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hub_intents_status_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hub_intents_status_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hub_intents_status_log_id_seq OWNED BY public.hub_intents_status_log.id;


--
-- Name: hub_invoices_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hub_invoices_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hub_invoices_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hub_invoices_auto_id_seq OWNED BY public.hub_invoices.auto_id;


--
-- Name: hub_meta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hub_meta (
    id character(120) NOT NULL,
    domain character varying NOT NULL,
    paused boolean,
    owner character varying(66),
    proposed_owner character varying(66),
    proposed_ownership_timestamp bigint,
    gateway character varying(66),
    watchtower character varying(66),
    manager character varying(66),
    settler character varying(66),
    min_solver_supported_domains bigint,
    expiry_time_buffer bigint,
    discount_per_epoch bigint,
    epoch_length bigint,
    mailbox character varying(66),
    security_module character varying(66),
    acceptance_delay bigint,
    supported_domains jsonb,
    chain_gateways jsonb
);


--
-- Name: hub_token_update_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hub_token_update_logs (
    id character(120) NOT NULL,
    domain character varying NOT NULL,
    ticker_hash character varying(66) NOT NULL,
    kind character varying NOT NULL,
    fee_recipients character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    fee_amounts character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    max_discount_bps bigint NOT NULL,
    discount_per_epoch bigint NOT NULL,
    prioritized_strategy character varying(255) NOT NULL,
    transaction_hash character(130) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL
);


--
-- Name: lock_positions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lock_positions (
    "user" character varying(66) NOT NULL,
    amount_locked character varying(255) NOT NULL,
    start bigint NOT NULL,
    expiry bigint NOT NULL
);


--
-- Name: merkle_trees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merkle_trees (
    id integer NOT NULL,
    asset character varying(66) NOT NULL,
    root character varying NOT NULL,
    epoch_end_timestamp timestamp without time zone NOT NULL,
    merkle_tree character varying NOT NULL,
    proof character varying NOT NULL,
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: merkle_trees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.merkle_trees_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: merkle_trees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.merkle_trees_id_seq OWNED BY public.merkle_trees.id;


--
-- Name: messages_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_auto_id_seq OWNED BY public.messages.auto_id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id character varying(66) NOT NULL,
    auto_id integer NOT NULL,
    token_fee character varying(255) NOT NULL,
    native_fee character varying(255) NOT NULL,
    intent_ids character varying(66)[] NOT NULL,
    initiator character varying(66) NOT NULL,
    transaction_hash character(66) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL,
    gas_limit bigint NOT NULL,
    gas_price bigint NOT NULL
);


--
-- Name: orders_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_auto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_auto_id_seq OWNED BY public.orders.auto_id;


--
-- Name: origin_intents_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.origin_intents_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: origin_intents_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.origin_intents_auto_id_seq OWNED BY public.origin_intents.auto_id;


--
-- Name: origin_intents_status_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.origin_intents_status_log (
    id integer NOT NULL,
    origin_intent_id character(66) NOT NULL,
    new_status public.intent_status,
    changed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: origin_intents_status_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.origin_intents_status_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: origin_intents_status_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.origin_intents_status_log_id_seq OWNED BY public.origin_intents_status_log.id;


--
-- Name: otc_sale_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otc_sale_table (
    order_id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id text NOT NULL,
    origin integer NOT NULL,
    destinations integer[] NOT NULL,
    ticker_hash text NOT NULL,
    amount text NOT NULL,
    total_fee text NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    transaction_hash text,
    expires_at timestamp without time zone
);


--
-- Name: protocol_update_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.protocol_update_logs (
    id character(120) NOT NULL,
    domain character varying NOT NULL,
    event character varying NOT NULL,
    key character varying NOT NULL,
    updated text NOT NULL,
    chain_id character varying(66) NOT NULL,
    transaction_hash character(130) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL
);


--
-- Name: queue_dispatches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.queue_dispatches (
    domain character varying NOT NULL,
    queue_type character varying NOT NULL,
    queue_first bigint NOT NULL,
    queue_last bigint NOT NULL,
    task_id character varying NOT NULL,
    relayer_type character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    dispatched_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: queues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.queues (
    id character varying(255) NOT NULL,
    domain character varying(66) NOT NULL,
    last_processed bigint,
    size bigint NOT NULL,
    first bigint NOT NULL,
    last bigint NOT NULL,
    type public.queue_type NOT NULL,
    ticker_hash character varying(255),
    epoch bigint
);


--
-- Name: queues_type_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.queues_type_log (
    id integer NOT NULL,
    queue_id character(66) NOT NULL,
    new_type public.queue_type NOT NULL,
    changed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: queues_type_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.queues_type_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: queues_type_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.queues_type_log_id_seq OWNED BY public.queues_type_log.id;


--
-- Name: rewards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rewards (
    id integer NOT NULL,
    account character varying(66) NOT NULL,
    asset character varying(66) NOT NULL,
    merkle_root character varying NOT NULL,
    proof character varying NOT NULL,
    stake_apy character varying NOT NULL,
    stake_rewards character varying NOT NULL,
    total_clear_staked character varying NOT NULL,
    protocol_rewards character varying DEFAULT '0'::character varying NOT NULL,
    epoch_timestamp timestamp without time zone NOT NULL,
    proof_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    cumulative_rewards character varying DEFAULT '0'::character varying NOT NULL
);


--
-- Name: rewards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rewards_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rewards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rewards_id_seq OWNED BY public.rewards.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: settlement_intents_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.settlement_intents_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: settlement_intents_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.settlement_intents_auto_id_seq OWNED BY public.settlement_intents.auto_id;


--
-- Name: solana_lookup_tables; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solana_lookup_tables (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_address text NOT NULL,
    mint_address text NOT NULL,
    user_token_account text NOT NULL,
    program_vault_account text NOT NULL,
    lookup_table_address text NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    chain_id integer NOT NULL,
    slot integer NOT NULL
);


--
-- Name: spoke_meta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spoke_meta (
    id character(120) NOT NULL,
    domain character varying NOT NULL,
    paused boolean,
    gateway character varying(66),
    lighthouse character varying(66),
    message_receiver character varying(66),
    watchtower character varying(66),
    message_gas_limit bigint,
    fee_adapter character varying(66),
    fee_adapter_recipient character varying(66),
    fill_signer character varying(66),
    fee_signer character varying(66),
    mailbox character varying(66),
    security_module character varying(66),
    module_for_strategies jsonb
);


--
-- Name: swap_fills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swap_fills (
    id integer NOT NULL,
    intent_id character varying(66) NOT NULL,
    fill_tx_hash character varying(66) NOT NULL,
    distribution_tx_hash character varying(66),
    fill_method character varying(20) NOT NULL,
    filled_at bigint NOT NULL,
    distributed_at bigint,
    gas_used character varying(78)
);


--
-- Name: swap_fills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.swap_fills_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: swap_fills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.swap_fills_id_seq OWNED BY public.swap_fills.id;


--
-- Name: swap_intents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swap_intents (
    intent_id character varying(66) NOT NULL,
    swap_pair_id character varying(50) NOT NULL,
    origin_chain character varying(20) NOT NULL,
    destination_chain character varying(20) NOT NULL,
    input_amount character varying(78) NOT NULL,
    expected_output_amount character varying(78) NOT NULL,
    actual_output_amount character varying(78),
    margin_bps integer NOT NULL,
    swap_rate character varying(78) NOT NULL,
    swap_identifier character varying(66) NOT NULL,
    micky_address character varying(66) NOT NULL,
    user_address character varying(66) NOT NULL,
    status character varying(20) NOT NULL,
    fill_method character varying(20),
    fill_timestamp bigint,
    created_at bigint NOT NULL,
    updated_at bigint NOT NULL
);


--
-- Name: swap_inventory_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.swap_inventory_snapshots (
    id integer NOT NULL,
    chain character varying(20) NOT NULL,
    asset character varying(66) NOT NULL,
    total_inventory character varying(78) NOT NULL,
    reserved_inventory character varying(78) NOT NULL,
    available_inventory character varying(78) NOT NULL,
    "timestamp" bigint NOT NULL,
    pending_inventory character varying(78) NOT NULL,
    reserved_count integer DEFAULT 0 NOT NULL,
    pending_count integer DEFAULT 0 NOT NULL
);


--
-- Name: swap_inventory_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.swap_inventory_snapshots_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: swap_inventory_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.swap_inventory_snapshots_id_seq OWNED BY public.swap_inventory_snapshots.id;


--
-- Name: tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tokens (
    id character(66) NOT NULL,
    fee_recipients character varying[],
    fee_amounts character varying[],
    max_discount_bps bigint NOT NULL,
    discount_per_epoch bigint NOT NULL,
    prioritized_strategy character varying(255) NOT NULL
);


--
-- Name: solana_spoke_instructions; Type: TABLE; Schema: solana; Owner: -
--

CREATE TABLE solana.solana_spoke_instructions (
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
    parsed text
);


--
-- Name: bridge_in_error; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.bridge_in_error (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    "timestamp" numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: bridge_updated; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.bridge_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    old_bridge bytea NOT NULL,
    new_bridge bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: bridged_in; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.bridged_in (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    src_chain_id numeric NOT NULL,
    sender bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: bridged_lock; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.bridged_lock (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    chain_id numeric NOT NULL,
    sender bytea NOT NULL,
    amount numeric NOT NULL,
    expiry numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: bridged_lock_error; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.bridged_lock_error (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    receiver bytea NOT NULL,
    amount numeric NOT NULL,
    expiry numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: bridged_out; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.bridged_out (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    dst_chain_id numeric NOT NULL,
    bridge_user bytea NOT NULL,
    token_receiver bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: chain_gateway_added; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.chain_gateway_added (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    chain_id numeric NOT NULL,
    gateway bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: chain_gateway_removed; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.chain_gateway_removed (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    chain_id numeric NOT NULL,
    gateway bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: early_exit; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.early_exit (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    "user" bytea NOT NULL,
    amount_unlocked numeric NOT NULL,
    amount_received numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: eip712_domain_changed; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.eip712_domain_changed (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: epoch_rewards_updated; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.epoch_rewards_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    epoch numeric[] NOT NULL,
    rewards numeric[] NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: eth_withdrawn; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.eth_withdrawn (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    sender bytea NOT NULL,
    amount numeric NOT NULL,
    withdraw_id numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: fee_info; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.fee_info (
    vid bigint NOT NULL,
    block_range text NOT NULL,
    id bytea NOT NULL,
    domain numeric NOT NULL,
    fee numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: gateway_updated; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.gateway_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    old_gateway bytea NOT NULL,
    new_gateway bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: hub_gauge_updated; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.hub_gauge_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    hub_gauge bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: lock_position; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.lock_position (
    vid bigint NOT NULL,
    block_range text NOT NULL,
    id bytea NOT NULL,
    owner bytea NOT NULL,
    delegate bytea NOT NULL,
    amount numeric NOT NULL,
    expiry numeric NOT NULL,
    vb_balance numeric NOT NULL,
    bias numeric NOT NULL,
    slope numeric NOT NULL,
    "timestamp" numeric NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL
);


--
-- Name: mailbox_updated; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.mailbox_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    old_mailbox bytea NOT NULL,
    new_mailbox bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: message_gas_limit_updated; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.message_gas_limit_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    domain numeric[] NOT NULL,
    old_gas_limit numeric[] NOT NULL,
    new_gas_limit numeric[] NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: mint_message_sent; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.mint_message_sent (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    sender bytea NOT NULL,
    amount numeric NOT NULL,
    domain numeric NOT NULL,
    message_id bytea NOT NULL,
    fee_spent numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: new_lock_position; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.new_lock_position (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    caller bytea NOT NULL,
    "user" bytea NOT NULL,
    new_total_amount_locked numeric NOT NULL,
    expiry numeric NOT NULL,
    new_vb_balance numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: ownership_transferred; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.ownership_transferred (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    previous_owner bytea NOT NULL,
    new_owner bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: process_error; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.process_error (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    nonce numeric NOT NULL,
    error_id integer NOT NULL,
    sender bytea NOT NULL,
    amount numeric NOT NULL,
    additional_data numeric NOT NULL,
    active boolean NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: retry_bridge_out; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.retry_bridge_out (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    domain numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: retry_lock; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.retry_lock (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    receiver bytea NOT NULL,
    amount numeric NOT NULL,
    expiry numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: retry_message; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.retry_message (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    domain numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: retry_mint; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.retry_mint (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    chain_id numeric NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: retry_transfer; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.retry_transfer (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    error_id numeric NOT NULL,
    chain_id numeric NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: return_fee_updated; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.return_fee_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    domain numeric[] NOT NULL,
    old_fee numeric[] NOT NULL,
    new_fee numeric[] NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: reward_claimed; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.reward_claimed (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    token bytea NOT NULL,
    account bytea NOT NULL,
    amount numeric NOT NULL,
    update_count numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: reward_metadata_updated; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.reward_metadata_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    token bytea NOT NULL,
    merkle_root bytea NOT NULL,
    proof bytea NOT NULL,
    update_count numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: rewards_claimed; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.rewards_claimed (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    recipient bytea NOT NULL,
    epoch numeric NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: security_module_updated; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.security_module_updated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    contract bytea NOT NULL,
    old_security_module bytea NOT NULL,
    new_security_module bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: user; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics."user" (
    vid bigint NOT NULL,
    block_range text NOT NULL,
    id bytea NOT NULL,
    claimed numeric NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL
);


--
-- Name: vote_cast; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.vote_cast (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    owner bytea NOT NULL,
    domain numeric NOT NULL,
    votes numeric NOT NULL,
    epoch numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: vote_delegated; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.vote_delegated (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    "user" bytea NOT NULL,
    delegate bytea NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: withdraw; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.withdraw (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    "user" bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: withdraw_eth; Type: TABLE; Schema: tokenomics; Owner: -
--

CREATE TABLE tokenomics.withdraw_eth (
    vid bigint NOT NULL,
    block integer NOT NULL,
    id bytea NOT NULL,
    receiver bytea NOT NULL,
    amount numeric NOT NULL,
    block_number numeric NOT NULL,
    block_timestamp numeric NOT NULL,
    transaction_hash bytea NOT NULL,
    _gs_chain text NOT NULL,
    _gs_gid text NOT NULL,
    insert_timestamp timestamp without time zone,
    latency interval
);


--
-- Name: fill_queue; Type: TABLE; Schema: tron; Owner: -
--

CREATE TABLE tron.fill_queue (
    queue_idx bigint NOT NULL,
    intent_id text,
    message_id text,
    message_timestamp bigint
);


--
-- Name: intent_queue; Type: TABLE; Schema: tron; Owner: -
--

CREATE TABLE tron.intent_queue (
    queue_idx bigint NOT NULL,
    intent_id text,
    message_id text,
    message_timestamp bigint
);


--
-- Name: origin_intents; Type: TABLE; Schema: tron; Owner: -
--

CREATE TABLE tron.origin_intents (
    id text NOT NULL,
    native_fee text,
    token_fee text,
    fee_adapter_initiator text,
    order_id text,
    order_initiator text
);


--
-- Name: tron_spoke_raw_logs; Type: TABLE; Schema: tron; Owner: -
--

CREATE TABLE tron.tron_spoke_raw_logs (
    id text NOT NULL,
    block_number bigint,
    block_hash text,
    transaction_hash text,
    transaction_index bigint,
    log_index bigint,
    address text,
    data text,
    topics text,
    block_timestamp bigint
);


--
-- Name: destination_intents auto_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destination_intents ALTER COLUMN auto_id SET DEFAULT nextval('public.destination_intents_auto_id_seq'::regclass);


--
-- Name: destination_intents_status_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destination_intents_status_log ALTER COLUMN id SET DEFAULT nextval('public.destination_intents_status_log_id_seq'::regclass);


--
-- Name: epoch_results id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_results ALTER COLUMN id SET DEFAULT nextval('public.epoch_results_id_seq'::regclass);


--
-- Name: hub_deposits auto_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_deposits ALTER COLUMN auto_id SET DEFAULT nextval('public.hub_deposits_auto_id_seq'::regclass);


--
-- Name: hub_intents auto_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_intents ALTER COLUMN auto_id SET DEFAULT nextval('public.hub_intents_auto_id_seq'::regclass);


--
-- Name: hub_intents_status_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_intents_status_log ALTER COLUMN id SET DEFAULT nextval('public.hub_intents_status_log_id_seq'::regclass);


--
-- Name: hub_invoices auto_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_invoices ALTER COLUMN auto_id SET DEFAULT nextval('public.hub_invoices_auto_id_seq'::regclass);


--
-- Name: merkle_trees id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merkle_trees ALTER COLUMN id SET DEFAULT nextval('public.merkle_trees_id_seq'::regclass);


--
-- Name: messages auto_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN auto_id SET DEFAULT nextval('public.messages_auto_id_seq'::regclass);


--
-- Name: orders auto_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN auto_id SET DEFAULT nextval('public.orders_auto_id_seq'::regclass);


--
-- Name: origin_intents auto_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_intents ALTER COLUMN auto_id SET DEFAULT nextval('public.origin_intents_auto_id_seq'::regclass);


--
-- Name: origin_intents_status_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_intents_status_log ALTER COLUMN id SET DEFAULT nextval('public.origin_intents_status_log_id_seq'::regclass);


--
-- Name: queues_type_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.queues_type_log ALTER COLUMN id SET DEFAULT nextval('public.queues_type_log_id_seq'::regclass);


--
-- Name: rewards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rewards ALTER COLUMN id SET DEFAULT nextval('public.rewards_id_seq'::regclass);


--
-- Name: settlement_intents auto_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_intents ALTER COLUMN auto_id SET DEFAULT nextval('public.settlement_intents_auto_id_seq'::regclass);


--
-- Name: swap_fills id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swap_fills ALTER COLUMN id SET DEFAULT nextval('public.swap_fills_id_seq'::regclass);


--
-- Name: swap_inventory_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swap_inventory_snapshots ALTER COLUMN id SET DEFAULT nextval('public.swap_inventory_snapshots_id_seq'::regclass);


--
-- Name: alert_triage_log alert_triage_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_triage_log
    ADD CONSTRAINT alert_triage_log_pkey PRIMARY KEY (fingerprint);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: balances balances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.balances
    ADD CONSTRAINT balances_pkey PRIMARY KEY (id);


--
-- Name: checkpoints checkpoints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkpoints
    ADD CONSTRAINT checkpoints_pkey PRIMARY KEY (check_name);


--
-- Name: depositors depositors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.depositors
    ADD CONSTRAINT depositors_pkey PRIMARY KEY (id);


--
-- Name: destination_intents destination_intents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destination_intents
    ADD CONSTRAINT destination_intents_pkey PRIMARY KEY (id);


--
-- Name: destination_intents_status_log destination_intents_status_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destination_intents_status_log
    ADD CONSTRAINT destination_intents_status_log_pkey PRIMARY KEY (id);


--
-- Name: epoch_results epoch_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.epoch_results
    ADD CONSTRAINT epoch_results_pkey PRIMARY KEY (id);


--
-- Name: hub_asset_update_logs hub_asset_update_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_asset_update_logs
    ADD CONSTRAINT hub_asset_update_logs_pkey PRIMARY KEY (id);


--
-- Name: hub_deposits hub_deposits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_deposits
    ADD CONSTRAINT hub_deposits_pkey PRIMARY KEY (id);


--
-- Name: hub_intents hub_intents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_intents
    ADD CONSTRAINT hub_intents_pkey PRIMARY KEY (id);


--
-- Name: hub_intents_status_log hub_intents_status_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_intents_status_log
    ADD CONSTRAINT hub_intents_status_log_pkey PRIMARY KEY (id);


--
-- Name: hub_invoices hub_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_invoices
    ADD CONSTRAINT hub_invoices_pkey PRIMARY KEY (id);


--
-- Name: hub_meta hub_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_meta
    ADD CONSTRAINT hub_meta_pkey PRIMARY KEY (id);


--
-- Name: hub_token_update_logs hub_token_update_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hub_token_update_logs
    ADD CONSTRAINT hub_token_update_logs_pkey PRIMARY KEY (id);


--
-- Name: lock_positions lock_positions_user_start_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lock_positions
    ADD CONSTRAINT lock_positions_user_start_pkey PRIMARY KEY ("user", start);


--
-- Name: merkle_trees merkle_trees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merkle_trees
    ADD CONSTRAINT merkle_trees_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: origin_intents origin_intents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_intents
    ADD CONSTRAINT origin_intents_pkey PRIMARY KEY (id);


--
-- Name: origin_intents_status_log origin_intents_status_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_intents_status_log
    ADD CONSTRAINT origin_intents_status_log_pkey PRIMARY KEY (id);


--
-- Name: otc_sale_table otc_sale_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otc_sale_table
    ADD CONSTRAINT otc_sale_table_pkey PRIMARY KEY (order_id);


--
-- Name: protocol_update_logs protocol_update_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.protocol_update_logs
    ADD CONSTRAINT protocol_update_logs_pkey PRIMARY KEY (id);


--
-- Name: queue_dispatches queue_dispatches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.queue_dispatches
    ADD CONSTRAINT queue_dispatches_pkey PRIMARY KEY (domain, queue_type, queue_first, queue_last);


--
-- Name: queues queues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.queues
    ADD CONSTRAINT queues_pkey PRIMARY KEY (id);


--
-- Name: queues_type_log queues_type_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.queues_type_log
    ADD CONSTRAINT queues_type_log_pkey PRIMARY KEY (id);


--
-- Name: rewards rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rewards
    ADD CONSTRAINT rewards_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: settlement_intents settlement_intents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_intents
    ADD CONSTRAINT settlement_intents_pkey PRIMARY KEY (id);


--
-- Name: solana_lookup_tables solana_lookup_tables_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solana_lookup_tables
    ADD CONSTRAINT solana_lookup_tables_pkey PRIMARY KEY (id);


--
-- Name: solana_lookup_tables solana_lookup_tables_user_address_mint_address_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solana_lookup_tables
    ADD CONSTRAINT solana_lookup_tables_user_address_mint_address_key UNIQUE (user_address, mint_address);


--
-- Name: spoke_meta spoke_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spoke_meta
    ADD CONSTRAINT spoke_meta_pkey PRIMARY KEY (id);


--
-- Name: swap_fills swap_fills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swap_fills
    ADD CONSTRAINT swap_fills_pkey PRIMARY KEY (id);


--
-- Name: swap_intents swap_intents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swap_intents
    ADD CONSTRAINT swap_intents_pkey PRIMARY KEY (intent_id);


--
-- Name: swap_inventory_snapshots swap_inventory_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swap_inventory_snapshots
    ADD CONSTRAINT swap_inventory_snapshots_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: solana_spoke_instructions solana_spoke_instructions_pkey; Type: CONSTRAINT; Schema: solana; Owner: -
--

ALTER TABLE ONLY solana.solana_spoke_instructions
    ADD CONSTRAINT solana_spoke_instructions_pkey PRIMARY KEY (id);


--
-- Name: bridge_in_error bridge_in_error_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.bridge_in_error
    ADD CONSTRAINT bridge_in_error_pkey PRIMARY KEY (_gs_gid);


--
-- Name: bridge_updated bridge_updated_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.bridge_updated
    ADD CONSTRAINT bridge_updated_pkey PRIMARY KEY (_gs_gid);


--
-- Name: bridged_in bridged_in_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.bridged_in
    ADD CONSTRAINT bridged_in_pkey PRIMARY KEY (_gs_gid);


--
-- Name: bridged_lock_error bridged_lock_error_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.bridged_lock_error
    ADD CONSTRAINT bridged_lock_error_pkey PRIMARY KEY (_gs_gid);


--
-- Name: bridged_lock bridged_lock_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.bridged_lock
    ADD CONSTRAINT bridged_lock_pkey PRIMARY KEY (_gs_gid);


--
-- Name: bridged_out bridged_out_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.bridged_out
    ADD CONSTRAINT bridged_out_pkey PRIMARY KEY (_gs_gid);


--
-- Name: chain_gateway_added chain_gateway_added_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.chain_gateway_added
    ADD CONSTRAINT chain_gateway_added_pkey PRIMARY KEY (_gs_gid);


--
-- Name: chain_gateway_removed chain_gateway_removed_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.chain_gateway_removed
    ADD CONSTRAINT chain_gateway_removed_pkey PRIMARY KEY (_gs_gid);


--
-- Name: early_exit early_exit_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.early_exit
    ADD CONSTRAINT early_exit_pkey PRIMARY KEY (_gs_gid);


--
-- Name: eip712_domain_changed eip712_domain_changed_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.eip712_domain_changed
    ADD CONSTRAINT eip712_domain_changed_pkey PRIMARY KEY (_gs_gid);


--
-- Name: epoch_rewards_updated epoch_rewards_updated_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.epoch_rewards_updated
    ADD CONSTRAINT epoch_rewards_updated_pkey PRIMARY KEY (_gs_gid);


--
-- Name: eth_withdrawn eth_withdrawn_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.eth_withdrawn
    ADD CONSTRAINT eth_withdrawn_pkey PRIMARY KEY (_gs_gid);


--
-- Name: fee_info fee_info_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.fee_info
    ADD CONSTRAINT fee_info_pkey PRIMARY KEY (_gs_gid);


--
-- Name: gateway_updated gateway_updated_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.gateway_updated
    ADD CONSTRAINT gateway_updated_pkey PRIMARY KEY (_gs_gid);


--
-- Name: hub_gauge_updated hub_gauge_updated_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.hub_gauge_updated
    ADD CONSTRAINT hub_gauge_updated_pkey PRIMARY KEY (_gs_gid);


--
-- Name: lock_position lock_position_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.lock_position
    ADD CONSTRAINT lock_position_pkey PRIMARY KEY (_gs_gid);


--
-- Name: mailbox_updated mailbox_updated_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.mailbox_updated
    ADD CONSTRAINT mailbox_updated_pkey PRIMARY KEY (_gs_gid);


--
-- Name: message_gas_limit_updated message_gas_limit_updated_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.message_gas_limit_updated
    ADD CONSTRAINT message_gas_limit_updated_pkey PRIMARY KEY (_gs_gid);


--
-- Name: mint_message_sent mint_message_sent_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.mint_message_sent
    ADD CONSTRAINT mint_message_sent_pkey PRIMARY KEY (_gs_gid);


--
-- Name: new_lock_position new_lock_position_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.new_lock_position
    ADD CONSTRAINT new_lock_position_pkey PRIMARY KEY (_gs_gid);


--
-- Name: ownership_transferred ownership_transferred_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.ownership_transferred
    ADD CONSTRAINT ownership_transferred_pkey PRIMARY KEY (_gs_gid);


--
-- Name: process_error process_error_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.process_error
    ADD CONSTRAINT process_error_pkey PRIMARY KEY (_gs_gid);


--
-- Name: retry_bridge_out retry_bridge_out_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.retry_bridge_out
    ADD CONSTRAINT retry_bridge_out_pkey PRIMARY KEY (_gs_gid);


--
-- Name: retry_lock retry_lock_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.retry_lock
    ADD CONSTRAINT retry_lock_pkey PRIMARY KEY (_gs_gid);


--
-- Name: retry_message retry_message_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.retry_message
    ADD CONSTRAINT retry_message_pkey PRIMARY KEY (_gs_gid);


--
-- Name: retry_mint retry_mint_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.retry_mint
    ADD CONSTRAINT retry_mint_pkey PRIMARY KEY (_gs_gid);


--
-- Name: retry_transfer retry_transfer_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.retry_transfer
    ADD CONSTRAINT retry_transfer_pkey PRIMARY KEY (_gs_gid);


--
-- Name: return_fee_updated return_fee_updated_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.return_fee_updated
    ADD CONSTRAINT return_fee_updated_pkey PRIMARY KEY (_gs_gid);


--
-- Name: reward_claimed reward_claimed_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.reward_claimed
    ADD CONSTRAINT reward_claimed_pkey PRIMARY KEY (_gs_gid);


--
-- Name: reward_metadata_updated reward_metadata_updated_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.reward_metadata_updated
    ADD CONSTRAINT reward_metadata_updated_pkey PRIMARY KEY (_gs_gid);


--
-- Name: rewards_claimed rewards_claimed_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.rewards_claimed
    ADD CONSTRAINT rewards_claimed_pkey PRIMARY KEY (_gs_gid);


--
-- Name: security_module_updated security_module_updated_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.security_module_updated
    ADD CONSTRAINT security_module_updated_pkey PRIMARY KEY (_gs_gid);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (_gs_gid);


--
-- Name: vote_cast vote_cast_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.vote_cast
    ADD CONSTRAINT vote_cast_pkey PRIMARY KEY (_gs_gid);


--
-- Name: vote_delegated vote_delegated_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.vote_delegated
    ADD CONSTRAINT vote_delegated_pkey PRIMARY KEY (_gs_gid);


--
-- Name: withdraw_eth withdraw_eth_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.withdraw_eth
    ADD CONSTRAINT withdraw_eth_pkey PRIMARY KEY (_gs_gid);


--
-- Name: withdraw withdraw_pkey; Type: CONSTRAINT; Schema: tokenomics; Owner: -
--

ALTER TABLE ONLY tokenomics.withdraw
    ADD CONSTRAINT withdraw_pkey PRIMARY KEY (_gs_gid);


--
-- Name: origin_intents origin_intents_pkey; Type: CONSTRAINT; Schema: tron; Owner: -
--

ALTER TABLE ONLY tron.origin_intents
    ADD CONSTRAINT origin_intents_pkey PRIMARY KEY (id);


--
-- Name: fill_queue tron_fill_queue_pkey; Type: CONSTRAINT; Schema: tron; Owner: -
--

ALTER TABLE ONLY tron.fill_queue
    ADD CONSTRAINT tron_fill_queue_pkey PRIMARY KEY (queue_idx);


--
-- Name: intent_queue tron_intent_queue_pkey; Type: CONSTRAINT; Schema: tron; Owner: -
--

ALTER TABLE ONLY tron.intent_queue
    ADD CONSTRAINT tron_intent_queue_pkey PRIMARY KEY (queue_idx);


--
-- Name: tron_spoke_raw_logs tron_spoke_raw_logs_pkey; Type: CONSTRAINT; Schema: tron; Owner: -
--

ALTER TABLE ONLY tron.tron_spoke_raw_logs
    ADD CONSTRAINT tron_spoke_raw_logs_pkey PRIMARY KEY (id);


--
-- Name: assets_domain_token_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assets_domain_token_id_idx ON public.assets USING btree (token_id, domain);


--
-- Name: daily_metrics_by_chains_tokens_day_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_metrics_by_chains_tokens_day_index ON public.daily_metrics_by_chains_tokens USING btree (day);


--
-- Name: daily_metrics_by_chains_tokens_from_asset_address_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_metrics_by_chains_tokens_from_asset_address_index ON public.daily_metrics_by_chains_tokens USING btree (from_asset_address);


--
-- Name: daily_metrics_by_chains_tokens_from_asset_symbol_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_metrics_by_chains_tokens_from_asset_symbol_index ON public.daily_metrics_by_chains_tokens USING btree (from_asset_symbol);


--
-- Name: daily_metrics_by_chains_tokens_from_chain_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_metrics_by_chains_tokens_from_chain_id_index ON public.daily_metrics_by_chains_tokens USING btree (from_chain_id);


--
-- Name: daily_metrics_by_chains_tokens_to_asset_address_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_metrics_by_chains_tokens_to_asset_address_index ON public.daily_metrics_by_chains_tokens USING btree (to_asset_address);


--
-- Name: daily_metrics_by_chains_tokens_to_asset_symbol_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_metrics_by_chains_tokens_to_asset_symbol_index ON public.daily_metrics_by_chains_tokens USING btree (to_asset_symbol);


--
-- Name: daily_metrics_by_chains_tokens_to_chain_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_metrics_by_chains_tokens_to_chain_id_index ON public.daily_metrics_by_chains_tokens USING btree (to_chain_id);


--
-- Name: daily_metrics_by_date_day_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX daily_metrics_by_date_day_index ON public.daily_metrics_by_date USING btree (day);


--
-- Name: destination_intents_auto_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX destination_intents_auto_id_index ON public.destination_intents USING btree (auto_id);


--
-- Name: destination_intents_destination_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX destination_intents_destination_status_idx ON public.destination_intents USING btree (filled_domain, status);


--
-- Name: destination_intents_tx_nonce_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX destination_intents_tx_nonce_idx ON public.destination_intents USING btree (tx_nonce);


--
-- Name: hub_asset_update_logs_asset_domain_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_asset_update_logs_asset_domain_idx ON public.hub_asset_update_logs USING btree (asset_domain);


--
-- Name: hub_asset_update_logs_asset_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_asset_update_logs_asset_id_idx ON public.hub_asset_update_logs USING btree (asset_id);


--
-- Name: hub_asset_update_logs_block_number_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_asset_update_logs_block_number_idx ON public.hub_asset_update_logs USING btree (block_number);


--
-- Name: hub_asset_update_logs_ticker_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_asset_update_logs_ticker_hash_idx ON public.hub_asset_update_logs USING btree (ticker_hash);


--
-- Name: hub_asset_update_logs_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_asset_update_logs_timestamp_idx ON public.hub_asset_update_logs USING btree ("timestamp");


--
-- Name: hub_deposits_auto_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_deposits_auto_id_index ON public.hub_deposits USING btree (auto_id);


--
-- Name: hub_intents_auto_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_intents_auto_id_index ON public.hub_intents USING btree (auto_id);


--
-- Name: hub_invoices_auto_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_invoices_auto_id_index ON public.hub_invoices USING btree (auto_id);


--
-- Name: hub_invoices_domain_status_queue_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_invoices_domain_status_queue_id_idx ON public.hub_invoices USING btree (owner, id);


--
-- Name: hub_meta_domain_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_meta_domain_idx ON public.hub_meta USING btree (domain);


--
-- Name: hub_token_update_logs_block_number_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_token_update_logs_block_number_idx ON public.hub_token_update_logs USING btree (block_number);


--
-- Name: hub_token_update_logs_ticker_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_token_update_logs_ticker_hash_idx ON public.hub_token_update_logs USING btree (ticker_hash);


--
-- Name: hub_token_update_logs_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hub_token_update_logs_timestamp_idx ON public.hub_token_update_logs USING btree ("timestamp");


--
-- Name: idx_alert_triage_log_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_alert_triage_log_created_at ON public.alert_triage_log USING btree (created_at);


--
-- Name: idx_alert_triage_log_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_alert_triage_log_expires_at ON public.alert_triage_log USING btree (expires_at);


--
-- Name: idx_alert_triage_log_type_env; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_alert_triage_log_type_env ON public.alert_triage_log USING btree (report_type, env);


--
-- Name: idx_epoch_results_account_domain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_epoch_results_account_domain ON public.epoch_results USING btree (account, domain);


--
-- Name: idx_epoch_results_epoch_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_epoch_results_epoch_timestamp ON public.epoch_results USING btree (epoch_timestamp);


--
-- Name: idx_epoch_results_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_epoch_results_id ON public.epoch_results USING btree (id);


--
-- Name: idx_fill_intent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fill_intent ON public.swap_fills USING btree (intent_id);


--
-- Name: idx_merkle_trees_asset; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_merkle_trees_asset ON public.merkle_trees USING btree (asset);


--
-- Name: idx_merkle_trees_epoch_end_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_merkle_trees_epoch_end_timestamp ON public.merkle_trees USING btree (epoch_end_timestamp);


--
-- Name: idx_merkle_trees_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_merkle_trees_id ON public.merkle_trees USING btree (id);


--
-- Name: idx_merkle_trees_root; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_merkle_trees_root ON public.merkle_trees USING btree (root);


--
-- Name: idx_origin_intents_is_swap; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_origin_intents_is_swap ON public.origin_intents USING btree (is_swap);


--
-- Name: idx_proofs_initiator; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_proofs_initiator ON public.rewards USING btree (account);


--
-- Name: idx_proofs_initiator_merkle_root_proof; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_proofs_initiator_merkle_root_proof ON public.rewards USING btree (account, merkle_root, proof);


--
-- Name: idx_proofs_merkle_root; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_proofs_merkle_root ON public.rewards USING btree (merkle_root);


--
-- Name: idx_queue_dispatches_dedup; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_queue_dispatches_dedup ON public.queue_dispatches USING btree (domain, queue_type, queue_first, queue_last) WHERE ((status)::text = 'pending'::text);


--
-- Name: idx_queue_dispatches_status_dispatched; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_queue_dispatches_status_dispatched ON public.queue_dispatches USING btree (status, dispatched_at);


--
-- Name: idx_snapshot_chain_asset; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_snapshot_chain_asset ON public.swap_inventory_snapshots USING btree (chain, asset);


--
-- Name: idx_snapshot_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_snapshot_timestamp ON public.swap_inventory_snapshots USING btree ("timestamp");


--
-- Name: idx_swap_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_swap_created ON public.swap_intents USING btree (created_at);


--
-- Name: idx_swap_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_swap_pair ON public.swap_intents USING btree (swap_pair_id);


--
-- Name: idx_swap_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_swap_status ON public.swap_intents USING btree (status);


--
-- Name: idx_swap_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_swap_user ON public.swap_intents USING btree (user_address);


--
-- Name: messages_auto_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_auto_id_index ON public.messages USING btree (auto_id);


--
-- Name: messages_tx_nonce_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_tx_nonce_idx ON public.messages USING btree (tx_nonce);


--
-- Name: orders_auto_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_auto_id_idx ON public.orders USING btree (auto_id);


--
-- Name: origin_intents_auto_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX origin_intents_auto_id_index ON public.origin_intents USING btree (auto_id);


--
-- Name: origin_intents_order_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX origin_intents_order_id_idx ON public.origin_intents USING btree (order_id);


--
-- Name: origin_intents_origin_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX origin_intents_origin_status_idx ON public.origin_intents USING btree (origin, status);


--
-- Name: origin_intents_tx_nonce_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX origin_intents_tx_nonce_idx ON public.origin_intents USING btree (tx_nonce);


--
-- Name: protocol_update_logs_block_number_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX protocol_update_logs_block_number_idx ON public.protocol_update_logs USING btree (block_number);


--
-- Name: protocol_update_logs_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX protocol_update_logs_timestamp_idx ON public.protocol_update_logs USING btree ("timestamp");


--
-- Name: queues_domain_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX queues_domain_type_idx ON public.queues USING btree (domain, type);


--
-- Name: settlement_intents_auto_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settlement_intents_auto_id_index ON public.settlement_intents USING btree (auto_id);


--
-- Name: settlement_intents_id_domain_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settlement_intents_id_domain_index ON public.settlement_intents USING btree (id, domain);


--
-- Name: spoke_meta_domain_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX spoke_meta_domain_idx ON public.spoke_meta USING btree (domain);


--
-- Name: new_lock_position_timestamp_idx; Type: INDEX; Schema: tokenomics; Owner: -
--

CREATE INDEX new_lock_position_timestamp_idx ON tokenomics.new_lock_position USING btree (insert_timestamp);


--
-- Name: reward_claimed_timestamp_idx; Type: INDEX; Schema: tokenomics; Owner: -
--

CREATE INDEX reward_claimed_timestamp_idx ON tokenomics.reward_claimed USING btree (insert_timestamp);


--
-- Name: destination_intents destination_intent_status_change_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER destination_intent_status_change_trigger AFTER UPDATE OF status ON public.destination_intents FOR EACH ROW EXECUTE FUNCTION public.log_destination_intent_status_change();


--
-- Name: hub_intents hub_intent_status_change_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER hub_intent_status_change_trigger AFTER UPDATE OF status ON public.hub_intents FOR EACH ROW EXECUTE FUNCTION public.log_hub_intent_status_change();


--
-- Name: origin_intents origin_intent_status_change_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER origin_intent_status_change_trigger AFTER UPDATE OF status ON public.origin_intents FOR EACH ROW EXECUTE FUNCTION public.log_origin_intent_status_change();


--
-- Name: queues queue_type_change_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER queue_type_change_trigger AFTER UPDATE OF type ON public.queues FOR EACH ROW EXECUTE FUNCTION public.log_queue_type_change();


--
-- Name: destination_intents validate_destination_intent_status_transition; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER validate_destination_intent_status_transition BEFORE UPDATE OF status ON public.destination_intents FOR EACH ROW EXECUTE FUNCTION public.validate_ascending_status_transition();


--
-- Name: hub_intents validate_hub_intent_status_transition; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER validate_hub_intent_status_transition BEFORE UPDATE OF status ON public.hub_intents FOR EACH ROW EXECUTE FUNCTION public.validate_ascending_status_transition();


--
-- Name: origin_intents validate_origin_intent_status_transition; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER validate_origin_intent_status_transition BEFORE UPDATE OF status ON public.origin_intents FOR EACH ROW EXECUTE FUNCTION public.validate_ascending_status_transition();


--
-- Name: settlement_intents validate_settlement_intent_status_transition; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER validate_settlement_intent_status_transition BEFORE UPDATE OF status ON public.settlement_intents FOR EACH ROW EXECUTE FUNCTION public.validate_ascending_status_transition();


--
-- Name: solana_spoke_instructions process_cpi_events_trigger; Type: TRIGGER; Schema: solana; Owner: -
--

CREATE TRIGGER process_cpi_events_trigger BEFORE INSERT OR UPDATE ON solana.solana_spoke_instructions FOR EACH ROW EXECUTE FUNCTION public.process_cpi_events();


--
-- Name: new_lock_position new_lock_position_set_timestamp_and_latency; Type: TRIGGER; Schema: tokenomics; Owner: -
--

CREATE TRIGGER new_lock_position_set_timestamp_and_latency BEFORE INSERT ON tokenomics.new_lock_position FOR EACH ROW EXECUTE FUNCTION tokenomics.set_timestamp_and_latency();


--
-- Name: reward_claimed reward_claimed_set_timestamp_and_latency; Type: TRIGGER; Schema: tokenomics; Owner: -
--

CREATE TRIGGER reward_claimed_set_timestamp_and_latency BEFORE INSERT ON tokenomics.reward_claimed FOR EACH ROW EXECUTE FUNCTION tokenomics.set_timestamp_and_latency();


--
-- Name: tron_spoke_raw_logs process_tron_spoke_events_trigger; Type: TRIGGER; Schema: tron; Owner: -
--

CREATE TRIGGER process_tron_spoke_events_trigger BEFORE INSERT OR UPDATE ON tron.tron_spoke_raw_logs FOR EACH ROW EXECUTE FUNCTION public.process_tron_spoke_events();


--
-- Name: balances balances_account_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.balances
    ADD CONSTRAINT balances_account_fkey FOREIGN KEY (account) REFERENCES public.depositors(id);


--
-- Name: origin_intents origin_intents_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origin_intents
    ADD CONSTRAINT origin_intents_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: swap_fills swap_fills_intent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.swap_fills
    ADD CONSTRAINT swap_fills_intent_id_fkey FOREIGN KEY (intent_id) REFERENCES public.swap_intents(intent_id);


--
-- PostgreSQL database dump complete
--

\unrestrict 91qdweOh5mTVodfEIBpHZn4WexPfX4kRQzL8QqOotlUeBanVg9jWPDyNGmedwe3


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20240430215513'),
    ('20240516020542'),
    ('20240519201521'),
    ('20240528215127'),
    ('20240528232758'),
    ('20240601012138'),
    ('20240610174446'),
    ('20240611233619'),
    ('20240618021124'),
    ('20240620203804'),
    ('20240621164349'),
    ('20240624162844'),
    ('20240624213205'),
    ('20240625121123'),
    ('20240628023432'),
    ('20240630101907'),
    ('20240711215625'),
    ('20240712020202'),
    ('20240716000818'),
    ('20240716024041'),
    ('20240717134849'),
    ('20240718165937'),
    ('20240718183732'),
    ('20240719063119'),
    ('20240719150630'),
    ('20240719224308'),
    ('20240720040612'),
    ('20240721002153'),
    ('20240721191656'),
    ('20240722034446'),
    ('20240723033712'),
    ('20240723230551'),
    ('20240724140303'),
    ('20240725010223'),
    ('20240725135849'),
    ('20240725222348'),
    ('20240726162516'),
    ('20240729105227'),
    ('20240729183207'),
    ('20240802233404'),
    ('20240807053411'),
    ('20240807171452'),
    ('20240808042919'),
    ('20240808161158'),
    ('20240809010310'),
    ('20240809194214'),
    ('20240812103500'),
    ('20240812143819'),
    ('20240812220300'),
    ('20240813122412'),
    ('20240821225802'),
    ('20240826150027'),
    ('20240828152225'),
    ('20240828184702'),
    ('20240829163737'),
    ('20240829164448'),
    ('20240830060205'),
    ('20240909225426'),
    ('20240930174646'),
    ('20241017161719'),
    ('20241017173142'),
    ('20241021172341'),
    ('20241024144602'),
    ('20241024151037'),
    ('20241028060015'),
    ('20241105150146'),
    ('20241105150153'),
    ('20241106180857'),
    ('20241112225945'),
    ('20241125234750'),
    ('20241126223030'),
    ('20241127005743'),
    ('20241127010004'),
    ('20241206021732'),
    ('20241206140725'),
    ('20241217225034'),
    ('20250107062058'),
    ('20250108140315'),
    ('20250321152002'),
    ('20250322012505'),
    ('20250325230805'),
    ('20250410040210'),
    ('20250411120150'),
    ('20250415125459'),
    ('20250415163121'),
    ('20250415204003'),
    ('20250416224500'),
    ('20250417163412'),
    ('20250418160651'),
    ('20250418195903'),
    ('20250421233253'),
    ('20250423160717'),
    ('20250430160025'),
    ('20250522082114'),
    ('20250522084000'),
    ('20250528030214'),
    ('20250530175841'),
    ('20250612163456'),
    ('20250623193039'),
    ('20250624105537'),
    ('20250701013945'),
    ('20250708181540'),
    ('20250708185702'),
    ('20250708190952'),
    ('20250717210433'),
    ('20250726140256'),
    ('20250731212912'),
    ('20250801041441'),
    ('20250801173912'),
    ('20251022134056'),
    ('20251103222403'),
    ('20251104200144'),
    ('20251105135808'),
    ('20251105153713'),
    ('20251106014319'),
    ('20251110024449'),
    ('20251110053118'),
    ('20251110182740'),
    ('20251125175538'),
    ('20251127055400'),
    ('20251202011749'),
    ('20251202161540'),
    ('20251202165553'),
    ('20251205153936'),
    ('20251211224120'),
    ('20260112150248'),
    ('20260203002000'),
    ('20260203200000'),
    ('20260212000100'),
    ('20260213000100'),
    ('20260213194500'),
    ('20260326000100');
