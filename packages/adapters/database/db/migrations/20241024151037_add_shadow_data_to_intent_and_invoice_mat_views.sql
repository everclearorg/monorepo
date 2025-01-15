-- migrate:up

DROP MATERIALIZED VIEW IF EXISTS public.daily_metrics_by_chains_tokens;
DROP MATERIALIZED VIEW IF EXISTS public.daily_metrics_by_date;
DROP MATERIALIZED VIEW IF EXISTS public.invoices;
DROP MATERIALIZED VIEW IF EXISTS public.intents;

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
   FROM public.hub_invoices
    LEFT JOIN public.origin_intents ON origin_intents.id = hub_invoices.intent_id
    LEFT JOIN public.hub_intents ON origin_intents.id = hub_intents.id
    LEFT JOIN public.findinvoicedomain as findinvoicedomain ON origin_intents.id = findinvoicedomain.data__invoice_intent_id
    LEFT JOIN public.matchdeposit as matchdeposit ON origin_intents.id = matchdeposit.data__invoice_intent_id
  WITH NO DATA;

REFRESH MATERIALIZED VIEW public.invoices;

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
    genStatus(origin_intents.status, hub_intents.status, settlement_intents.status, hasCallData(origin_intents.data)) AS status,
    hasCallData(origin_intents.data) AS has_calldata,
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
  FROM public.origin_intents
    LEFT JOIN public.destination_intents ON origin_intents.id = destination_intents.id
    LEFT JOIN public.settlement_intents ON origin_intents.id = settlement_intents.id
    LEFT JOIN public.hub_intents ON origin_intents.id = hub_intents.id
    LEFT JOIN public.finddepositdomain as finddepositdomain ON origin_intents.id = finddepositdomain.data__intent_id
    LEFT JOIN public.settledeposit as settledeposit ON origin_intents.id = settledeposit.data__intent_id
  WITH NO DATA;

REFRESH MATERIALIZED VIEW public.intents;

CREATE MATERIALIZED VIEW public.daily_metrics_by_chains_tokens AS WITH metadata AS (
    SELECT Symbol AS symbol,
        CAST(Decimals AS INTEGER) AS decimal,
        CAST(DomainID AS INTEGER) AS domain_id,
        LOWER(Address) AS address,
        LOWER(
            CONCAT(
                '0x',
                LPAD(
                    SUBSTRING(
                        Address
                        FROM 3
                    ),
                    64,
                    '0'
                )
            )
        ) AS adopted_address
    FROM (
            VALUES (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    1,
                    '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    10,
                    '0x4200000000000000000000000000000000000006'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    56,
                    '0x2170Ed0880ac9A755fd29B2688956BD959F933F8'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    8453,
                    '0x4200000000000000000000000000000000000006'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    42161,
                    '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    1,
                    '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    10,
                    '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85'
                ),
                (
                    'USD Coin',
                    'USDC',
                    18,
                    56,
                    '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    8453,
                    '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    42161,
                    '0xaf88d065e77c8cC2239327C5EDb3A432268e5831'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    1,
                    '0xdAC17F958D2ee523a2206206994597C13D831ec7'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    10,
                    '0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'
                ),
                (
                    'Tether USD',
                    'USDT',
                    18,
                    56,
                    '0x55d398326f99059fF775485246999027B3197955'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    42161,
                    '0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    42161,
                    '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'
                )
        ) AS asset_data (AssetName, Symbol, Decimals, DomainID, Address)
),
netted_raw AS (
    SELECT DATE_TRUNC('day', to_timestamp(i.origin_timestamp)) AS day,
        CAST(i.origin_origin AS INTEGER) AS from_chain_id,
        i.origin_input_asset AS from_asset_address,
        fm.symbol AS from_asset_symbol,
        CAST(i.settlement_domain AS INTEGER) AS to_chain_id,
        i.settlement_asset AS to_asset_address,
        tm.symbol AS to_asset_symbol,
        SUM(i.origin_amount::float / (10 ^ 18)) AS netting_volume,
        AVG(
            (
                i.settlement_timestamp::FLOAT - i.origin_timestamp::FLOAT
            ) / 3600
        ) AS netting_avg_time_in_hrs,
        SUM(0.0001 * i.origin_amount::FLOAT / (10 ^ 18)) AS netting_protocol_revenue,
        COUNT(i.id) AS netting_total_intents,
        AVG(i.origin_amount::float / (10 ^ 18)) AS netting_avg_intent_size
    FROM public.intents i
        LEFT JOIN public.invoices inv ON i.id = inv.id
        LEFT JOIN metadata fm ON (
            i.origin_input_asset = fm.adopted_address
            AND CAST(i.origin_origin AS INTEGER) = fm.domain_id
        )
        LEFT JOIN metadata tm ON (
            LOWER(i.settlement_asset) = tm.address
            AND CAST(i.settlement_domain AS INTEGER) = tm.domain_id
        )
    WHERE inv.id IS NULL
        AND i.status = 'SETTLED_AND_COMPLETED'
        AND i.hub_status != 'DISPATCHED_UNSUPPORTED'
    GROUP BY 1,
        2,
        3,
        4,
        5,
        6,
        7
),
netted_final AS (
    SELECT day,
        from_chain_id,
        from_asset_address,
        from_asset_symbol,
        to_chain_id,
        to_asset_address,
        to_asset_symbol,
        netting_volume,
        netting_avg_intent_size,
        netting_protocol_revenue,
        netting_total_intents,
        netting_avg_time_in_hrs
    FROM netted_raw
),
settled_raw AS (
    SELECT DATE_TRUNC('day', to_timestamp(i.origin_timestamp)) AS day,
        CAST(i.origin_origin AS INTEGER) AS from_chain_id,
        i.origin_input_asset AS from_asset_address,
        fm.symbol AS from_asset_symbol,
        CAST(i.settlement_domain AS INTEGER) AS to_chain_id,
        i.settlement_asset AS to_asset_address,
        tm.symbol AS to_asset_symbol,
        AVG(
            (
                CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18)
            ) - (
                CAST(i.settlement_amount AS FLOAT) / 10 ^ tm.decimal
            )
        ) AS avg_discounts_by_mm,
        SUM(
            (
                CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18)
            ) - (
                CAST(i.settlement_amount AS FLOAT) / 10 ^ tm.decimal
            )
        ) AS discounts_by_mm,
        -- rewards
        AVG(
            CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18) - CAST(i.origin_amount AS FLOAT) / (10 ^ 18)
        ) AS avg_rewards_by_invoice,
        -- when calculating rewards, we take fee that out the baked in protocol_fee: SUM(fee_value * origin_amount)
        SUM(
            CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18) - CAST(i.origin_amount AS FLOAT) / (10 ^ 18) - (0.0001 * CAST(i.origin_amount AS FLOAT)) / (10 ^ 18)
        ) AS rewards_for_invoices,
        SUM(i.origin_amount::float / (10 ^ 18)) AS volume_settled_by_mm,
        COUNT(i.id) AS total_intents_by_mm,
        -- proxy for system to settle invoices
        AVG(
            (
                i.hub_settlement_enqueued_timestamp::FLOAT - i.hub_added_timestamp::FLOAT
            ) / 3600
        ) AS avg_time_in_hrs,
        ROUND(
            AVG(
                inv.hub_settlement_epoch - inv.hub_invoice_entry_epoch
            ),
            0
        ) AS avg_discount_epoch,
        SUM(0.0001 * i.origin_amount::FLOAT / (10 ^ 18)) AS protocol_revenue_mm
    FROM public.intents i
        INNER JOIN public.invoices inv ON i.id = inv.id
        LEFT JOIN metadata fm ON (
            i.origin_input_asset = fm.adopted_address
            AND CAST(i.origin_origin AS INTEGER) = fm.domain_id
        )
        LEFT JOIN metadata tm ON (
            LOWER(i.settlement_asset) = tm.address
            AND CAST(i.settlement_domain AS INTEGER) = tm.domain_id
        )
    WHERE i.status = 'SETTLED_AND_COMPLETED'
        AND i.hub_status IN ('DISPATCHED', 'SETTLED')
    GROUP BY 1,
        2,
        3,
        4,
        5,
        6,
        7
),
settled_final AS (
    SELECT day,
        from_chain_id,
        from_asset_address,
        from_asset_symbol,
        to_chain_id,
        to_asset_address,
        to_asset_symbol,
        volume_settled_by_mm,
        protocol_revenue_mm,
        total_intents_by_mm,
        discounts_by_mm,
        avg_discounts_by_mm,
        rewards_for_invoices,
        avg_rewards_by_invoice,
        avg_time_in_hrs AS avg_settlement_time_in_hrs_by_mm,
        ((discounts_by_mm) / volume_settled_by_mm) * 365 * 100 AS apy,
        avg_discount_epoch AS avg_discount_epoch_by_mm
    FROM settled_raw
)
SELECT -- groups
    COALESCE(n.day, s.day) AS day,
    COALESCE(n.from_chain_id, s.from_chain_id) AS from_chain_id,
    COALESCE(n.from_asset_address, s.from_asset_address) AS from_asset_address,
    COALESCE(n.from_asset_symbol, s.from_asset_symbol) AS from_asset_symbol,
    COALESCE(n.to_chain_id, s.to_chain_id) AS to_chain_id,
    COALESCE(n.to_asset_address, s.to_asset_address) AS to_asset_address,
    COALESCE(n.to_asset_symbol, s.to_asset_symbol) AS to_asset_symbol,
    -- metrics
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
    -- add the combinations of metrics here
    -- clearing volume
    COALESCE(n.netting_volume, 0) + COALESCE(s.volume_settled_by_mm, 0) AS total_volume,
    -- intents
    COALESCE(n.netting_total_intents, 0) + COALESCE(s.total_intents_by_mm, 0) AS total_intents,
    -- revenue
    COALESCE(n.netting_protocol_revenue, 0) + COALESCE(s.protocol_revenue_mm, 0) AS total_protocol_revenue,
    -- rebalancing fee
    COALESCE(n.netting_protocol_revenue, 0) + COALESCE(s.protocol_revenue_mm, 0) + COALESCE(s.discounts_by_mm, 0) AS total_rebalancing_fee
FROM netted_final n
    FULL OUTER JOIN settled_final s ON n.day = s.day
    AND n.from_chain_id = s.from_chain_id
    AND n.to_chain_id = s.to_chain_id
    AND n.from_asset_address = s.from_asset_address
    AND n.to_asset_address = s.to_asset_address WITH NO DATA;

REFRESH MATERIALIZED VIEW public.daily_metrics_by_chains_tokens;

CREATE MATERIALIZED VIEW public.daily_metrics_by_date AS WITH metadata AS (
    SELECT Symbol AS symbol,
        CAST(Decimals AS INTEGER) AS decimal,
        CAST(DomainID AS INTEGER) AS domain_id,
        LOWER(Address) AS address,
        LOWER(
            CONCAT(
                '0x',
                LPAD(
                    SUBSTRING(
                        Address
                        FROM 3
                    ),
                    64,
                    '0'
                )
            )
        ) AS adopted_address
    FROM (
            VALUES (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    1,
                    '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    10,
                    '0x4200000000000000000000000000000000000006'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    56,
                    '0x2170Ed0880ac9A755fd29B2688956BD959F933F8'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    8453,
                    '0x4200000000000000000000000000000000000006'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    42161,
                    '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    1,
                    '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    10,
                    '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85'
                ),
                (
                    'USD Coin',
                    'USDC',
                    18,
                    56,
                    '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    8453,
                    '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    42161,
                    '0xaf88d065e77c8cC2239327C5EDb3A432268e5831'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    1,
                    '0xdAC17F958D2ee523a2206206994597C13D831ec7'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    10,
                    '0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'
                ),
                (
                    'Tether USD',
                    'USDT',
                    18,
                    56,
                    '0x55d398326f99059fF775485246999027B3197955'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    42161,
                    '0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    42161,
                    '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'
                )
        ) AS asset_data (AssetName, Symbol, Decimals, DomainID, Address)
),
netted_raw AS (
    SELECT DATE_TRUNC('day', to_timestamp(i.origin_timestamp)) AS day,
        SUM(i.origin_amount::float / (10 ^ 18)) AS netting_volume,
        AVG(
            (
                i.settlement_timestamp::FLOAT - i.origin_timestamp::FLOAT
            ) / 3600
        ) AS netting_avg_time_in_hrs,
        SUM(0.0001 * i.origin_amount::FLOAT / (10 ^ 18)) AS netting_protocol_revenue,
        COUNT(i.id) AS netting_total_intents,
        AVG(i.origin_amount::float / (10 ^ 18)) AS netting_avg_intent_size
    FROM public.intents i
        LEFT JOIN public.invoices inv ON i.id = inv.id
        LEFT JOIN metadata fm ON (
            i.origin_input_asset = fm.adopted_address
            AND CAST(i.origin_origin AS INTEGER) = fm.domain_id
        )
        LEFT JOIN metadata tm ON (
            LOWER(i.settlement_asset) = tm.address
            AND CAST(i.settlement_domain AS INTEGER) = tm.domain_id
        )
    WHERE inv.id IS NULL
        AND i.status = 'SETTLED_AND_COMPLETED'
        AND i.hub_status != 'DISPATCHED_UNSUPPORTED'
    GROUP BY 1
),
netted_final AS (
    SELECT day,
        netting_volume,
        netting_avg_intent_size,
        netting_protocol_revenue,
        netting_total_intents,
        netting_avg_time_in_hrs
    FROM netted_raw
),
settled_raw AS (
    SELECT DATE_TRUNC('day', to_timestamp(i.origin_timestamp)) AS day,
        AVG(
            (
                CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18)
            ) - (
                CAST(i.settlement_amount AS FLOAT) / 10 ^ tm.decimal
            )
        ) AS avg_discounts_by_mm,
        SUM(
            (
                CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18)
            ) - (
                CAST(i.settlement_amount AS FLOAT) / 10 ^ tm.decimal
            )
        ) AS discounts_by_mm,
        -- rewards
        AVG(
            CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18) - CAST(i.origin_amount AS FLOAT) / (10 ^ 18)
        ) AS avg_rewards_by_invoice,
        -- when calculating rewards, we take fee that out the baked in protocol_fee: SUM(fee_value * origin_amount)
        SUM(
            CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18) - CAST(i.origin_amount AS FLOAT) / (10 ^ 18) - (0.0001 * CAST(i.origin_amount AS FLOAT)) / (10 ^ 18)
        ) AS rewards_for_invoices,
        SUM(i.origin_amount::float / (10 ^ 18)) AS volume_settled_by_mm,
        COUNT(i.id) AS total_intents_by_mm,
        -- proxy for system to settle invoices
        AVG(
            (
                i.hub_settlement_enqueued_timestamp::FLOAT - i.hub_added_timestamp::FLOAT
            ) / 3600
        ) AS avg_time_in_hrs,
        ROUND(
            AVG(
                inv.hub_settlement_epoch - inv.hub_invoice_entry_epoch
            ),
            0
        ) AS avg_discount_epoch,
        SUM(0.0001 * i.origin_amount::FLOAT / (10 ^ 18)) AS protocol_revenue_mm
    FROM public.intents i
        INNER JOIN public.invoices inv ON i.id = inv.id
        LEFT JOIN metadata fm ON (
            i.origin_input_asset = fm.adopted_address
            AND CAST(i.origin_origin AS INTEGER) = fm.domain_id
        )
        LEFT JOIN metadata tm ON (
            LOWER(i.settlement_asset) = tm.address
            AND CAST(i.settlement_domain AS INTEGER) = tm.domain_id
        )
    WHERE i.status = 'SETTLED_AND_COMPLETED'
        AND i.hub_status IN ('DISPATCHED', 'SETTLED')
    GROUP BY 1
),
settled_final AS (
    SELECT day,
        volume_settled_by_mm,
        protocol_revenue_mm,
        total_intents_by_mm,
        discounts_by_mm,
        avg_discounts_by_mm,
        rewards_for_invoices,
        avg_rewards_by_invoice,
        avg_time_in_hrs AS avg_settlement_time_in_hrs_by_mm,
        ((discounts_by_mm) / volume_settled_by_mm) * 365 * 100 AS apy,
        avg_discount_epoch AS avg_discount_epoch_by_mm
    FROM settled_raw
)
SELECT -- groups
    COALESCE(n.day, s.day) AS day,
    -- metrics
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
    -- add the combinations of metrics here
    -- clearing volume
    COALESCE(n.netting_volume, 0) + COALESCE(s.volume_settled_by_mm, 0) AS total_volume,
    -- intents
    COALESCE(n.netting_total_intents, 0) + COALESCE(s.total_intents_by_mm, 0) AS total_intents,
    -- revenue
    COALESCE(n.netting_protocol_revenue, 0) + COALESCE(s.protocol_revenue_mm, 0) AS total_protocol_revenue,
    -- rebalancing fee
    COALESCE(n.netting_protocol_revenue, 0) + COALESCE(s.protocol_revenue_mm, 0) + COALESCE(s.discounts_by_mm, 0) AS total_rebalancing_fee
FROM netted_final n
    FULL OUTER JOIN settled_final s ON n.day = s.day WITH NO DATA;

REFRESH MATERIALIZED VIEW public.daily_metrics_by_date;

-- Create metrics indices
CREATE INDEX daily_metrics_by_chains_tokens_day_index ON public.daily_metrics_by_chains_tokens USING btree (day);
CREATE INDEX daily_metrics_by_chains_tokens_from_chain_id_index ON public.daily_metrics_by_chains_tokens USING btree (from_chain_id);
CREATE INDEX daily_metrics_by_chains_tokens_to_chain_id_index ON public.daily_metrics_by_chains_tokens USING btree (to_chain_id);
CREATE INDEX daily_metrics_by_chains_tokens_from_asset_address_index ON public.daily_metrics_by_chains_tokens USING btree (from_asset_address);
CREATE INDEX daily_metrics_by_chains_tokens_to_asset_address_index ON public.daily_metrics_by_chains_tokens USING btree (to_asset_address);
CREATE INDEX daily_metrics_by_chains_tokens_from_asset_symbol_index ON public.daily_metrics_by_chains_tokens USING btree (from_asset_symbol);
CREATE INDEX daily_metrics_by_chains_tokens_to_asset_symbol_index ON public.daily_metrics_by_chains_tokens USING btree (to_asset_symbol);
CREATE INDEX daily_metrics_by_date_day_index ON public.daily_metrics_by_date USING btree (day);

-- Grant access to reader and query roles
GRANT SELECT ON public.invoices TO reader;
GRANT SELECT ON public.invoices TO query;
GRANT SELECT ON public.intents TO reader;
GRANT SELECT ON public.intents TO query;
GRANT SELECT ON public.daily_metrics_by_chains_tokens TO reader;
GRANT SELECT ON public.daily_metrics_by_chains_tokens TO query;
GRANT SELECT ON public.daily_metrics_by_date TO reader;
GRANT SELECT ON public.daily_metrics_by_date TO query;


-- migrate:down

DROP MATERIALIZED VIEW IF EXISTS public.daily_metrics_by_chains_tokens;
DROP MATERIALIZED VIEW IF EXISTS public.daily_metrics_by_date;
DROP MATERIALIZED VIEW IF EXISTS public.intents;
DROP MATERIALIZED VIEW IF EXISTS public.invoices;

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
   FROM public.hub_invoices
     LEFT JOIN public.origin_intents ON origin_intents.id = hub_invoices.intent_id
     LEFT JOIN public.hub_intents ON origin_intents.id = hub_intents.id
  WITH NO DATA;

REFRESH MATERIALIZED VIEW public.invoices;

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
    genStatus(origin_intents.status, hub_intents.status, settlement_intents.status, hasCallData(origin_intents.data)) AS status,
    hasCallData(origin_intents.data) AS has_calldata,
    hub_intents.auto_id AS hub_auto_id
  FROM public.origin_intents
    LEFT JOIN public.destination_intents ON origin_intents.id = destination_intents.id
    LEFT JOIN public.settlement_intents ON origin_intents.id = settlement_intents.id
    LEFT JOIN public.hub_intents ON origin_intents.id = hub_intents.id
  WITH NO DATA;

REFRESH MATERIALIZED VIEW public.intents;

CREATE MATERIALIZED VIEW public.daily_metrics_by_chains_tokens AS WITH metadata AS (
    SELECT Symbol AS symbol,
        CAST(Decimals AS INTEGER) AS decimal,
        CAST(DomainID AS INTEGER) AS domain_id,
        LOWER(Address) AS address,
        LOWER(
            CONCAT(
                '0x',
                LPAD(
                    SUBSTRING(
                        Address
                        FROM 3
                    ),
                    64,
                    '0'
                )
            )
        ) AS adopted_address
    FROM (
            VALUES (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    1,
                    '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    10,
                    '0x4200000000000000000000000000000000000006'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    56,
                    '0x2170Ed0880ac9A755fd29B2688956BD959F933F8'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    8453,
                    '0x4200000000000000000000000000000000000006'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    42161,
                    '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    1,
                    '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    10,
                    '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85'
                ),
                (
                    'USD Coin',
                    'USDC',
                    18,
                    56,
                    '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    8453,
                    '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    42161,
                    '0xaf88d065e77c8cC2239327C5EDb3A432268e5831'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    1,
                    '0xdAC17F958D2ee523a2206206994597C13D831ec7'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    10,
                    '0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'
                ),
                (
                    'Tether USD',
                    'USDT',
                    18,
                    56,
                    '0x55d398326f99059fF775485246999027B3197955'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    42161,
                    '0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    42161,
                    '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'
                )
        ) AS asset_data (AssetName, Symbol, Decimals, DomainID, Address)
),
netted_raw AS (
    SELECT DATE_TRUNC('day', to_timestamp(i.origin_timestamp)) AS day,
        CAST(i.origin_origin AS INTEGER) AS from_chain_id,
        i.origin_input_asset AS from_asset_address,
        fm.symbol AS from_asset_symbol,
        CAST(i.settlement_domain AS INTEGER) AS to_chain_id,
        i.settlement_asset AS to_asset_address,
        tm.symbol AS to_asset_symbol,
        SUM(i.origin_amount::float / (10 ^ 18)) AS netting_volume,
        AVG(
            (
                i.settlement_timestamp::FLOAT - i.origin_timestamp::FLOAT
            ) / 3600
        ) AS netting_avg_time_in_hrs,
        SUM(0.0001 * i.origin_amount::FLOAT / (10 ^ 18)) AS netting_protocol_revenue,
        COUNT(i.id) AS netting_total_intents,
        AVG(i.origin_amount::float / (10 ^ 18)) AS netting_avg_intent_size
    FROM public.intents i
        LEFT JOIN public.invoices inv ON i.id = inv.id
        LEFT JOIN metadata fm ON (
            i.origin_input_asset = fm.adopted_address
            AND CAST(i.origin_origin AS INTEGER) = fm.domain_id
        )
        LEFT JOIN metadata tm ON (
            LOWER(i.settlement_asset) = tm.address
            AND CAST(i.settlement_domain AS INTEGER) = tm.domain_id
        )
    WHERE inv.id IS NULL
        AND i.status = 'SETTLED_AND_COMPLETED'
        AND i.hub_status != 'DISPATCHED_UNSUPPORTED'
    GROUP BY 1,
        2,
        3,
        4,
        5,
        6,
        7
),
netted_final AS (
    SELECT day,
        from_chain_id,
        from_asset_address,
        from_asset_symbol,
        to_chain_id,
        to_asset_address,
        to_asset_symbol,
        netting_volume,
        netting_avg_intent_size,
        netting_protocol_revenue,
        netting_total_intents,
        netting_avg_time_in_hrs
    FROM netted_raw
),
settled_raw AS (
    SELECT DATE_TRUNC('day', to_timestamp(i.origin_timestamp)) AS day,
        CAST(i.origin_origin AS INTEGER) AS from_chain_id,
        i.origin_input_asset AS from_asset_address,
        fm.symbol AS from_asset_symbol,
        CAST(i.settlement_domain AS INTEGER) AS to_chain_id,
        i.settlement_asset AS to_asset_address,
        tm.symbol AS to_asset_symbol,
        AVG(
            (
                CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18)
            ) - (
                CAST(i.settlement_amount AS FLOAT) / 10 ^ tm.decimal
            )
        ) AS avg_discounts_by_mm,
        SUM(
            (
                CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18)
            ) - (
                CAST(i.settlement_amount AS FLOAT) / 10 ^ tm.decimal
            )
        ) AS discounts_by_mm,
        -- rewards
        AVG(
            CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18) - CAST(i.origin_amount AS FLOAT) / (10 ^ 18)
        ) AS avg_rewards_by_invoice,
        -- when calculating rewards, we take fee that out the baked in protocol_fee: SUM(fee_value * origin_amount)
        SUM(
            CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18) - CAST(i.origin_amount AS FLOAT) / (10 ^ 18) - (0.0001 * CAST(i.origin_amount AS FLOAT)) / (10 ^ 18)
        ) AS rewards_for_invoices,
        SUM(i.origin_amount::float / (10 ^ 18)) AS volume_settled_by_mm,
        COUNT(i.id) AS total_intents_by_mm,
        -- proxy for system to settle invoices
        AVG(
            (
                i.hub_settlement_enqueued_timestamp::FLOAT - i.hub_added_timestamp::FLOAT
            ) / 3600
        ) AS avg_time_in_hrs,
        ROUND(
            AVG(
                inv.hub_settlement_epoch - inv.hub_invoice_entry_epoch
            ),
            0
        ) AS avg_discount_epoch,
        SUM(0.0001 * i.origin_amount::FLOAT / (10 ^ 18)) AS protocol_revenue_mm
    FROM public.intents i
        INNER JOIN public.invoices inv ON i.id = inv.id
        LEFT JOIN metadata fm ON (
            i.origin_input_asset = fm.adopted_address
            AND CAST(i.origin_origin AS INTEGER) = fm.domain_id
        )
        LEFT JOIN metadata tm ON (
            LOWER(i.settlement_asset) = tm.address
            AND CAST(i.settlement_domain AS INTEGER) = tm.domain_id
        )
    WHERE i.status = 'SETTLED_AND_COMPLETED'
        AND i.hub_status IN ('DISPATCHED', 'SETTLED')
    GROUP BY 1,
        2,
        3,
        4,
        5,
        6,
        7
),
settled_final AS (
    SELECT day,
        from_chain_id,
        from_asset_address,
        from_asset_symbol,
        to_chain_id,
        to_asset_address,
        to_asset_symbol,
        volume_settled_by_mm,
        protocol_revenue_mm,
        total_intents_by_mm,
        discounts_by_mm,
        avg_discounts_by_mm,
        rewards_for_invoices,
        avg_rewards_by_invoice,
        avg_time_in_hrs AS avg_settlement_time_in_hrs_by_mm,
        ((discounts_by_mm) / volume_settled_by_mm) * 365 * 100 AS apy,
        avg_discount_epoch AS avg_discount_epoch_by_mm
    FROM settled_raw
)
SELECT -- groups
    COALESCE(n.day, s.day) AS day,
    COALESCE(n.from_chain_id, s.from_chain_id) AS from_chain_id,
    COALESCE(n.from_asset_address, s.from_asset_address) AS from_asset_address,
    COALESCE(n.from_asset_symbol, s.from_asset_symbol) AS from_asset_symbol,
    COALESCE(n.to_chain_id, s.to_chain_id) AS to_chain_id,
    COALESCE(n.to_asset_address, s.to_asset_address) AS to_asset_address,
    COALESCE(n.to_asset_symbol, s.to_asset_symbol) AS to_asset_symbol,
    -- metrics
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
    -- add the combinations of metrics here
    -- clearing volume
    COALESCE(n.netting_volume, 0) + COALESCE(s.volume_settled_by_mm, 0) AS total_volume,
    -- intents
    COALESCE(n.netting_total_intents, 0) + COALESCE(s.total_intents_by_mm, 0) AS total_intents,
    -- revenue
    COALESCE(n.netting_protocol_revenue, 0) + COALESCE(s.protocol_revenue_mm, 0) AS total_protocol_revenue,
    -- rebalancing fee
    COALESCE(n.netting_protocol_revenue, 0) + COALESCE(s.protocol_revenue_mm, 0) + COALESCE(s.discounts_by_mm, 0) AS total_rebalancing_fee
FROM netted_final n
    FULL OUTER JOIN settled_final s ON n.day = s.day
    AND n.from_chain_id = s.from_chain_id
    AND n.to_chain_id = s.to_chain_id
    AND n.from_asset_address = s.from_asset_address
    AND n.to_asset_address = s.to_asset_address WITH NO DATA;

REFRESH MATERIALIZED VIEW public.daily_metrics_by_chains_tokens;

CREATE MATERIALIZED VIEW public.daily_metrics_by_date AS WITH metadata AS (
    SELECT Symbol AS symbol,
        CAST(Decimals AS INTEGER) AS decimal,
        CAST(DomainID AS INTEGER) AS domain_id,
        LOWER(Address) AS address,
        LOWER(
            CONCAT(
                '0x',
                LPAD(
                    SUBSTRING(
                        Address
                        FROM 3
                    ),
                    64,
                    '0'
                )
            )
        ) AS adopted_address
    FROM (
            VALUES (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    1,
                    '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    10,
                    '0x4200000000000000000000000000000000000006'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    56,
                    '0x2170Ed0880ac9A755fd29B2688956BD959F933F8'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    8453,
                    '0x4200000000000000000000000000000000000006'
                ),
                (
                    'Wrapped Ether',
                    'WETH',
                    18,
                    42161,
                    '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    1,
                    '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    10,
                    '0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85'
                ),
                (
                    'USD Coin',
                    'USDC',
                    18,
                    56,
                    '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    8453,
                    '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'
                ),
                (
                    'USD Coin',
                    'USDC',
                    6,
                    42161,
                    '0xaf88d065e77c8cC2239327C5EDb3A432268e5831'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    1,
                    '0xdAC17F958D2ee523a2206206994597C13D831ec7'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    10,
                    '0x94b008aA00579c1307B0EF2c499aD98a8ce58e58'
                ),
                (
                    'Tether USD',
                    'USDT',
                    18,
                    56,
                    '0x55d398326f99059fF775485246999027B3197955'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    42161,
                    '0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'
                ),
                (
                    'Tether USD',
                    'USDT',
                    6,
                    42161,
                    '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9'
                )
        ) AS asset_data (AssetName, Symbol, Decimals, DomainID, Address)
),
netted_raw AS (
    SELECT DATE_TRUNC('day', to_timestamp(i.origin_timestamp)) AS day,
        SUM(i.origin_amount::float / (10 ^ 18)) AS netting_volume,
        AVG(
            (
                i.settlement_timestamp::FLOAT - i.origin_timestamp::FLOAT
            ) / 3600
        ) AS netting_avg_time_in_hrs,
        SUM(0.0001 * i.origin_amount::FLOAT / (10 ^ 18)) AS netting_protocol_revenue,
        COUNT(i.id) AS netting_total_intents,
        AVG(i.origin_amount::float / (10 ^ 18)) AS netting_avg_intent_size
    FROM public.intents i
        LEFT JOIN public.invoices inv ON i.id = inv.id
        LEFT JOIN metadata fm ON (
            i.origin_input_asset = fm.adopted_address
            AND CAST(i.origin_origin AS INTEGER) = fm.domain_id
        )
        LEFT JOIN metadata tm ON (
            LOWER(i.settlement_asset) = tm.address
            AND CAST(i.settlement_domain AS INTEGER) = tm.domain_id
        )
    WHERE inv.id IS NULL
        AND i.status = 'SETTLED_AND_COMPLETED'
        AND i.hub_status != 'DISPATCHED_UNSUPPORTED'
    GROUP BY 1
),
netted_final AS (
    SELECT day,
        netting_volume,
        netting_avg_intent_size,
        netting_protocol_revenue,
        netting_total_intents,
        netting_avg_time_in_hrs
    FROM netted_raw
),
settled_raw AS (
    SELECT DATE_TRUNC('day', to_timestamp(i.origin_timestamp)) AS day,
        AVG(
            (
                CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18)
            ) - (
                CAST(i.settlement_amount AS FLOAT) / 10 ^ tm.decimal
            )
        ) AS avg_discounts_by_mm,
        SUM(
            (
                CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18)
            ) - (
                CAST(i.settlement_amount AS FLOAT) / 10 ^ tm.decimal
            )
        ) AS discounts_by_mm,
        -- rewards
        AVG(
            CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18) - CAST(i.origin_amount AS FLOAT) / (10 ^ 18)
        ) AS avg_rewards_by_invoice,
        -- when calculating rewards, we take fee that out the baked in protocol_fee: SUM(fee_value * origin_amount)
        SUM(
            CAST(inv.hub_invoice_amount AS FLOAT) / (10 ^ 18) - CAST(i.origin_amount AS FLOAT) / (10 ^ 18) - (0.0001 * CAST(i.origin_amount AS FLOAT)) / (10 ^ 18)
        ) AS rewards_for_invoices,
        SUM(i.origin_amount::float / (10 ^ 18)) AS volume_settled_by_mm,
        COUNT(i.id) AS total_intents_by_mm,
        -- proxy for system to settle invoices
        AVG(
            (
                i.hub_settlement_enqueued_timestamp::FLOAT - i.hub_added_timestamp::FLOAT
            ) / 3600
        ) AS avg_time_in_hrs,
        ROUND(
            AVG(
                inv.hub_settlement_epoch - inv.hub_invoice_entry_epoch
            ),
            0
        ) AS avg_discount_epoch,
        SUM(0.0001 * i.origin_amount::FLOAT / (10 ^ 18)) AS protocol_revenue_mm
    FROM public.intents i
        INNER JOIN public.invoices inv ON i.id = inv.id
        LEFT JOIN metadata fm ON (
            i.origin_input_asset = fm.adopted_address
            AND CAST(i.origin_origin AS INTEGER) = fm.domain_id
        )
        LEFT JOIN metadata tm ON (
            LOWER(i.settlement_asset) = tm.address
            AND CAST(i.settlement_domain AS INTEGER) = tm.domain_id
        )
    WHERE i.status = 'SETTLED_AND_COMPLETED'
        AND i.hub_status IN ('DISPATCHED', 'SETTLED')
    GROUP BY 1
),
settled_final AS (
    SELECT day,
        volume_settled_by_mm,
        protocol_revenue_mm,
        total_intents_by_mm,
        discounts_by_mm,
        avg_discounts_by_mm,
        rewards_for_invoices,
        avg_rewards_by_invoice,
        avg_time_in_hrs AS avg_settlement_time_in_hrs_by_mm,
        ((discounts_by_mm) / volume_settled_by_mm) * 365 * 100 AS apy,
        avg_discount_epoch AS avg_discount_epoch_by_mm
    FROM settled_raw
)
SELECT -- groups
    COALESCE(n.day, s.day) AS day,
    -- metrics
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
    -- add the combinations of metrics here
    -- clearing volume
    COALESCE(n.netting_volume, 0) + COALESCE(s.volume_settled_by_mm, 0) AS total_volume,
    -- intents
    COALESCE(n.netting_total_intents, 0) + COALESCE(s.total_intents_by_mm, 0) AS total_intents,
    -- revenue
    COALESCE(n.netting_protocol_revenue, 0) + COALESCE(s.protocol_revenue_mm, 0) AS total_protocol_revenue,
    -- rebalancing fee
    COALESCE(n.netting_protocol_revenue, 0) + COALESCE(s.protocol_revenue_mm, 0) + COALESCE(s.discounts_by_mm, 0) AS total_rebalancing_fee
FROM netted_final n
    FULL OUTER JOIN settled_final s ON n.day = s.day WITH NO DATA;

REFRESH MATERIALIZED VIEW public.daily_metrics_by_date;

-- Create metrics indices
CREATE INDEX daily_metrics_by_chains_tokens_day_index ON public.daily_metrics_by_chains_tokens USING btree (day);
CREATE INDEX daily_metrics_by_chains_tokens_from_chain_id_index ON public.daily_metrics_by_chains_tokens USING btree (from_chain_id);
CREATE INDEX daily_metrics_by_chains_tokens_to_chain_id_index ON public.daily_metrics_by_chains_tokens USING btree (to_chain_id);
CREATE INDEX daily_metrics_by_chains_tokens_from_asset_address_index ON public.daily_metrics_by_chains_tokens USING btree (from_asset_address);
CREATE INDEX daily_metrics_by_chains_tokens_to_asset_address_index ON public.daily_metrics_by_chains_tokens USING btree (to_asset_address);
CREATE INDEX daily_metrics_by_chains_tokens_from_asset_symbol_index ON public.daily_metrics_by_chains_tokens USING btree (from_asset_symbol);
CREATE INDEX daily_metrics_by_chains_tokens_to_asset_symbol_index ON public.daily_metrics_by_chains_tokens USING btree (to_asset_symbol);
CREATE INDEX daily_metrics_by_date_day_index ON public.daily_metrics_by_date USING btree (day);

-- Grant access to reader and query roles
GRANT SELECT ON public.invoices TO reader;
GRANT SELECT ON public.invoices TO query;
GRANT SELECT ON public.intents TO reader;
GRANT SELECT ON public.intents TO query;
GRANT SELECT ON public.daily_metrics_by_chains_tokens TO reader;
GRANT SELECT ON public.daily_metrics_by_chains_tokens TO query;
GRANT SELECT ON public.daily_metrics_by_date TO reader;
GRANT SELECT ON public.daily_metrics_by_date TO query;