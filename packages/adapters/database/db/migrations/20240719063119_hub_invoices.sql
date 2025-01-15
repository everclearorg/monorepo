-- migrate:up


CREATE TABLE public.hub_invoices (
    id character(66) NOT NULL,
    intent_id character(66) NOT NULL,
    amount bigint NOT NULL,
    ticker_hash character(66) NOT NULL,
    owner character(66) NOT NULL,
    entry_epoch bigint NOT NULL,
    enqueued_tx_nonce bigint,
    enqueued_timestamp bigint,
    auto_id bigint NOT NULL
);


CREATE SEQUENCE public.hub_invoices_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.hub_invoices_auto_id_seq OWNED BY public.hub_invoices.auto_id;


ALTER TABLE ONLY public.hub_invoices ALTER COLUMN auto_id SET DEFAULT nextval('public.hub_invoices_auto_id_seq'::regclass);

ALTER TABLE ONLY public.hub_invoices
    ADD CONSTRAINT hub_invoices_pkey PRIMARY KEY (id);


CREATE INDEX hub_invoices_auto_id_index ON public.hub_invoices USING btree (auto_id);


CREATE INDEX hub_invoices_domain_status_queue_id_idx ON public.hub_invoices USING btree (owner, id);


-- migrate:down

-- Drop indexes
DROP INDEX IF EXISTS public.hub_invoices_domain_status_queue_id_idx;
DROP INDEX IF EXISTS public.hub_invoices_auto_id_index;

-- Drop primary key constraint
ALTER TABLE ONLY public.hub_invoices DROP CONSTRAINT IF EXISTS hub_invoices_pkey;

-- Remove default value from auto_id (optional step, usually covered by dropping the table)
ALTER TABLE ONLY public.hub_invoices ALTER COLUMN auto_id DROP DEFAULT;

-- Drop the sequence
DROP SEQUENCE IF EXISTS public.hub_invoices_auto_id_seq;

-- Drop the table
DROP TABLE IF EXISTS public.hub_invoices;