-- migrate:up
GRANT SELECT ON public.routers TO query;

-- migrate:down
REVOKE SELECT ON public.routers FROM query;
