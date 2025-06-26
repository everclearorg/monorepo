-- migrate:up

CREATE OR REPLACE FUNCTION genStatus(origin_status intent_status, hub_status intent_status, settlement_status intent_status, has_calldata boolean)
RETURNS intent_status AS $$
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
$$ LANGUAGE plpgsql IMMUTABLE;


-- migrate:down

