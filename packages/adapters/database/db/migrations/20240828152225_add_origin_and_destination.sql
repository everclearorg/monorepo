-- migrate:up
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS origin_domain character varying(66);
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS destination_domain character varying(66);

-- migrate:down
ALTER TABLE public.messages DROP COLUMN origin_domain;
ALTER TABLE public.messages DROP COLUMN destination_domain;
