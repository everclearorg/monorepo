-- migrate:up
-- Update otc_sale_table schema

-- Rename columns
ALTER TABLE public.otc_sale_table RENAME COLUMN id TO order_id;
ALTER TABLE public.otc_sale_table RENAME COLUMN destination TO destinations;
ALTER TABLE public.otc_sale_table RENAME COLUMN token TO ticker_hash;

-- Add new columns
ALTER TABLE public.otc_sale_table ADD COLUMN transaction_hash TEXT NULL;
ALTER TABLE public.otc_sale_table ADD COLUMN expires_at TIMESTAMP NOT NULL;

-- migrate:down
-- Revert schema changes

-- Drop newly added columns
ALTER TABLE public.otc_sale_table DROP COLUMN IF EXISTS transaction_hash;
ALTER TABLE public.otc_sale_table DROP COLUMN IF EXISTS expires_at;

-- Rename columns back to their original names
ALTER TABLE public.otc_sale_table RENAME COLUMN order_id TO id;
ALTER TABLE public.otc_sale_table RENAME COLUMN destinations TO destination;
ALTER TABLE public.otc_sale_table RENAME COLUMN ticker_hash TO token;
