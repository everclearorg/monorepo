-- migrate:up
-- Add 'DELIVERED' to intent_status enum
ALTER TYPE public.intent_status ADD VALUE IF NOT EXISTS 'DELIVERED';

-- migrate:down
