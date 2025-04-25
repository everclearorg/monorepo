-- migrate:up

CREATE OR REPLACE FUNCTION public.parse_and_insert_new_intent_cpi_event(hex_data TEXT, rec record) RETURNS BOOLEAN AS $$
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
		'',
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

    RETURN TRUE;
END;$$
LANGUAGE PLPGSQL;

-- migrate:down

