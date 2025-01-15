-- migrate:up
DROP MATERIALIZED VIEW IF EXISTS public.router_balances;
DROP TABLE IF EXISTS routers CASCADE;
DROP TABLE IF EXISTS bids CASCADE;
DROP TABLE IF EXISTS auctions CASCADE;

-- migrate:down

--
-- Name: routers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routers (
    address character varying(66) NOT NULL,
    owner character varying(66) NOT NULL,
    supported_domains character varying(66)[] NOT NULL
);


--
-- Name: router_balances; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.router_balances AS
 SELECT r.address,
    r.owner,
    r.supported_domains,
    b.id,
    b.account,
    b.asset,
    b.amount
   FROM (public.routers r
     JOIN public.balances b ON (((r.address)::text = (b.account)::text)))
  WITH NO DATA;


--
-- Name: routers routers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routers
    ADD CONSTRAINT routers_pkey PRIMARY KEY (address);


--
-- Name: routers_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX routers_owner_idx ON public.routers USING btree (owner);

--
-- Name: bids; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bids (
    id character varying(255) NOT NULL,
    origin character varying(66) NOT NULL,
    auction character varying NOT NULL,
    router character(66) NOT NULL,
    fee character varying(255) NOT NULL,
    index bigint NOT NULL,
    transaction_hash character(66) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL
);
--
-- Name: bids bids_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bids
    ADD CONSTRAINT bids_pkey PRIMARY KEY (id);


CREATE TABLE public.auctions (
    id character varying(255) NOT NULL,
    origin character varying(66) NOT NULL,
    winner character varying(66),
    lowest_fee character varying(255),
    end_time bigint NOT NULL,
    bid_count bigint NOT NULL,
    transaction_hash character(66) NOT NULL,
    "timestamp" bigint NOT NULL,
    block_number bigint NOT NULL,
    tx_origin character varying(66) NOT NULL,
    tx_nonce bigint NOT NULL,
    auto_id bigint NOT NULL
);
--
-- Name: auctions_auto_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auctions_auto_id_index ON public.auctions USING btree (auto_id);


--
-- Name: auctions_auto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auctions_auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: auctions_auto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auctions_auto_id_seq OWNED BY public.auctions.auto_id;

-- Name: auctions auto_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auctions ALTER COLUMN auto_id SET DEFAULT nextval('public.auctions_auto_id_seq'::regclass);

