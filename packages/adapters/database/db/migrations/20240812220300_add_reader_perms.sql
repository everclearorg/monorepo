-- migrate:up
GRANT SELECT ON public.settlement_intents TO query;
GRANT SELECT ON public.settlement_intents TO reader;


-- migrate:down
REVOKE SELECT ON public.settlement_intents FROM query;
REVOKE SELECT ON public.settlement_intents FROM reader;

