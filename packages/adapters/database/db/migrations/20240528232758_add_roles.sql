-- migrate:up
DO $do$ BEGIN IF EXISTS (
  SELECT
  FROM pg_catalog.pg_roles
  WHERE rolname = 'query'
) THEN RAISE NOTICE 'Role "query" already exists. Skipping.';
ELSE create role query nologin;
END IF;
END $do$;
GRANT CONNECT ON DATABASE everclear TO query;
grant usage on schema public to query;
grant select on public.origin_intents to query;
grant select on public.destination_intents to query;
grant select on public.hub_intents to query;
grant select on public.auctions to query;
grant select on public.messages to query;
DO $do$ BEGIN IF EXISTS (
  SELECT
  FROM pg_catalog.pg_roles
  WHERE rolname = 'reader'
) THEN RAISE NOTICE 'Role "reader" already exists. Skipping.';
ELSE create role reader noinherit login password '3eadooor';
END IF;
END $do$;
GRANT CONNECT ON DATABASE everclear TO reader;
grant usage on schema public to reader;
GRANT SELECT ON public.origin_intents TO reader;
GRANT SELECT ON public.destination_intents TO reader;
GRANT SELECT ON public.hub_intents TO reader;
GRANT SELECT ON public.messages TO reader;
GRANT SELECT ON public.queues TO reader;
GRANT SELECT ON public.bids TO reader;
GRANT SELECT ON public.auctions TO reader;
GRANT SELECT ON public.routers TO reader;
GRANT SELECT ON public.assets TO reader;
GRANT SELECT ON public.tokens TO reader;
GRANT SELECT ON public.depositors TO reader;
GRANT SELECT ON public.balances TO reader;
GRANT SELECT ON public.checkpoints TO reader;
grant query to reader;

-- migrate:down
REVOKE SELECT ON public.messages FROM query;
REVOKE SELECT ON public.auctions FROM query;
REVOKE SELECT ON public.hub_intents FROM query;
REVOKE SELECT ON public.destination_intents FROM query;
REVOKE SELECT ON public.origin_intents FROM query;
REVOKE USAGE ON SCHEMA public FROM query;
REVOKE CONNECT ON DATABASE everclear FROM query;
DROP ROLE IF EXISTS query;

REVOKE SELECT ON public.checkpoints FROM reader;
REVOKE SELECT ON public.balances FROM reader;
REVOKE SELECT ON public.depositors FROM reader;
REVOKE SELECT ON public.tokens FROM reader;
REVOKE SELECT ON public.assets FROM reader;
REVOKE SELECT ON public.routers FROM reader;
REVOKE SELECT ON public.auctions FROM reader;
REVOKE SELECT ON public.bids FROM reader;
REVOKE SELECT ON public.queues FROM reader;
REVOKE SELECT ON public.messages FROM reader;
REVOKE SELECT ON public.hub_intents FROM reader;
REVOKE SELECT ON public.destination_intents FROM reader;
REVOKE SELECT ON public.origin_intents FROM reader;
REVOKE USAGE ON SCHEMA public FROM reader;
REVOKE CONNECT ON DATABASE everclear FROM reader;
DROP ROLE IF EXISTS reader;