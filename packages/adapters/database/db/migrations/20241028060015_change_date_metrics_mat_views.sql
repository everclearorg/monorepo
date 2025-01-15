-- migrate:up
-- Create the materialized view `daily_metrics`
DROP MATERIALIZED VIEW IF EXISTS public.daily_metrics_by_chains_tokens;
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
    SELECT DATE_TRUNC('day', to_timestamp(i.settlement_timestamp)) AS day,
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
        AND i.status IN ('SETTLED_AND_COMPLETED', 'SETTLED_AND_MANUALLY_EXECUTED')
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
    SELECT DATE_TRUNC('day', to_timestamp(i.settlement_timestamp)) AS day,
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
    WHERE i.status IN ('SETTLED_AND_COMPLETED', 'SETTLED_AND_MANUALLY_EXECUTED')
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
),
combined AS (
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
        AND n.to_asset_address = s.to_asset_address
)
SELECT *
FROM combined WITH NO DATA;

REFRESH MATERIALIZED VIEW public.daily_metrics_by_chains_tokens;

-- Grant access to reader and query roles
GRANT SELECT ON public.daily_metrics_by_chains_tokens TO reader;
GRANT SELECT ON public.daily_metrics_by_chains_tokens TO query;

-- migrate:down
DROP MATERIALIZED VIEW IF EXISTS public.daily_metrics_by_chains_tokens;