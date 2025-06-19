-- migrate:up

CREATE TABLE public.otc_sale_table (
  order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),    -- unique ID per entry
  partner_id TEXT NOT NULL,                               -- identifier for the partner
  origin INTEGER NOT NULL,                                -- origin domain_id
  destinations INTEGER[] NOT NULL,                        -- destinations domain_id
  ticker_hash TEXT NOT NULL,                              -- ticker hash (e.g. bytes32 hex string)
  amount TEXT NOT NULL,                                   -- decimal-formatted string (stored as TEXT)
  total_fee TEXT NOT NULL,                                -- also stored as TEXT, supports large decimals
  transaction_hash TEXT NULL,                             -- transaction hash of intent created for the order
  created_at TIMESTAMP DEFAULT NOW(),                     -- optional timestamp
  expires_at TIMESTAMP NOT NULL                           -- optional timestamp
);

-- migrate:down
DROP TABLE IF EXISTS public.otc_sale_table;
