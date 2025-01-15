-- migrate:up
ALTER TABLE public.assets DROP COLUMN decimals;

-- migrate:down
ALTER TABLE public.assets ADD COLUMN decimals numeric NOT NULL;

