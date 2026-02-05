-- migrate:up

CREATE OR REPLACE FUNCTION get_intent_status_order(status public.intent_status)
RETURNS INTEGER AS $$
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
        WHEN 'SETTLED' THEN 60
        WHEN 'SETTLED_AND_COMPLETED' THEN 61
        WHEN 'SETTLED_AND_MANUALLY_EXECUTED' THEN 62
        WHEN 'UNSUPPORTED' THEN 70
        WHEN 'UNSUPPORTED_RETURNED' THEN 71
        WHEN 'DELIVERED' THEN 80
        ELSE 0
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- A trigger function to enforce ascending intent status transitions
-- If a descending transition is attempted, the status is silently preserved (not updated)
CREATE OR REPLACE FUNCTION validate_ascending_status_transition()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

-- Create triggers for all intent tables
CREATE TRIGGER validate_origin_intent_status_transition
    BEFORE UPDATE OF status ON public.origin_intents
    FOR EACH ROW
    EXECUTE FUNCTION validate_ascending_status_transition();

CREATE TRIGGER validate_destination_intent_status_transition
    BEFORE UPDATE OF status ON public.destination_intents
    FOR EACH ROW
    EXECUTE FUNCTION validate_ascending_status_transition();

CREATE TRIGGER validate_hub_intent_status_transition
    BEFORE UPDATE OF status ON public.hub_intents
    FOR EACH ROW
    EXECUTE FUNCTION validate_ascending_status_transition();

CREATE TRIGGER validate_settlement_intent_status_transition
    BEFORE UPDATE OF status ON public.settlement_intents
    FOR EACH ROW
    EXECUTE FUNCTION validate_ascending_status_transition();

-- migrate:down

DROP TRIGGER IF EXISTS validate_origin_intent_status_transition ON public.origin_intents;
DROP TRIGGER IF EXISTS validate_destination_intent_status_transition ON public.destination_intents;
DROP TRIGGER IF EXISTS validate_hub_intent_status_transition ON public.hub_intents;
DROP TRIGGER IF EXISTS validate_settlement_intent_status_transition ON public.settlement_intents;

DROP FUNCTION IF EXISTS validate_ascending_status_transition();
DROP FUNCTION IF EXISTS get_intent_status_order(public.intent_status);

