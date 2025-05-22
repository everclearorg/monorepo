-- migrate:up
  
CREATE TABLE public.solana_lookup_tables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_address TEXT NOT NULL,                       -- base58
  mint_address TEXT NOT NULL,                       -- base58
  user_token_account TEXT NOT NULL,                 -- ATA
  program_vault_account TEXT NOT NULL,              -- PDA
  lookup_table_address TEXT NOT NULL,               -- created LUT address
  created_at TIMESTAMP DEFAULT NOW(),
  chain_id INT NOT NULL,                            -- chain id
  slot INT NOT NULL,                                -- slot number
  UNIQUE (user_address, mint_address)               -- enforce one LUT per (user, asset)
);


-- migrate:down
DROP TABLE IF EXISTS public.solana_lookup_tables;
