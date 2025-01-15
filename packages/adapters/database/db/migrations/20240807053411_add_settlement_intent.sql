-- migrate:up
CREATE TABLE settlement_intents (
    id character(66) NOT NULL,
    amount character varying(255) NOT NULL,
    asset character varying(66) NOT NULL,
    recipient character varying(66) NOT NULL,
    update_virtual_balances boolean NOT NULL,
    domain character varying(66) NOT NULL,
    transaction_hash character(66) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL,
    auto_id bigint NOT NULL,
    gas_limit bigint NOT NULL,
    gas_price bigint NOT NULL
);

CREATE SEQUENCE public.settlement_intents_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.settlement_intents_auto_id_seq OWNED BY public.settlement_intents.auto_id;
ALTER TABLE ONLY public.settlement_intents ALTER COLUMN auto_id SET DEFAULT nextval('public.settlement_intents_auto_id_seq'::regclass);

ALTER TABLE ONLY public.settlement_intents
    ADD CONSTRAINT settlement_intents_pkey PRIMARY KEY (id);


CREATE INDEX settlement_intents_auto_id_index ON public.settlement_intents USING btree (auto_id);
CREATE INDEX settlement_intents_id_domain_index ON public.settlement_intents USING btree (id, domain);

GRANT SELECT ON public.settlement_intents TO query;



-- migrate:down
REVOKE SELECT ON public.settlement_intents FROM query;

DROP INDEX IF EXISTS public.settlement_intents_auto_id_index;
DROP INDEX IF EXISTS public.settlement_intents_id_domain_index;

ALTER TABLE ONLY public.settlement_intents DROP CONSTRAINT IF EXISTS settlement_intents_pkey;

DROP TABLE IF EXISTS public.settlement_intents;

DROP SEQUENCE IF EXISTS public.settlement_intents_auto_id_seq;