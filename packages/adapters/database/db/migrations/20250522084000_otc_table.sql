-- migrate:up

CREATE TABLE otc_sale_table (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),     -- unique ID per entry
  partner_id TEXT NOT NULL,                          -- identifier for the partner
  origin INTEGER NOT NULL,                           -- origin domain_id
  destination INTEGER[] NOT NULL,                       -- destination domain_id
  token TEXT NOT NULL,                               -- ticker hash (e.g. bytes32 hex string)
  amount TEXT NOT NULL,                              -- decimal-formatted string (stored as TEXT)
  total_fee TEXT NOT NULL,                           -- also stored as TEXT, supports large decimals
  created_at TIMESTAMP DEFAULT NOW()                 -- optional timestamp
);

-- migrate:down

