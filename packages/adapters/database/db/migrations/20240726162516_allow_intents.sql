-- migrate:up

GRANT SELECT ON public.intents TO query;


-- migrate:down

REVOKE SELECT ON public.intents FROM query;