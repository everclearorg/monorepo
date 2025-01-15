-- migrate:up
ALTER TABLE public.tokens ADD COLUMN max_discount_bps BIGINT NOT NULL;

-- migrate:down
ALTER TABLE public.tokens DROP COLUMN max_discount_bps;
