-- migrate:up
GRANT SELECT ON public.invoices TO reader;
GRANT SELECT ON public.intents TO reader;

-- migrate:down
REVOKE SELECT ON public.invoices FROM reader;
REVOKE SELECT ON public.intents FROM reader;

