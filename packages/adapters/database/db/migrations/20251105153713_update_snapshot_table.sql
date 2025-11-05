-- migrate:up

-- Add INSERT permission for api role
GRANT INSERT ON public.swap_inventory_snapshots TO api;

-- Update table schema
ALTER TABLE public.swap_inventory_snapshots 
DROP COLUMN IF EXISTS threshold_status,
ADD COLUMN pending_inventory VARCHAR(78) NOT NULL,
ADD COLUMN reserved_count INTEGER NOT NULL DEFAULT 0,
DROP COLUMN IF EXISTS pending_intent_count,
ADD COLUMN pending_count INTEGER NOT NULL DEFAULT 0;

-- migrate:down

-- Revert schema changes
ALTER TABLE public.swap_inventory_snapshots 
DROP COLUMN IF EXISTS pending_inventory,
DROP COLUMN IF EXISTS reserved_count,
DROP COLUMN IF EXISTS pending_count,
ADD COLUMN pending_intent_count INTEGER NOT NULL DEFAULT 0,
ADD COLUMN threshold_status VARCHAR(20) NOT NULL DEFAULT 'normal';

-- Remove INSERT permission
REVOKE INSERT ON public.swap_inventory_snapshots FROM api;