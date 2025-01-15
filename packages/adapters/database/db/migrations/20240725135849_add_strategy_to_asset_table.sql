-- migrate:up
ALTER TABLE public.assets ADD COLUMN strategy character varying(255) NOT NULL;

-- migrate:down
ALTER TABLE public.assets DROP COLUMN strategy;
