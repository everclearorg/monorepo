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
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: shadow; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA shadow;


--
-- Name: solana; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA solana;


--
-- Name: tokenomics; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA tokenomics;


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
-- Name: create_shadow_mat_view(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_shadow_mat_view(shadow_table_name text, view_name text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec record;
    view_columns TEXT := '';
    add_comma BOOLEAN := FALSE;
BEGIN
    FOR rec IN (SELECT * FROM information_schema.columns WHERE table_schema = 'shadow' AND table_name = shadow_table_name) LOOP
        IF (add_comma) THEN
            view_columns := view_columns || ', ';
        END IF;
        view_columns := view_columns || 'shadow_table.' || rec.column_name;
        add_comma := TRUE;
    END LOOP;

    EXECUTE format('DROP MATERIALIZED VIEW IF EXISTS public.%s', view_name);
    EXECUTE format('CREATE MATERIALIZED VIEW public.%s AS SELECT %s FROM shadow.%s as shadow_table WITH NO DATA', view_name, view_columns, shadow_table_name);
    EXECUTE format('REFRESH MATERIALIZED VIEW public.%s', view_name);
    EXECUTE format('SELECT cron.schedule(''* * * * *'', ''REFRESH MATERIALIZED VIEW public.%s;'')', view_name);
END;
$$;


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
    max_fee INT;
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
	max_fee := to_int(reverse_bytes(SUBSTRING(hex_data, pos, 8)));
	pos := pos + 8;
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
		max_fee,
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
-- Name: set_timestamp_and_latency(); Type: FUNCTION; Schema: shadow; Owner: -
--

CREATE FUNCTION shadow.set_timestamp_and_latency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
            NEW.timestamp := CURRENT_TIMESTAMP;
            NEW.latency := NEW.timestamp - NEW.block_timestamp;
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
-- Name: closedepochsprocessed_fa915858_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.closedepochsprocessed_fa915858_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data___last_closed_epoch_processed bigint,
    data___ticker_hash character varying(66),
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: closedepochsprocessed; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.closedepochsprocessed AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data___last_closed_epoch_processed,
    shadow_table.data___ticker_hash,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.closedepochsprocessed_fa915858_73f6f386 shadow_table
  WITH NO DATA;


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
    transaction_hash character(66) NOT NULL,
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
    return_data character varying
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
    order_id character varying(66)
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
 SELECT origin_intents.id,
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
    public.genstatus(origin_intents.status, hub_intents.status, settlement_intents.status, public.hascalldata(origin_intents.data)) AS status,
    public.hascalldata(origin_intents.data) AS has_calldata,
    hub_intents.auto_id AS hub_auto_id
   FROM (((public.origin_intents
     LEFT JOIN public.destination_intents ON ((origin_intents.id = destination_intents.id)))
     LEFT JOIN public.settlement_intents ON ((origin_intents.id = settlement_intents.id)))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
  WITH NO DATA;


--
-- Name: invoices; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.invoices AS
 SELECT origin_intents.id,
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
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
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
-- Name: depositenqueued_2f2b1630_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.depositenqueued_2f2b1630_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data___amount numeric(78,0),
    data___domain integer,
    data___epoch bigint,
    data___intent_id character varying(66),
    data___ticker_hash character varying(66),
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: depositenqueued; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.depositenqueued AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data___amount,
    shadow_table.data___domain,
    shadow_table.data___epoch,
    shadow_table.data___intent_id,
    shadow_table.data___ticker_hash,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.depositenqueued_2f2b1630_73f6f386 shadow_table
  WITH NO DATA;


--
-- Name: depositprocessed_ffe546d6_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.depositprocessed_ffe546d6_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data___amount_and_rewards numeric(78,0),
    data___domain bigint,
    data___epoch bigint,
    data___intent_id character varying(66),
    data___ticker_hash character varying(66),
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: depositprocessed; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.depositprocessed AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data___amount_and_rewards,
    shadow_table.data___domain,
    shadow_table.data___epoch,
    shadow_table.data___intent_id,
    shadow_table.data___ticker_hash,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.depositprocessed_ffe546d6_73f6f386 shadow_table
  WITH NO DATA;


--
-- Name: deposit_enqueued_not_processed; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.deposit_enqueued_not_processed AS
 SELECT depositenqueued.address,
    depositenqueued.block_hash,
    depositenqueued.block_number,
    depositenqueued.block_timestamp,
    depositenqueued.chain,
    depositenqueued.block_log_index,
    depositenqueued.name,
    depositenqueued.network,
    depositenqueued.topic_0,
    depositenqueued.topic_1,
    depositenqueued.topic_2,
    depositenqueued.topic_3,
    depositenqueued.transaction_hash,
    depositenqueued.transaction_index,
    depositenqueued.transaction_log_index,
    depositenqueued.data___amount,
    depositenqueued.data___domain,
    depositenqueued.data___epoch,
    depositenqueued.data___intent_id,
    depositenqueued.data___ticker_hash,
    depositprocessed.address AS depositprocessed_address,
    depositprocessed.block_hash AS depositprocessed_block_hash,
    depositprocessed.block_number AS depositprocessed_block_number,
    depositprocessed.block_timestamp AS depositprocessed_block_timestamp,
    depositprocessed.chain AS depositprocessed_chain,
    depositprocessed.block_log_index AS depositprocessed_block_log_index,
    depositprocessed.name AS depositprocessed_name,
    depositprocessed.network AS depositprocessed_network,
    depositprocessed.topic_0 AS depositprocessed_topic_0,
    depositprocessed.topic_1 AS depositprocessed_topic_1,
    depositprocessed.topic_2 AS depositprocessed_topic_2,
    depositprocessed.topic_3 AS depositprocessed_topic_3,
    depositprocessed.transaction_hash AS depositprocessed_transaction_hash,
    depositprocessed.transaction_index AS depositprocessed_transaction_index,
    depositprocessed.transaction_log_index AS depositprocessed_transaction_log_index,
    depositprocessed.data___amount_and_rewards AS depositprocessed_data___amount_and_rewards,
    depositprocessed.data___domain AS depositprocessed_data___domain,
    depositprocessed.data___epoch AS depositprocessed_data___epoch,
    depositprocessed.data___intent_id AS depositprocessed_data___intent_id,
    depositprocessed.data___ticker_hash AS depositprocessed_data___ticker_hash
   FROM (public.depositenqueued
     LEFT JOIN public.depositprocessed ON (((depositenqueued.data___intent_id)::text = (depositprocessed.data___intent_id)::text)))
  WHERE (depositprocessed.data___intent_id IS NULL)
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
-- Name: finddepositdomain_2744076b_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.finddepositdomain_2744076b_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data__amount numeric(78,0),
    data__amount_and_rewards numeric(78,0),
    data__destinations jsonb,
    data__highest_liquidity_destination numeric(78,0),
    data__intent_id character varying(66),
    data__is_deposit boolean,
    data__liquidity_in_destinations jsonb,
    data__origin bigint,
    data__selected_destination bigint,
    data__ticker_hash character varying(66),
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: finddepositdomain; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.finddepositdomain AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data__amount,
    shadow_table.data__amount_and_rewards,
    shadow_table.data__destinations,
    shadow_table.data__highest_liquidity_destination,
    shadow_table.data__intent_id,
    shadow_table.data__is_deposit,
    shadow_table.data__liquidity_in_destinations,
    shadow_table.data__origin,
    shadow_table.data__selected_destination,
    shadow_table.data__ticker_hash,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.finddepositdomain_2744076b_73f6f386 shadow_table
  WITH NO DATA;


--
-- Name: findinvoicedomain_e0b68ef7_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.findinvoicedomain_e0b68ef7_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data__amount_after_discount numeric(78,0),
    data__amount_to_be_discoutned numeric(78,0),
    data__current_epoch bigint,
    data__discount_dbps integer,
    data__domain bigint,
    data__entry_epoch bigint,
    data__invoice_amount numeric(78,0),
    data__invoice_intent_id character varying(66),
    data__invoice_owner character varying(66),
    data__liquidity numeric(78,0),
    data__rewards_for_depositors numeric(78,0),
    data__selected_domain bigint,
    data__selected_liquidity numeric(78,0),
    data__ticker_hash character varying(66),
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: findinvoicedomain; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.findinvoicedomain AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data__amount_after_discount,
    shadow_table.data__amount_to_be_discoutned,
    shadow_table.data__current_epoch,
    shadow_table.data__discount_dbps,
    shadow_table.data__domain,
    shadow_table.data__entry_epoch,
    shadow_table.data__invoice_amount,
    shadow_table.data__invoice_intent_id,
    shadow_table.data__invoice_owner,
    shadow_table.data__liquidity,
    shadow_table.data__rewards_for_depositors,
    shadow_table.data__selected_domain,
    shadow_table.data__selected_liquidity,
    shadow_table.data__ticker_hash,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.findinvoicedomain_e0b68ef7_73f6f386 shadow_table
  WITH NO DATA;


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
-- Name: settledeposit_488e0804_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.settledeposit_488e0804_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data__amount numeric(78,0),
    data__amount_after_fees numeric(78,0),
    data__amount_and_rewards numeric(78,0),
    data__destinations jsonb,
    data__input_asset character varying(66),
    data__intent_id character varying(66),
    data__is_deposit boolean,
    data__is_settlement boolean,
    data__origin bigint,
    data__output_asset character varying(66),
    data__rewards numeric(78,0),
    data__selected_destination bigint,
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: settledeposit; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.settledeposit AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data__amount,
    shadow_table.data__amount_after_fees,
    shadow_table.data__amount_and_rewards,
    shadow_table.data__destinations,
    shadow_table.data__input_asset,
    shadow_table.data__intent_id,
    shadow_table.data__is_deposit,
    shadow_table.data__is_settlement,
    shadow_table.data__origin,
    shadow_table.data__output_asset,
    shadow_table.data__rewards,
    shadow_table.data__selected_destination,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.settledeposit_488e0804_73f6f386 shadow_table
  WITH NO DATA;


--
-- Name: intents_with_shadow_data; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.intents_with_shadow_data AS
 SELECT origin_intents.id,
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
    public.genstatus(origin_intents.status, hub_intents.status, settlement_intents.status, public.hascalldata(origin_intents.data)) AS status,
    public.hascalldata(origin_intents.data) AS has_calldata,
    hub_intents.auto_id AS hub_auto_id,
    finddepositdomain.data__amount AS find_deposit_amount,
    finddepositdomain.data__amount_and_rewards AS find_deposit_amount_and_rewards,
    finddepositdomain.data__destinations AS find_deposit_destinations,
    finddepositdomain.data__highest_liquidity_destination AS find_deposit_highest_liquidity_destination,
    finddepositdomain.data__liquidity_in_destinations AS find_deposit_liquidity_in_destinations,
    finddepositdomain.data__origin AS find_deposit_origin,
    finddepositdomain.data__selected_destination AS find_deposit_selected_destination,
    finddepositdomain.data__ticker_hash AS ticker_hash,
    finddepositdomain.data__is_deposit AS is_deposit,
    settledeposit.data__amount AS settle_deposit_amount,
    settledeposit.data__amount_after_fees AS settle_deposit_amount_after_fees,
    settledeposit.data__amount_and_rewards AS settle_deposit_amount_and_rewards,
    settledeposit.data__destinations AS settle_deposit_destinations,
    settledeposit.data__input_asset AS settle_deposit_input_asset,
    settledeposit.data__is_settlement AS settle_deposit_is_settlement,
    settledeposit.data__origin AS settle_deposit_origin,
    settledeposit.data__output_asset AS settle_deposit_output_asset,
    settledeposit.data__rewards AS settle_deposit_rewards,
    settledeposit.data__selected_destination AS settle_deposit_selected_destination
   FROM (((((public.origin_intents
     LEFT JOIN public.destination_intents ON ((origin_intents.id = destination_intents.id)))
     LEFT JOIN public.settlement_intents ON ((origin_intents.id = settlement_intents.id)))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
     LEFT JOIN public.finddepositdomain finddepositdomain ON ((origin_intents.id = (finddepositdomain.data__intent_id)::bpchar)))
     LEFT JOIN public.settledeposit settledeposit ON ((origin_intents.id = (settledeposit.data__intent_id)::bpchar)))
  WITH NO DATA;


--
-- Name: invoiceenqueued_81d2714b_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.invoiceenqueued_81d2714b_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data___amount numeric(78,0),
    data___entry_epoch bigint,
    data___intent_id character varying(66),
    data___owner character varying(66),
    data___ticker_hash character varying(66),
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: invoiceenqueued; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.invoiceenqueued AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data___amount,
    shadow_table.data___entry_epoch,
    shadow_table.data___intent_id,
    shadow_table.data___owner,
    shadow_table.data___ticker_hash,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.invoiceenqueued_81d2714b_73f6f386 shadow_table
  WITH NO DATA;


--
-- Name: settlementenqueued_49194ff9_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.settlementenqueued_49194ff9_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data___amount numeric(78,0),
    data___asset character varying(66),
    data___domain bigint,
    data___entry_epoch bigint,
    data___intent_id character varying(66),
    data___owner character varying(66),
    data___update_virtual_balance boolean,
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: settlementenqueued; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.settlementenqueued AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data___amount,
    shadow_table.data___asset,
    shadow_table.data___domain,
    shadow_table.data___entry_epoch,
    shadow_table.data___intent_id,
    shadow_table.data___owner,
    shadow_table.data___update_virtual_balance,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.settlementenqueued_49194ff9_73f6f386 shadow_table
  WITH NO DATA;


--
-- Name: invoice_enqueued_not_settled; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.invoice_enqueued_not_settled AS
 SELECT invoiceenqueued.address AS invoiceenqueued_address,
    invoiceenqueued.block_hash AS invoiceenqueued_block_hash,
    invoiceenqueued.block_number AS invoiceenqueued_block_number,
    invoiceenqueued.block_timestamp AS invoiceenqueued_block_timestamp,
    invoiceenqueued.chain AS invoiceenqueued_chain,
    invoiceenqueued.block_log_index AS invoiceenqueued_block_log_index,
    invoiceenqueued.name AS invoiceenqueued_name,
    invoiceenqueued.network AS invoiceenqueued_network,
    invoiceenqueued.topic_0 AS invoiceenqueued_topic_0,
    invoiceenqueued.topic_1 AS invoiceenqueued_topic_1,
    invoiceenqueued.topic_2 AS invoiceenqueued_topic_2,
    invoiceenqueued.topic_3 AS invoiceenqueued_topic_3,
    invoiceenqueued.transaction_hash AS invoiceenqueued_transaction_hash,
    invoiceenqueued.transaction_index AS invoiceenqueued_transaction_index,
    invoiceenqueued.transaction_log_index AS invoiceenqueued_transaction_log_index,
    invoiceenqueued.data___amount AS invoiceenqueued_data___amount,
    invoiceenqueued.data___entry_epoch AS invoiceenqueued_data___entry_epoch,
    invoiceenqueued.data___intent_id AS invoiceenqueued_data___intent_id,
    invoiceenqueued.data___owner AS invoiceenqueued_data___owner,
    invoiceenqueued.data___ticker_hash AS invoiceenqueued_data___ticker_hash,
    settlementenqueued.address AS settlementenqueued_address,
    settlementenqueued.block_hash AS settlementenqueued_block_hash,
    settlementenqueued.block_number AS settlementenqueued_block_number,
    settlementenqueued.block_timestamp AS settlementenqueued_block_timestamp,
    settlementenqueued.chain AS settlementenqueued_chain,
    settlementenqueued.block_log_index AS settlementenqueued_block_log_index,
    settlementenqueued.name AS settlementenqueued_name,
    settlementenqueued.network AS settlementenqueued_network,
    settlementenqueued.topic_0 AS settlementenqueued_topic_0,
    settlementenqueued.topic_1 AS settlementenqueued_topic_1,
    settlementenqueued.topic_2 AS settlementenqueued_topic_2,
    settlementenqueued.topic_3 AS settlementenqueued_topic_3,
    settlementenqueued.transaction_hash AS settlementenqueued_transaction_hash,
    settlementenqueued.transaction_index AS settlementenqueued_transaction_index,
    settlementenqueued.transaction_log_index AS settlementenqueued_transaction_log_index,
    settlementenqueued.data___amount AS settlementenqueued_data___amount,
    settlementenqueued.data___asset AS settlementenqueued_data___asset,
    settlementenqueued.data___domain AS settlementenqueued_data___domain,
    settlementenqueued.data___entry_epoch AS settlementenqueued_data___entry_epoch,
    settlementenqueued.data___intent_id AS settlementenqueued_data___intent_id,
    settlementenqueued.data___owner AS settlementenqueued_data___owner,
    settlementenqueued.data___update_virtual_balance AS settlementenqueued_data___update_virtual_balance
   FROM (public.invoiceenqueued
     LEFT JOIN public.settlementenqueued ON (((invoiceenqueued.data___intent_id)::text = (settlementenqueued.data___intent_id)::text)))
  WHERE (settlementenqueued.data___intent_id IS NULL)
  WITH NO DATA;


--
-- Name: matchdeposit_883a2568_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.matchdeposit_883a2568_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data__deposit_intent_id character varying(66),
    data__deposit_purchase_power numeric(78,0),
    data__deposit_rewards numeric(78,0),
    data__discount_dbps integer,
    data__domain bigint,
    data__invoice_amount numeric(78,0),
    data__invoice_intent_id character varying(66),
    data__invoice_owner character varying(66),
    data__match_count numeric(78,0),
    data__remaining_amount numeric(78,0),
    data__selected_amount_after_discount numeric(78,0),
    data__selected_amount_to_be_discounted numeric(78,0),
    data__selected_rewards_for_depositors numeric(78,0),
    data__ticker_hash character varying(66),
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: matchdeposit; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.matchdeposit AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data__deposit_intent_id,
    shadow_table.data__deposit_purchase_power,
    shadow_table.data__deposit_rewards,
    shadow_table.data__discount_dbps,
    shadow_table.data__domain,
    shadow_table.data__invoice_amount,
    shadow_table.data__invoice_intent_id,
    shadow_table.data__invoice_owner,
    shadow_table.data__match_count,
    shadow_table.data__remaining_amount,
    shadow_table.data__selected_amount_after_discount,
    shadow_table.data__selected_amount_to_be_discounted,
    shadow_table.data__selected_rewards_for_depositors,
    shadow_table.data__ticker_hash,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.matchdeposit_883a2568_73f6f386 shadow_table
  WITH NO DATA;


--
-- Name: invoices_with_shadow_data; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.invoices_with_shadow_data AS
 SELECT origin_intents.id,
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
    hub_intents.settlement_epoch AS hub_settlement_epoch,
    COALESCE(findinvoicedomain.data__ticker_hash, matchdeposit.data__ticker_hash) AS ticker_hash,
    findinvoicedomain.data__amount_after_discount AS find_invoice_amount_after_discount,
    findinvoicedomain.data__amount_to_be_discoutned AS find_invoice_amount_to_be_discoutned,
    findinvoicedomain.data__current_epoch AS find_invoice_current_epoch,
    findinvoicedomain.data__discount_dbps AS find_invoice_discount_dbps,
    findinvoicedomain.data__entry_epoch AS find_invoice_entry_epoch,
    findinvoicedomain.data__invoice_amount AS find_invoice_invoice_amount,
    findinvoicedomain.data__invoice_owner AS find_invoice_invoice_owner,
    findinvoicedomain.data__rewards_for_depositors AS find_invoice_rewards_for_depositors,
    findinvoicedomain.data__domain AS find_invoice_current_domain,
    findinvoicedomain.data__selected_domain AS find_invoice_selected_domain,
    findinvoicedomain.data__liquidity AS find_invoice_liquidity,
    findinvoicedomain.data__selected_liquidity AS find_invoice_selected_liquidity,
    matchdeposit.data__deposit_intent_id AS match_deposit_intent_id,
    matchdeposit.data__deposit_purchase_power AS match_deposit_purchase_power,
    matchdeposit.data__deposit_rewards AS match_deposit_rewards,
    matchdeposit.data__discount_dbps AS match_deposit_discount_dbps,
    matchdeposit.data__domain AS match_deposit_domain,
    matchdeposit.data__invoice_amount AS match_deposit_invoice_amount,
    matchdeposit.data__invoice_owner AS match_deposit_invoice_owner,
    matchdeposit.data__match_count AS match_deposit_match_count,
    matchdeposit.data__remaining_amount AS match_deposit_remaining_amount,
    matchdeposit.data__selected_amount_after_discount AS match_deposit_selected_amount_after_discount,
    matchdeposit.data__selected_amount_to_be_discounted AS match_deposit_selected_amount_to_be_discounted,
    matchdeposit.data__selected_rewards_for_depositors AS match_deposit_selected_rewards_for_depositors
   FROM ((((public.hub_invoices
     LEFT JOIN public.origin_intents ON ((origin_intents.id = hub_invoices.intent_id)))
     LEFT JOIN public.hub_intents ON ((origin_intents.id = hub_intents.id)))
     LEFT JOIN public.findinvoicedomain findinvoicedomain ON ((origin_intents.id = (findinvoicedomain.data__invoice_intent_id)::bpchar)))
     LEFT JOIN public.matchdeposit matchdeposit ON ((origin_intents.id = (matchdeposit.data__invoice_intent_id)::bpchar)))
  WITH NO DATA;


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
    version character varying(128) NOT NULL
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
-- Name: settlementqueueprocessed_17786ebb_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.settlementqueueprocessed_17786ebb_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data___amount bigint,
    data___domain bigint,
    data___message_id character varying(66),
    data___quote numeric(78,0),
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: settlementqueueprocessed; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.settlementqueueprocessed AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data___amount,
    shadow_table.data___domain,
    shadow_table.data___message_id,
    shadow_table.data___quote,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.settlementqueueprocessed_17786ebb_73f6f386 shadow_table
  WITH NO DATA;


--
-- Name: settlementsent_dac85f08_73f6f386; Type: TABLE; Schema: shadow; Owner: -
--

CREATE TABLE shadow.settlementsent_dac85f08_73f6f386 (
    address character varying(66) NOT NULL,
    block_hash character varying(66) NOT NULL,
    block_number bigint NOT NULL,
    block_timestamp timestamp without time zone NOT NULL,
    chain character varying(20) NOT NULL,
    block_log_index bigint,
    name character varying(66),
    network character varying(20) NOT NULL,
    topic_0 character varying(66) NOT NULL,
    topic_1 character varying(66),
    topic_2 character varying(66),
    topic_3 character varying(66),
    transaction_hash character varying(66) NOT NULL,
    transaction_index bigint NOT NULL,
    transaction_log_index bigint NOT NULL,
    data__current_epoch bigint,
    data__intent_ids jsonb,
    "timestamp" timestamp without time zone,
    latency interval
);


--
-- Name: settlementsent; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.settlementsent AS
 SELECT shadow_table.address,
    shadow_table.block_hash,
    shadow_table.block_number,
    shadow_table.block_timestamp,
    shadow_table.chain,
    shadow_table.block_log_index,
    shadow_table.name,
    shadow_table.network,
    shadow_table.topic_0,
    shadow_table.topic_1,
    shadow_table.topic_2,
    shadow_table.topic_3,
    shadow_table.transaction_hash,
    shadow_table.transaction_index,
    shadow_table.transaction_log_index,
    shadow_table.data__current_epoch,
    shadow_table.data__intent_ids,
    shadow_table."timestamp",
    shadow_table.latency
   FROM shadow.settlementsent_dac85f08_73f6f386 shadow_table
  WITH NO DATA;


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
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: closedepochsprocessed_fa915858_73f6f386 closedepochsprocessed_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.closedepochsprocessed_fa915858_73f6f386
    ADD CONSTRAINT closedepochsprocessed_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


--
-- Name: depositenqueued_2f2b1630_73f6f386 depositenqueued_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.depositenqueued_2f2b1630_73f6f386
    ADD CONSTRAINT depositenqueued_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


--
-- Name: depositprocessed_ffe546d6_73f6f386 depositprocessed_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.depositprocessed_ffe546d6_73f6f386
    ADD CONSTRAINT depositprocessed_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


--
-- Name: finddepositdomain_2744076b_73f6f386 finddepositdomain_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.finddepositdomain_2744076b_73f6f386
    ADD CONSTRAINT finddepositdomain_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


--
-- Name: findinvoicedomain_e0b68ef7_73f6f386 findinvoicedomain_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.findinvoicedomain_e0b68ef7_73f6f386
    ADD CONSTRAINT findinvoicedomain_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


--
-- Name: invoiceenqueued_81d2714b_73f6f386 invoiceenqueued_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.invoiceenqueued_81d2714b_73f6f386
    ADD CONSTRAINT invoiceenqueued_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


--
-- Name: matchdeposit_883a2568_73f6f386 matchdeposit_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.matchdeposit_883a2568_73f6f386
    ADD CONSTRAINT matchdeposit_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


--
-- Name: settledeposit_488e0804_73f6f386 settledeposit_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.settledeposit_488e0804_73f6f386
    ADD CONSTRAINT settledeposit_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


--
-- Name: settlementenqueued_49194ff9_73f6f386 settlementenqueued_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.settlementenqueued_49194ff9_73f6f386
    ADD CONSTRAINT settlementenqueued_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


--
-- Name: settlementqueueprocessed_17786ebb_73f6f386 settlementqueueprocessed_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.settlementqueueprocessed_17786ebb_73f6f386
    ADD CONSTRAINT settlementqueueprocessed_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


--
-- Name: settlementsent_dac85f08_73f6f386 settlementsent_transaction_hash_transaction__key; Type: CONSTRAINT; Schema: shadow; Owner: -
--

ALTER TABLE ONLY shadow.settlementsent_dac85f08_73f6f386
    ADD CONSTRAINT settlementsent_transaction_hash_transaction__key UNIQUE (transaction_hash, transaction_log_index);


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
-- Name: assets_domain_token_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assets_domain_token_id_idx ON public.assets USING btree (token_id, domain);


--
-- Name: closedepochsprocessed_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX closedepochsprocessed_timestamp_idx ON public.closedepochsprocessed USING btree ("timestamp");


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
-- Name: depositenqueued_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX depositenqueued_timestamp_idx ON public.depositenqueued USING btree ("timestamp");


--
-- Name: depositprocessed_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX depositprocessed_timestamp_idx ON public.depositprocessed USING btree ("timestamp");


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
-- Name: finddepositdomain_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX finddepositdomain_timestamp_idx ON public.finddepositdomain USING btree ("timestamp");


--
-- Name: findinvoicedomain_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX findinvoicedomain_timestamp_idx ON public.findinvoicedomain USING btree ("timestamp");


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
-- Name: invoiceenqueued_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX invoiceenqueued_timestamp_idx ON public.invoiceenqueued USING btree ("timestamp");


--
-- Name: matchdeposit_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX matchdeposit_timestamp_idx ON public.matchdeposit USING btree ("timestamp");


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
-- Name: queues_domain_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX queues_domain_type_idx ON public.queues USING btree (domain, type);


--
-- Name: settledeposit_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settledeposit_timestamp_idx ON public.settledeposit USING btree ("timestamp");


--
-- Name: settlement_intents_auto_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settlement_intents_auto_id_index ON public.settlement_intents USING btree (auto_id);


--
-- Name: settlement_intents_id_domain_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settlement_intents_id_domain_index ON public.settlement_intents USING btree (id, domain);


--
-- Name: settlementenqueued_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settlementenqueued_timestamp_idx ON public.settlementenqueued USING btree ("timestamp");


--
-- Name: settlementqueueprocessed_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settlementqueueprocessed_timestamp_idx ON public.settlementqueueprocessed USING btree ("timestamp");


--
-- Name: settlementsent_timestamp_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settlementsent_timestamp_idx ON public.settlementsent USING btree ("timestamp");


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
-- Name: closedepochsprocessed_fa915858_73f6f386 closedepochsprocessed_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER closedepochsprocessed_set_timestamp_and_latency BEFORE INSERT ON shadow.closedepochsprocessed_fa915858_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: depositenqueued_2f2b1630_73f6f386 depositenqueued_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER depositenqueued_set_timestamp_and_latency BEFORE INSERT ON shadow.depositenqueued_2f2b1630_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: depositprocessed_ffe546d6_73f6f386 depositprocessed_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER depositprocessed_set_timestamp_and_latency BEFORE INSERT ON shadow.depositprocessed_ffe546d6_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: finddepositdomain_2744076b_73f6f386 finddepositdomain_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER finddepositdomain_set_timestamp_and_latency BEFORE INSERT ON shadow.finddepositdomain_2744076b_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: findinvoicedomain_e0b68ef7_73f6f386 findinvoicedomain_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER findinvoicedomain_set_timestamp_and_latency BEFORE INSERT ON shadow.findinvoicedomain_e0b68ef7_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: invoiceenqueued_81d2714b_73f6f386 invoiceenqueued_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER invoiceenqueued_set_timestamp_and_latency BEFORE INSERT ON shadow.invoiceenqueued_81d2714b_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: matchdeposit_883a2568_73f6f386 matchdeposit_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER matchdeposit_set_timestamp_and_latency BEFORE INSERT ON shadow.matchdeposit_883a2568_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: settledeposit_488e0804_73f6f386 settledeposit_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER settledeposit_set_timestamp_and_latency BEFORE INSERT ON shadow.settledeposit_488e0804_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: settlementenqueued_49194ff9_73f6f386 settlementenqueued_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER settlementenqueued_set_timestamp_and_latency BEFORE INSERT ON shadow.settlementenqueued_49194ff9_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: settlementqueueprocessed_17786ebb_73f6f386 settlementqueueprocessed_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER settlementqueueprocessed_set_timestamp_and_latency BEFORE INSERT ON shadow.settlementqueueprocessed_17786ebb_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: settlementsent_dac85f08_73f6f386 settlementsent_set_timestamp_and_latency; Type: TRIGGER; Schema: shadow; Owner: -
--

CREATE TRIGGER settlementsent_set_timestamp_and_latency BEFORE INSERT ON shadow.settlementsent_dac85f08_73f6f386 FOR EACH ROW EXECUTE FUNCTION shadow.set_timestamp_and_latency();


--
-- Name: solana_spoke_instructions process_cpi_events_trigger; Type: TRIGGER; Schema: solana; Owner: -
--

CREATE TRIGGER process_cpi_events_trigger BEFORE INSERT OR UPDATE ON solana.solana_spoke_instructions FOR EACH ROW EXECUTE FUNCTION public.process_cpi_events();


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
-- PostgreSQL database dump complete
--


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
    ('20250421233253');
