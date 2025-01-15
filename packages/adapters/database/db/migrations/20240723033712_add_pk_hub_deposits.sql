-- migrate:up
ALTER TABLE ONLY public.hub_deposits
    ADD CONSTRAINT hub_deposits_pkey PRIMARY KEY (id);


ALTER TABLE public.hub_deposits
    ALTER COLUMN domain TYPE character varying(66);


-- migrate:down
ALTER TABLE ONLY public.hub_deposits DROP CONSTRAINT IF EXISTS hub_deposits_pkey;

ALTER TABLE public.hub_deposits
    ALTER COLUMN domain TYPE character(66);
