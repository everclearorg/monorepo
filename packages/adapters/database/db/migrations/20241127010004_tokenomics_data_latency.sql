-- migrate:up

CREATE FUNCTION tokenomics.set_timestamp_and_latency() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
            NEW.insert_timestamp := CURRENT_TIMESTAMP;
            NEW.latency := NEW.insert_timestamp - TO_TIMESTAMP(NEW.block_timestamp);
            RETURN NEW;
        END;
    $$;

DO $$
DECLARE
    table_name TEXT;
    table_names TEXT[] := ARRAY[
        'bridge_in_error',
        'bridge_updated',
        'bridged_in',
        'bridged_lock',
        'bridged_lock_error',
        'bridged_out',
        'chain_gateway_added',
        'chain_gateway_removed',
        'early_exit',
        'eip712_domain_changed',
        'epoch_rewards_updated',
        'eth_withdrawn',
        'fee_info',
        'gateway_updated',
        'hub_gauge_updated',
        'lock_position',
        'mailbox_updated',
        'message_gas_limit_updated',
        'mint_message_sent',
        'new_lock_position',
        'ownership_transferred',
        'process_error',
        'retry_bridge_out',
        'retry_lock',
        'retry_message',
        'retry_mint',
        'retry_transfer',
        'return_fee_updated',
        'reward_claimed',
        'reward_metadata_updated',
        'rewards_claimed',
        'security_module_updated',
        'user',
        'vote_cast',
        'vote_delegated',
        'withdraw',
        'withdraw_eth'
    ];
BEGIN
    FOREACH table_name IN ARRAY table_names LOOP

        IF (public.table_exists(table_name, 'tokenomics')) THEN
            EXECUTE format('ALTER TABLE tokenomics.%s ADD COLUMN IF NOT EXISTS insert_timestamp timestamp', table_name);
            EXECUTE format('ALTER TABLE tokenomics.%s ADD COLUMN IF NOT EXISTS latency interval', table_name);
            EXECUTE format('CREATE TRIGGER %s_set_timestamp_and_latency BEFORE INSERT ON tokenomics.%s FOR EACH ROW EXECUTE FUNCTION tokenomics.set_timestamp_and_latency()',
                table_name, table_name);
            EXECUTE format('CREATE INDEX %s_timestamp_idx ON tokenomics.%s(insert_timestamp)', table_name, table_name);
        END IF;
    END LOOP;
END $$;

-- migrate:down

DROP FUNCTION IF EXISTS tokenomics.set_timestamp_and_latency();

