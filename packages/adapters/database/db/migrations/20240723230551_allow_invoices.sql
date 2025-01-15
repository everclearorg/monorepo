-- migrate:up

GRANT SELECT ON public.invoices TO query;


-- migrate:down

REVOKE SELECT ON public.invoices FROM query;