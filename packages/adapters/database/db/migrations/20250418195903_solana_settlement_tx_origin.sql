-- migrate:up

CREATE OR REPLACE FUNCTION public.parse_and_insert_delivered_cpi_event(hex_data TEXT, rec record) RETURNS BOOLEAN AS $$
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
END;$$
    LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION public.parse_and_insert_settled_cpi_event(hex_data TEXT, rec record) RETURNS BOOLEAN AS $$
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
END;$$
LANGUAGE PLPGSQL;


-- migrate:down

