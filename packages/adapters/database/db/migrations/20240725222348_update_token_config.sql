-- migrate:up
ALTER TABLE public.tokens ADD COLUMN discount_per_epoch BIGINT NOT NULL;
ALTER TABLE public.tokens ADD COLUMN prioritized_strategy character varying(255) NOT NULL;;

-- migrate:down
ALTER TABLE public.tokens DROP COLUMN discount_per_epoch;
ALTER TABLE public.tokens DROP COLUMN prioritized_strategy;
